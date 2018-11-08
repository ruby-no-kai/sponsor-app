class SponsorshipAcceptedMailer < ApplicationMailer
  def user_email
    @sponsorship = params[:sponsorship]
    mail(
    )
  end
end
