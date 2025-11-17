class RetractTitoTicketJob < ApplicationJob
  class Unable < StandardError; end

  # @param retraction [TitoTicketRetraction]
  def perform(retraction)
    logger.tagged(retraction_id: retraction.id, sponsorship_id: retraction.sponsorship_id, tito_registration_id: retraction.tito_registration_id, tito_registration_reference: retraction.order_reference) do |log|
      if retraction.completed?
        logger.info("RetractTitoTicketJob: completed, skipeed")
        return
      end

      api = TitoApi.new
      retraction.refresh_tito_registration(api:)
      if retraction.tito_registration.fetch('cancelled')
        logger.info("RetractTitoTicketJob: registration already cancelled, marking retraction as completed")
        retraction.restore_tito_registration!
        retraction.update!(completed: true)
        return
      end

      unless retraction.retractable?
        raise Unable, "Precondition not met; retraction_id=#{retraction.id.inspect}; #{retraction.preconditions.inspect}" 
      end

      logger.info("RetractTitoTicketJob: proceeding with cancellation")
      api.create_registration_note(
        retraction.conference.tito_slug,
        retraction.tito_registration_id,
        content: "sponsor-app cancelled this order due to sponsor's request; TitoTicketRetraction id=#{retraction.id}, reason: #{retraction.reason.truncate(240)}",
      )
      cancellation = api.cancel_registration(
        retraction.conference.tito_slug,
        retraction.tito_registration_id,
      )
      retraction.update!(
        tito_cancellation: cancellation,
        completed: true,
      )
      logger.info("RetractTitoTicketJob: cancelled successfully")

      conference = retraction.conference
      sponsorship = retraction.sponsorship
      SlackWebhookJob.perform_later(
        {
          text: ":rewind: <#{conference_sponsorship_url(conference, sponsorship)}|#{sponsorship.name}> retracted their Tito order <#{retraction.tito_admin_url}|#{retraction.order_reference}> (#{retraction.ticket_release_slugs.join(?,)}).\n\n>>> *Reason:* #{retraction.reason.truncate(500)}",
        },
        hook_name: :feed,
      )

      logger.info("RetractTitoTicketJob: completed successfully")
    end
  end

  def logger
    @logger ||= SemanticLogger[self.class.name]
  end
end
