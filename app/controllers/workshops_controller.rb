class WorkshopsController < ApplicationController
  before_action :set_workshop, only: [ :show, :edit, :update, :destroy ]

  def index
    @workshops = current_edition.workshops.order(:time_slot, :name)
  end

  def new
    @workshop = Workshop.new
  end

  def create
    result = Actors::CreateWorkshop.call(
      edition: current_edition,
      workshop_params: workshop_params
    )

    if result.success?
      redirect_to workshops_path, notice: "Atelier créé."
    else
      @workshop = result.workshop || Workshop.new(workshop_params)
      @error = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @registrations = @workshop.registrations.includes(:person).order("people.last_name")
  end

  def edit
  end

  def update
    result = Actors::UpdateWorkshop.call(
      workshop: @workshop,
      workshop_params: workshop_params
    )

    if result.success?
      redirect_to workshop_path(@workshop), notice: "Atelier mis à jour."
    else
      @error = result.error
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    result = Actors::DestroyWorkshop.call(workshop: @workshop)

    if result.success?
      redirect_to workshops_path, notice: "Atelier supprimé."
    else
      redirect_to workshop_path(@workshop), alert: result.error
    end
  end

  private

  def set_workshop
    @workshop = current_edition.workshops.find(params[:id])
  end

  def workshop_params
    params.require(:workshop).permit(
      :name,
      :time_slot,
      :capacity,
      :helloasso_column_name
    )
  end
end
