class Admin::SessionsController < ::ApplicationController
  layout 'admin'

  def new
    if params[:proceed]
      session.delete(:back_to)
      if params[:back_to]
        uri = Addressable::URI.parse(params[:back_to])
        if uri && uri.host.nil? && uri.scheme.nil? && uri.path.start_with?('/')
          session[:back_to] = params[:back_to]
        end
      end
      redirect_to '/auth/github'
    end
  end

  def create
    auth = request.env['omniauth.auth']
    case auth[:provider]
    when 'github'
      unless staff_member?(auth.fetch('credentials').fetch('token'))
        return render(status: 403, plain: "Forbidden (You have to be in any of these repo: #{Rails.application.config.x.github.repo}")
      end

      staff = Staff.create_with(
        name: auth.fetch('info').fetch('name') || auth.fetch('info').fetch('nickname'),
        avatar_url: auth.fetch('info').fetch('image'),
        login: auth.fetch('info').fetch('nickname'),
      ).find_or_create_by!(
        uid: auth.fetch('uid'),
      )
    else
      render status: 404, plain: "Unsupported provider: #{auth[:provider]}"
    end

    session[:staff_id] = staff.id
    return redirect_to(session.delete(:back_to) || '/')
  end

  def destroy
    session.delete(:staff_id)
    redirect_to '/'
  end

  private

  def staff_member?(access_token)
    octo = Octokit::Client.new(
      access_token: access_token,
    )

    octo.repository?(Rails.application.config.x.github.repo)
  end
end
