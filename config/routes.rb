Rails.application.routes.draw do
  constraints subdomain: %w(admin sponsorship-admin) do
    scope module: 'admin' do
      resources :conferences do
        resources :form_descriptions, except: %i(index)
        resources :plans, except: %i(index show)
        resources :sponsorships, except: %i(index new create destroy) do
          member do
            get :download_asset
          end
        end
      end
    end
  end

  get '/' => 'root#index'

  scope as: :user do
    resource :session, only: %i(new create destroy) do
      get 'claim/:key', action: :claim
    end

    resources :conferences, only: %i(index) do
      resource :sponsorship, only: %i(new create show edit update)
      resource :sponsorship_asset_file, only: %i(create update)
    end
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
