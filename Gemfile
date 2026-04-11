source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Authentication
gem "devise"

# Background jobs
gem "sidekiq"
gem "sidekiq-cron"

# HTTP client
gem "faraday"
gem "faraday-retry"

# PDF generation
gem "prawn"
gem "prawn-table"

# Charts
gem "chartkick"
gem "groupdate"

# Pagination
gem "pagy", "~> 9.0"

# Actor pattern
gem "interactor"

# Audit log
gem "paper_trail"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "webmock"
  gem "vcr"
  gem "shoulda-matchers"
  gem "capybara"
  gem "selenium-webdriver"
  gem "pdf-reader"
end

group :development do
  gem "web-console"
end
