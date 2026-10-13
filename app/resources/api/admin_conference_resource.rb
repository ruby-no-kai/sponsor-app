# typed: strict
# frozen_string_literal: true

module Api
  # Takes the application form URL in `params[:application_form_url]`, as it is built from the
  # request's host.
  class AdminConferenceResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminConference do
      one :conference, source: proc { self }, resource: Api::ConferenceResource
      attributes :hidden, :allow_restricted_access, :booth_capacity
      attribute(:application_form_url) { params.fetch(:application_form_url) }

      # Blank strings are what the HAML form saves for an empty field.
      # Conference#github_repo returns the parsed GithubRepo, so the column is read as stored.
      attribute(:github_repo, if: proc { |conference| conference[:github_repo].present? }) do |conference|
        conference[:github_repo]
      end
      attributes :github_repo_images_path, if: proc { |conference| conference.github_repo_images_path.present? }
      attributes :tito_slug, if: proc { |conference| conference.tito_slug.present? }
      attribute(:tito_booth_paid_flat_discount_amount) do |conference|
        conference.tito_booth_paid_flat_discount_amount.to_s('F')
      end
    end
  end
end
