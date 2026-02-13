class GenerateSponsorsYamlFileJob < ApplicationJob
  delegate :octokit, :base_branch, to: :github_installation

  def perform(conference, push: true)
    @conference = conference

    yaml_data # to generate
    if push
      ApplicationRecord.transaction do
        @last&.lock!
        push_to_github
      end
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

    @last = SponsorshipEditingHistory.where(sponsorship_id: sponsorships.each_value.flat_map { |_| _.map(&:id) }).order(id: :desc).first
    unless @last # this is falsy if no sponsorships have presense
      Rails.logger.warn "Conference #{@conference.slug} (#{@conference.id}) have no sponsorships with presense, resulting null sponsors data"
      return nil
    end
    @last_id = @last.id

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
                  url: _.url.strip,
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

  def events_data
    events = @conference.sponsor_events
      .accepted
      .includes(sponsorship: :organization)
      .order(starts_at: :asc)

    @last_event_editing_history_id = SponsorEventEditingHistory
      .where(sponsor_event_id: events.map(&:id))
      .maximum(:id)

    events.map do |event|
      hosts = event.all_host_sponsorships.map do |sponsorship|
        {
          slug: sponsorship.slug,
          name: sponsorship.name,
          url: sponsorship.url,
        }
      end

      {
        id: event.id,
        slug: event.slug,
        title: event.title,
        starts_at: event.starts_at.iso8601,
        url: event.url,
        price: event.price,
        capacity: event.capacity,
        location_en: event.location_en,
        location_local: event.location_local,
        link_name: event.link_name,
        hosts:,
      }.compact
    end
  end

  def yaml_data
    return @yaml_data if defined? @yaml_data

    data = self.data()
    events = events_data
    if data.nil? && events.blank?
      @yaml_data = nil
      return @yaml_data
    end

    combined_data = data ? data.merge("_events" => events) : { "_events" => events }
    comment_parts = []
    comment_parts << "last_editing_history: #{@last_id}" if @last_id
    comment_parts << "last_event_editing_history: #{@last_event_editing_history_id}" if @last_event_editing_history_id
    @yaml_data = [
      "# #{comment_parts.join(', ')}",
      combined_data.to_yaml,
      "",
    ].join("\n")
  end

  def json_data
    return @json_data if defined? @json_data

    data = self.data()
    @json_data = data ? "#{data.to_json}\n" : nil
  end

  def push_to_github
    return unless repo
    return if yaml_data.nil? # to generate
    push_id = @last_id || "event-#{@last_event_editing_history_id}"
    @branch_name = "sponsor-app/#{push_id}"
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
      "Update sponsors.yml for #{@conference.slug} (#{push_id})",
      blob_sha,
      yaml_data,
      branch: @branch_name,
    )
    octokit.create_pull_request(
      repo.name,
      base_branch,
      @branch_name,
      "Update sponsors.yml for #{@conference.slug} (#{push_id})",
      nil,
    )
  end

  # For debugging
  def self.get_octokit(repo)
    GithubInstallation.new(repo).octokit
  end

  private

  def github_installation
    @github_installation ||= GithubInstallation.new(repo.name, branch: repo.branch)
  end
end
