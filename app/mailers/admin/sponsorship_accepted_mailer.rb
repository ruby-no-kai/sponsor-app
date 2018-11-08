class Admin::SponsorshipAcceptedMailer < Admin::ApplicationMailer
  def admin_email
    @sponsorship = params[:sponsorship]

    @sponsor_name = @sponsorship.contact.organization
    @sponsor_org_name = @sponsorship.contact.organization
    @sponsor_contact_name = @sponsorship.contact.name
    @sponsor_contact_email = @sponsorship.contact.email

    @link = conference_sponsorship_url(@sponsorship.conference, @sponsorship)

    message_id_for "admin/sponsorships/#{@sponsorship.id}"
    mail(
      to: @sponsorship.conference.contact_email_address,
      subject: make_subject(name: @sponsor_name),
    )
  end

  private

  def subject_prefix
    "[#{@sponsorship.conference.name}] "
  end
end
