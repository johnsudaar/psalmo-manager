require "rails_helper"

RSpec.describe Edition, type: :model do
  describe "attachments" do
    it "can attach a logo" do
      edition = create(:edition)
      edition.logo.attach(
        io: StringIO.new("fake image data"),
        filename: "logo.png",
        content_type: "image/png"
      )

      expect(edition.logo).to be_attached
    end
  end
end
