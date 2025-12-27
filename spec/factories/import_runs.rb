FactoryBot.define do
  factory :import_run do
    total_lines { 1 }
    successful_records { 1 }
    validation_errors { "" }
    warnings { "" }
    statistics { "" }
    status { "MyString" }
  end
end
