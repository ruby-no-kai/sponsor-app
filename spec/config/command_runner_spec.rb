# frozen_string_literal: true

require_relative '../../config/lambda_runner'

RSpec.describe CommandRunner do
  let(:context) { Struct.new(:aws_request_id).new('req-1') }

  describe '.run' do
    it "runs an argv array" do
      result = nil
      expect { result = described_class.run(%w[echo hello], context:) }.to output(/^hello$/).to_stdout
      expect(result).to include(ok: true, status: 0, output: "hello\n")
    end

    it "rejects an empty array" do
      expect { described_class.run([], context:) }
        .to raise_error(RuntimeError, 'invalid argument')
        .and output(/RUNCMD req-1/).to_stdout
    end

    it "rejects non-string arguments" do
      expect { described_class.run(['echo', 1], context:) }
        .to raise_error(RuntimeError, 'invalid argument')
        .and output(/RUNCMD req-1/).to_stdout
    end
  end
end
