FactoryBot.define do
  factory :user do
    sequence(:full_name) { |n| "#{Faker::Name.name} #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :no_admin }

    trait :admin do
      role { :admin }
    end
  end
end
