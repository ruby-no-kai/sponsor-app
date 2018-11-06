class RootController < ApplicationController
  def index
    # TODO: redirect to the user_sponsorship path when logged in
    redirect_to user_conferences_path
  end
end
