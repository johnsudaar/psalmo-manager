namespace :import do
  desc "Import staff financial data from Sheet 2 CSV exports. Usage: rails import:staff[/path/recap.csv,/path/versements.csv,EDITION_ID]"
  task :staff, [ :profiles_csv, :payments_csv, :edition_id ] => :environment do |_t, args|
    profiles_csv = args[:profiles_csv]
    payments_csv = args[:payments_csv]
    edition_id   = args[:edition_id].to_i

    abort "Usage: rails import:staff[/path/recap.csv,/path/versements.csv,EDITION_ID]" if profiles_csv.blank? || edition_id.zero?

    profiles_result = Importers::StaffCsvImporter.new(
      csv_path:   profiles_csv,
      edition_id: edition_id
    ).call

    puts "Imported staff profiles: #{profiles_result[:created]} created, #{profiles_result[:updated]} updated, #{profiles_result[:errors].count} errors"
    profiles_result[:errors].each { |e| puts "  ERROR: #{e}" }

    if payments_csv.present?
      payments_result = Importers::VersementsCsvImporter.new(
        csv_path:   payments_csv,
        edition_id: edition_id
      ).call

      puts "Imported versements: #{payments_result[:advances]} advances, #{payments_result[:payments]} payments, #{payments_result[:errors].count} errors"
      payments_result[:errors].each { |e| puts "  ERROR: #{e}" }
    end
  end
end
