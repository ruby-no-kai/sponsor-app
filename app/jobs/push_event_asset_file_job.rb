require 'open3'

class PushEventAssetFileJob < ApplicationJob
  def perform(record)
    resolve_record(record)
    @sponsorship = @event.sponsorship
    @conference = @event.conference

    return if @conference.github_repo_images_path.blank?
    repo = @conference.github_repo
    return unless repo
    return unless @event.accepted?
    asset_file = @event.asset_file
    return unless asset_file

    gi = GithubInstallation.new(repo.name, branch: repo.branch)
    webp_content = convert_to_webp(asset_file)
    push_to_github(gi, repo, asset_file, webp_content)
  end

  private

  def resolve_record(record)
    case record
    when SponsorEventEditingHistory
      @editing_history = record
      @event = record.sponsor_event
    when SponsorEvent
      @event = record
      @editing_history = record.last_editing_history
    when SponsorEventAssetFile
      @event = record.sponsor_event
      raise ArgumentError, "SponsorEventAssetFile##{record.id} has no associated sponsor_event" unless @event
      @editing_history = @event.last_editing_history
    else
      raise ArgumentError, "expected SponsorEventEditingHistory, SponsorEvent, or SponsorEventAssetFile, got #{record.class}"
    end
  end

  def convert_to_webp(asset_file)
    tmpdir = Rails.root.join('tmp', "PushEventAssetFileJob-#{job_id}-#{asset_file.id}")
    FileUtils.mkdir_p(tmpdir)

    input_path = tmpdir.join("input.#{asset_file.extension}")
    output_path = tmpdir.join("output.webp")

    File.open(input_path, 'wb') do |f|
      asset_file.get_object(response_target: f)
    end

    thumbnail_size = thumbnail_size_for(input_path)

    _stdout, stderr, status = Open3.capture3(
      { 'VIPS_BLOCK_UNTRUSTED' => '1' },
      'vipsthumbnail', input_path.to_s,
      '-s', thumbnail_size,
      '-o', output_path.to_s + '[Q=72,preset=drawing,smart_subsample=true,effort=6,strip=true]'
    )
    raise "vipsthumbnail failed (status=#{status.exitstatus}): #{stderr}" unless status.success?

    content = File.binread(output_path)
    FileUtils.rm_rf(tmpdir)
    content
  end

  THUMBNAIL_MAX_SIZE = 800

  # Avoid enlarging images smaller than THUMBNAIL_MAX_SIZE
  def thumbnail_size_for(input_path)
    stdout, _, status = Open3.capture3(
      { 'VIPS_BLOCK_UNTRUSTED' => '1' },
      'vipsheader', '-f', 'width', input_path.to_s
    )
    if status.success?
      input_width = stdout.strip.to_i
      if input_width > 0 && input_width < THUMBNAIL_MAX_SIZE
        return input_width.to_s
      end
    end
    THUMBNAIL_MAX_SIZE.to_s
  end

  def push_to_github(gi, repo, asset_file, webp_content)
    octokit = gi.octokit
    images_path = @conference.github_repo_images_path.chomp('/')
    filepath = "#{images_path}/events/#{@sponsorship.id}-#{@event.id}.webp"
    branch_name = "sponsor-app/event-asset/#{@sponsorship.id}-#{@event.id}/#{@editing_history.id}"
    pr_title = "Event asset: #{@sponsorship.name} [#{@event.id}@#{@editing_history.id}]"

    begin
      octokit.delete_branch(repo.name, branch_name)
    rescue Octokit::UnprocessableEntity
    end

    head = octokit.branch(repo.name, gi.base_branch)
    octokit.create_ref(repo.name, "refs/heads/#{branch_name}", head[:commit][:sha])

    begin
      blob_sha = octokit.contents(repo.name, path: filepath, ref: gi.base_branch)[:sha]
    rescue Octokit::NotFound
      blob_sha = nil
    end

    octokit.update_contents(
      repo.name, filepath, pr_title, blob_sha, webp_content,
      branch: branch_name,
    )

    body = <<~MARKDOWN
      ## Event Asset

      - **Event:** #{@event.title}
      - **Sponsor:** #{@sponsorship.name} (#{@conference.name})
      - **Admin:** #{conference_sponsor_event_url(@conference, @event)}
    MARKDOWN

    octokit.create_pull_request(repo.name, gi.base_branch, branch_name, pr_title, body)
  end
end
