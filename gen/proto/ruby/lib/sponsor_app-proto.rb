# frozen_string_literal: true

# Requires this app's packages only, because gems load the descriptors they own and a second
# registration raises. Feature names match the `require` lines inside the generated files.
Dir.glob("rubykaigi/**/*_pb.rb", base: __dir__).each do |path|
  require path.delete_suffix(".rb")
end
