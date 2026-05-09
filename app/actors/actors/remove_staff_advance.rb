module Actors
  class RemoveStaffAdvance
    include Interactor

    def call
      context.staff_advance.destroy!
    rescue => e
      context.fail!(error: e.message)
    end
  end
end
