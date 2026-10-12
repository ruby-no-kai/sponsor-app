# typed: true

# Tapioca types only the instance `helpers` as HelperProxy, so the class-level reader lacks the app's helpers.
class ApplicationController
  sig { returns(HelperProxy) }
  def self.helpers; end
end
