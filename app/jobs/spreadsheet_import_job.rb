class SpreadsheetImportJob < ApplicationJob
  queue_as :default

  # Spreadsheet data is untrusted external input: every cell is treated as
  # plain data (never evaluated or interpreted), and a bad row is recorded as
  # a SpreadsheetImportRowError instead of aborting the whole import.
  def perform(spreadsheet_import_id)
    import = SpreadsheetImport.find_by(id: spreadsheet_import_id)
    return unless import&.pending?

    import.update!(status: :processing)

    rows = parse_rows(import)
    import.update!(total_rows: rows.size)

    rows.each { |row_number, data| import_row(import, row_number, data) }

    import.update!(status: :completed)
  rescue => e
    Rails.logger.warn("SpreadsheetImportJob: failed to process import #{spreadsheet_import_id}: #{e.message}")
    import&.update!(status: :failed)
  end

  private
    def parse_rows(import)
      import.file.open do |tempfile|
        extension = File.extname(import.file.filename.to_s).delete(".").downcase.to_sym
        sheet = Roo::Spreadsheet.open(tempfile.path, extension: extension).sheet(0)
        headers = sheet.row(1).map { |header| header.to_s.strip.downcase }

        (2..sheet.last_row).filter_map do |row_number|
          values = sheet.row(row_number)
          next if values.all? { |value| value.to_s.strip.blank? }
          [ row_number, headers.zip(values).to_h ]
        end
      end
    end

    def import_row(import, row_number, data)
      user = User.new(
        email: data["email"].to_s.strip,
        full_name: data["full_name"].to_s.strip,
        password: SecureRandom.hex(16),
        role: :no_admin
      )

      unless user.save
        import.spreadsheet_import_row_errors.create!(
          row_number: row_number,
          message: user.errors.full_messages.to_sentence,
          raw_data: data.to_json
        )
      end

      import.update!(processed_rows: import.processed_rows + 1)
    end
end
