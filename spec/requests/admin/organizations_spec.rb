# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Organizations", type: :request do
  let!(:organization) { FactoryBot.create(:organization) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }
  let(:new_params) { {name: 'New name', domain: 'new.example.com'} }

  before do
    get claim_user_session_path(session_token.handle)
  end

  context "with unrestricted staff" do
    it "lists organizations" do
      get organizations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(organization.name)
    end

    it "shows an organization" do
      get organization_path(organization)
      expect(response).to have_http_status(:ok)
    end

    it "renders the new form" do
      get new_organization_path
      expect(response).to have_http_status(:ok)
    end

    it "creates an organization" do
      post organizations_path, params: {organization: new_params}
      expect(response).to redirect_to(organization_path(Organization.find_by!(domain: 'new.example.com')))
    end

    it "renders the edit form" do
      get edit_organization_path(organization)
      expect(response).to have_http_status(:ok)
    end

    it "updates an organization" do
      patch organization_path(organization), params: {organization: new_params}
      expect(response).to redirect_to(organization_path(organization.reload))
      expect(organization).to have_attributes(new_params)
    end
  end

  context "with restricted staff" do
    let(:staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi.org']) }

    it "forbids index" do
      get organizations_path
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids show" do
      get organization_path(organization)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids new" do
      get new_organization_path
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids create" do
      expect {
        post organizations_path, params: {organization: new_params}
      }.not_to change(Organization, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids edit" do
      get edit_organization_path(organization)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids update" do
      expect {
        patch organization_path(organization), params: {organization: new_params}
      }.not_to change { organization.reload.attributes }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
