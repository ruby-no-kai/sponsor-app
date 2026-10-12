# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class PlansController < Api::Admin::ApplicationController
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListPlansResponse
      def list_plans
        plans = conference.plans.with_active_sponsorship_count.order(rank: :asc, id: :asc)

        Rk::SponsorApp::AdminServiceListPlansResponse.new(plans: plans.map { admin_plan_message(it) })
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetPlanResponse
      def get_plan
        Rk::SponsorApp::AdminServiceGetPlanResponse.new(plan: admin_plan_message(find_plan))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreatePlanResponse
      def create_plan
        plan = conference.plans.build
        save_input!(plan)

        Rk::SponsorApp::AdminServiceCreatePlanResponse.new(plan: admin_plan_message(plan))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdatePlanResponse
      def update_plan
        plan = find_plan
        save_input!(plan)

        Rk::SponsorApp::AdminServiceUpdatePlanResponse.new(plan: admin_plan_message(plan))
      end

      #: () -> Plan
      private def find_plan
        plan_id = connect_request.plan_id #: Integer
        conference.plans.with_active_sponsorship_count.find_by(id: plan_id) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no plan #{plan_id}.",
        ))
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (Plan) -> void
      private def save_input!(plan)
        input = connect_request.input #: Rk::SponsorApp::PlanInput
        plan.update!(
          name: input.name,
          rank: input.rank,
          summary: input.has_summary? ? input.summary : nil,
          price_text: input.price_text,
          price: input.price,
          price_booth: input.price_booth,
          capacity: input.capacity,
          number_of_guests: input.number_of_guests,
          booth_size: input.has_booth_size? ? input.booth_size : nil,
          words_limit: input.words_limit,
          auto_acceptance: input.auto_acceptance,
          talkable: input.talkable,
          closes_at: input.closes_at&.to_time,
        )
      end

      #: (Plan) -> Rk::SponsorApp::AdminPlan
      private def admin_plan_message(plan)
        Api::AdminPlanResource.new(plan).as_protobuf
      end
    end
  end
end
