require "pagy/extras/overflow"

Pagy::DEFAULT[:limit] = 50
Pagy::DEFAULT[:overflow] = :last_page
