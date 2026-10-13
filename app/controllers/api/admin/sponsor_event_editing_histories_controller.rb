# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorEventEditingHistoriesController < Api::Admin::ApplicationController
      include Api::Admin::SponsorEventLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListSponsorEventEditingHistoryResponse
      def list_sponsor_event_editing_history
        entries = find_sponsor_event.editing_histories.includes(:staff)

        Rk::SponsorApp::AdminServiceListSponsorEventEditingHistoryResponse.new(
          entries: entries.map { Api::EditingHistoryEntryResource.new(it).as_protobuf },
        )
      end
    end
  end
end
