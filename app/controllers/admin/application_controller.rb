class Admin::ApplicationController < ::ApplicationController
  layout 'admin'
  before_action :require_staff
end
