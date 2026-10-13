# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connect services' do # rubocop:disable RSpec/DescribeClass
  pool = Google::Protobuf::DescriptorPool.generated_pool
  services = ['rubykaigi.sponsor_app.AdminService', 'rubykaigi.sponsor_app.SponsorService'].index_with do |name|
    pool.lookup(name)
  end

  # Every message and enum a message reaches through its fields, itself included.
  def reachable_types(descriptor, seen = {})
    return seen if seen.key?(descriptor.name)

    seen[descriptor.name] = descriptor
    descriptor.each do |field|
      subtype = field.subtype
      next unless subtype

      subtype.is_a?(Google::Protobuf::Descriptor) ? reachable_types(subtype, seen) : seen[subtype.name] = subtype
    end
    seen
  end

  services.each do |service_name, service|
    service.each do |method|
      describe "#{service_name}/#{method.name}" do
        route = Rails.application.routes.recognize_path("/#{service_name}/#{method.name}", method: :post)
        controller = "#{route.fetch(:controller).camelize}Controller".constantize
        action = route.fetch(:action)
        policy = controller.rpc_policy(action)

        it 'is routed to an action that declares a policy' do
          expect(controller.action_methods).to include(action)
          expect(policy).to be_present
        end

        if [:conference, :sponsorship].include?(policy)
          it "takes conference_slug as field 1, which its #{policy.inspect} policy reads" do
            field = method.input_type.lookup('conference_slug')
            expect([field&.number, field&.type]).to eq([1, :string])
          end
        end

        it 'references no internal type' do
          names = [method.input_type, method.output_type].flat_map { reachable_types(it).keys }

          expect(names.grep(/\.internal\./)).to be_empty
        end
      end
    end
  end
end
