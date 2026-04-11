require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<HELLOASSO_TOKEN>") { ENV["HELLOASSO_CLIENT_SECRET"] }
  # Allow WebMock stubs to work in specs that don't use a VCR cassette
  config.allow_http_connections_when_no_cassette = true
end
