# typed: strict
# frozen_string_literal: true

class GenerateSponsorsYamlFileJob < ApplicationJob
  #: type sponsor_entry = {
  #|   id: Integer,
  #|   asset_file_id: Integer?,
  #|   base_plan: String,
  #|   plan_name: String?,
  #|   slug: String?,
  #|   name: String,
  #|   url: String,
  #|   profile: String,
  #| }
  #: type plan_entry = { plan_name: String?, sponsors: Array[sponsor_entry] }
  #: type base_plan_entry = { base_plan: String, plans: Hash[String, plan_entry] }
  #: type host_entry = { slug: String?, name: String, url: String }
  #: type event_entry = {
  #|   id: Integer,
  #|   slug: String,
  #|   title: String,
  #|   starts_at: String,
  #|   url: String,
  #|   price: String,
  #|   capacity: String,
  #|   location_en: String,
  #|   location_local: String,
  #|   link_name: String,
  #|   hosts: Array[host_entry],
  #| }

  #: (Conference, ?push: bool) -> void
  def perform(conference, push: true)
    @conference = conference #: Conference?

    yaml_data # to generate
    if push
      ApplicationRecord.transaction do
        @last&.lock!
        push_to_github
      end
    end
  end

  #: () -> Conference::GithubRepo?
  def repo
    conference.github_repo
  end

  #: () -> Hash[String, base_plan_entry]?
  def data
    sponsorships = conference.sponsorships
      .have_presence
      .order(id: :asc)
      .includes(:plan)
      .includes(:organization)
      .includes(:asset_file)
      .group_by { |s| presence_plan(s).name.downcase.gsub(/[^a-z0-9]/, '_') }

    @last = SponsorshipEditingHistory.where(sponsorship_id: sponsorships.each_value.flat_map { |ss| ss.map(&:id) }).order(id: :desc).first #: SponsorshipEditingHistory?
    unless @last # this is falsy if no sponsorships have presense
      Rails.logger.warn "Conference #{conference.slug} (#{conference.id}) have no sponsorships with presense, resulting null sponsors data"
      return
    end
    @last_id = @last.id #: Integer?

    sponsorships.map do |base_plan_slug, sponsorships|
      [
        base_plan_slug,
        {
          base_plan: presence_plan(sponsorships.fetch(0)).name.downcase,
          plans: sponsorships.group_by { |s| Must.because(s.plan_name) { "have_presence selects sponsorships with a plan" }.downcase.gsub(/[^a-z0-9]/, '_') }.map do |plan_slug, sponsors|
            [
              plan_slug,
              {
                plan_name: sponsors.fetch(0).plan_name,
                sponsors: sponsors.map do |sp|
                  {
                    id: sp.id,
                    asset_file_id: sp.asset_file&.id,
                    base_plan: presence_plan(sp).name.downcase,
                    plan_name: sp.plan_name,
                    slug: sp.slug,
                    name: sp.name,
                    url: sp.url.strip,
                    profile: sp.profile,
                  }
                end,
              },
            ]
          end.to_h,
        },
      ]
    end.to_h
  end

  #: () -> Array[event_entry]
  def events_data
    events = conference.sponsor_events
      .accepted
      .includes(sponsorship: :organization)
      .order(starts_at: :asc, id: :asc)

    @last_event_editing_history_id = SponsorEventEditingHistory
      .where(sponsor_event_id: events.map(&:id))
      .maximum(:id) #: Integer?

    events.map do |event|
      hosts = event.all_host_sponsorships.sort_by(&:id).map do |sponsorship|
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

  #: () -> String?
  def yaml_data
    return @yaml_data if defined? @yaml_data

    data = self.data
    events = events_data
    if data.nil? && events.blank?
      @yaml_data = nil #: String?
      return @yaml_data
    end

    combined_data = data ? data.merge("_events" => events) : {"_events" => events}
    comment_parts = [
      "last_editing_history: #{@last_id || 0}",
      "last_event_editing_history: #{@last_event_editing_history_id || 0}",
    ]
    @yaml_data = [
      "# #{comment_parts.join(", ")}",
      combined_data.to_yaml,
      "",
    ].join("\n")
  end

  #: () -> String?
  def json_data
    return @json_data if defined? @json_data

    data = self.data
    @json_data = data ? "#{data.to_json}\n" : nil #: String?
  end

  #: () -> void
  def push_to_github
    github_repo = repo
    return unless github_repo

    content = yaml_data
    return if content.nil?

    push_id = @last_id || "event-#{@last_event_editing_history_id}"
    GitHubPusher.new(
      conference: conference,
      filepath: github_repo.path,
      content: content,
      last_editing_history_id: @last_id,
      last_event_editing_history_id: @last_event_editing_history_id,
      push_id:,
      build_summary: method(:build_edit_summary),
    ).push
  end

  #: (Integer, Integer) -> String?
  private def build_edit_summary(from_last_id, from_last_event_id)
    last_id = @last_id || 0
    last_event_id = @last_event_editing_history_id || 0
    sections = [] #: Array[String]

    if from_last_id < last_id
      edits = SponsorshipEditingHistory
        .where(id: (from_last_id + 1)..last_id)
        .includes(:sponsorship, :staff)
        .order(id: :asc)
      if edits.any?
        lines = edits.map do |edit|
          staff = edit.staff
          actor = staff ? "#{staff.login} (staff)" : "sponsor"
          fields = edit.diff_summary.map { |s| "`#{s}`" }.join(", ")
          "- **#{Must.expect(edit.sponsorship).name}** (#{fields}) — by #{actor}"
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
          staff = edit.staff
          actor = staff ? "#{staff.login} (staff)" : "sponsor"
          fields = edit.diff_summary.map { |s| "`#{s}`" }.join(", ")
          "- **#{Must.expect(edit.sponsor_event).title}** (#{fields}) — by #{actor}"
        end
        sections << "**Event changes:**\n#{lines.join("\n")}"
      end
    end

    sections.any? ? sections.join("\n\n") : nil
  end

  #: () -> Conference
  private def conference = Must.because(@conference) { "perform sets the conference" }

  #: (Sponsorship) -> Plan
  private def presence_plan(sponsorship)
    Must.because(sponsorship.plan) { "have_presence selects sponsorships with a plan" }
  end

  # For debugging
  #: (String) -> Octokit::Client
  def self.get_octokit(repo)
    GithubInstallation.new(repo).octokit
  end

  class GitHubPusher
    MAX_RETRIES = 3 #: Integer

    delegate :octokit, :base_branch, to: :github_installation

    #: (conference: Conference, filepath: String, content: String, last_editing_history_id: Integer?,
    #|  last_event_editing_history_id: Integer?, push_id: Integer | String, ?build_summary: Method?) -> void
    def initialize(conference:, filepath:, content:, last_editing_history_id:, last_event_editing_history_id:, push_id:, build_summary: nil)
      @conference = conference
      @repo = conference.github_repo #: Conference::GithubRepo?
      @filepath = filepath
      @content = content
      @last_id = last_editing_history_id || 0 #: Integer
      @last_event_id = last_event_editing_history_id || 0 #: Integer
      @branch_name = "sponsor-app/#{conference.slug}" #: String
      @pr_title = "Update sponsors.yml for #{conference.slug} (#{push_id})" #: String
      @build_summary = build_summary
      @base_last_id = nil #: Integer?
      @base_last_event_id = nil #: Integer?
      @prev_last_id = nil #: Integer?
      @prev_last_event_id = nil #: Integer?
    end

    #: () -> void
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

    #: () -> void
    private def read_previous_ids
      @base_last_id, @base_last_event_id = read_ids_from_ref(base_branch)
      @prev_last_id, @prev_last_event_id = read_ids_from_ref(@branch_name)
    end

    #: (String) -> [Integer, Integer]
    private def read_ids_from_ref(ref)
      existing = octokit.contents(repo.name, path: @filepath, ref: ref)
      content = Base64.decode64(existing[:content])
      last_id = content =~ /\blast_editing_history: (\d+)/ ? ::Regexp.last_match(1).to_i : 0
      last_event_id = content =~ /\blast_event_editing_history: (\d+)/ ? ::Regexp.last_match(1).to_i : 0
      [last_id, last_event_id]
    rescue Octokit::NotFound
      [0, 0]
    end

    #: () -> void
    private def ensure_branch
      octokit.branch(repo.name, @branch_name)
    rescue Octokit::NotFound
      head_sha = octokit.branch(repo.name, base_branch)[:commit][:sha]
      octokit.create_ref(repo.name, "refs/heads/#{@branch_name}", head_sha)
    end

    #: () -> void
    private def commit_content
      begin
        blob_sha = octokit.contents(repo.name, path: @filepath, ref: @branch_name)[:sha]
      rescue Octokit::NotFound
        blob_sha = nil
      end

      retries = 0
      begin
        octokit.update_contents(repo.name, @filepath, @pr_title, blob_sha, @content, branch: @branch_name)
      rescue Octokit::Conflict, Octokit::UnprocessableEntity
        if retries < MAX_RETRIES && !branch_has_newer_data?
          retries += 1
          begin
            blob_sha = octokit.contents(repo.name, path: @filepath, ref: @branch_name)[:sha]
          rescue Octokit::NotFound
            blob_sha = nil
          end
          Rails.logger.info "GenerateSponsorsYamlFileJob: commit conflict, retrying (#{retries}/#{MAX_RETRIES})"
          retry
        else
          Rails.logger.info "GenerateSponsorsYamlFileJob: commit conflict and branch has newer data (or max retries), skipping"
          nil
        end
      end
    end

    #: () -> bool
    private def branch_has_newer_data?
      existing = octokit.contents(repo.name, path: @filepath, ref: @branch_name)
      existing_content = Base64.decode64(existing[:content])

      branch_last_id = existing_content =~ /\blast_editing_history: (\d+)/ ? ::Regexp.last_match(1).to_i : 0
      branch_last_event_id = existing_content =~ /\blast_event_editing_history: (\d+)/ ? ::Regexp.last_match(1).to_i : 0

      # Branch is newer when both IDs are >= ours and at least one is strictly greater
      branch_last_id >= @last_id && branch_last_event_id >= @last_event_id &&
        (branch_last_id > @last_id || branch_last_event_id > @last_event_id)
    rescue Octokit::NotFound
      false # Branch or file doesn't exist
    end

    #: () -> void
    private def create_or_update_pull_request
      full_summary = @build_summary&.call(@base_last_id, @base_last_event_id) #: String?
      owner = repo.name.split('/')[0]
      existing_prs = octokit.pull_requests(repo.name, state: 'open', head: "#{owner}:#{@branch_name}")
      if existing_prs.any?
        pr_number = existing_prs[0][:number]
        octokit.update_pull_request(repo.name, pr_number, title: @pr_title, body: full_summary)
        incremental = @build_summary&.call(@prev_last_id, @prev_last_event_id) #: String?
        octokit.add_comment(repo.name, pr_number, incremental) if incremental
      else
        begin
          octokit.create_pull_request(repo.name, base_branch, @branch_name, @pr_title, full_summary)
        rescue Octokit::UnprocessableEntity
          # Concurrent job already created PR
          existing_prs = octokit.pull_requests(repo.name, state: 'open', head: "#{owner}:#{@branch_name}")
          if existing_prs.any?
            pr_number = existing_prs[0][:number]
            octokit.update_pull_request(repo.name, pr_number, title: @pr_title, body: full_summary)
            incremental = @build_summary&.call(@prev_last_id, @prev_last_event_id) #: String?
            octokit.add_comment(repo.name, pr_number, incremental) if incremental
          end
        end
      end
    end

    #: () -> GithubInstallation
    private def github_installation
      @github_installation ||= GithubInstallation.new(repo.name, branch: repo.branch) #: GithubInstallation?
    end

    #: () -> Conference::GithubRepo
    private def repo = Must.because(@repo) { "push returns early without a github_repo" }
  end
end
