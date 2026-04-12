User.find_or_create_by!(email: "admin@psalmodia.fr") do |user|
  user.password = "psalmodia2026!"
  user.password_confirmation = "psalmodia2026!"
end

puts "Admin user ready: admin@psalmodia.fr / psalmodia2026!"

Edition.find_or_create_by!(year: 2026) do |e|
  e.name           = "Psalmodia 2026"
  e.start_date     = Date.new(2026, 7, 20)
  e.end_date       = Date.new(2026, 8, 2)
  e.km_rate_cents  = 32
end

puts "Edition ready: Psalmodia 2026"
