require "rails_helper"

RSpec.describe "Audit logs", type: :system do
  let(:user) { create(:user, email: "admin@example.test") }

  before do
    sign_in user
  end

  it "shows the audit log section in the sidebar" do
    visit root_path

    expect(page).to have_link("Audit log", href: audit_logs_path)
  end

  it "lists recent paper trail versions" do
    edition = create(:edition, name: "Psalmodia 2027")
    edition.update!(name: "Psalmodia 2027 bis")

    visit audit_logs_path

    expect(page).to have_text("Audit log")
    expect(page).to have_text("Création")
    expect(page).to have_text("Modification")
    expect(page).to have_text("Edition")
    expect(page).to have_text("Psalmodia 2027 bis")
    expect(page).to have_text("Nom : Psalmodia 2027 -> Psalmodia 2027 bis")
  end

  it "does not show import-generated changes" do
    edition = create(:edition, year: 2026, start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 15))

    Importers::ParticipantsCsvImporter.new(
      csv_path: Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv").to_s,
      edition_id: edition.id
    ).call

    visit audit_logs_path

    expect(page).not_to have_text("CMD-001")
    expect(page).not_to have_text("Registration")
  end
end
