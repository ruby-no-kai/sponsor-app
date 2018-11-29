class ApplicationJob < ActiveJob::Base
  include Rails.application.routes.url_helpers

  def default_url_options
    {host: Rails.application.config.x.public_url_host, protocol: 'https'}
  end
end
