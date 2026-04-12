class ParticipantsController < ApplicationController
  before_action :set_person, only: [ :show, :edit_workshops, :update_workshops, :destroy_workshop_override ]

  def index
    scope = Person
      .joins(:registrations)
      .where(registrations: { edition_id: current_edition.id })
      .distinct

    if params[:q].present?
      term = params[:q].downcase
      scope = scope.where(
        "LOWER(people.last_name || ' ' || people.first_name) LIKE ? OR LOWER(people.email) LIKE ?",
        "%#{term}%",
        "%#{term}%"
      )
    end

    if params[:age_category].present?
      scope = scope
        .joins(:registrations)
        .where(registrations: { age_category: Registration.age_categories[params[:age_category]] })
    end

    if params[:workshop_id].present?
      scope = scope
        .joins(registrations: :registration_workshops)
        .where(registration_workshops: { workshop_id: params[:workshop_id] })
    end

    if params[:unaccompanied_minors] == "1"
      scope = scope.where(registrations: { is_unaccompanied_minor: true })
    end

    if params[:with_conflicts] == "1"
      scope = scope.where(registrations: { has_conflict: true })
    end

    if params[:excluded_from_stats] == "1"
      scope = scope.where(registrations: { excluded_from_stats: true })
    end

    scope = scope.order("people.last_name, people.first_name")

    @pagy, @people = pagy(scope, items: 50)
  end

  def show
    @registrations = edition_registrations
  end

  def edit_workshops
    @registration = edition_registrations
      .includes(registration_workshops: :workshop)
      .find(params[:registration_id])
    @workshops = current_edition.workshops.order(:time_slot, :name)
  end

  def update_workshops
    registration = edition_registrations.find(params[:registration_id])

    result = Actors::ApplyWorkshopSubstitution.call(
      registration: registration,
      workshop_ids: workshop_params[:workshop_ids]
    )

    if result.success?
      redirect_to participant_path(@person), notice: "Ateliers mis à jour."
    else
      redirect_to edit_workshops_participant_path(@person, registration_id: registration.id), alert: result.error
    end
  end

  def destroy_workshop_override
    registration = edition_registrations.find(params[:registration_id])

    result = Actors::RemoveWorkshopOverride.call(registration: registration)

    unless result.success?
      redirect_to participant_path(@person), alert: result.error and return
    end

    redirect_to participant_path(@person), notice: "Changement d'atelier supprimé."
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def edition_registrations
    @person.registrations
      .where(edition_id: current_edition.id)
      .includes(:order, registration_workshops: :workshop)
  end

  def workshop_params
    params.permit(:registration_id, workshop_ids: [])
  end
end
