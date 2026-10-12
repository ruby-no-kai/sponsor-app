# typed: true
# frozen_string_literal: true

# Entrypoints the app reaches for but `Bundler.require` does not load, either
# because the Gemfile marks them `require: false` or because the gem lazy-loads
# the constant.
