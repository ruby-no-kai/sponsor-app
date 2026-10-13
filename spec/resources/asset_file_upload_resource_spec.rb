# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssetFileUploadResource do
  it 'builds an AssetFileUpload from the presigned POST and report_to' do
    session = {url: 'https://s3.example.com/', fields: {'key' => 'k'}, max_size: 10, id: 3}

    expect(described_class.new(session, params: {report_to: '/report/here'}).as_protobuf).to eq(Rk::SponsorApp::AssetFileUpload.new(
      file_id: 3,
      url: 'https://s3.example.com/',
      fields: {'key' => 'k'},
      max_size: 10,
      report_to: '/report/here',
      id: '3',
    ))
  end
end
