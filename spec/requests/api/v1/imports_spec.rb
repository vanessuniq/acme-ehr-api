require "rails_helper"

RSpec.describe "Api::V1::Imports", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "text/plain" } }

  def post_import_raw(jsonl)
    post "/api/v1/import", params: jsonl, headers: headers
  end

  def post_import_file(jsonl)
    file = Tempfile.new([ "resources", ".jsonl" ])
    file.write(jsonl)
    file.rewind

    uploaded = Rack::Test::UploadedFile.new(file.path, "text/plain")
    post "/api/v1/import", params: { file: uploaded }

    file.close
    file.unlink
  end

  it "returns 400 when no data is provided" do
    post "/api/v1/import", params: "", headers: headers

    expect(response).to have_http_status(:bad_request)
    body = JSON.parse(response.body)
    expect(body["error"]).to eq("No data provided for import")
  end

  it "imports valid resources from raw JSONL and returns an ImportRun summary" do
    jsonl = [
      {
        "resourceType" => "Observation",
        "id" => "obs-001",
        "status" => "final",
        "code" => { "text" => "Glucose" },
        "subject" => { "reference" => "Patient/PT-001" },
        "valueQuantity" => { "value" => 95, "unit" => "mg/dL" }
      }.to_json,
      # Patient does NOT require subject per your Validator rule
      {
        "resourceType" => "Patient",
        "id" => "PT-001",
        "name" => [ { "family" => "Doe", "given" => [ "John" ] } ],
        "active" => true
      }.to_json
    ].join("\n")

    expect { post_import_raw(jsonl) }.to change(ImportRun, :count).by(1)
      .and change(Record, :count).by(2)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body["status"]).to eq("completed")
    expect(body["total_lines"]).to eq(2)
    expect(body["successful_records"]).to eq(2)

    expect(body["validation_errors"]).to eq([])
    expect(body["warnings"]).to be_an(Array)

    # Statistics shape (don’t over-specify exact contents)
    expect(body["statistics"]).to be_a(Hash)
    expect(body["statistics"]["by_resource_type"]).to be_a(Hash)
  end

  it "imports from multipart file upload" do
    jsonl = [
      {
        "resourceType" => "Observation",
        "id" => "obs-010",
        "status" => "final",
        "code" => { "text" => "Cholesterol" },
        "subject" => { "reference" => "Patient/PT-003" }
      }.to_json
    ].join("\n")

    expect { post_import_file(jsonl) }.to change(ImportRun, :count).by(1)
      .and change(Record, :count).by(1)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["successful_records"]).to eq(1)
  end

  it "reports invalid JSON with correct line number and path '$'" do
    jsonl = [
      { "resourceType" => "Patient", "id" => "PT-001", "name" => [ { "family" => "Doe" } ], "active" => true }.to_json,
      "{ this is not valid json }",
      { "resourceType" => "Patient", "id" => "PT-002", "name" => [ { "family" => "Smith" } ], "active" => true }.to_json
    ].join("\n")

    post_import_raw(jsonl)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body["total_lines"]).to eq(3)
    expect(body["successful_records"]).to eq(2)

    errors = body["validation_errors"]
    expect(errors).to be_an(Array)

    bad = errors.find { |e| e["line"] == 2 }
    expect(bad).not_to be_nil
    expect(bad["path"]).to eq("$")
    expect(bad["message"]).to match(/Invalid JSON/i)
    expect(bad["resourceType"]).to be_nil
  end

  it "reports required-field and status validation errors with line numbers" do
    jsonl = [
      # Missing status for Observation => required + status enum error
      {
        "resourceType" => "Observation",
        "id" => "obs-bad",
        "code" => { "text" => "HbA1c" },
        "subject" => { "reference" => "Patient/PT-002" }
      }.to_json,
      # Condition clinicalStatus invalid (clinicalStatus.coding[0].code is nil) => invalid status
      {
        "resourceType" => "Condition",
        "id" => "cond-bad",
        "code" => { "text" => "Hypertension" },
        "subject" => { "reference" => "Patient/PT-001" },
        "clinicalStatus" => { "coding" => [ { "code" => "NOT_A_VALID_CODE" } ] }
      }.to_json
    ].join("\n")

    expect { post_import_raw(jsonl) }.to change(ImportRun, :count).by(1)
      .and change(Record, :count).by(0)

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)

    expect(body["successful_records"]).to eq(0)
    errors = body["validation_errors"]
    expect(errors).to be_an(Array)
    expect(errors.map { |e| e["line"] }).to include(1, 2)

    # Observation missing status should show "status is required..."
    obs_err = errors.find { |e| e["line"] == 1 && e["path"] == "status" }
    expect(obs_err).not_to be_nil
    expect(obs_err["message"]).to match(/status is required/i)

    # Condition invalid clinicalStatus should include invalid status
    cond_err = errors.find { |e| e["line"] == 2 && e["path"] == "status" }
    expect(cond_err).not_to be_nil
    expect(cond_err["message"]).to match(/invalid status/i)
  end
end
