module Actors
  class AddStaffAdvance
    include Interactor

    def call
      staff_profile = context.staff_profile
      amount_cents  = (context.amount_cents.to_s.gsub(/[€\s]/, "").gsub(",", ".").to_f * 100).round

      advance = staff_profile.staff_advances.build(
        date:         context.date,
        amount_cents: amount_cents,
        comment:      context.comment
      )

      unless advance.save
        context.fail!(error: advance.errors.full_messages.join(", "))
      end

      context.staff_advance = advance
    end
  end
end
