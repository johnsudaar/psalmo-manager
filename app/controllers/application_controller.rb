class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit

  include Pagy::Backend

  helper_method :current_edition

  def user_for_paper_trail
    current_user&.email
  end

  private

  def current_edition
    @current_edition ||= Edition.find_by(id: session[:edition_id]) ||
                         Edition.order(year: :desc).first
  end
end
