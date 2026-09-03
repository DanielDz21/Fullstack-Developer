require "rails_helper"

RSpec.describe "Admin spreadsheet import live progress", type: :system do
  it "updates the progress bar and status live as the background job processes rows" do
    admin = create(:user, :admin, password: "password123")

    sign_in_via_ui(admin)
    click_link "Importação de Planilhas"
    click_link "Nova Importação"

    attach_file "Planilha (CSV ou XLSX)", Rails.root.join("spec/fixtures/files/valid_import.csv")
    click_button "Enviar"

    expect(page).to have_content("Planilha enviada. A importação está sendo processada em segundo plano.")
    within("#spreadsheet_import_progress") do
      expect(page).to have_content("Status: Pendente")
      expect(page).to have_content("0 / 0 linhas processadas")
    end

    SpreadsheetImportJob.perform_now(SpreadsheetImport.last.id)

    within("#spreadsheet_import_progress") do
      expect(page).to have_content("Status: Concluída")
      expect(page).to have_content("3 / 3 linhas processadas")
    end

    expect(User.exists?(email: "alice@example.com")).to be true
  end
end
