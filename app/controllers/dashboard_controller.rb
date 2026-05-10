class DashboardController < ApplicationController
  def index
    return unless current_edition

    @stats = DashboardStats.new(current_edition)
  end
end
