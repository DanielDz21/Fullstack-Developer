require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to have_secure_password }

    it "rejects a malformed email" do
      user = build(:user, email: "not-an-email")

      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end
  end

  describe "email normalization" do
    it "strips whitespace and downcases the email before saving" do
      user = create(:user, email: "  MixedCase@Example.com  ")

      expect(user.email).to eq("mixedcase@example.com")
    end
  end

  describe "role enum" do
    it "defaults to no_admin" do
      user = User.new

      expect(user.role).to eq("no_admin")
      expect(user).to be_no_admin
    end

    it { is_expected.to define_enum_for(:role).with_values(no_admin: 0, admin: 1) }
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
  end
end
