class Admin::DashboardController < Admin::ApplicationController
  def index
    redirect_to conferences_path
  end
end
