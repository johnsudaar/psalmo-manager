# 04 — HelloAsso Integration

## Overview

HelloAsso is the French payment platform used by Psalmodia to collect registrations.
The application integrates with HelloAsso API v5 in two ways:

1. **Scheduled sync** — Sidekiq-cron job runs every 30 minutes, fetches all orders/items for the
   current edition, upserts records in the database.
2. **Webhook** — HelloAsso POSTs a notification to our endpoint on every payment event (new
   order, payment update, refund). This provides near-real-time updates without polling.

---

## API Reference

**Base URL**: `https://api.helloasso.com/v5`

**Authentication**: OAuth2 Client Credentials

**Rate limits**: Not officially documented, but be conservative — use retry with exponential
backoff and avoid hammering the API in tight loops.

---

## OAuth2 Authentication

HelloAsso uses the **client_credentials** grant. Tokens expire after 30 minutes.

### Token request

```
POST https://api.helloasso.com/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
```

**Response**:
```json
{
  "access_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "refresh_token": "abc123..."
}
```

### Token refresh

When the access token expires, use the refresh token:

```
POST https://api.helloasso.com/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&client_id=YOUR_CLIENT_ID
&client_secret=YOUR_CLIENT_SECRET
&refresh_token=abc123...
```

### Implementation

Token storage: use Rails cache (`Rails.cache`) with a TTL of 25 minutes (5-minute buffer before
the 30-minute expiry). Store both `access_token` and `refresh_token`.

```ruby
# app/services/helloasso/client.rb
module Helloasso
  class Client
    BASE_URL = "https://api.helloasso.com/v5"
    TOKEN_URL = "https://api.helloasso.com/oauth2/token"
    CACHE_KEY = "helloasso_access_token"
    TOKEN_TTL  = 25.minutes

    def initialize
      @conn = Faraday.new(BASE_URL) do |f|
        f.request :json
        f.response :json
        f.response :raise_error
        f.request :retry, max: 3, interval: 1, backoff_factor: 2,
                           exceptions: [Faraday::TimeoutError, Faraday::ServerError]
      end
    end

    def get(path, params = {})
      @conn.get(path, params) { |req| req.headers["Authorization"] = "Bearer #{access_token}" }
    end

    private

    def access_token
      Rails.cache.fetch(CACHE_KEY, expires_in: TOKEN_TTL) { fetch_token }
    end

    def fetch_token
      resp = Faraday.post(TOKEN_URL, {
        grant_type: "client_credentials",
        client_id: ENV["HELLOASSO_CLIENT_ID"],
        client_secret: ENV["HELLOASSO_CLIENT_SECRET"]
      })
      JSON.parse(resp.body)["access_token"]
    end
  end
end
```

---

## Key API Endpoints

### List forms for an organisation

```
GET /v5/organizations/{orgSlug}/forms
```

Returns all forms (events) for the organisation. Use `formType=Event` to filter.

**Response fields of interest**:
- `title` — form name (e.g. "Psalmodia 2026")
- `formSlug` — the slug used in subsequent calls
- `formType` — "Event"
- `startDate`, `endDate`

---

### List orders for a form

```
GET /v5/organizations/{orgSlug}/forms/{formType}/{formSlug}/orders
  ?pageIndex=1
  &pageSize=20
  &withDetails=true
```

**Pagination**: Response includes `pagination.pageIndex`, `pagination.totalPages`.
Loop until `pageIndex >= totalPages`.

**Response (one order)**:
```json
{
  "id": "abc-123",
  "date": "2026-03-15T10:30:00Z",
  "formSlug": "psalmodia-2026",
  "payer": {
    "firstName": "Marie",
    "lastName": "Dupont",
    "email": "marie@example.com",
    "address": "12 rue de la Paix",
    "dateOfBirth": "1985-04-20T00:00:00Z"
  },
  "items": [...],
  "payments": [...],
  "discount": { "code": "2026POUMA", "amount": 61 },
  "totalAmount": 200
}
```

---

### Items (billets) within an order

Items are embedded in the order response (with `withDetails=true`):

