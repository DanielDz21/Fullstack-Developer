require "rails_helper"

RSpec.describe "Admin spreadsheet import live progress", type: :system do
  it "updates the progress bar and status live as the background job processes rows" do
    admin = create(:user, :admin, password: "password123")

    sign_in_via_ui(admin)
    click_link "Spreadsheet imports"
    click_link "New import"

    attach_file "Spreadsheet (CSV or XLSX)", Rails.root.join("spec/fixtures/files/valid_import.csv")
    click_button "Upload"

    expect(page).to have_content("Spreadsheet uploaded. Import is processing in the background.")
    within("#spreadsheet_import_progress") do
      expect(page).to have_content("Status: Pending")
      expect(page).to have_content("0 / 0 rows processed")
    end

    SpreadsheetImportJob.perform_now(SpreadsheetImport.last.id)

    within("#spreadsheet_import_progress") do
      expect(page).to have_content("Status: Completed")
      expect(page).to have_content("3 / 3 rows processed")
    end

    expect(User.exists?(email: "alice@example.com")).to be true
  end
end
