module ApplicationHelper
  include Pagy::Frontend

  def format_euros(cents)
    return "—" if cents.nil?
    "#{format('%.2f', cents / 100.0).gsub('.', ',')} €"
  end

  def format_date(date)
    return "—" if date.nil?
    date.strftime("%d/%m/%Y")
  end
end