```json
{
  "id": "item-456",
  "type": "Membership",
  "state": "Processed",
  "firstName": "Léa",
  "lastName": "Dupont",
  "email": "lea@example.com",
  "dateOfBirth": "2015-06-10T00:00:00Z",
  "customFields": [
    { "name": "Atelier 1", "answer": "CIRQUE" },
    { "name": "Atelier 2", "answer": "" },
    { "name": "Semaine", "answer": "Semaine 1" }
  ],
  "initialAmount": 100,
  "discount": 0,
  "amount": 100,
  "payer": { ... }
}
```

**Note**: Workshop selections are stored in `customFields`. Field names may vary between editions.
The CSV importer handles historical data; the API importer must adapt to the field names used in
each form's custom fields configuration.

---

## Sync Service

`app/services/helloasso/sync_service.rb`

Responsibilities:
1. Fetch all orders for a given `Edition` (paginated)
2. For each order: upsert `Order`, upsert `Person` (payer), upsert each `Registration` (item),
   resolve workshops from custom fields
3. Compute `age_category` from `dateOfBirth` and `edition.start_date`
4. Compute `registration_week` from `order.date`
5. Store raw JSON in `helloasso_raw` columns

```ruby
# app/services/helloasso/sync_service.rb
module Helloasso
  class SyncService
    def initialize(edition)
      @edition = edition
      @client = Client.new
    end

    def call
      page = 1
      loop do
        resp = @client.get(
          "/v5/organizations/#{org_slug}/forms/Event/#{@edition.helloasso_form_slug}/orders",
          pageIndex: page, pageSize: 50, withDetails: true
        )
        data = resp.body
        data["data"].each { |order_data| process_order(order_data) }
        break if page >= data.dig("pagination", "totalPages").to_i
        page += 1
      end
    end

    private

    def org_slug
      ENV["HELLOASSO_ORG_SLUG"]
    end

    def process_order(data)
      # upsert Order, Person (payer), Registrations, Workshops
      # see implementation details in Phase 3
    end
  end
end
```

---

## Sidekiq Job

```ruby
# app/jobs/helloasso_sync_job.rb
class HelloassoSyncJob < ApplicationJob
  queue_as :default

  def perform(edition_id)
    edition = Edition.find(edition_id)
    Helloasso::SyncService.new(edition).call
  rescue => e
    Rails.logger.error("[HelloassoSyncJob] Failed for edition #{edition_id}: #{e.message}")
    raise # re-raise so Sidekiq retries
  end
end
```

**Sidekiq-cron schedule** (`config/schedule.rb`):
```ruby
Sidekiq::Cron::Job.create(
  name: "HelloAsso sync — current edition",
  cron: "*/30 * * * *",
  class: "HelloassoSyncJob",
  args: [-> { Edition.order(year: :desc).first&.id }]
)
```

---

## Webhook

### Endpoint

```
POST /webhooks/helloasso
```

This endpoint must be publicly accessible. Register it in the HelloAsso dashboard.

### Payload structure

HelloAsso sends a JSON body with the following shape:

```json
{
  "eventType": "Order",
  "data": {
    "order": { ... },  // full order object
    "form":  { ... }
  },
  "metadata": {
    "deliveryDate": "2026-04-01T14:30:00Z",
    "attemptNumber": 1
  }
}
```

Event types:
- `"Order"` — new or updated order
- `"Payment"` — payment state change (e.g. refund)
- `"Form"` — form published/unpublished (not consumed)

### Signature verification

HelloAsso signs webhook payloads with HMAC-SHA256. The signature is in the
`X-HelloAsso-Signature` header.

```ruby
# app/controllers/webhooks/helloasso_controller.rb
module Webhooks
  class HelloassoController < ActionController::API
    def create
      return head :unauthorized unless valid_signature?

      payload = JSON.parse(request.body.read)
      Helloasso::WebhookProcessor.new(payload).call
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def valid_signature?
      secret = ENV["HELLOASSO_WEBHOOK_SECRET"]
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)
      ActiveSupport::SecurityUtils.secure_compare(
        expected,
        request.headers["X-HelloAsso-Signature"].to_s
      )
    end
  end
end
```

### Webhook processor

```ruby
# app/services/helloasso/webhook_processor.rb
module Helloasso
  class WebhookProcessor
    def initialize(payload)
      @payload = payload
    end

    def call
      case @payload["eventType"]
      when "Order"
        edition = find_edition_from_form(@payload.dig("data", "form", "formSlug"))
        return unless edition
        SyncService.new(edition).process_order(@payload.dig("data", "order"))
      when "Payment"
        # update order status if refund
      end
    end

    private

    def find_edition_from_form(slug)
      Edition.find_by(helloasso_form_slug: slug)
    end
  end
end
```

