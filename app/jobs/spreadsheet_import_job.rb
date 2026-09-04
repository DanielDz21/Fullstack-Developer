class SpreadsheetImportJob < ApplicationJob
  queue_as :default

  # Broadcasting progress on every single row floods Turbo Streams/Solid Cable on
  # large imports (one full partial render + DB write per row); broadcast at most
  # every Nth row instead, always including the last one.
  PROGRESS_BROADCAST_INTERVAL = 10

  # Spreadsheet data is untrusted external input: every cell is treated as
  # plain data (never evaluated or interpreted), and a bad row is recorded as
  # a SpreadsheetImportRowError instead of aborting the whole import.
  def perform(spreadsheet_import_id)
    import = SpreadsheetImport.find_by(id: spreadsheet_import_id)
    return unless import&.pending?

    import.update!(status: :processing)

    rows = parse_rows(import)
    import.update!(total_rows: rows.size)

    users_created = 0

    rows.each_with_index do |(row_number, data), index|
      users_created += 1 if import_row(import, row_number, data)
      import.update_columns(processed_rows: index + 1)
      import.broadcast_progress if broadcast_now?(index, rows.size)
    end

    User.broadcast_dashboard_counts! if users_created.positive?
    import.update!(status: :completed)
  rescue => e
    Rails.logger.warn("SpreadsheetImportJob: failed to process import #{spreadsheet_import_id}: #{e.message}")
    import&.update!(status: :failed)
  end

  private
    def broadcast_now?(index, total)
      (index + 1) % PROGRESS_BROADCAST_INTERVAL == 0 || index == total - 1
    end

    def parse_rows(import)
      import.file.open do |tempfile|
        extension = File.extname(import.file.filename.to_s).delete(".").downcase.to_sym
        sheet = Roo::Spreadsheet.open(tempfile.path, extension: extension).sheet(0)
        first_data_row = import.has_header? ? 2 : 1

        (first_data_row..sheet.last_row).filter_map do |row_number|
          values = sheet.row(row_number)
          next if values.all? { |value| value.to_s.strip.blank? }
          [ row_number, { "nome" => values[0].to_s.strip, "email" => values[1].to_s.strip } ]
        end
      end
    end

    # Returns true if the row created a user, false if it was recorded as an error.
    def import_row(import, row_number, data)
      user = User.new(
        email: data["email"],
        full_name: data["nome"],
        password: SecureRandom.hex(16),
        role: :no_admin,
        skip_dashboard_broadcast: true
      )

      return true if user.save

      import.spreadsheet_import_row_errors.create!(
        row_number: row_number,
        message: user.errors.full_messages.to_sentence,
        raw_data: data.to_json
      )
      false
    end
end
