class StaffPaymentsController < ApplicationController
  before_action :set_staff_profile

  def create
    result = Actors::AddStaffPayment.call(
      staff_profile: @staff_profile,
      date: params[:staff_payment][:date],
      amount_cents: params[:staff_payment][:amount_cents],
      comment: params[:staff_payment][:comment]
    )

    if result.success?
      render turbo_stream: [
        turbo_stream.replace("staff_payments", render_to_string(
          partial: "staff_profiles/staff_payments",
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
        "staff_payments",
        render_to_string(
          partial: "staff_profiles/staff_payments",
          locals: { staff_profile: @staff_profile }
        )
      )
    end
  end

  def destroy
    @payment = @staff_profile.staff_payments.find(params[:id])
    Actors::RemoveStaffPayment.call(staff_payment: @payment)

    render turbo_stream: [
      turbo_stream.replace("staff_payments", render_to_string(
        partial: "staff_profiles/staff_payments",
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
