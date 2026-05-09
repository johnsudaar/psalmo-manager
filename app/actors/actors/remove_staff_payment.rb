module Actors
  class RemoveStaffPayment
    include Interactor

    def call
      context.staff_payment.destroy!
    rescue => e
      context.fail!(error: e.message)
    end
  end
end
