# frozen_string_literal: true

module QueryCountHelper
  # SQL statements the block runs, leaving out schema lookups and query cache hits.
  def query_count(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCountHelper, type: :request
  config.include QueryCountHelper, type: :model
end
