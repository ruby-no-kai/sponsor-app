require 'rails_helper'

RSpec.describe Admin::FormDescriptionsController, type: :routing do
  describe 'routing' do
    it 'routes to #new' do
      expect(get: '/admin/conferences/rk2025/form_descriptions/new').to route_to(
        controller: 'admin/form_descriptions',
        action: 'new',
        conference_slug: 'rk2025'
      )
    end

    it 'routes to #create' do
      expect(post: '/admin/conferences/rk2025/form_descriptions').to route_to(
        controller: 'admin/form_descriptions',
        action: 'create',
        conference_slug: 'rk2025'
      )
    end

    it 'routes to #show using locale parameter' do
      expect(get: '/admin/conferences/rk2025/form_descriptions/en').to route_to(
        controller: 'admin/form_descriptions',
        action: 'show',
        conference_slug: 'rk2025',
        locale: 'en'
      )
    end

    it 'routes to #edit using locale parameter' do
      expect(get: '/admin/conferences/rk2025/form_descriptions/ja/edit').to route_to(
        controller: 'admin/form_descriptions',
        action: 'edit',
        conference_slug: 'rk2025',
        locale: 'ja'
      )
    end

    it 'routes to #update via PUT using locale parameter' do
      expect(put: '/admin/conferences/rk2025/form_descriptions/en').to route_to(
        controller: 'admin/form_descriptions',
        action: 'update',
        conference_slug: 'rk2025',
        locale: 'en'
      )
    end

    it 'routes to #update via PATCH using locale parameter' do
      expect(patch: '/admin/conferences/rk2025/form_descriptions/en').to route_to(
        controller: 'admin/form_descriptions',
        action: 'update',
        conference_slug: 'rk2025',
        locale: 'en'
      )
    end

    it 'routes to #destroy using locale parameter' do
      expect(delete: '/admin/conferences/rk2025/form_descriptions/ja').to route_to(
        controller: 'admin/form_descriptions',
        action: 'destroy',
        conference_slug: 'rk2025',
        locale: 'ja'
      )
    end
  end
end
