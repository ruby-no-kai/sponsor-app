# typed: true

# Rails sets Time.zone_default from config.time_zone (UTC unless configured)
# at boot, so Time.current never returns a bare Time here.
class Time
  sig { returns(ActiveSupport::TimeWithZone) }
  def self.current; end
end
