# typed: strict
# frozen_string_literal: true

module Api
  # Publishes a Broadcast as one sponsorship received it. Takes the URL of the sponsorship's
  # dashboard in `params[:dashboard_url]`, as it is built from the request's host.
  class BroadcastDeliveryResource < Api::ApplicationResource
    # Where an email's Markdown asks for the recipient's sign-in link.
    SIGN_IN_PLACEHOLDER = /@LOGIN@|@FORM@/ #: Regexp

    with_protobuf Rk::SponsorApp::BroadcastDelivery do
      attribute(:broadcast_id, &:id)
      attributes :title
      attribute(:sent_at) { |broadcast| (broadcast.dispatched_at || broadcast.created_at).to_time }
      attribute(:body_html) do |broadcast|
        url = ERB::Util.html_escape(params.fetch(:dashboard_url))
        broadcast.html.to_str.gsub(SIGN_IN_PLACEHOLDER) { %(<a href="#{url}">#{url}</a>) }
      end
    end
  end
end
