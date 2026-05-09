User.find_or_create_by!(email: "admin@psalmodia.fr") do |user|
  user.password = "psalmodia2026!"
  user.password_confirmation = "psalmodia2026!"
end

puts "Admin user ready: admin@psalmodia.fr / psalmodia2026!"
