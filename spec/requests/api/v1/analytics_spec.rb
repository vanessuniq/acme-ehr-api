require "rails_helper"

RSpec.describe "Api::V1::Analytics", type: :request do
  describe "GET /api/v1/analytics" do
    it "returns 200 with core analytics + custom stats" do
      # Import runs (assumes you have these scopes; otherwise adjust to your statuses)
      ImportRun.create!(status: "completed", validation_errors: [], warnings: [], statistics: {})
      ImportRun.create!(status: "failed", validation_errors: [ { path: "$", message: "Invalid JSON", resourceType: "Observation" } ], warnings: [], statistics: {})
      ImportRun.create!(status: "completed", validation_errors: [ { path: "status", message: "invalid status 'bogus' for Observation", resourceType: "Observation" } ], warnings: [], statistics: {})

      # Records
      run = ImportRun.create!(status: "completed", validation_errors: [], warnings: [], statistics: {})

      Record.create!(
        import_run: run,
        resource_id: "PT-001",
        resource_type: "Patient",
        subject_reference: nil,
        extracted_data: { "id" => "PT-001", "resourceType" => "Patient", "name" => [ { "family" => "Doe" } ] },
        raw_data: { "resourceType" => "Patient", "id" => "PT-001" }
      )

      Record.create!(
        import_run: run,
        resource_id: "obs-001",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: { "id" => "obs-001", "resourceType" => "Observation", "subject" => { "reference" => "Patient/PT-001" } },
        raw_data: { "resourceType" => "Observation", "id" => "obs-001", "subject" => { "reference" => "Patient/PT-001" } }
      )

      Record.create!(
        import_run: run,
        resource_id: "cond-001",
        resource_type: "Condition",
        subject_reference: "Patient/PT-001",
        extracted_data: { "id" => "cond-001", "resourceType" => "Condition", "subject" => { "reference" => "Patient/PT-001" } },
        raw_data: { "resourceType" => "Condition", "id" => "cond-001", "subject" => { "reference" => "Patient/PT-001" } }
      )

      get "/api/v1/analytics"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)

      # Top-level keys
      expect(body).to include(
        "total_records",
        "records_by_type",
        "unique_patients",
        "imports_summary",
        "records_per_patient"
      )

      # Totals
      expect(body["total_records"]).to eq(3)
      expect(body["records_by_type"]).to include(
        "Patient" => 1,
        "Observation" => 1,
        "Condition" => 1
      )

      expect(body["unique_patients"]).to eq(1)

      # Custom statistic: non-patient records grouped by subject_reference
      expect(body["records_per_patient"]).to include(
        "Patient/PT-001" => 2
      )

      # Imports summary shape
      imports = body["imports_summary"]
      expect(imports).to include(
        "total_imports",
        "successful_imports",
        "failed_imports",
        "imports_with_errors",
        "error_summary"
      )

      # Error summary is an array of runs, each with import_id/error_count/errors
      expect(imports["error_summary"]).to be_an(Array)
      with_errors_run = imports["error_summary"].find { |r| r["error_count"].to_i > 0 }
      expect(with_errors_run).to include("import_id", "error_count", "errors")
      expect(with_errors_run["errors"]).to be_a(Hash)
    end

    it "returns 500 when report building raises" do
      allow(Analytics::AnalyticsReport).to receive(:new).and_raise(StandardError, "boom")

      get "/api/v1/analytics"

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)).to eq({ "error" => "boom" })
    end
  end
end
