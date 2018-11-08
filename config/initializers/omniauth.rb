Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github, Rails.application.config.x.github.client_id, Rails.application.config.x.github.client_secret
end
