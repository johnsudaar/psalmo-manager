class ExportsController < ApplicationController
  STUB_MESSAGE = "Export non disponible (Phase 8).".freeze

  def index
  end

  def participants
    render plain: STUB_MESSAGE
  end

  def workshop_roster_csv
    render plain: STUB_MESSAGE
  end

  def staff_summary
    render plain: STUB_MESSAGE
  end

  def financial_report
    render plain: STUB_MESSAGE
  end

  def orders_csv
    render plain: STUB_MESSAGE
  end
end
