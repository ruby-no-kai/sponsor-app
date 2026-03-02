class GenerateSponsorsYamlFileJob < ApplicationJob
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
    comment_parts = [
      "last_editing_history: #{@last_id || 0}",
      "last_event_editing_history: #{@last_event_editing_history_id || 0}",
    ]
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
    return if yaml_data.nil?

    push_id = @last_id || "event-#{@last_event_editing_history_id}"
    GitHubPusher.new(
      conference: @conference,
      filepath: repo.path,
      content: yaml_data,
      last_editing_history_id: @last_id,
      last_event_editing_history_id: @last_event_editing_history_id,
      push_id:,
      build_summary: method(:build_edit_summary),
    ).push
  end

  private

  def build_edit_summary(from_last_id, from_last_event_id)
    last_id = @last_id || 0
    last_event_id = @last_event_editing_history_id || 0
    sections = []

    if from_last_id < last_id
      edits = SponsorshipEditingHistory
        .where(id: (from_last_id + 1)..last_id)
        .includes(:sponsorship, :staff)
        .order(id: :asc)
      if edits.any?
        lines = edits.map do |edit|
          actor = edit.staff ? "#{edit.staff.login} (staff)" : "sponsor"
          fields = edit.diff_summary.map { |s| "`#{s}`" }.join(", ")
          "- **#{edit.sponsorship.name}** (#{fields}) — by #{actor}"
        end
        sections << "**Sponsorship changes:**\n#{lines.join("\n")}"
      end
    end

    if from_last_event_id < last_event_id
      event_edits = SponsorEventEditingHistory
        .where(id: (from_last_event_id + 1)..last_event_id)
        .includes(:sponsor_event, :staff)
        .order(id: :asc)
      if event_edits.any?
        lines = event_edits.map do |edit|
          actor = edit.staff ? "#{edit.staff.login} (staff)" : "sponsor"
          fields = edit.diff_summary.map { |s| "`#{s}`" }.join(", ")
          "- **#{edit.sponsor_event.title}** (#{fields}) — by #{actor}"
        end
        sections << "**Event changes:**\n#{lines.join("\n")}"
      end
    end

    sections.any? ? sections.join("\n\n") : nil
  end

  # For debugging
  def self.get_octokit(repo)
    GithubInstallation.new(repo).octokit
  end

  class GitHubPusher
    MAX_RETRIES = 3

    delegate :octokit, :base_branch, to: :github_installation

    def initialize(conference:, filepath:, content:, last_editing_history_id:, last_event_editing_history_id:, push_id:, build_summary: nil)
      @conference = conference
      @repo = conference.github_repo
      @filepath = filepath
      @content = content
      @last_id = last_editing_history_id || 0
      @last_event_id = last_event_editing_history_id || 0
      @branch_name = "sponsor-app/#{conference.slug}"
      @pr_title = "Update sponsors.yml for #{conference.slug} (#{push_id})"
      @build_summary = build_summary
    end

    def push
      return unless @repo

      if branch_has_newer_data?
        Rails.logger.info "GenerateSponsorsYamlFileJob: branch has newer data, skipping"
        return
      end

      read_previous_ids
      ensure_branch
      commit_content
      create_or_update_pull_request
    end

    private

    def read_previous_ids
      @base_last_id, @base_last_event_id = read_ids_from_ref(base_branch)
      @prev_last_id, @prev_last_event_id = read_ids_from_ref(@branch_name)
    end

    def read_ids_from_ref(ref)
      existing = octokit.contents(@repo.name, path: @filepath, ref: ref)
      content = Base64.decode64(existing[:content])
      last_id = content =~ /\blast_editing_history: (\d+)/ ? $1.to_i : 0
      last_event_id = content =~ /\blast_event_editing_history: (\d+)/ ? $1.to_i : 0
      [last_id, last_event_id]
    rescue Octokit::NotFound
      [0, 0]
    end

    def ensure_branch
      octokit.branch(@repo.name, @branch_name)
    rescue Octokit::NotFound
      head_sha = octokit.branch(@repo.name, base_branch)[:commit][:sha]
      octokit.create_ref(@repo.name, "refs/heads/#{@branch_name}", head_sha)
    end

    def commit_content
      begin
        blob_sha = octokit.contents(@repo.name, path: @filepath, ref: @branch_name)[:sha]
      rescue Octokit::NotFound
        blob_sha = nil
      end

      retries = 0
      begin
        octokit.update_contents(@repo.name, @filepath, @pr_title, blob_sha, @content, branch: @branch_name)
      rescue Octokit::Conflict, Octokit::UnprocessableEntity => e
        if retries < MAX_RETRIES && !branch_has_newer_data?
          retries += 1
          begin
            blob_sha = octokit.contents(@repo.name, path: @filepath, ref: @branch_name)[:sha]
          rescue Octokit::NotFound
            blob_sha = nil
          end
          Rails.logger.info "GenerateSponsorsYamlFileJob: commit conflict, retrying (#{retries}/#{MAX_RETRIES})"
          retry
        else
          Rails.logger.info "GenerateSponsorsYamlFileJob: commit conflict and branch has newer data (or max retries), skipping"
          return
        end
      end
    end

    def branch_has_newer_data?
      existing = octokit.contents(@repo.name, path: @filepath, ref: @branch_name)
      existing_content = Base64.decode64(existing[:content])

      branch_last_id = existing_content =~ /\blast_editing_history: (\d+)/ ? $1.to_i : 0
      branch_last_event_id = existing_content =~ /\blast_event_editing_history: (\d+)/ ? $1.to_i : 0

      # Branch is newer when both IDs are >= ours and at least one is strictly greater
      branch_last_id >= @last_id && branch_last_event_id >= @last_event_id &&
        (branch_last_id > @last_id || branch_last_event_id > @last_event_id)
    rescue Octokit::NotFound
      false # Branch or file doesn't exist
    end

    def create_or_update_pull_request
      full_summary = @build_summary&.call(@base_last_id, @base_last_event_id)
      owner = @repo.name.split('/')[0]
      existing_prs = octokit.pull_requests(@repo.name, state: 'open', head: "#{owner}:#{@branch_name}")
      if existing_prs.any?
        pr_number = existing_prs[0][:number]
        octokit.update_pull_request(@repo.name, pr_number, title: @pr_title, body: full_summary)
        incremental = @build_summary&.call(@prev_last_id, @prev_last_event_id)
        octokit.add_comment(@repo.name, pr_number, incremental) if incremental
      else
        begin
          octokit.create_pull_request(@repo.name, base_branch, @branch_name, @pr_title, full_summary)
        rescue Octokit::UnprocessableEntity
          # Concurrent job already created PR
          existing_prs = octokit.pull_requests(@repo.name, state: 'open', head: "#{owner}:#{@branch_name}")
          if existing_prs.any?
            pr_number = existing_prs[0][:number]
            octokit.update_pull_request(@repo.name, pr_number, title: @pr_title, body: full_summary)
            incremental = @build_summary&.call(@prev_last_id, @prev_last_event_id)
            octokit.add_comment(@repo.name, pr_number, incremental) if incremental
          end
        end
      end
    end

    def github_installation
      @github_installation ||= GithubInstallation.new(@repo.name, branch: @repo.branch)
    end
  end
end
