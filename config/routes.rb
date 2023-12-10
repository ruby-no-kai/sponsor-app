Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  scope path: 'admin', module: 'admin' do
    get '/' => 'dashboard#index', as: :dashboard
    get '/slacktown' => 'dashboard#slacktown', as: :slacktown
    get '/mailtown' => 'dashboard#mailtown', as: :mailtown

    resources :conferences, param: :slug do
      member do
        get :attendees_keeper
        get :sponsors_yml
        get :sponsors_json
        get :asset_urls
        get :table_view
      end

      resource :booth_assignment, only: %i(show update)

      resources :form_descriptions, except: %i(index)
      resources :plans, except: %i(index show)

      resources :sponsorships, except: %i(index new create) do
        resources :sponsorship_editing_histories, as: :editing_histories, path: 'editing_history', only: %i(index)
        resources :sponsorship_staff_notes, as: :staff_notes, path: 'staff_notes', only: %i(index create edit update destroy)
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
    resource :session, only: %i(new destroy) do
      get :rise, as: :rise
    end
  end

  get '/t/:handle' => 'reception/registrations#short_show', as: :reception_ticket

  scope as: :reception, path: 'reception', module: 'reception' do
    get 'session/assume/:handle' => 'sessions#assume', as: :assume_session

    resources :conferences, param: :slug, only: %i(show) do
      member do
        get :code
      end

      resources :registrations, param: :code, only: %i(new show update create)
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
        resource :exhibition, only: %i(new create edit update)
      end
      resource :sponsorship_asset_file, only: %i(create update show)

      resource :ticket, only: %i(new create show) do
        get 'code' => 'tickets#code', as: :code
        get 'new_code' => 'tickets#new_code', as: :new_code
        get 'retrieve/:handle' => 'tickets#retrieve', as: :retrieve
      end
    end


    post '/webhooks/mailgun' => 'webhooks/mailgun#webhook'
  end


  get '/site/sha' => RevisionPlate::App.new(File.join(__dir__, '..', 'REVISION'))
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
