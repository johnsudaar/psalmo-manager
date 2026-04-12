module Actors
  class AddStaffPayment
    include Interactor

    def call
      staff_profile = context.staff_profile
      amount_cents  = (context.amount_cents.to_s.gsub(/[€\s]/, "").gsub(",", ".").to_f * 100).round

      payment = staff_profile.staff_payments.build(
        date:         context.date,
        amount_cents: amount_cents,
        comment:      context.comment
      )

      unless payment.save
        context.fail!(error: payment.errors.full_messages.join(", "))
      end

      context.staff_payment = payment
    end
  end
end
