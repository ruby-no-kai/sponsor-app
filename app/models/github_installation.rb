require 'jwt'

class GithubInstallation
  GITHUB_MEDIA_TYPE = 'application/vnd.github.machine-man-preview+json'

  attr_reader :repo_name

  def initialize(repo_name, branch: nil)
    @repo_name = repo_name
    @branch = branch
    @octokit = nil
    @app_octokit = nil
    @github_installation_token = nil
  end

  def octokit
    @octokit ||= Octokit::Client.new(
      access_token: github_installation_token,
    )
  end

  def base_branch
    @base_branch ||= @branch || default_branch
  end

  private

  def github_installation_token
    @github_installation_token ||= begin
      installation = app_octokit.find_repository_installation(repo_name, accept: GITHUB_MEDIA_TYPE)
      raise "no github app installation found for #{repo_name.inspect}" unless installation

      issuance = app_octokit.create_app_installation_access_token(installation[:id], accept: GITHUB_MEDIA_TYPE)
      issuance[:token]
    end
  end

  def app_octokit
    @app_octokit ||= Octokit::Client.new(
      bearer_token: github_jwt,
    )
  end

  def github_jwt
    iat = Time.now.to_i
    payload = {
      iss: Rails.application.config.x.github.app_id,
      iat:,
      exp: iat + (3 * 60),
    }
    JWT.encode(payload, Rails.application.config.x.github.private_key, 'RS256')
  end

  def default_branch
    octokit.repository(repo_name)[:default_branch]
  end
end
