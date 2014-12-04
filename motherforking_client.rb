class MotherforkingClient
  def initialize(login: nil, password: nil, access_token: nil)
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
    
    @user = @octokit_client.user
    @user.login
  end
  
  def motherfork(old_repo)
    new_repo = fork(old_repo)
    copy_features_settings(old_repo, new_repo)
    copy_labels(old_repo, new_repo)
    copy_issues(old_repo, new_repo)
    copy_pull_requests(old_repo, new_repo)
    copy_wikis(old_repo, new_repo)
    make_old_owner_a_collaborator(old_repo, new_repo)
    invite_old_collaborators(old_repo, new_repo)
  end
  
  private
  
  def fork(repo)
    @octokit_client.fork(repo)[:full_name]
  end
  
  def copy_features_settings(old_repo, new_repo)
    raise "implement me"
  end
  
  def copy_labels(old_repo, new_repo)
    raise "implement me"
  end
  
  def copy_issues(old_repo, new_repo)
    raise "implement me"
  end
  
  def copy_pull_requests(old_repo, new_repo)
    raise "implement me"
  end
  
  def copy_wikis(old_repo)
    raise "implement me"
  end
  
  def make_old_owner_a_collaborator(old_repo, new_repo)
    raise "implement me"
  end
  
  def invite_old_collaborators(old_repo, new_repo)
    raise "implement me"
  end
end