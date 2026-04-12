class StaffProfilesController < ApplicationController
  before_action :set_staff_profile, only: [ :show, :edit, :update ]

  def index
    @staff_profiles = current_edition.staff_profiles
      .left_joins(:person)
      .includes(:person)
      .order(Arel.sql("COALESCE(people.last_name, staff_profiles.last_name)"))
  end

  def new
    @staff_profile = StaffProfile.new
  end

  def create
    person = Person.find_by(id: staff_profile_params[:person_id]) if staff_profile_params[:person_id].present?

    result = Actors::CreateStaffProfile.call(
      edition:              current_edition,
      person:               person,
      staff_profile_params: staff_profile_params.except(:person_id)
    )

    if result.success?
      redirect_to staff_profile_path(result.staff_profile), notice: "Fiche staff créée."
    else
      @staff_profile = result.staff_profile || StaffProfile.new
      @error = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # @staff_profile already set by set_staff_profile; associations loaded lazily
  end

  def edit
  end

  def update
    success = true
    last_failed_field = nil

    staff_profile_params.to_h.each do |k, v|
      result = Actors::UpdateStaffField.call(
        staff_profile: @staff_profile,
        field: k,
        value: v
      )

      unless result.success?
        success = false
        last_failed_field = k
        @error = result.error
      end
    end

    respond_to do |format|
      format.turbo_stream do
        if success
          streams = staff_profile_params.keys.map { |field|
            turbo_stream.replace("field_error_#{field}", "")
          }
          streams << turbo_stream.replace("financial_summary", render_to_string(
            partial: "staff_profiles/financial_summary",
            locals: { staff_profile: @staff_profile }
          ))
          render turbo_stream: streams
        else
          render turbo_stream: turbo_stream.replace(
            "field_error_#{last_failed_field}",
            @error.to_s
          )
        end
      end
      format.html do
        if success
          redirect_to staff_profile_path(@staff_profile), notice: "Paramètres mis à jour."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  def fiche
    @staff_profile = current_edition.staff_profiles
      .includes(:person, :edition, :staff_advances, :staff_payments)
      .find(params[:id])

    pdf = FicheIndemnisationPdf.new(@staff_profile).render

    send_data pdf,
              filename:    "fiche_#{@staff_profile.dossier_number}_#{@staff_profile.full_name.gsub(' ', '_')}.pdf",
              type:        "application/pdf",
              disposition: "inline"
  end

  private

  def set_staff_profile
    @staff_profile = current_edition.staff_profiles.find(params[:id])
  end

  def staff_profile_params
    params.require(:staff_profile).permit(
      :person_id,
      :first_name,
      :last_name,
      :email,
      :phone,
      :transport_mode,
      :km_traveled,
      :km_rate_override_cents,
      :allowance_cents,
      :allowance_label,
      :supplies_cost_cents,
      :accommodation_cost_cents,
      :meals_cost_cents,
      :tickets_cost_cents,
      :member_uncovered_accommodation_cents,
      :member_uncovered_meals_cents,
      :member_uncovered_tickets_cents,
      :member_covered_tickets_cents,
      :notes
    )
  end
end
