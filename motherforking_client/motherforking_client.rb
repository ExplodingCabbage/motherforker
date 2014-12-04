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
    copy_issues()
    copy_pull_requests()
    copy_wikis()
    make_old_owner_a_collaborator()
    invite_old_collaborators()
  end
  
  private
  
  def copy_settings()
    @new_repo.set_settings(@old_repo.settings)
  end
  
  def copy_labels()
    raise "implement me"
  end
  
  def copy_issues()
    raise "implement me"
  end
  
  def copy_pull_requests()
    raise "implement me"
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