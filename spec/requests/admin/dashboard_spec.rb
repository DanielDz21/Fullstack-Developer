require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  describe "GET /admin/dashboard" do
    it "redirects unauthenticated visitors to sign in" do
      get admin_dashboard_path

      expect(response).to redirect_to(new_session_path)
    end

    it "forbids a signed in no_admin user" do
      user = create(:user, password: "password123")
      sign_in_as(user)

      get admin_dashboard_path

      expect(response).to have_http_status(:forbidden)
    end

    it "allows a signed in admin user" do
      admin = create(:user, :admin, password: "password123")
      sign_in_as(admin)

      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
    end
  end
end
