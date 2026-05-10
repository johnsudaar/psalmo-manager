require "capybara/rails"
require "capybara/rspec"
require "selenium-webdriver"

# Use the remote Selenium Chrome service defined in docker-compose.yml
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

# The app server runs inside Docker on its own port — tell Selenium where to reach it
Capybara.app_host = "http://app:3000"
Capybara.server_host = "0.0.0.0"
Capybara.server_port = 3001

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # For JS-tagged examples, use the remote Selenium Chrome driver and allow
  # outbound connections that WebMock would otherwise block.
  config.before(:each, :js, type: :system) do
    driven_by :selenium_remote_chrome
  end

  config.around(:each, :js, type: :system) do |example|
    WebMock.allow_net_connect!
    example.run
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
