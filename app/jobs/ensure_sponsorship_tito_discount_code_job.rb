class EnsureSponsorshipTitoDiscountCodeJob < ApplicationJob
  def perform(sponsorship, kind, ignore_quantity: false)
    return unless Rails.application.config.x.tito.token
    @kind = kind
    @sponsorship = sponsorship
    @conference = @sponsorship.conference
    return unless @conference.tito_slug.present?

    @discount_code = @sponsorship.tito_discount_codes.where(kind: kind).first

    if @discount_code
      return if @discount_code.quantity == quantity && !ignore_quantity
      tito.update_discount_code(@conference.tito_slug, @discount_code.tito_discount_code_id, **discount_code_attributes)
      @discount_code.update!(quantity: quantity)
    else
      return if quantity < 1
      tito_discount_code = tito.create_discount_code(@conference.tito_slug, **discount_code_attributes)
      TitoDiscountCode.create!(
        sponsorship: @sponsorship,
        kind: @kind,
        code: code,
        quantity: quantity,
        tito_discount_code_id: tito_discount_code.fetch(:discount_code).fetch(:id),
      )
    end
  end
  
  def code
    "#{code_prefix}_#{@sponsorship.id}_#{@sponsorship.ticket_key[0,12]}"
  end

  def discount_code_attributes
    {
      code: code,
      type: 'PercentOffDiscountCode',
      value: '100.0',
      only_show_attached: true,
      reveal_secret: true,
      quantity: quantity,
      release_ids: quantity > 0 ? [release_id] : nil,
      description_for_organizer: "sponsorship=#{@sponsorship.id}, domain=#{@sponsorship.organization&.domain}, plan=#{@sponsorship.plan&.name}",
    }
  end

  def quantity
    {
      'attendee' => @sponsorship.total_number_of_attendees,
      'booth_staff' => @sponsorship.total_number_of_booth_staff,
    }.fetch(@kind)
  end

  def code_prefix
    {
      'attendee' => 'sa',
      'booth_staff' => 'sb',
    }.fetch(@kind)
  end

  def release_slug
    {
      'attendee' => 'sponsor',
      'booth_staff' => 'booth-staff',
    }.fetch(@kind)
  end

  def release_id
    @release_id ||= tito.get_release(@conference.tito_slug, release_slug).fetch(:release).fetch(:id)
  end

  def tito
    @tito ||= TitoApi.new
  end
end
