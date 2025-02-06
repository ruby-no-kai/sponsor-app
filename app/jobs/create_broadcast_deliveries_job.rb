class CreateBroadcastDeliveriesJob < ApplicationJob
  Recipient = Struct.new(:sponsorship, :email, :email_ccs, keyword_init: true)

  module Filters
    class Base
      def initialize(broadcast:, params:)
        @broadcast = broadcast
        @params = params
      end

      attr_reader :broadcast, :params

      def recipients
        raise NotImplementedError
      end

      private def status_scope
        case params[:status]
        when 'all', nil
          Sponsorship.all
        when 'not_accepted'
          Sponsorship.where(accepted_at: nil)
        when 'pending'
          Sponsorship.where(accepted_at: nil).not_withdrawn
        when 'accepted'
          Sponsorship.accepted
        when 'active'
          Sponsorship.active
        when 'withdrawn'
          Sponsorship.withdrawn
        else
          Sponsorship.none
        end
      end

      private def plan_scope
        if params[:plan_id].present?
          plan = @broadcast.conference.plans.where(id: params[:plan_id]).first
          if plan
            return Sponsorship.where(plan:)
          end
        end
        nil
      end

      private def locale_scope
        if params[:locale].present?
          Sponsorship.where(locale: params[:locale]) 
        else
          nil
        end
      end

      private def exhibitor_scope
        if params[:exhibitors].present?
          Sponsorship.exhibitor 
        else
          nil
        end
      end

      private def scope_sponsorships(scope)
        [
          status_scope,
          plan_scope,
          locale_scope,
          exhibitor_scope,
        ].inject(scope) do |r,i|
          i ? r.merge(i) : r
        end
      end

      private def sponsorships_to_recipients(scope)
        scope.map do |sponsorship|
          Recipient.new(
            sponsorship: sponsorship,
            email: sponsorship.contact.email,
            email_ccs: sponsorship.contact.email_ccs,
          )
        end
      end
    end

    class All < Base
      def recipients
        scope = scope_sponsorships(@broadcast.conference.sponsorships.includes(:contact))
        sponsorships_to_recipients(scope)
      end
    end

    class PastSponsors < Base
      def recipients
        conference = Conference.find_by!(id: params[:id])
        scope = scope_sponsorships(conference.sponsorships.includes(:contact))
        sponsorships_to_recipients(scope)
      end
    end

    class Manual < Base
      def recipients
        scope = Sponsorship.where(id: [*params[:sponsorship_ids]])
        if params[:exclude_current_sponsors].present?
          scope = scope.where.not(organization_id: @broadcast.conference.sponsorships.pluck(:organization_id))
        end
        sponsorships_to_recipients(scope)
      end
    end

    class Raw < Base
      def recipients
        [*params[:emails]].flatten.flat_map do |email_lines|
          email_lines.to_s.each_line.map do |email|
            Recipient.new(
              email: email.chomp,
              email_ccs: [],
            )
          end
        end
      end
    end
  end

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
        raise "Invalid state for CreateBroadcastDeliveriesJob (broadcast_id=#{broadcast.id}, state=#{broadcast.status})"
      end

      existing_emails = broadcast.deliveries.pluck(:recipient).tally
      recipients = recipient_filter_params.flat_map do |filter|
        filter = filter.dup
        kind = filter.delete('kind')

        filter_recipients(kind, filter)
      end

      recipients.map do |recipient|
        next if existing_emails[recipient.email]
        broadcast.deliveries.create!(
          status: :ready,
          sponsorship: recipient.sponsorship,
          recipient: recipient.email,
          recipient_cc: recipient.email_ccs&.join(','),
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
      Filters::All.new(broadcast: @broadcast, params: params).recipients
    when 'past_sponsors'
      Filters::PastSponsors.new(broadcast: @broadcast, params: params).recipients
    when 'raw'
      Filters::Raw.new(broadcast: @broadcast, params: params).recipients
    when 'manual'
      Filters::Manual.new(broadcast: @broadcast, params: params).recipients
    when 'none'
      []
    else
      []
    end
  end
end