---

## Override-Preservation Contract

HelloAsso is the **source of truth** for participant data, but certain fields are owned by the
admin and must **never be overwritten** by a sync.

### HelloAsso-owned fields (always overwritten on sync)

| Model | Fields |
|---|---|
| `people` | `first_name`, `last_name`, `email`, `phone`, `date_of_birth` |
| `orders` | `order_date`, `status`, `payment_method`, `promo_code`, `promo_amount_cents`, `helloasso_raw` |
| `registrations` | `ticket_price_cents`, `discount_cents`, `actual_price_cents`, `age_category`, `registration_week`, `helloasso_raw` |
| `registration_workshops` | All rows where `is_override: false` — these are fully replaced on sync |

### Override-owned fields (never touched by sync)

| Model | Fields |
|---|---|
| `registrations` | `excluded_from_stats`, `is_unaccompanied_minor`, `responsible_person_note` |
| `registration_workshops` | Any row where `is_override: true` — these are preserved on sync |

### Upsert logic for `registration_workshops`

When syncing a registration's workshops:
1. Delete all `registration_workshops` where `is_override: false` for that registration.
2. Re-create them from the HelloAsso `customFields`.
3. Leave all `registration_workshops` where `is_override: true` untouched.

This means an admin-applied workshop substitution survives a sync. If the participant's HelloAsso
data shows a different workshop in the same slot, the override record takes precedence in the UI
(the non-override record for that slot will not exist after step 1).

### Implementation pattern

```ruby
# In SyncService#upsert_registration_workshops(registration, item_data)
def upsert_registration_workshops(registration, item_data)
  # Destroy only non-override rows — overrides are sticky
  registration.registration_workshops.where(is_override: false).destroy_all

  item_data["customFields"].each do |field|
    next if field["answer"].blank?
    workshop = @edition.workshops.find_by(name: field["answer"].upcase)
    next unless workshop

    registration.registration_workshops.create!(
      workshop: workshop,
      price_paid_cents: 0,  # will be updated by pricing logic
      is_override: false
    )
  end
end
```

---

## Field Mapping: HelloAsso → Database

| HelloAsso field | DB column | Notes |
|---|---|---|
| `order.id` | `orders.helloasso_order_id` | |
| `order.date` | `orders.order_date` | |
| `order.payer.firstName` | `people.first_name` | |
| `order.payer.lastName` | `people.last_name` | |
| `order.payer.email` | `people.email` | |
| `order.payer.dateOfBirth` | `people.date_of_birth` | parse ISO8601 |
| `order.discount.code` | `orders.promo_code` | |
| `order.discount.amount` | `orders.promo_amount_cents` | multiply by 100 |
| `item.id` | `registrations.helloasso_ticket_id` | |
| `item.firstName` | `people.first_name` | participant (may differ from payer) |
| `item.lastName` | `people.last_name` | |
| `item.dateOfBirth` | `people.date_of_birth` | used to compute age_category |
| `item.initialAmount` | `registrations.ticket_price_cents` | multiply by 100 |
| `item.discount` | `registrations.discount_cents` | multiply by 100 |
| `item.amount` | `registrations.actual_price_cents` | multiply by 100 |
| `item.customFields` | `registration_workshops` | match by field name → workshop.name |

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Token expired mid-sync | Middleware detects 401, refreshes token, retries request once |
| API returns 5xx | Faraday::Retry retries up to 3 times with exponential backoff |
| API returns 429 (rate limit) | Treat as retryable, honor `Retry-After` header if present |
| Order already exists in DB | `find_or_initialize_by(helloasso_order_id:)` → update attributes |
| Workshop in API not found in DB | Log warning, skip that registration_workshop, do not crash |
| Webhook signature invalid | Return 401, log the attempt |
| Webhook payload malformed | Return 400, log the raw body |

---

## Development / Testing

- Use **WebMock** to stub all `https://api.helloasso.com` requests in tests.
- Use **VCR** to record/replay real API responses during integration tests.
- VCR cassettes live in `spec/fixtures/vcr_cassettes/helloasso/`.
- Never commit real credentials or real API responses — scrub cassettes of personal data before
  committing.
