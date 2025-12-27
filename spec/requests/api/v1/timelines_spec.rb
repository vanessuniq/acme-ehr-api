require "rails_helper"

RSpec.describe "Api::V1::Timelines", type: :request do
  let(:headers) { { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" } }

  def get_timeline(params = {})
    get "/api/v1/timelines", params: params, headers: headers
  end

  # Minimal helper to create a Record with raw_data that matches your timeline extractor.
  def create_record!(resource_type:, resource_id:, subject_reference:, raw_data:)
    import_run = ImportRun.create!(status: "completed")

    Record.create!(
      import_run: import_run,
      resource_type: resource_type,
      resource_id: resource_id,
      subject_reference: subject_reference,
      extracted_data: { "resourceType" => resource_type, "id" => resource_id },
      raw_data: raw_data
    )
  end

  describe "GET /api/v1/timelines" do
    let(:subject) { "Patient/PT-001" }

    it "returns 422 when subject is missing" do
      get_timeline

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["error"]).to match(/subject is required/i)
    end

    it "returns events sorted by date and limited (default 100)" do
      # later
      create_record!(
        resource_type: "Observation",
        resource_id: "obs-2",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-2",
          "subject" => { "reference" => subject },
          "effectiveDateTime" => "2025-01-10T10:00:00Z",
          "code" => { "text" => "Glucose" },
          "valueQuantity" => { "value" => 95, "unit" => "mg/dL" }
        }
      )

      # earlier
      create_record!(
        resource_type: "Procedure",
        resource_id: "proc-1",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Procedure",
          "id" => "proc-1",
          "subject" => { "reference" => subject },
          "performedDateTime" => "2025-01-10T09:00:00Z",
          "code" => { "text" => "Annual Physical" }
        }
      )

      get_timeline(subject: subject)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
      expect(data.length).to eq(2)

      # sorted ascending (earliest first)
      expect(data[0]).to include("resourceType" => "Procedure", "id" => "proc-1")
      expect(data[1]).to include("resourceType" => "Observation", "id" => "obs-2")

      # includes basic shape
      expect(data[0]).to include("date", "summary", "details")
    end

    it "filters by resourceTypes (csv) and ignores blank tokens" do
      create_record!(
        resource_type: "Observation",
        resource_id: "obs-1",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-1",
          "subject" => { "reference" => subject },
          "effectiveDateTime" => "2025-01-10T09:00:00Z",
          "code" => { "text" => "Blood Pressure" }
        }
      )

      create_record!(
        resource_type: "MedicationRequest",
        resource_id: "med-1",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "MedicationRequest",
          "id" => "med-1",
          "subject" => { "reference" => subject },
          "authoredOn" => "2025-01-10T08:00:00Z",
          "medicationCodeableConcept" => { "text" => "Metformin" },
          "dosageInstruction" => [ { "text" => "Take one tablet twice daily with meals" } ]
        }
      )

      get_timeline(subject: subject, resourceTypes: "Observation, , ")

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.map { |e| e["resourceType"] }.uniq).to eq([ "Observation" ])
    end

    it "filters by from/to (date-only) and returns only in-range events" do
      create_record!(
        resource_type: "Observation",
        resource_id: "obs-in",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-in",
          "subject" => { "reference" => subject },
          "effectiveDateTime" => "2025-01-10T09:00:00Z",
          "code" => { "text" => "In range" }
        }
      )

      create_record!(
        resource_type: "Observation",
        resource_id: "obs-out",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-out",
          "subject" => { "reference" => subject },
          "effectiveDateTime" => "2025-01-12T09:00:00Z",
          "code" => { "text" => "Out of range" }
        }
      )

      get_timeline(subject: subject, from: "2025-01-10", to: "2025-01-10")

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data[0]).to include("id" => "obs-in")
    end

    it "respects limit param" do
      3.times do |i|
        create_record!(
          resource_type: "Observation",
          resource_id: "obs-#{i}",
          subject_reference: subject,
          raw_data: {
            "resourceType" => "Observation",
            "id" => "obs-#{i}",
            "subject" => { "reference" => subject },
            "effectiveDateTime" => "2025-01-10T0#{i}:00:00Z",
            "code" => { "text" => "Obs #{i}" }
          }
        )
      end

      get_timeline(subject: subject, limit: 2)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(2)
    end

    it "skips records missing the configured date field for that resourceType" do
      create_record!(
        resource_type: "Observation",
        resource_id: "obs-missing-date",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-missing-date",
          "subject" => { "reference" => subject },
          "code" => { "text" => "No date" }
          # no effectiveDateTime
        }
      )

      get_timeline(subject: subject)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to eq([])
    end

    it "includes Observation component details when component exists" do
      create_record!(
        resource_type: "Observation",
        resource_id: "obs-bp",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "Observation",
          "id" => "obs-bp",
          "subject" => { "reference" => subject },
          "effectiveDateTime" => "2025-01-10T09:00:00Z",
          "code" => { "text" => "Blood Pressure" },
          "component" => [
            {
              "code" => { "coding" => [ { "code" => "8480-6", "display" => "Systolic blood pressure" } ] },
              "valueQuantity" => { "value" => 120, "unit" => "mmHg" }
            },
            {
              "code" => { "coding" => [ { "code" => "8462-4", "display" => "Diastolic blood pressure" } ] },
              "valueQuantity" => { "value" => 80, "unit" => "mmHg" }
            }
          ]
        }
      )

      get_timeline(subject: subject)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)

      details = data[0]["details"]
      expect(details).to include(
        "Systolic blood pressure" => "120 mmHg",
        "Diastolic blood pressure" => "80 mmHg"
      )
    end

    it "includes MedicationRequest dosage details when present" do
      create_record!(
        resource_type: "MedicationRequest",
        resource_id: "med-1",
        subject_reference: subject,
        raw_data: {
          "resourceType" => "MedicationRequest",
          "id" => "med-1",
          "subject" => { "reference" => subject },
          "authoredOn" => "2025-01-10T08:00:00Z",
          "medicationCodeableConcept" => { "text" => "Metformin" },
          "dosageInstruction" => [ { "text" => "Take one tablet twice daily" } ]
        }
      )

      get_timeline(subject: subject)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data[0]["details"]).to include("dosage" => "Take one tablet twice daily")
    end
  end
end
