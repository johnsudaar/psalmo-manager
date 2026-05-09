class SessionsController < ApplicationController
  def update_edition
    session[:edition_id] = params[:edition_id]
    redirect_back fallback_location: root_path
  end
end
