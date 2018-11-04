Rails.application.routes.draw do
  constraints subdomain: %w(admin sponsorship-admin) do
    scope module: 'admin' do
      resources :conferences do
        resources :form_descriptions, except: %i(index)
        resources :plans, except: %i(index show)
      end
    end
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
