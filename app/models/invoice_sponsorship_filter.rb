# typed: strict
# frozen_string_literal: true

class InvoiceSponsorshipFilter
  CUSTOMIZATION_VALUES = %w[all with without].freeze #: Array[String]

  #: Array[String]
  attr_reader :locales, :selected_locales, :selected_plan_ids

  #: Array[Plan]
  attr_reader :plans

  #: String
  attr_reader :customization_filter

  #: (conference: Conference, filters: String?, locales: Array[String]?, plan_ids: Array[String]?, customization_filter: String?) -> void
  def initialize(conference:, filters:, locales:, plan_ids:, customization_filter:)
    @base_scope = conference.sponsorships.active #: Sponsorship::PrivateAssociationRelation
    @locales = base_scope.reorder(nil).distinct.order(:locale).pluck(:locale) #: Array[String]
    @plans = conference.plans.order(:rank, :id).to_a #: Array[Plan]
    @selected_locales = selected_values(filters, locales, @locales) #: Array[String]
    @selected_plan_ids = selected_values(filters, plan_ids, plans.map { |plan| plan.id.to_s }) #: Array[String]
    @customization_filter = customization_filter && CUSTOMIZATION_VALUES.include?(customization_filter) ? customization_filter : 'all' #: String
    @sponsorships = nil #: Sponsorship::PrivateAssociationRelation?
  end

  #: () -> Sponsorship::PrivateAssociationRelation
  def sponsorships
    @sponsorships ||= filter_by_customization(
      base_scope.where(locale: selected_locales, plan_id: selected_plan_ids),
    ).includes_contacts.includes(:plan, :expense_report).order(:plan_id, :id)
  end

  #: () -> Sponsorship::PrivateAssociationRelation
  private def base_scope = @base_scope

  #: (String?, Array[String]?, Array[String]) -> Array[String]
  private def selected_values(filters, values, default_values)
    return default_values if filters.blank?

    Array(values) & default_values
  end

  #: (Sponsorship::PrivateAssociationRelation) -> Sponsorship::PrivateAssociationRelation
  private def filter_by_customization(scope)
    case customization_filter
    when 'with' then scope.where(customization: true)
    when 'without' then scope.where(customization: false)
    else scope
    end
  end
end
