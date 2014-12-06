require 'uri'
require 'utils/string_extensions.rb'

# Represents a GithubRepo and provides methods for fetching and setting
# things.
# The interface here should be mimicked when adding support for new providers,
# like Bitbucket or Google Code
class GithubRepo
  # repo_name: either the full URL of the repo or the "full name" as returned by
  #            the GitHub API, e.g. "ExplodingCabbage/motherforker"
  # octokit_client: an Octokit::Client instance to use when making API requests.
  #                 Note that if the client hasn't been passed credentials, or
  #                 if the authenticated user doesn't have write permission to
  #                 this repo, then all write requests will fail.
  def initialize(repo_name, octokit_client)
    @repo_name =
      if repo_name.count('/') == 1 then
        repo_name
      else
        full_name_from_url(repo_name)
      end
      
    @octokit_client = octokit_client
  end
  
  def fork
  # This interface won't generalise when we start supporting Google Code or
  # Bitbucket and will need to change.
    new_repo_name = @octokit_client.fork(@repo_name)[:full_name]
    @new_repo = GithubRepo.new(new_repo_name, @octokit_client)
  end
  
  def settings
    repo_details = @octokit_client.repo @repo_name
    return {
      description: repo_details.description,
      has_issues: repo_details.has_issues,
      has_wikis: repo_details.has_wikis,
      default_branch: repo_details.default_branch,
      private: repo_details.private
    }
  end
  
  def set_settings(settings)
    @octokit_client.edit_repository(@repo_name, settings)
  end
  
  def labels
    label_resources = auto_paginate do
      @octokit_client.labels @repo_name
    end
    
    return label_resources.map { |resource| 
      {
        name: resource.name,
        color: resource.color
      }
    }
  end
  
  # Note: when adding Google Code support, something will need to be tweaked to
  #       work around the fact that Google Code doesn't have colors on labels.
  #       We'll want to autogenerate label colors, either within this method
  #       or prior to calling it.
  def set_labels(new_labels)
    existing_labels = labels
    existing_labels.each do |existing_label|
      should_exist = new_labels.any? do |new_label|
        new_label[:name] == existing_label[:name]
      end
      @octokit_client.delete_label!(
        @repo_name,
        existing_label[:name]
      ) unless should_exist
    end
    
    new_labels.each do |new_label|
      already_exists = existing_labels.any? do |existing_label| 
        new_label[:name] == existing_label[:name]
      end
      
      if already_exists
        @octokit_client.update_label(@repo_name, new_label[:name], new_label)
      else
        @octokit_client.add_label(
          @repo_name,
          new_label[:name],
          new_label[:color]
        )
      end
    end
  end
  
  def issues_and_pull_requests
    Enumerator.new do |enum|
      raw_issues = enumerate_paginated do
        @octokit_client.list_issues(@repo_name, {
          sort: "created",
          direction: "asc",
          state: "all"
        })
      end
      raw_issues.each do |raw_issue|
        raw_comments = @octokit_client.issue_comments(
          @repo_name,
          raw_issue[:number]
        )
        comments = raw_comments.map do |raw_comment|
          {
            id: raw_comment[:id],
            author: raw_comment[:user][:login],
            date: raw_comment[:created_at]
          }
        end
        
        is_pull_request = raw_issue.has_key?("pull_request")
        
        issue = {
          number: raw_issue[:number],
          url: raw_issue[:html_url],
          title: raw_issue[:title],
          body: raw_issue[:body],
          labels: raw_issue[:labels].map { |label_hash| label_hash[:name] },
          author: raw_issue[:user][:login],
          date: raw_issue[:created_at],
          closed: raw_issue[:state] == 'closed',
          close_date: raw_issue[:closed_at],
          comments: comments,
          site: :github,
          is_pull_request: is_pull_request
        }
        
        if is_pull_request
          raise "TODO: Implement me"
        end
        
        enum.yield()
      end
    end
  end
  
  # Takes an issue from some other repo and duplicates it on the new one.
  # issue must be a hash with the following keys:
  #   :number - the issue number
  #   :url - link to the old issue
  #   :title - issue title
  #   :body - issue body in a Github-compatible format
  #   :labels - array of label names
  #   :author - name of original author
  #   :date - a Time object representing the UTC time the issue was posted
  #   :closed - boolean, whether the issue is closed
  #   :close_date - optional Time only to be provided if the issue is closed
  #   :comments - array of comments, each with an author, body and date
  #   :site - the site - either :github, :googlecode or :bitbucket - on which
  #           the issue was originally opened.
  #
  # Note that what this method does depends upon the state of the repo.
  # * If the issue has already been copied (determined by baking a link to the
  #   original issue into the copy) then it does nothing.
  # * If the issue has not yet been copied, but cannot be copied in an
  #   issue-number-preserving way (because the number has already been taken, 
  #   or the immediately prior issue number has not yet been taken), then it
  #   raises an exception.
  # * Otherwise, it creates the issue.
  def create_issue_if_not_exists(issue)
    existing_issue = begin
      @octokit_client.issue(@repo_name, issue[:number])
    rescue Octokit::NotFound
      nil
    end
    
    if existing_issue.nil?
      if issue[:number] != 1
        begin
          @octokit_client.issue(@repo_name, issue[:number]-1).nil?
        rescue Octokit::NotFound
          raise "Cannot create issue\n#{issue.to_s}\nbecause the previous "\
                "issue does not yet exist."
        end
      end
      
      create_issue(issue)
    elsif existing_issue[:body].include? issue[:url]
      # Issue has already been created on a previous pass; perhaps we crashed
      # after creating it?
      # Anyway, nothing more to do.
      return
    else
      raise "An issue with the desired ID already exists, but it seems to be "\
            "a separate issue from the one we're trying to create now; the "\
            "motherforker always creates issues containing a link back to "\
            "the original, but there is no such link in this case.\n"\
            "Issue that caused the failure:\n" + issue.to_s
    end      
  end
  
  private
  
  # Takes a block that should perform a GET using @octokit_client and yield the
  # result.
  # Uses autopagination to ensure that ALL results are included.
  def auto_paginate
    previous_setting = @octokit_client.auto_paginate
    @octokit_client.auto_paginate = true
    result = yield
    @octokit_client.auto_paginate = previous_setting
    result
  end
  
  # Takes a block that should perform a GET using the @octokit_client and yield
  # the result.
  # Uses the 'link' headers to fetch each subsequent page when needed.
  # Returns an enumerator that does all of the above.
  def enumerate_paginated
    current_page = yield
    next_page_relation = @octokit_client.last_response.rels[:next]
    return Enumerator.new { |enum|
      loop do
        current_page.each { |issue|
          enum.yield issue
        }
        break if next_page_relation.nil?
        current_page = next_page_relation.get.data
        next_page_relation = @octokit_client.last_response.rels[:next]
      end
    }
  end
  
  def create_issue(issue)
    # A hack: we don't want to notify everybody mentioned in the issue upon its
    # creation (since that would be really obnoxious and spam the fuck out of
    # everybody who was involved with the previous repo.) We avoid this by
    # creating all our posts with empty bodies and then editing their content.
    # Editing posts on GitHub does not generate notifications.
    new_issue = @octokit_client.create_issue(@repo_name, issue[:title], '')
    if new_issue[:number] != issue[:number]
      raise "Huh? newly created issue doesn't have the issue number expected"
    end
    
    @octokit_client.update_issue(@repo_name, issue[:number], {
      body: body_for_issue(issue),
      state: issue[:closed] ? 'closed' : 'open',
      labels: issue[:labels]
    })
    
    issue[:comments].each do |comment|
      # We apply the same hack that we used for the issue itself - we create
      # a placeholder comment first, then edit its contents, thus avoiding
      # notifying anybody.
      new_comment = @octokit_client.add_comment(
        @repo_name,
        issue[:number],
        "I am a placeholder."
      )
      
      @octokit_client.update_comment(
        @repo_name,
        new_comment[:id],
        body_for_comment(comment, issue[:site])
      )
    end
    
    if issue[:closed]
      formatted_date = issue[:close_date].strftime("%Y-%m-%d at %H:%M (UTC)")
      @octokit_client.add_comment(
        @repo_name,
        issue[:number],
        "Motherforker note: this issue was originally closed on #{formatted_date}."
      )
    end
  end
  
  # Spits out a new body for the issue. This will just consist of the old body
  # with a header on top reading something along the lines of:
  #
  #     Issue originally opened by @ExplodingCabbage on 2014-05-02.
  #     Original issue: https://github.com/ExplodingCabbage/somerepo/issues/3
  def body_for_issue(issue)
    if issue[:site] == :github
      username = '@' + issue[:author]
    else
      username = issue[:author]
    end
    
    formatted_date = issue[:date].strftime("%Y-%m-%d at %H:%M (UTC)")
    header = "Issue originally opened by #{username} on #{formatted_date}, "\
             "and migrated by the [Motherforker](https://github.com/ExplodingCabbage/motherforker).\n\n"\
             "Original issue: #{issue[:url]}\n\n"\
             "----------------------------------------------\n\n"
             
    return header + issue[:body]
  end
  
  # Analagous to body_for_issue, but for comments
  def body_for_comment(comment, site)
    if site == :github
      username = '@' + comment[:author]
    else
      username = comment[:author]
    end
    
    formatted_date = comment[:date].strftime("%Y-%m-%d at %H:%M (UTC)")
    header = "comment originally posted by #{username} on #{formatted_date}, "\
             "and migrated by the [Motherforker](https://github.com/ExplodingCabbage/motherforker).\n\n"\
             "Original comment: #{comment[:url]}\n\n"\
             "----------------------------------------------\n\n"
             
    return header + comment[:body]
  end
  
  def full_name_from_url(repo_url)
    URI.parse(repo_url).path.strip('/')
  end
end