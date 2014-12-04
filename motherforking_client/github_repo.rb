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
    @full_name =
      if repo_name.count('/') == 1 then
        repo_name
      else
        full_name_from_url(repo_name)
      end
      
    @octokit_client = octokit_client
  end
  
  def fork()
  # This interface won't generalise when we start supporting Google Code or
  # Bitbucket and will need to change.
    new_repo_name = @octokit_client.fork(@full_name)[:full_name]
    @new_repo = GithubRepo.new(new_repo_name, @octokit_client)
  end
  
  def settings()
    repo_details = @octokit_client.repo @full_name
    return {
      description: repo_details.description,
      has_issues: repo_details.has_issues,
      has_wikis: repo_details.has_wikis,
      default_branch: repo_details.default_branch,
      private: repo_details.private
    }
  end
  
  def set_settings(settings)
    @octokit_client.edit_repository(@full_name, settings)
  end
  
  private
  
  def full_name_from_url(repo_url)
    URI.parse(repo_url).path.strip('/')
  end
end