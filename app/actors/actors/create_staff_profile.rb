module Actors
  class CreateStaffProfile
    include Interactor

    def call
      profile = StaffProfile.new(context.staff_profile_params)
      profile.person  = context.person
      profile.edition = context.edition

      unless profile.save
        context.fail!(error: profile.errors.full_messages.join(", "))
      end

      context.staff_profile = profile
    end
  end
end
