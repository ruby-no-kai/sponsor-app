class CreateBroadcastDeliveriesJob < ApplicationJob
  Recipient = Struct.new(:sponsorship, :email, keyword_init: true)

  def perform(broadcast, recipient_filter_params)
    ApplicationRecord.transaction do
      @broadcast = broadcast
      broadcast.lock!

      case
      when broadcast.created?
        broadcast.update!(status: :preparing)
      when broadcast.ready?
        broadcast.update!(status: :modifying)
      when broadcast.modifying?
        broadcast.update!(status: :modifying)
      else
        raise "Invalid state for CreateRemoteTaskExecutionsJob (broadcast_id=#{broadcast.id}, state=#{broadcast.status})"
      end

      existing_emails = broadcast.deliveries.pluck(:recipient)
      recipients = recipient_filter_params.flat_map do |filter|
        filter = filter.dup
        kind = filter.delete('kind') || target.delete(:kind)

        filter_recipients(kind, filter)
      end

      recipients.map do |recipient|
        next if existing_emails.include?(recipient.email)
        broadcast.deliveries.create!(
          status: :ready,
          sponsorship: recipient.sponsorship,
          recipient: recipient.email,
        )
      end

      broadcast.lock!(false)

      broadcast.status = :ready
      broadcast.save!
    end
  end

  def filter_recipients(kind, params)
    case kind.to_s
    when 'all'
      scope = @broadcast.conference.sponsorships.includes(:contact)
      scope = scope.where(locale: params[:locale]) if params[:locale].present?
      scope = scope.exhibitor if params[:exhibitors].present?
      scope.map do |sponsorship|
        Recipient.new(
          sponsorship: sponsorship,
          email: sponsorship.contact.email,
        )
      end
    when 'past_sponsors'
      conference = Conference.find_by!(id: params[:id])
      scope = conference.sponsorships.includes(:contact)
      scope = scope.where(locale: params[:locale]) if params[:locale].present?
      scope = scope.where.not(organization_id: @broadcast.conference.sponsorships.pluck(:organization_id)) if params[:exclude_current_sponsors]
      scope.map do |sponsorship|
        Recipient.new(
          sponsorship: sponsorship,
          email: sponsorship.contact.email,
        )
      end
    when 'raw'
      [*params[:emails]].flatten.flat_map do |email_lines|
        email_lines.to_s.each_line.map do |email|
          Recipient.new(
            email: email.chomp,
          )
        end
      end
    when 'manual'
      p params
      scope = Sponsorship.where(id: [*params[:sponsorship_ids]])
      scope.map do |sponsorship|
        Recipient.new(
          sponsorship: sponsorship,
          email: sponsorship.contact.email,
        )
      end
    when 'none'
      []
    else
      []
    end
  end
end
