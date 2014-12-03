class MotherforkingClient
  def initialize (login: nil, password: nil, access_token: nil)
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
end