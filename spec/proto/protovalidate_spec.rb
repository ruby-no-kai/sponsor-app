# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'buf.validate rules' do # rubocop:disable RSpec/DescribeClass
  it 'compiles for every generated message' do
    # AbstractMessage is a private constant.
    messages = Google::Protobuf.const_get(:AbstractMessage).subclasses.select { it.name&.start_with?('Rk::SponsorApp::') }
    validator = Protovalidate::Validator.new

    expect(messages).to include(Rk::SponsorApp::ExpenseLineItemPatch)
    expect { validator.register(*messages) }.not_to raise_error
  end
end
