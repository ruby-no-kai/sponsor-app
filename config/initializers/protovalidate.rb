# typed: strict
# frozen_string_literal: true

# Compiles every message's buf.validate rules at boot, so a broken CEL expression fails startup and
# no request waits on the compilation lock. The generated messages are loaded by Bundler.require.
Rails.application.config.after_initialize do
  Protovalidate.register_all
end
