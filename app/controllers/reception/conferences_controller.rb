class Reception::ConferencesController < ::Reception::ApplicationController
  def show
    @ticket = Ticket.new
  end

  def code
    render plain: RQRCode::QRCode.new(session_assume_url, :m).as_svg(module_size: 3), content_type: 'image/svg+xml'
  end

  private
  helper_method def session_assume_url
    reception_assume_session_url(handle: "#{@conference.id}--#{@conference.reception_key}")
  end
end
