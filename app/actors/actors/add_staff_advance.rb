module Actors
  class AddStaffAdvance
    include Interactor

    def call
      staff_profile = context.staff_profile

      advance = staff_profile.staff_advances.build(
        date:         context.date,
        amount_cents: context.amount_cents.to_i,
        comment:      context.comment
      )

      unless advance.save
        context.fail!(error: advance.errors.full_messages.join(", "))
      end

      context.staff_advance = advance
    end
  end
end
