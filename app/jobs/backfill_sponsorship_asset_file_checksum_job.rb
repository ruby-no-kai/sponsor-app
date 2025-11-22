class BackfillSponsorshipAssetFileChecksumJob < ApplicationJob
  def perform(sponsorship_asset_file)
    sponsorship = sponsorship_asset_file.sponsorship
    resp = sponsorship_asset_file.get_object()
    sponsorship_asset_file.put_object(body: resp.body, checksum_algorithm: 'SHA256', content_type: resp.content_type)
    sponsorship_asset_file.update_object_header

    was = sponsorship_asset_file.checksum_sha256_was
    sponsorship_asset_file.save!
    SlackWebhookJob.perform_now(
      {
        text: ":receipt: <#{conference_sponsorship_url(sponsorship.conference, sponsorship)}|#{sponsorship.name}> asset file checksum backfilled (#{was} → #{sponsorship_asset_file.checksum_sha256})",
      },
      hook_name: 'feed',
    )
  end
end
