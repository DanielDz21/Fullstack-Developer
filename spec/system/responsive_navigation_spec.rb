require "rails_helper"

RSpec.describe "Responsive navigation", type: :system do
  after { Capybara.current_window.resize_to(1280, 800) }

  it "shows the nav links inline on a desktop viewport" do
    Capybara.current_window.resize_to(1280, 800)
    user = create(:user, password: "password123")

    sign_in_via_ui(user)

    expect(page).to have_link("My Profile", visible: true)
    expect(page).not_to have_button("Menu", visible: true)
  end

  it "collapses the nav behind a toggle button on a mobile viewport" do
    Capybara.current_window.resize_to(375, 667)
    admin = create(:user, :admin, password: "password123")

    sign_in_via_ui(admin)

    expect(page).to have_button("Menu", visible: true)
    expect(page).to have_link("Manage users", visible: :hidden)

    click_button "Menu"
    click_link "Manage users"

    expect(page).to have_content("Users")
    expect(page).to have_link("New user")
  end
end
