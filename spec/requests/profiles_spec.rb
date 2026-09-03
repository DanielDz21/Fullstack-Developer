require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /profile" do
    it "redirects unauthenticated visitors to sign in" do
      get profile_path

      expect(response).to redirect_to(new_session_path)
    end

    it "shows the signed in user's own info" do
      user = create(:user, password: "password123")
      sign_in_as(user)

      get profile_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.full_name)
    end
  end
end
