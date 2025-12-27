FactoryBot.define do
  factory :record do
    import_run { nil }
    resource_id { "MyString" }
    resource_type { "MyString" }
    subject_reference { "MyString" }
    extracted_data { "" }
    raw_data { "" }
  end
end
