module Actors
  class AddStaffPayment
    include Interactor

    def call
      staff_profile = context.staff_profile

      payment = staff_profile.staff_payments.build(
        date:         context.date,
        amount_cents: context.amount_cents.to_i,
        comment:      context.comment
      )

      unless payment.save
        context.fail!(error: payment.errors.full_messages.join(", "))
      end

      context.staff_payment = payment
    end
  end
end
