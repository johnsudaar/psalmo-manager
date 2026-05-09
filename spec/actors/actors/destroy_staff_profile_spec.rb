require "rails_helper"

RSpec.describe Actors::DestroyStaffProfile do
  let!(:staff_profile) { create(:staff_profile) }

  it "destroys the staff profile" do
    expect { described_class.call(staff_profile: staff_profile) }.to change(StaffProfile, :count).by(-1)
  end

  it "succeeds" do
    expect(described_class.call(staff_profile: staff_profile)).to be_success
  end
end
