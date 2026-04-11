class WorkshopSubstitutionsController < ApplicationController
  def index
    @people = []

    if params[:q].present?
      @people = Person
        .joins(:registrations)
        .where(registrations: { edition_id: current_edition.id })
        .where(
          "LOWER(people.last_name || ' ' || people.first_name) LIKE ?",
          "%#{params[:q].downcase}%"
        )
        .distinct
        .limit(20)
    end
  end

  def new
    @registration = current_edition.registrations
      .includes(registration_workshops: :workshop)
      .find(params[:registration_id])
    @workshops = current_edition.workshops.order(:time_slot, :name)
  end

  def create
    reg = current_edition.registrations.find(params[:registration_id])
    new_ws = current_edition.workshops.find(params[:new_workshop_id])

    result = Actors::ApplyWorkshopSubstitution.call(
      registration: reg,
      new_workshop: new_ws
    )

    if result.success?
      redirect_to workshop_substitutions_path, notice: "Changement appliqué."
    else
      redirect_back fallback_location: workshop_substitutions_path, alert: result.error
    end
  end
end
