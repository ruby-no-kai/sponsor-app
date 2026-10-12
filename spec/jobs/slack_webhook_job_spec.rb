# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SlackWebhookJob, type: :job do
  before do
    allow(Net::HTTP).to receive(:post_form)
  end

  it 'posts the payload to the named webhook' do
    allow(Rails.application.config.x.slack).to receive(:webhook_urls).and_return(
      {default: 'https://hooks.example/default', feed: 'https://hooks.example/feed'},
    )

    described_class.perform_now({text: 'hi'}, hook_name: 'feed')

    expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/feed'), {payload: '{"text":"hi"}'})
  end

  it 'does nothing without a webhook URL' do
    described_class.perform_now({text: 'hi'})

    expect(Net::HTTP).not_to have_received(:post_form)
  end
end
