require 'motherforking_client/github_repo'

class MotherforkingClient
  # repo_to_fork: the URL or full_name of the repo to be forked
  # login,
  # password,
  # access_token: user credentials corresponding to the arguments of the same
  #               names in Octokit::Client.new.
  #               If appropriate credentials are not passed, write requests
  #               will fail.
  def initialize(repo_to_fork, login: nil, password: nil, access_token: nil)
    if login && password
      @octokit_client = Octokit::Client.new(
        login: login,
        password: password
      )
    elsif access_token
      @octokit_client = Octokit::Client.new(
        access_token: access_token
      )
    else
      raise ArgumentError, "Neither login and password nor access_token given"
    end
    
    @old_repo = GithubRepo.new(repo_to_fork, @octokit_client)
    @new_repo = nil;
  end
  
  def motherfork()
    @new_repo = @old_repo.fork
    copy_settings()
    copy_labels()
    copy_issues_and_pull_requests()
    copy_wikis()
    make_old_owner_a_collaborator()
    invite_old_collaborators()
  end
  
  private
  
  def copy_settings()
    @new_repo.set_settings(@old_repo.settings)
  end
  
  def copy_labels()
    @new_repo.set_labels(@old_repo.labels)
  end
  
  def copy_issues_and_pull_requests()
    # It would be nice to be able to split this up into a copy_issues method and
    # a copy_pull_requests method for simplicity, but unfortunately we can't; we
    # want to preserve the numbering of issues and pull requests when copying
    # them so that references to them using #1234 syntax, either from commit 
    # messages or from other issues, will not be broken. Since issues and pull
    # requests on GitHub are numbered by the same counter, and we can only
    # control the numbering given to issues by creating them in the same order
    # as they were originally created, we are forced to interweave the migration
    # of issues and migration of pull requests.
    
    # TODO: Throwing an exception here when we detect that there are already
    #       some incompatible issues won't do. We need to ask the user to
    #       confirm that they're happy to proceed knowing that the issue
    #       numbering will be screwed up.
    previous_id = 0
    @old_repo.issues_and_pull_requests.each do |issue|
      raise "ids should be sequential" unless issue[:id] != previous_id+1
      
      if issue[:is_pull_request]
        @new_repo.create_pull_request_if_not_exists issue
      else
        @new_repo.create_issue_if_not_exists issue
      end
    end
  end
  
  def copy_wikis(old_repo)
    raise "implement me"
  end
  
  def make_old_owner_a_collaborator()
    raise "implement me"
  end
  
  def invite_old_collaborators()
    raise "implement me"
  end
end