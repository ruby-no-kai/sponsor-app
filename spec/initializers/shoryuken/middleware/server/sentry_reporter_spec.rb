# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shoryuken::Middleware::Server::SentryReporter do
  subject(:middleware) { described_class.new }

  let(:transaction) { instance_double(Sentry::Transaction, set_http_status: nil, finish: nil) }
  let(:scope) do
    instance_double(
      Sentry::Scope,
      set_contexts: nil, set_tags: nil, set_transaction_name: nil, set_span: nil,
      transaction_name: 'DummyJob', transaction_source: :task,
    )
  end
  let(:sqs_msg) do
    instance_double(Shoryuken::Message, message_id: 'msg-1', message_attributes: {'shoryuken_class' => {string_value: 'Shoryuken::ActiveJob::JobWrapper'}})
  end
  let(:body) { {'job_class' => 'DummyJob', 'job_id' => 'job-1'} }

  before do
    allow(Sentry).to receive_messages(initialized?: true, start_transaction: transaction)
    allow(Sentry).to receive(:with_scope).and_yield(scope)
    allow(Sentry).to receive(:capture_exception)
  end

  it "finishes the transaction with 200 when the job succeeds" do
    result = middleware.call(nil, 'default', sqs_msg, body) { :done }

    expect(result).to eq(:done)
    expect(transaction).to have_received(:set_http_status).with(200)
    expect(transaction).to have_received(:finish).once
    expect(Sentry).not_to have_received(:capture_exception)
  end

  it "captures the exception and finishes the transaction with 500 when the job fails" do
    expect {
      middleware.call(nil, 'default', sqs_msg, body) { raise 'boom' }
    }.to raise_error(RuntimeError, 'boom')

    expect(Sentry).to have_received(:capture_exception).with(an_instance_of(RuntimeError), hint: {background: false})
    expect(transaction).to have_received(:set_http_status).with(500)
    expect(transaction).to have_received(:finish).once
  end
end
