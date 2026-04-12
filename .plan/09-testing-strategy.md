# 09 — Testing Strategy

## Stack

| Tool | Purpose |
|---|---|
| RSpec Rails | Test framework |
| FactoryBot Rails | Test data creation |
| Faker | Random data for factories |
| WebMock | Stub HTTP requests (HelloAsso API) |
| VCR | Record/replay real API responses |
| Shoulda Matchers | One-liner association and validation specs |
| Capybara (rack_test) | System (end-to-end) specs — default driver |
| Capybara + Selenium | JS-tagged system specs only (`:js` metadata) |

---

## Folder Structure

```
spec/
├── rails_helper.rb
├── spec_helper.rb
├── support/
│   ├── capybara.rb        ← NEW: rack_test default, selenium only for :js
│   ├── factory_bot.rb
│   ├── shoulda_matchers.rb
│   ├── webmock.rb
│   └── vcr.rb
├── factories/
│   ├── users.rb
│   ├── editions.rb
│   ├── workshops.rb
│   ├── people.rb
│   ├── orders.rb
│   ├── registrations.rb
│   ├── registration_workshops.rb
│   ├── staff_profiles.rb
│   ├── staff_advances.rb
│   └── staff_payments.rb
├── models/
│   ├── edition_spec.rb
│   ├── workshop_spec.rb
│   ├── person_spec.rb
│   ├── order_spec.rb
│   ├── registration_spec.rb
│   ├── registration_workshop_spec.rb
│   ├── staff_profile_spec.rb
│   ├── staff_advance_spec.rb
│   └── staff_payment_spec.rb
├── services/
│   ├── helloasso/
│   │   ├── client_spec.rb
│   │   ├── sync_service_spec.rb
│   │   └── webhook_processor_spec.rb
│   └── importers/
│       ├── participants_csv_importer_spec.rb
│       └── staff_csv_importer_spec.rb
├── jobs/
│   └── helloasso_sync_job_spec.rb
├── requests/
│   ├── webhooks/
│   │   └── helloasso_spec.rb
│   ├── exports_spec.rb
│   └── orders_spec.rb
├── queries/
│   └── dashboard_stats_spec.rb
├── pdf/
│   ├── fiche_indemnisation_pdf_spec.rb
│   └── workshop_roster_pdf_spec.rb
├── system/
│   ├── authentication_spec.rb
│   ├── participants_spec.rb
│   ├── workshop_substitution_spec.rb
│   └── staff_profile_spec.rb
└── fixtures/
    ├── csv/
    │   ├── donnes_brutes_sample.csv
    │   ├── filtres_sample.csv
    │   ├── exclusions_sample.csv
    │   ├── mineurs_sample.csv
    │   ├── staff_recap_sample.csv
    │   └── versements_sample.csv
    └── vcr_cassettes/
        └── helloasso/
```

---

## Support Files

### spec/support/capybara.rb

The **default driver for all system specs is `:rack_test`** (no browser, no network).
Selenium remote Chrome is only used for examples explicitly tagged `js: true`.

```ruby
require "capybara/rails"
require "capybara/rspec"
require "selenium-webdriver"

Capybara.register_driver :selenium_remote_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,900")

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://selenium:4444/wd/hub",
    options: options
  )
end

Capybara.default_driver    = :rack_test
Capybara.javascript_driver = :selenium_remote_chrome

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_remote_chrome
  end

  config.around(:each, :js, type: :system) do |example|
    WebMock.allow_net_connect!
    example.run
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
```

**Why rack_test instead of Selenium for most system specs?**  
Running Selenium inside Docker requires the remote Chrome container to reach the Capybara test
Puma server by name/IP. This caused `ERR_SSL_PROTOCOL_ERROR` in our setup (Selenium hub at
`http://selenium:4444` could not reach `http://app:3001`). Since the critical user flows do not
rely on JavaScript (no Turbo Frame in-place updates, no Stimulus auto-save in the test path),
`rack_test` gives full coverage without the networking complexity. Tag individual examples with
`js: true` only when JavaScript execution is genuinely required.

### spec/rails_helper.rb — required additions

```ruby
# Devise helpers — must be included for all 3 spec types
config.include Devise::Test::ControllerHelpers, type: :controller
config.include Devise::Test::IntegrationHelpers, type: :request
config.include Devise::Test::IntegrationHelpers, type: :system
```

