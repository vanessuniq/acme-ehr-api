module Extraction
  # Service for extracting configured fields from FHIR resources.
  #
  # This service uses ExtractionConfig to determine which fields should be extracted
  # from a given FHIR resource type, then uses JsonPath to navigate and extract those
  # field values from the resource data.
  #
  # Purpose:
  #   - Extract specific fields from FHIR resources based on resource type
  #   - Track missing expected fields as warnings
  #   - Provide structured extracted data for storage and querying
  #
  # Usage:
  #   extractor = Extraction::Extractor.new
  #   extracted_data, warnings = extractor.extract(fhir_resource)
  #
  # Parameters:
  #   resource [Hash] - A FHIR resource as a hash (must include "resourceType")
  #
  # Returns:
  #   Array containing two elements:
  #   [0] extracted [Hash] - Hash of field paths to their extracted values
  #   [1] warnings [Array] - Array of warning hashes for missing expected fields
  #
  # Example:
  #   resource = {
  #     "resourceType" => "Observation",
  #     "id" => "obs-123",
  #     "status" => "final",
  #     "code" => { "text" => "Blood Pressure" }
  #   }
  #
  #   extracted, warnings = extractor.extract(resource)
  #   # extracted => { "id" => "obs-123", "status" => "final", "code" => {...}, ... }
  #   # warnings => [{ field: "valueQuantity", message: "missing expected field" }]
  #
  # See also:
  #   - Extraction::ExtractionConfig for field configuration
  #   - JsonPath for path navigation syntax
  class Extractor
    def extract(resource)
      rt = resource["resourceType"]
      fields = ExtractionConfig.fields_for(rt)

      extracted = {}
      warnings = []

      fields.each do |field|
        value = JsonPath.get(resource, field)
        extracted[field] = value

        # warning if expected but missing
        if value.nil?
          warnings << { field:, message: "missing expected field" }
        end
      end

      [ extracted, warnings ]
    end
  end
end
