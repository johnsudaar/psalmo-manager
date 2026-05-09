namespace :import do
  desc "Import participants from DONNES_BRUTES CSV export (Sheet 1). Usage: rails import:participants[/path/to/file.csv,EDITION_ID]"
  task :participants, [ :csv_path, :edition_id ] => :environment do |_t, args|
    csv_path   = args[:csv_path]
    edition_id = args[:edition_id].to_i

    abort "Usage: rails import:participants[/path/to/file.csv,EDITION_ID]" if csv_path.blank? || edition_id.zero?

    result = Importers::ParticipantsCsvImporter.new(
      csv_path:   csv_path,
      edition_id: edition_id
    ).call

    puts "Imported participants: #{result[:created]} created, #{result[:updated]} updated, #{result[:errors].count} errors"
    result[:errors].each { |e| puts "  ERROR: #{e}" }
  end

  desc "Apply workshop overrides from FIltres CSV export. Usage: rails import:filtres[/path/to/filtres.csv,EDITION_ID]"
  task :filtres, [ :csv_path, :edition_id ] => :environment do |_t, args|
    csv_path   = args[:csv_path]
    edition_id = args[:edition_id].to_i

    abort "Usage: rails import:filtres[/path/to/filtres.csv,EDITION_ID]" if csv_path.blank? || edition_id.zero?

    result = Importers::FiltresCsvImporter.new(
      csv_path:   csv_path,
      edition_id: edition_id
    ).call

    puts "Applied overrides: #{result[:applied]} registrations updated, #{result[:errors].count} errors"
    result[:errors].each { |e| puts "  ERROR: #{e}" }
  end

  desc "Apply stat exclusions from Calcul Statistiques CSV export. Usage: rails import:exclusions[/path/to/exclusions.csv,EDITION_ID]"
  task :exclusions, [ :csv_path, :edition_id ] => :environment do |_t, args|
    csv_path   = args[:csv_path]
    edition_id = args[:edition_id].to_i

    abort "Usage: rails import:exclusions[/path/to/exclusions.csv,EDITION_ID]" if csv_path.blank? || edition_id.zero?

    result = Importers::ExclusionsCsvImporter.new(
      csv_path:   csv_path,
      edition_id: edition_id
    ).call

    puts "Applied exclusions: #{result[:applied]} registrations updated, #{result[:errors].count} errors"
    result[:errors].each { |e| puts "  ERROR: #{e}" }
  end

  desc "Apply unaccompanied minor flags from Mineurs_Seuls CSV export. Usage: rails import:mineurs[/path/to/mineurs.csv,EDITION_ID]"
  task :mineurs, [ :csv_path, :edition_id ] => :environment do |_t, args|
    csv_path   = args[:csv_path]
    edition_id = args[:edition_id].to_i

    abort "Usage: rails import:mineurs[/path/to/mineurs.csv,EDITION_ID]" if csv_path.blank? || edition_id.zero?

    result = Importers::MineursCsvImporter.new(
      csv_path:   csv_path,
      edition_id: edition_id
    ).call

    puts "Applied unaccompanied minor flags: #{result[:applied]} registrations updated, #{result[:errors].count} errors"
    result[:errors].each { |e| puts "  ERROR: #{e}" }
  end
end
