class Admin::ApplicationMailer < ::ApplicationMailer
  def default_url_options
    {
      host: Rails.application.config.x.admin_url_host,
      protocol: 'https',
    }
  end
end
