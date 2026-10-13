# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "sponsor_app-proto"
  spec.version = "0.0.0"
  spec.authors = ["Sorah Fukumori"]
  spec.email = ["her@sorah.jp"]
  spec.summary = "sponsor-app Protocol Buffers messages, generated from proto/"
  spec.homepage = "https://github.com/ruby-no-kai/sponsor-app"
  spec.license = "MIT"

  # Read from disk rather than git so freshly generated files load before they are committed.
  spec.files = [
    File.basename(__FILE__),
    *Dir.glob(["lib/**/*.rb", "sig/**/*.rbs"], base: __dir__),
  ]
  spec.require_paths = ["lib"]

  # The generated code targets the runtime of the protoc release pinned in mise.toml.
  spec.add_dependency("google-protobuf", "~> 4.36")
end
