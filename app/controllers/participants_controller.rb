class ParticipantsController < ApplicationController
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
    @person = Person.find(params[:id])
    @registrations = @person.registrations
      .where(edition_id: current_edition.id)
      .includes(:order, registration_workshops: :workshop)
  end
end
