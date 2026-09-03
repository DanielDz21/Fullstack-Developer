class SpreadsheetImportRowError < ApplicationRecord
  belongs_to :spreadsheet_import

  validates :row_number, presence: true
  validates :message, presence: true
end
