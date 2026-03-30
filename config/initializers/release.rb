# frozen_string_literal: true

Rails.configuration.x.release.release = begin
  Rails.root.join('REVISION').read.chomp
rescue
  'unknown'
end
