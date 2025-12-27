module Timelines
  # Service for building chronological timelines of patient clinical events.
  #
  # This service creates a sorted, time-based view of a patient's clinical records,
  # combining data from multiple FHIR resource types into a unified timeline.
  #
  # Purpose:
  #   - Provide chronological view of patient clinical history
  #   - Filter events by resource type and date range
  #   - Extract meaningful summaries and details from FHIR resources
  #   - Support clinical decision-making with temporal context
  #
  # Usage:
  #   timeline = Timelines::PatientTimeline.new
  #   events = timeline.build(
  #     subject: "Patient/123",
  #     resource_types: ["Observation", "Procedure"],
  #     from: "2024-01-01",
  #     to: "2024-12-31",
  #     limit: 100
  #   )
  #
  # Parameters:
  #   subject [String] - Required. Patient reference (e.g., "Patient/123")
  #   resource_types [Array<String>] - Optional. Filter by resource types
  #   from [String] - Optional. Start date (YYYY-MM-DD or ISO8601)
  #   to [String] - Optional. End date (YYYY-MM-DD or ISO8601)
  #   limit [Integer] - Optional. Maximum events to return (default: 100)
  #
  # Returns:
  #   Array of event hashes, sorted chronologically. Each event contains:
  #     - date: Original date string from the resource
  #     - resourceType: FHIR resource type
  #     - id: Resource ID
  #     - summary: Human-readable summary (code text or display)
  #     - details: Resource-specific details (values, dosages, etc.)
  #
  # Date Field Mapping:
  #   - Observation: effectiveDateTime
  #   - Procedure: performedDateTime
  #   - MedicationRequest: authoredOn
  #   - Condition: onsetDateTime
  #
  # Date Handling:
  #   - Supports ISO8601 timestamps and YYYY-MM-DD dates
  #   - Date-only values: start boundary uses 00:00:00, end boundary uses 23:59:59
  #   - All times processed in UTC
  #
  # Example:
  #   events = timeline.build(subject: "Patient/123", from: "2024-01-01")
  #   # => [
  #   #   {
  #   #     date: "2024-01-15",
  #   #     resourceType: "Observation",
  #   #     id: "obs-1",
  #   #     summary: "Blood Pressure",
  #   #     details: { "Systolic" => "120 mmHg", "Diastolic" => "80 mmHg" }
  #   #   },
  #   #   ...
  #   # ]
  #
  # Limitations:
  #   - Only includes resources with date fields defined in DATE_FIELDS
  #   - Maximum limit enforced to prevent performance issues
  #   - Resources without valid dates are excluded from timeline
  #
  # See also:
  #   - Record.filter for underlying query logic
  #   - JsonPath for field extraction
  class PatientTimeline
    # Maps FHIR resource types to their respective date fields for timeline ordering.
    DATE_FIELDS = {
      "Observation" => "effectiveDateTime",
      "Procedure" => "performedDateTime",
      "MedicationRequest" => "authoredOn",
      "Condition" => "onsetDateTime"
    }.freeze

    def build(subject:, resource_types: nil, from: nil, to: nil, limit: 100)
      from_time = parse_time(from, boundary: :start)
      to_time   = parse_time(to, boundary: :end)

      records = Record.filter(resource_type: resource_types, subject: subject)

      events = records.map { |record| extract_event(record) }.compact
      events = filter_by_date(events, from_time, to_time)

      events
        .sort_by { |e| e[:occurred_at] }
        .first(limit)
        .map { |e| serialize_event(e) }
    end

    private

    def extract_event(record)
      date_path = DATE_FIELDS[record.resource_type]
      return unless date_path

      raw_date = JsonPath.get(record.raw_data, date_path)
      occurred_at = parse_time(raw_date, boundary: :start)
      return unless occurred_at

      {
        occurred_at: occurred_at,
        date: raw_date, # keep original string for display
        resourceType: record.resource_type,
        id: record.resource_id,
        summary: build_summary(record),
        details: build_details(record)
      }
    end

    def filter_by_date(events, from_time, to_time)
      events.select do |e|
        (!from_time || e[:occurred_at] >= from_time) &&
          (!to_time || e[:occurred_at] <= to_time)
      end
    end

    def parse_time(value, boundary: :start)
      s = value.to_s.strip
      return nil if s.blank?

      if s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        # Date-only:
        # - boundary :start => 00:00:00
        # - boundary :end   => 23:59:59
        time_str = boundary == :end ? "#{s} 23:59:59" : "#{s} 00:00:00"
        Time.use_zone("UTC") { Time.zone.parse(time_str) }
      else
        Time.iso8601(s)
      end
    rescue ArgumentError, TypeError
      nil
    end


    def serialize_event(e)
      {
        date: e[:date],
        resourceType: e[:resourceType],
        id: e[:id],
        summary: e[:summary],
        details: e[:details]
      }
    end

    # keep your existing build_summary/build_details as-is
    def build_summary(record)
      JsonPath.get(record.raw_data, "code.text") ||
        JsonPath.get(record.raw_data, "code.coding[0].display") ||
        JsonPath.get(record.raw_data, "code.coding[0].code") ||
        JsonPath.get(record.raw_data, "medicationCodeableConcept.text") ||
        JsonPath.get(record.raw_data, "medicationCodeableConcept.coding[0].display") ||
        JsonPath.get(record.raw_data, "medicationCodeableConcept.coding[0].code")
    end

    def build_details(record)
      case record.resource_type
      when "Observation"
        if (component = JsonPath.get(record.raw_data, "component"))
          component.each_with_object({}) do |comp, acc|
            code = JsonPath.get(comp, "code.coding[0].display") || JsonPath.get(comp, "code.coding[0].code")
            v = JsonPath.get(comp, "valueQuantity.value")
            u = JsonPath.get(comp, "valueQuantity.unit")
            acc[code] = "#{v} #{u}".strip
          end
        else
          value = JsonPath.get(record.raw_data, "valueQuantity.value")
          unit = JsonPath.get(record.raw_data, "valueQuantity.unit")
          { value: "#{value} #{unit}".strip }
        end
      when "MedicationRequest"
        { dosage: JsonPath.get(record.raw_data, "dosageInstruction[0].text") }
      else
        {}
      end
    end
  end
end
