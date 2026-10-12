# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorshipEditingHistoriesController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListSponsorshipEditingHistoryResponse
      def list_sponsorship_editing_history
        entries = find_sponsorship.editing_histories.includes(:staff)

        Rk::SponsorApp::AdminServiceListSponsorshipEditingHistoryResponse.new(
          entries: entries.map { Api::EditingHistoryEntryResource.new(it).as_protobuf },
        )
      end
    end
  end
end
