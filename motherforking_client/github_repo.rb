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
    next_page_relation = c.last_response.rels[:next]
    return Enumerator.new { |enum|
      loop do
        current_page.each { |issue|
          enum.yield issue
        }
        break if next_page_relation.nil?
        current_page = next_page_relation.get.data
        next_page_relation = c.last_response.rels[:next]
      end
    }
  end
  
  def full_name_from_url(repo_url)
    URI.parse(repo_url).path.strip('/')
  end
end