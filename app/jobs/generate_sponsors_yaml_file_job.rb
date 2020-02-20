class GenerateSponsorsYamlFileJob < ApplicationJob
  GITHUB_MEDIA_TYPE = 'application/vnd.github.machine-man-preview+json'

  def perform(conference, push: true)
    @conference = conference

    if push
      push_to_github
    end
  end

  def repo
    @conference.github_repo
  end

  def data
    sponsorships = @conference.sponsorships
      .have_presence
      .order(id: :asc)
      .includes(:plan)
      .includes(:organization)
      .includes(:asset_file)
      .group_by { |_| _.plan.name.downcase.gsub(/[^a-z0-9]/, '_') }

    @last_id = SponsorshipEditingHistory.where(sponsorship_id: sponsorships.each_value.flat_map { |_| _.map(&:id) }).order(id: :desc).limit(1).pluck(:id)[0]

    sponsorships.map do |base_plan_slug, sponsorships|
      [
        base_plan_slug,
        {
          base_plan: sponsorships[0].plan.name.downcase,
          plans: sponsorships.group_by { |_| _.plan_name.downcase.gsub(/[^a-z0-9]/, '_') }.map do |plan_slug, sponsors|
            [
              plan_slug,
              {
                plan_name: sponsors[0].plan_name,
                sponsors: sponsors.map do |_|
                {
                  id: _.id,
                  asset_file_id: _.asset_file&.id,
                  base_plan: _.plan.name.downcase,
                  plan_name: _.plan_name,
                  slug: _.slug,
                  name: _.name,
                  url: _.url,
                  profile: _.profile,
                }
              end,
              },
            ]
          end.to_h,
        },
      ]
    end.to_h
  end

  def yaml_data
    return @yaml_data if defined? @yaml_data

    data = self.data()
    @yaml_data = [
      "# last_editing_history: #{@last_id}",
      data.to_yaml,
      "",
    ].join("\n")
  end

  def json_data
    return @json_data if defined? @json_data

    data = self.data()
    @json_data = "#{data.to_json}\n"
  end

  def push_to_github
    return unless repo
    yaml_data # to generate
    @branch_name = "sponsor-app/#{@last_id}"
    @filepath = repo.path

    begin
      octokit.delete_branch(repo.name, @branch_name)
    rescue Octokit::UnprocessableEntity
    end

    head = octokit.branch(repo.name, base_branch)
    octokit.create_ref(repo.name, "refs/heads/#{@branch_name}", head[:commit][:sha])

    begin
      blob_sha = octokit.contents(repo.name, path: @filepath)[:sha]
    rescue Octokit::NotFound
      blob_sha = nil
    end

    octokit.update_contents(
      repo.name,
      @filepath,
      "Update sponsors.yml for #{@conference.slug} (#{@last_id})",
      blob_sha,
      yaml_data,
      branch: @branch_name,
    )
    octokit.create_pull_request(
      repo.name,
      base_branch,
      @branch_name,
      "Update sponsors.yml for #{@conference.slug} (#{@last_id})",
      nil,
    )
  end

  def base_branch
    @base_branch ||= repo.branch || default_branch
  end

  def default_branch
    octokit.repository(repo.name)[:default_branch]
  end

  def octokit
    @octokit ||= Octokit::Client.new(
      access_token: github_installation_token,
    )
  end

  def github_installation_token
    return @github_installation_token if defined? @github_installation_token

    installation = app_octokit.find_repository_installation(repo.name, accept: GITHUB_MEDIA_TYPE)
    raise "no github app installation found for #{repo.name.inspect}" unless installation

    issuance = app_octokit.create_app_installation_access_token(installation[:id], accept: GITHUB_MEDIA_TYPE)
    @github_installation_token = issuance[:token]
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
      iat: iat,
      exp: iat + (3*60),
    }
    JWT.encode(payload, Rails.application.config.x.github.private_key, 'RS256')
  end

  # For debugging
  def self.get_octokit(repo)
    self.new(Struct.new(:github_repo).new(Struct.new(:name).new(repo)), push: false).tap(&:perform_now).octokit
  end
end
