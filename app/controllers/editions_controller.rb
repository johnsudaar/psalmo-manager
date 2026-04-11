class EditionsController < ApplicationController
  before_action :set_edition, only: [ :edit, :update ]

  def index
    @editions = Edition.ordered
  end

  def new
    @edition = Edition.new
  end

  def create
    result = Actors::CreateEdition.call(edition_params: edition_params)

    if result.success?
      redirect_to editions_path, notice: "Édition créée."
    else
      @edition = result.edition || Edition.new(edition_params)
      @error = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    success = true

    edition_params.to_h.each do |key, val|
      result = Actors::UpdateEditionSettings.call(
        edition: @edition,
        field: key,
        value: val
      )

      unless result.success?
        success = false
        @error = result.error
        @field = key
      end
    end

    if success
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: edition_params.keys.map { |field|
            turbo_stream.replace("field_error_#{field}", "")
          }
        end
        format.html do
          redirect_to edit_edition_path(@edition), notice: "Paramètres mis à jour."
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "field_error_#{@field}",
            @error.to_s
          )
        end
        format.html do
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_edition
    @edition = Edition.find(params[:id])
  end

  def edition_params
    params.require(:edition).permit(
      :name,
      :year,
      :start_date,
      :end_date,
      :helloasso_form_slug,
      :km_rate_cents
    )
  end
end
