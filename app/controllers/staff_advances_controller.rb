class StaffAdvancesController < ApplicationController
  before_action :set_staff_profile

  def create
    result = Actors::AddStaffAdvance.call(
      staff_profile: @staff_profile,
      date: params[:staff_advance][:date],
      amount_cents: params[:staff_advance][:amount_cents],
      comment: params[:staff_advance][:comment]
    )

    if result.success?
      render turbo_stream: [
        turbo_stream.replace("staff_advances", render_to_string(
          partial: "staff_profiles/staff_advances",
          locals: { staff_profile: @staff_profile.reload }
        )),
        turbo_stream.replace("financial_summary", render_to_string(
          partial: "staff_profiles/financial_summary",
          locals: { staff_profile: @staff_profile }
        ))
      ]
    else
      flash.now[:alert] = result.error
      render turbo_stream: turbo_stream.replace(
        "staff_advances",
        render_to_string(
          partial: "staff_profiles/staff_advances",
          locals: { staff_profile: @staff_profile }
        )
      )
    end
  end

  def destroy
    @advance = @staff_profile.staff_advances.find(params[:id])
    Actors::RemoveStaffAdvance.call(staff_advance: @advance)

    render turbo_stream: [
      turbo_stream.replace("staff_advances", render_to_string(
        partial: "staff_profiles/staff_advances",
        locals: { staff_profile: @staff_profile.reload }
      )),
      turbo_stream.replace("financial_summary", render_to_string(
        partial: "staff_profiles/financial_summary",
        locals: { staff_profile: @staff_profile }
      ))
    ]
  end

  private

  def set_staff_profile
    @staff_profile = current_edition.staff_profiles.find(params[:staff_profile_id])
  end
end
