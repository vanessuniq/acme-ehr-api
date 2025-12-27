require "rails_helper"

RSpec.describe "Api::V1::Transforms", type: :request do
  let(:headers) { { "ACCEPT" => "application/json" } }

  def parsed
    JSON.parse(response.body)
  end

  def create_record!(
    resource_id:,
    resource_type:,
    subject_reference:,
    raw_data:
  )
    run = ImportRun.create!(status: "completed")

    Record.create!(
      import_run: run,
      resource_id: resource_id,
      resource_type: resource_type,
      subject_reference: subject_reference,
      extracted_data: { "id" => resource_id, "resourceType" => resource_type }, # minimal
      raw_data: raw_data
    )
  end

  describe "POST /api/v1/transform" do
    before do
      @obs1 = create_record!(
        resource_id: "obs-001",
        resource_type: "Observation",
        subject_reference: "Patient/PT-001",
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-001",
          "status" => "final",
          "subject" => { "reference" => "Patient/PT-001" },
          "code" => {
            "coding" => [
              { "system" => "http://loinc.org", "code" => "85354-9", "display" => "Blood pressure panel" }
            ],
            "text" => "Blood Pressure"
          },
          "valueQuantity" => { "value" => 120, "unit" => "mmHg" }
        }
      )

      @obs2_other_patient = create_record!(
        resource_id: "obs-002",
        resource_type: "Observation",
        subject_reference: "Patient/PT-999",
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-002",
          "status" => "final",
          "subject" => { "reference" => "Patient/PT-999" },
          "code" => { "coding" => [ { "system" => "http://loinc.org", "code" => "2339-0" } ] },
          "valueQuantity" => { "value" => 95, "unit" => "mg/dL" }
        }
      )

      @proc = create_record!(
        resource_id: "proc-001",
        resource_type: "Procedure",
        subject_reference: "Patient/PT-001",
        raw_data: {
          "resourceType" => "Procedure",
          "id" => "proc-001",
          "status" => "completed",
          "subject" => { "reference" => "Patient/PT-001" },
          "code" => {
            "coding" => [
              { "system" => "http://snomed.info/sct", "code" => "171207006", "display" => "Depression screening" }
            ],
            "text" => "Annual Wellness Visit"
          },
          "performedDateTime" => "2025-01-12T10:00:00Z"
        }
      )
    end

    it "returns 200 and transforms records filtered by subject + resourceTypes" do
      payload = {
        resourceTypes: [ "Observation" ],
        filters: { subject: "Patient/PT-001" },
        transformations: [
          { action: "flatten", field: "code.coding[0]" },
          { action: "extract", field: "valueQuantity.value", as: "value" },
          { action: "extract", field: "valueQuantity.unit", as: "unit" }
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      body = parsed
      expect(body).to be_a(Array)
      expect(body.size).to eq(1)

      row = body.first
      expect(row).to include(
        "id" => "obs-001",
        "resourceType" => "Observation",
        "value" => 120,
        "unit" => "mmHg"
      )

      # flatten uses prefix = first segment of field ("code") + "_" + k
      # but your flatten reads the Hash at code.coding[0] and emits code_system/code_code/code_display
      expect(row).to include(
        "code_system" => "http://loinc.org",
        "code_code" => "85354-9",
        "code_display" => "Blood pressure panel"
      )
    end

    it "returns multiple records when filters are omitted (resourceTypes still applied)" do
      payload = {
        resourceTypes: [ "Observation" ],
        transformations: [
          { action: "extract", field: "subject.reference", as: "subject_ref" }
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      body = parsed
      expect(body.size).to eq(2)

      ids = body.map { |r| r["id"] }
      expect(ids).to match_array(%w[obs-001 obs-002])

      expect(body).to all(include("resourceType" => "Observation"))
      expect(body.map { |r| r["subject_ref"] }).to match_array([ "Patient/PT-001", "Patient/PT-999" ])
    end

    it "supports resourceTypes across multiple types" do
      payload = {
        resourceTypes: [ "Observation", "Procedure" ],
        filters: { subject: "Patient/PT-001" },
        transformations: [
          { action: "extract", field: "status", as: "status" }
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      body = parsed
      expect(body.size).to eq(2)

      types = body.map { |r| r["resourceType"] }
      expect(types).to match_array(%w[Observation Procedure])

      statuses = body.map { |r| r["status"] }
      expect(statuses).to match_array(%w[final completed])
    end

    it "adds _warning for unknown actions (and still returns id/resourceType)" do
      payload = {
        resourceTypes: [ "Observation" ],
        filters: { subject: "Patient/PT-001" },
        transformations: [
          { action: "do_magic", field: "status", as: "x" },
          { action: "extract", field: "status", as: "status" }
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      row = parsed.first

      expect(row).to include("id" => "obs-001", "resourceType" => "Observation", "status" => "final")
      expect(row["_warning"]).to include("unknown action do_magic")
    end

    it "handles extract on missing fields by returning null for that key" do
      payload = {
        resourceTypes: [ "Procedure" ],
        filters: { subject: "Patient/PT-001" },
        transformations: [
          { action: "extract", field: "valueQuantity.value", as: "value" } # not on Procedure
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      body = parsed
      expect(body.size).to eq(1)
      expect(body.first).to include("id" => "proc-001", "resourceType" => "Procedure", "value" => nil)
    end

    it "flatten does nothing when the targeted value isn't a Hash" do
      payload = {
        resourceTypes: [ "Observation" ],
        filters: { subject: "Patient/PT-001" },
        transformations: [
          { action: "flatten", field: "status" } # status is a String
        ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      row = parsed.first

      # It should still have id/resourceType, but no code_* keys were added
      expect(row).to include("id" => "obs-001", "resourceType" => "Observation")
      expect(row.keys.any? { |k| k.start_with?("status_") }).to be(false)
    end

    it "returns [] when no records match filters" do
      payload = {
        resourceTypes: [ "Observation" ],
        filters: { subject: "Patient/DOES-NOT-EXIST" },
        transformations: [ { action: "extract", field: "status", as: "status" } ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed).to eq([])
    end

    it "limits output to 500 records" do
      run = ImportRun.create!(status: "completed")

      510.times do |i|
        Record.create!(
          import_run: run,
          resource_id: "bulk-#{i}",
          resource_type: "Observation",
          subject_reference: "Patient/PT-BULK",
          extracted_data: { "id" => "bulk-#{i}", "resourceType" => "Observation" },
          raw_data: { "resourceType" => "Observation", "id" => "bulk-#{i}", "status" => "final" }
        )
      end

      payload = {
        resourceTypes: [ "Observation" ],
        filters: { subject: "Patient/PT-BULK" },
        transformations: [ { action: "extract", field: "status", as: "status" } ]
      }

      post "/api/v1/transform", params: payload, as: :json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed.size).to eq(500)
    end
  end
end
