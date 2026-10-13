# typed: true
# frozen_string_literal: true

# Entrypoints the app reaches for but `Bundler.require` does not load, either
# because the Gemfile marks them `require: false`, because the gem lazy-loads
# the constant, or because the entrypoint is an optional integration the gem
# never requires itself.

require "protobufable/alba_binding"
require "protobufable/protovalidate"
