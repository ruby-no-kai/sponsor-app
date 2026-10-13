# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SlackWebhookJob, type: :job do
  before do
    allow(Net::HTTP).to receive(:post_form)
    allow(Rails.application.config.x.slack).to receive(:webhook_urls).and_return(
      {default: 'https://hooks.example/default', feed: 'https://hooks.example/feed'},
    )
  end

  it 'posts the text to the named webhook' do
    described_class.perform_now(text: 'hi', hook_name: 'feed')

    expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/feed'), {payload: '{"text":"hi"}'})
  end

  it 'posts to the default webhook' do
    described_class.perform_now(text: 'hi')

    expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/default'), {payload: '{"text":"hi"}'})
  end

  it 'does nothing without a webhook URL' do
    allow(Rails.application.config.x.slack).to receive(:webhook_urls).and_return(nil)

    described_class.perform_now(text: 'hi')

    expect(Net::HTTP).not_to have_received(:post_form)
  end

  context 'with the arguments of a job enqueued with a payload Hash' do
    it 'posts the payload text to the named webhook' do
      job = described_class.new({text: 'hi'}, hook_name: :feed)
      job.deserialize(JSON.parse(JSON.generate(job.serialize)))
      job.perform_now

      expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/feed'), {payload: '{"text":"hi"}'})
    end

    it 'posts the payload text to the default webhook' do
      job = described_class.new({text: 'hi'})
      job.deserialize(JSON.parse(JSON.generate(job.serialize)))
      job.perform_now

      expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/default'), {payload: '{"text":"hi"}'})
    end
  end

  it 'round-trips text: through the queue' do
    job = described_class.new(text: 'hi', hook_name: :feed)
    job.deserialize(JSON.parse(JSON.generate(job.serialize)))
    job.perform_now

    expect(Net::HTTP).to have_received(:post_form).with(URI('https://hooks.example/feed'), {payload: '{"text":"hi"}'})
  end
end
