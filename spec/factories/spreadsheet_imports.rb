FactoryBot.define do
  factory :spreadsheet_import do
    association :user, factory: [ :user, :admin ]
    status { :pending }

    after(:build) do |spreadsheet_import|
      spreadsheet_import.file.attach(
        io: StringIO.new("email,full_name\nfixture@example.com,Fixture User\n"),
        filename: "import.csv",
        content_type: "text/csv"
      )
    end
  end

  factory :spreadsheet_import_row_error do
    association :spreadsheet_import
    sequence(:row_number) { |n| n + 1 }
    message { "E-mail can't be blank" }
    raw_data { { "email" => "", "full_name" => "Missing E-mail" }.to_json }
  end
end