### spec/support/factory_bot.rb
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

### spec/support/shoulda_matchers.rb
```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### spec/support/webmock.rb
```ruby
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
```

### spec/support/vcr.rb
```ruby
require "vcr"
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<HELLOASSO_TOKEN>") { ENV["HELLOASSO_CLIENT_SECRET"] }
end
```

---

## Factory Definitions

### users.rb
```ruby
FactoryBot.define do
  factory :user do
    email    { Faker::Internet.unique.email }
    password { "password123" }
  end
end
```

> **Required**: The `User` model is the Devise admin user. Both `email` and `password` must be
> set. `sign_in user` in specs uses Devise test helpers and requires a persisted user with valid
> credentials.

### editions.rb
```ruby
FactoryBot.define do
  factory :edition do
    name          { "Psalmodia #{year}" }
    year          { 2026 }
    start_date    { Date.new(year, 7, 1) }
    end_date      { Date.new(year, 7, 7) }
    helloasso_form_slug { "psalmodia-#{year}" }
    km_rate_cents { 33 }
  end
end
```

### workshops.rb
```ruby
FactoryBot.define do
  factory :workshop do
    association :edition
    name      { Faker::Lorem.unique.word.upcase }
    time_slot { :matin }
    capacity  { 20 }
  end
end
```

### people.rb
```ruby
FactoryBot.define do
  factory :person do
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    email         { Faker::Internet.unique.email }
    phone         { Faker::PhoneNumber.phone_number }
    date_of_birth { Faker::Date.birthday(min_age: 8, max_age: 60) }
  end
end
```

### orders.rb
```ruby
FactoryBot.define do
  factory :order do
    association :edition
    association :payer, factory: :person
    helloasso_order_id { "order-#{SecureRandom.hex(8)}" }
    order_date         { Time.current }
    status             { :confirmed }
  end
end
```

### registrations.rb
```ruby
FactoryBot.define do
  factory :registration do
    association :order
    association :person
    edition              { order.edition }
    helloasso_ticket_id  { "ticket-#{SecureRandom.hex(8)}" }
    age_category         { :adulte }
    ticket_price_cents   { 10000 }
    discount_cents       { 0 }
    has_conflict         { false }
  end
end
```

### staff_profiles.rb
```ruby
FactoryBot.define do
  factory :staff_profile do
    association :person
    association :edition
    dossier_number        { nil }  # auto-assigned by callback
    transport_mode        { "Voiture" }
    km_traveled           { 150 }
    allowance_cents       { 20000 }
    supplies_cost_cents   { 4500 }
    accommodation_cost_cents { 0 }
    meals_cost_cents         { 0 }
    tickets_cost_cents       { 0 }
  end
end
```

### staff_advances.rb
```ruby
FactoryBot.define do
  factory :staff_advance do
    association :staff_profile
    date         { Date.today - 30 }
    amount_cents { 5000 }
    comment      { "Acompte initial" }
  end
end
```

### staff_payments.rb
```ruby
FactoryBot.define do
  factory :staff_payment do
    association :staff_profile
    date         { Date.today }
    amount_cents { 20000 }
    comment      { "Virement final" }
  end
end
```

---

## Model Specs

### What to test in every model spec

1. **Validations** — presence, uniqueness, numericality (use Shoulda one-liners where possible)
2. **Associations** — use Shoulda `belong_to`, `have_many`
3. **Enums** — test that valid values are accepted and invalid values raise
4. **Scopes** — test each named scope returns the expected subset
5. **Computed methods** — test each method that calculates a value

### Example: staff_profile_spec.rb

```ruby
RSpec.describe StaffProfile, type: :model do
  subject(:profile) { build(:staff_profile) }

  describe "associations" do
    it { is_expected.to belong_to(:person) }
    it { is_expected.to belong_to(:edition) }
    it { is_expected.to have_many(:staff_advances).dependent(:destroy) }
    it { is_expected.to have_many(:staff_payments).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:dossier_number) }
    it { is_expected.to validate_uniqueness_of(:dossier_number).scoped_to(:edition_id) }
  end

  describe "#effective_km_rate_cents" do
    it "returns the edition rate when no override is set" do
      profile.km_rate_override_cents = nil
      expect(profile.effective_km_rate_cents).to eq(profile.edition.km_rate_cents)
    end

    it "returns the override rate when set" do
      profile.km_rate_override_cents = 41
      expect(profile.effective_km_rate_cents).to eq(41)
    end
  end

  describe "#travel_allowance_cents" do
    it "computes km × rate" do
      profile.km_traveled = 100
      profile.edition.km_rate_cents = 33
      profile.km_rate_override_cents = nil
      expect(profile.travel_allowance_cents).to eq(3300)
    end
  end

  describe "#balance_cents" do
    it "returns positive when Psalmodia owes the instructor" do
      profile.save!
      create(:staff_payment, staff_profile: profile, amount_cents: 100_00)
      # amount_owed - payments = positive → Psalmodia still owes
      expect(profile.balance_cents).to be > 0
    end
  end
