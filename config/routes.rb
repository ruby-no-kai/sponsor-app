# typed: strict
# frozen_string_literal: true

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  scope path: 'admin', module: 'admin' do
    get '/' => 'dashboard#index', as: :dashboard
    get '/slacktown' => 'dashboard#slacktown', as: :slacktown
    get '/mailtown' => 'dashboard#mailtown', as: :mailtown
    get '/errortown' => 'dashboard#errortown', as: :errortown

    resources :conferences, param: :slug do
      member do
        get :attendees_keeper
        get :sponsors_yml
        get :sponsors_json
        get :asset_urls
        get :table_view
      end

      resource :booth_assignment, only: %i(show update)

      resources :form_descriptions, param: :locale, except: %i(index)
      resources :plans, except: %i(show)

      resources :expense_reports, only: %i(index)

      resources :sponsorships, except: %i(index new create) do
        resources :sponsorship_editing_histories, as: :editing_histories, path: 'editing_history', only: %i(index)
        resources :sponsorship_staff_notes, as: :staff_notes, path: 'staff_notes', only: %i(index create edit update destroy)
        resource :impersonation, only: %i(create), controller: 'sponsorship_impersonations'
        member do
          get :download_asset
        end
        resource :expense_report, only: %i(show update), controller: 'expense_reports' do
          member do
            get :calculate
          end
          resources :line_items, controller: 'expense_line_items', only: %i(create update destroy)
          resources :reviews, controller: 'expense_report_reviews', only: %i(create)
        end
        resources :expense_files, only: %i(create update show destroy) do
          member do
            post :initiate_update
          end
        end
      end

      resources :sponsor_events, path: 'events', except: %i(new create destroy) do
        resources :sponsor_event_editing_histories, as: :editing_histories, path: 'editing_history', only: %i(index)
        member do
          get :download_asset
        end
      end

      resources :announcements
      resources :broadcasts do
        resources :broadcast_deliveries, as: :deliveries, path: 'deliveries', only: %i(create destroy)
        member do
          post :dispatch_delivery
        end
      end
    end

    resources :organizations, param: :slug, only: %i(index new create show edit update), constraints: {slug: %r{[^/]+}}

    resource :session, only: %i(new destroy) do
      get :rise, as: :rise
      post :backdoor
    end
  end

  get '/auth/:provider/callback' => 'admin/sessions#create'

  get '/' => 'root#index'

  scope as: :user do
    resource :session, only: %i(new create destroy) do
      get 'claim/:handle', action: :claim, as: :claim
    end

    resources :conferences, param: :slug, only: %i(index) do
      resource :sponsorship, only: %i(new create show edit update) do
        resources :broadcasts, only: %i(index)
        resource :exhibition, only: %i(new create edit update)
        resources :events, controller: 'sponsor_events', only: %i(new create show edit update destroy)
        resources :pass_redemptions, only: %i(index) do
          member do
            resource :retraction, only: %i(new create show), controller: 'pass_retractions'
          end
        end
        resource :expense_report, only: %i(create update show) do
          member do
            get :calculate
          end
          resources :line_items, controller: 'expense_line_items', only: %i(create update destroy)
          resource :submission, controller: 'expense_report_submissions', only: %i(create destroy)
        end
      end
      resources :sponsorship_asset_files, only: %i(create update show) do
        member do
          post :initiate_update
        end
      end
      resources :event_asset_files, controller: 'sponsor_event_asset_files', only: %i(create update show) do
        member do
          post :initiate_update
        end
      end
      resources :expense_files, only: %i(create update show destroy) do
        member do
          post :initiate_update
        end
      end
    end

    post '/webhooks/mailgun' => 'webhooks/mailgun#webhook'
  end

  # One connect_service block per service, as the first block for a service shadows any later one.
  # Outside any namespace, since connect_rpc_rails checks controller paths without its module.
  connect_rpc_enabled = Rails.application.config.x.connect_rpc.enabled #: bool
  if connect_rpc_enabled
    connect_service 'rubykaigi.sponsor_app.AdminService' do
      # Conferences
      rpc 'ListConferences' => 'api/admin/conferences'
      rpc 'GetConference' => 'api/admin/conferences'
      rpc 'CreateConference' => 'api/admin/conferences'
      rpc 'UpdateConference' => 'api/admin/conferences'
      rpc 'GetAttendeesKeeper' => 'api/admin/conferences'
      rpc 'ListSponsorshipTableRows' => 'api/admin/conferences'

      # Form descriptions
      rpc 'GetFormDescription' => 'api/admin/form_descriptions'
      rpc 'CreateFormDescription' => 'api/admin/form_descriptions'
      rpc 'UpdateFormDescription' => 'api/admin/form_descriptions'

      # Plans
      rpc 'ListPlans' => 'api/admin/plans'
      rpc 'GetPlan' => 'api/admin/plans'
      rpc 'CreatePlan' => 'api/admin/plans'
      rpc 'UpdatePlan' => 'api/admin/plans'

      # Sponsorships
      rpc 'GetSponsorship' => 'api/admin/sponsorships'
      rpc 'UpdateSponsorship' => 'api/admin/sponsorships'
      rpc 'WithdrawSponsorship' => 'api/admin/sponsorships'
      rpc 'ListSponsorshipEditingHistory' => 'api/admin/sponsorship_editing_histories'
      rpc 'ListSponsorshipStaffNotes' => 'api/admin/sponsorship_staff_notes'
      rpc 'CreateSponsorshipStaffNote' => 'api/admin/sponsorship_staff_notes'
      rpc 'UpdateSponsorshipStaffNote' => 'api/admin/sponsorship_staff_notes'
      rpc 'DeleteSponsorshipStaffNote' => 'api/admin/sponsorship_staff_notes'
      rpc 'ImpersonateSponsorship' => 'api/admin/sponsorship_impersonations'

      # Organizations
      rpc 'ListOrganizations' => 'api/admin/organizations'
      rpc 'GetOrganization' => 'api/admin/organizations'
      rpc 'CreateOrganization' => 'api/admin/organizations'
      rpc 'UpdateOrganization' => 'api/admin/organizations'

      # Booth assignments
      rpc 'GetBoothAssignment' => 'api/admin/booth_assignments'
      rpc 'UpdateBoothAssignment' => 'api/admin/booth_assignments'

      # Sponsor events
      rpc 'ListSponsorEvents' => 'api/admin/sponsor_events'
      rpc 'GetSponsorEvent' => 'api/admin/sponsor_events'
      rpc 'UpdateSponsorEvent' => 'api/admin/sponsor_events'
      rpc 'ListSponsorEventEditingHistory' => 'api/admin/sponsor_event_editing_histories'

      # Announcements
      rpc 'ListAnnouncements' => 'api/admin/announcements'
      rpc 'GetAnnouncement' => 'api/admin/announcements'
      rpc 'CreateAnnouncement' => 'api/admin/announcements'
      rpc 'UpdateAnnouncement' => 'api/admin/announcements'

      # Broadcasts
      rpc 'ListBroadcasts' => 'api/admin/broadcasts'
      rpc 'GetBroadcast' => 'api/admin/broadcasts'
      rpc 'CreateBroadcast' => 'api/admin/broadcasts'
      rpc 'UpdateBroadcast' => 'api/admin/broadcasts'
      rpc 'AddBroadcastRecipients' => 'api/admin/broadcast_deliveries'
      rpc 'RemoveBroadcastDelivery' => 'api/admin/broadcast_deliveries'
      rpc 'DispatchBroadcast' => 'api/admin/broadcasts'

      # Expense reports
      rpc 'ListExpenseReports' => 'api/admin/expense_reports'
      rpc 'GetExpenseReport' => 'api/admin/expense_reports'
      rpc 'CalculateExpenseReport' => 'api/admin/expense_reports'
      rpc 'CreateExpenseLineItem' => 'api/admin/expense_line_items'
      rpc 'UpdateExpenseLineItem' => 'api/admin/expense_line_items'
      rpc 'DeleteExpenseLineItem' => 'api/admin/expense_line_items'
      rpc 'CreateExpenseReportReview' => 'api/admin/expense_report_reviews'
      rpc 'CreateExpenseFileUpload' => 'api/admin/expense_files'
      rpc 'InitiateExpenseFileUpdate' => 'api/admin/expense_files'
      rpc 'CompleteExpenseFileUpload' => 'api/admin/expense_files'
      rpc 'DeleteExpenseFile' => 'api/admin/expense_files'

      # Viewer
      rpc 'GetViewer' => 'api/admin/viewer'
      rpc 'SignOut' => 'api/admin/viewer'
    end

    connect_service 'rubykaigi.sponsor_app.SponsorService' do
      # Shell
      rpc 'GetTranslations' => 'api/sponsor/locale'
      rpc 'SetLocale' => 'api/sponsor/locale'
      rpc 'ListOpenConferences' => 'api/sponsor/conferences'
      rpc 'GetSponsorship' => 'api/sponsor/sponsorships'

      # Applications
      rpc 'GetApplicationForm' => 'api/sponsor/sponsorship_applications'
      rpc 'CreateSponsorship' => 'api/sponsor/sponsorship_applications'
      rpc 'CreateSponsorshipAssetUpload' => 'api/sponsor/sponsorship_asset_files'
      rpc 'InitiateSponsorshipAssetUpdate' => 'api/sponsor/sponsorship_asset_files'
      rpc 'CompleteSponsorshipAssetUpload' => 'api/sponsor/sponsorship_asset_files'

      # Exhibitions and events

      # Broadcasts and passes

      # Expense reports

      # Viewer
      rpc 'GetViewer' => 'api/sponsor/viewer'
      rpc 'SignOut' => 'api/sponsor/viewer'
    end
  end

  get '/site/sha' => RevisionPlate::App.new(File.join(__dir__, '..', 'REVISION'))
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
