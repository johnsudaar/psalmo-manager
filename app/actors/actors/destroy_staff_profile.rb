module Actors
  class DestroyStaffProfile
    include Interactor

    def call
      context.staff_profile.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      context.fail!(error: e.message)
    end
  end
end
