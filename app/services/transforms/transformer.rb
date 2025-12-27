module Transforms
  # Service for transforming FHIR records based on user-defined transformations.
  #
  # The Transformer class processes FHIR resources and applies transformations to extract
  # and reshape data according to specified rules.
  #
  # Supported Payload Structure:
  #   {
  #     "resourceTypes": ["Patient", "Observation", ...],  # Array of FHIR resource types to filter
  #     "filters": {
  #       "subject": "patient-123"                          # Optional subject filter
  #     },
  #     "transformations": [                                # Array of transformation rules
  #       {
  #         "action": "extract",                            # Transformation action
  #         "field": "name[0].given[0]",                    # JSONPath field selector
  #         "as": "firstName"                               # Output field name
  #       }
  #     ]
  #   }
  #
  # Supported filters:
  #   - subject: Filters records to only those associated with the specified subject reference
  # Supported Actions:
  #   - "extract": Extracts a value from a JSONPath and outputs it with a custom field name
  #       Example: { "action": "extract", "field": "name[0].given[0]", "as": "firstName" }
  #       Extracts the first given name and outputs it as "firstName"
  #
  #   - "flatten": Extracts a hash and flattens its keys into the output with prefixed names
  #       Example: { "action": "flatten", "field": "code.coding[0]" }
  #       Transforms { "system": "...", "code": "...", "display": "..." }
  #       Into: { "code_system": "...", "code_code": "...", "code_display": "..." }
  #
  # Limitations:
  #   - Returns a maximum of 500 records per request
  #   - Unknown actions will add a "_warning" field to the output
  #   - JSONPath fields are evaluated using the JsonPath library
  #
  # Returns:
  #   Array of transformed resources, each containing:
  #   - "id": The resource ID
  #   - "resourceType": The FHIR resource type
  #   - Custom fields based on transformations
  #   - "_warning": Array of warnings (if any unknown actions were encountered)
  class Transformer
    def transform(payload)
      resource_types = payload["resourceTypes"] || []
      subject = payload.dig("filters", "subject")
      transformations = payload["transformations"] || []

      records = Record.filter(resource_type: resource_types, subject: subject)

      records.limit(500).map do |record|
        apply_transformations(record.raw_data, transformations).merge(
          "id" => record.resource_id,
          "resourceType" => record.resource_type
        )
      end
    end

    private

    def apply_transformations(resource, transformations)
      out = {}

      transformations.each do |t|
        action = t["action"]
        field = t["field"]
        as = t["as"]

        case action
        when "extract"
          out[as] = JsonPath.get(resource, field)
        when "flatten"
          value = JsonPath.get(resource, field)
          # flatten hash keys into output: system/code/display -> code_system, code_code, etc
          if value.is_a?(Hash)
            value.each { |k, v| out["#{field.split('.').first}_#{k}"] = v }
          end
        else
          out["_warning"] ||= []
          out["_warning"] << "unknown action #{action}"
        end
      end

      out
    end
  end
end
