module Actors
  class CreateStaffProfile
    include Interactor

    def call
      profile = StaffProfile.new(context.staff_profile_params || {})
      profile.edition = context.edition
      context.staff_profile = profile

      # Support two creation modes:
      # 1. Linked to an existing Person (person_id provided via context or params)
      # 2. Direct entry (first_name + last_name in staff_profile_params, no person)
      if context.person
        profile.person = context.person
      end

      unless profile.save
        context.fail!(error: profile.errors.full_messages.join(", "))
      end
    end
  end
end