end
```

---

## Service Specs

### HelloAsso Client

Test using WebMock stubs. Never make real HTTP calls in specs.

```ruby
RSpec.describe Helloasso::Client do
  let(:client) { described_class.new }

  before do
    stub_request(:post, "https://api.helloasso.com/oauth2/token")
      .to_return(body: { access_token: "fake-token", expires_in: 1800 }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  describe "#get" do
    it "includes the Bearer token in the Authorization header" do
      stub = stub_request(:get, %r{api\.helloasso\.com})
               .with(headers: { "Authorization" => "Bearer fake-token" })
               .to_return(body: "{}",
                          headers: { "Content-Type" => "application/json" })
      client.get("/v5/organizations/psalmodia/forms")
      expect(stub).to have_been_requested
    end
  end
end
```

### CSV Importers

Use fixture CSV files in `spec/fixtures/csv/`. Assert record counts and specific field values.
Fixture CSVs must use fictional names and `.example.test` email addresses only.

```ruby
RSpec.describe Importers::ParticipantsCsvImporter do
  let(:edition) { create(:edition) }
  let(:csv_path) { Rails.root.join("spec/fixtures/csv/donnes_brutes_sample.csv") }

  subject(:result) { described_class.new(csv_path: csv_path, edition_id: edition.id).call }

  it "creates the expected number of registrations" do
    expect { result }.to change(Registration, :count).by(3)
  end

  it "creates workshops from the pivot columns" do
    result
    expect(Workshop.where(edition: edition).pluck(:name)).to include("CIRQUE")
  end

  it "is idempotent" do
    described_class.new(csv_path: csv_path, edition_id: edition.id).call
    expect { result }.not_to change(Registration, :count)
  end
end
```

---

## Request Specs

Test HTTP responses, authentication, and content type. No JavaScript.

Important lesson: request specs must cover a smoke-test render for every controller endpoint,
especially index pages. This catches controller/view integration errors such as a bad
`includes(:association_name)` that model or actor specs will never exercise.

```ruby
RSpec.describe "Webhooks::Helloasso", type: :request do
  let(:secret) { ENV["HELLOASSO_WEBHOOK_SECRET"] }
  let(:payload) { { eventType: "Order", data: {} }.to_json }
  let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", secret, payload) }

  it "returns 200 with a valid signature" do
    post "/webhooks/helloasso",
         params: payload,
         headers: { "Content-Type" => "application/json",
                    "X-HelloAsso-Signature" => signature }
    expect(response).to have_http_status(:ok)
  end

  it "returns 401 with an invalid signature" do
    post "/webhooks/helloasso",
         params: payload,
         headers: { "Content-Type" => "application/json",
                    "X-HelloAsso-Signature" => "bad" }
    expect(response).to have_http_status(:unauthorized)
  end
end
```

---

## PDF Specs

Test that the generated PDF contains expected text content. Do not test layout/positioning.

```ruby
RSpec.describe FicheIndemnisationPdf do
  let(:staff_profile) { create(:staff_profile, :with_advances_and_payments) }
  let(:pdf_text) do
    pdf_data = described_class.new(staff_profile).render
    PDF::Reader.new(StringIO.new(pdf_data)).pages.map(&:text).join
  end

  it "includes the staff member's name" do
    expect(pdf_text).to include(staff_profile.full_name)
  end

  it "includes the dossier number" do
    expect(pdf_text).to include(staff_profile.dossier_number.to_s)
  end

  it "includes the total owed to the instructor" do
    expect(pdf_text).to include("Montant dû à l'animateur")
  end
end
```

**Note**: Add `gem "pdf-reader"` to the test group for text extraction.

---

## System Specs

Default driver is `:rack_test`. Use `js: true` metadata only when the test genuinely requires
JavaScript (Turbo Frame in-place updates, Stimulus events). See `spec/support/capybara.rb`.

### Rules for writing system specs

1. **Use `let!` (bang) for any factory that must exist before a `visit` call.** Lazy `let` will
   not create the record in time, causing `current_edition` to return `nil` and controller errors.

2. **Edition resolution in system specs**: `current_edition` falls back to
   `Edition.order(year: :desc).first`. As long as exactly one edition exists per example,
   this works without setting `session[:edition_id]`. Always use `let!(:edition)`.

3. **Turbo Frame selectors**: The view wraps partials in `<turbo-frame id="staff_advances">`.
   This creates two elements matching `#staff_advances` (the frame and the inner div). Use the
   element-specific selector `"turbo-frame#staff_advances"` to avoid Capybara's
   `Ambiguous match` error.

4. **Navigation selects**: The layout nav contains an edition selector `<select>`. `first("select")`
   will match it, not the content-area select. Always use a named selector:
   ```ruby
   find("select[name='new_workshop_id']")
   ```

5. **Controllers that render Turbo Stream must also handle HTML**: `rack_test` sends plain HTML
   requests, not `text/vnd.turbo-stream.html`. Any controller action that previously only rendered
   `turbo_stream:` must include a `respond_to` block with an `format.html` redirect fallback so
   the spec can follow the redirect and assert page content.

   Example (`StaffAdvancesController`):
   ```ruby
   respond_to do |format|
     format.turbo_stream { render turbo_stream: [...] }
     format.html         { redirect_to staff_profile_path(@staff_profile) }
   end
   ```

### Implemented system specs

| File | Driver | Flows covered |
|---|---|---|
| `spec/system/authentication_spec.rb` | rack_test | Login form, redirect, valid sign-in, invalid sign-in, sign-out |
| `spec/system/participants_spec.rb` | rack_test | Index renders, participant list, search filter, minor badge |
| `spec/system/workshop_substitution_spec.rb` | rack_test | Search, substitution form, applying substitution |
| `spec/system/staff_profile_spec.rb` | rack_test | Show page, add advance (with redirect), remove advance |

### Example

```ruby
RSpec.describe "Workshop substitution", type: :system do
  let(:user)    { create(:user) }
  let!(:edition) { create(:edition) }  # let! — must exist before visit
  let!(:workshop_a) { create(:workshop, edition: edition, name: "CIRQUE",    time_slot: :matin) }
  let!(:workshop_b) { create(:workshop, edition: edition, name: "MARMITONS", time_slot: :matin) }
  let(:person)       { create(:person) }
  let!(:registration) { create(:registration, person: person, order: create(:order, edition: edition), edition: edition) }
  let!(:rw)          { create(:registration_workshop, registration: registration, workshop: workshop_a) }

  before { sign_in user }

  it "replaces the workshop and redirects with a flash message" do
    visit new_workshop_substitution_path(registration_id: registration.id)
    find("select[name='new_workshop_id']").find("option", text: "MARMITONS").select_option
    click_button "Appliquer"
    expect(page).to have_text("Changement appliqué")
  end
end
```

---

## Coverage Targets

| Category | Target |
|---|---|
| Models (validations + methods) | 100% |
| Service objects | 90%+ |
| CSV importers | 90%+ |
| Controllers (request specs) | Happy path + auth check per endpoint |
| PDF classes | Key content present, edge cases |
| System specs | Login, participant list, workshop substitution, staff advance |

Use `SimpleCov` optionally — not mandatory but recommended once the suite is stable.

---

## CI Checklist (for any PR)

- [ ] `bundle exec rspec` — all tests pass
- [ ] `bundle exec rubocop` — no offences
- [ ] `bundle exec rake db:migrate` — migration runs cleanly
- [ ] No hardcoded credentials or real personal data in fixtures

Project-specific verification command:
- [ ] `docker compose exec -e RAILS_ENV=test app bundle exec rspec`
