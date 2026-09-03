module AuthenticationHelpers
  def sign_in_as(user, password: "password123")
    post session_path, params: { email: user.email, password: password }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
