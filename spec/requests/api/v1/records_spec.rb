require "rails_helper"

RSpec.describe "Api::V1::Records", type: :request do
  let(:headers) { { "ACCEPT" => "application/json" } }

  def parsed
    JSON.parse(response.body)
  end

  def create_record!(
    resource_id:,
    resource_type:,
    subject_reference:,
    extracted_data:,
    raw_data: { "resourceType" => resource_type, "id" => resource_id }
  )
    run = ImportRun.create!(status: "completed")

    Record.create!(
      import_run: run,
      resource_id: resource_id,
      resource_type: resource_type,
      subject_reference: subject_reference,
      extracted_data: extracted_data,
      raw_data: raw_data
    )
  end

  describe "GET /api/v1/records" do
    before do
      @obs_old = create_record!(
        resource_id: "obs-001",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: {
          "id" => "obs-001",
          "resourceType" => "Observation",
          "subject" => { "reference" => "Patient/PT-001" },
          "status" => "final",
          "code" => { "text" => "Glucose" }
        }
      )

      @proc = create_record!(
        resource_id: "proc-001",
        resource_type: "Procedure",
        subject_reference: "Patient/PT-001",
        extracted_data: {
          "id" => "proc-001",
          "resourceType" => "Procedure",
          "subject" => { "reference" => "Patient/PT-001" },
          "status" => "completed",
          "code" => { "text" => "Annual Physical" }
        }
      )

      @obs_new = create_record!(
        resource_id: "obs-002",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: {
          "id" => "obs-002",
          "resourceType" => "Observation",
          "subject" => { "reference" => "Patient/PT-001" },
          "status" => "final",
          "code" => { "text" => "Cholesterol" }
        }
      )

      @obs_other_patient = create_record!(
        resource_id: "obs-003",
        resource_type: "Observation",
        subject_reference: "Patient/PT-999",
        extracted_data: {
          "id" => "obs-003",
          "resourceType" => "Observation",
          "subject" => { "reference" => "Patient/PT-999" },
          "status" => "final",
          "code" => { "text" => "Heart Rate" }
        }
      )
    end

    it "returns 200 and a list of extracted_data (default)" do
      get "/api/v1/records", headers: headers

      expect(response).to have_http_status(:ok)
      body = parsed

      expect(body).to be_a(Array)
      expect(body.size).to eq(4)

      expect(body.first).to include("id", "resourceType")
      expect(body.first).not_to have_key("raw_data")
      expect(body.first).not_to have_key("created_at")
    end

    it "orders records by created_at desc (newest first)" do
      get "/api/v1/records", headers: headers

      ids = parsed.map { |h| h["id"] }
      expect(ids.first).to eq("obs-003") # last created in before block
      expect(ids).to include("obs-001", "obs-002", "proc-001", "obs-003")
    end

    it "filters by resourceType" do
      get "/api/v1/records", params: { resourceType: "Procedure" }, headers: headers

      body = parsed
      expect(body.size).to eq(1)
      expect(body.first["resourceType"]).to eq("Procedure")
      expect(body.first["id"]).to eq("proc-001")
    end

    it "filters by subject" do
      get "/api/v1/records", params: { subject: "Patient/PT-001" }, headers: headers

      body = parsed
      expect(body.size).to eq(3)
      expect(body.map { |h| h.dig("subject", "reference") }.uniq).to eq([ "Patient/PT-001" ])
    end

    it "filters by resourceType AND subject" do
      get "/api/v1/records",
          params: { resourceType: "Observation", subject: "Patient/PT-001" },
          headers: headers

      body = parsed
      expect(body.size).to eq(2)
      expect(body.map { |h| h["resourceType"] }.uniq).to eq([ "Observation" ])
      expect(body.map { |h| h.dig("subject", "reference") }.uniq).to eq([ "Patient/PT-001" ])
    end

    it "supports fields projection (returns only requested keys)" do
      get "/api/v1/records",
          params: { fields: "id,resourceType,status" },
          headers: headers

      body = parsed
      expect(body).to all(include("id", "resourceType", "status"))
      expect(body).to all(satisfy { |h| h.keys.sort == %w[id resourceType status].sort })
    end

    it "supports fields projection with whitespace" do
      get "/api/v1/records",
          params: { fields: "id, resourceType" },
          headers: headers

      body = parsed
      expect(body).to all(include("id", "resourceType"))
      expect(body).to all(satisfy { |h| h.keys.sort == %w[id resourceType].sort })
    end

    it "limits results to 500" do
      run = ImportRun.create!(status: "completed")

      510.times do |i|
        Record.create!(
          import_run: run,
          resource_id: "bulk-#{i}",
          resource_type: "Observation",
          subject_reference: "Patient/PT-BULK",
          extracted_data: { "id" => "bulk-#{i}", "resourceType" => "Observation" },
          raw_data: { "resourceType" => "Observation", "id" => "bulk-#{i}" }
        )
      end

      get "/api/v1/records", headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed.size).to eq(500)
    end

    it "returns 200 with an empty array when no records exist" do
      Record.delete_all
      ImportRun.delete_all

      get "/api/v1/records", headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed).to eq([])
    end
  end

  describe "GET /api/v1/records/:id" do
    it "returns 200 and extracted_data for a record by primary key" do
      record = create_record!(
        resource_id: "obs-123",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: {
          "id" => "obs-123",
          "resourceType" => "Observation",
          "status" => "final",
          "subject" => { "reference" => "Patient/PT-001" }
        }
      )

      get "/api/v1/records/#{record.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed).to include("id" => "obs-123", "resourceType" => "Observation")
    end

    it "supports fields projection" do
      record = create_record!(
        resource_id: "obs-124",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: {
          "id" => "obs-124",
          "resourceType" => "Observation",
          "status" => "final",
          "code" => { "text" => "Glucose" }
        }
      )

      get "/api/v1/records/#{record.id}", params: { fields: "id,status" }, headers: headers

      body = parsed
      expect(body.keys.sort).to eq(%w[id resourceType status].sort)
      expect(body["id"]).to eq("obs-124")
      expect(body["status"]).to eq("final")
    end

    it "returns 404 when record not found" do
      get "/api/v1/records/999999999", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(parsed).to eq({ "error" => "not_found" })
    end

    it "does not include raw_data or model fields" do
      record = create_record!(
        resource_id: "obs-125",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        extracted_data: { "id" => "obs-125", "resourceType" => "Observation" }
      )

      get "/api/v1/records/#{record.id}", headers: headers

      body = parsed
      expect(body).not_to have_key("raw_data")
      expect(body).not_to have_key("created_at")
      expect(body).not_to have_key("updated_at")
    end
  end
end
