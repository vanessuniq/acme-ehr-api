module Validation
  # Service for validating FHIR resources against configured validation rules.
  #
  # This service validates FHIR resources to ensure they meet minimum data quality
  # requirements before being imported into the system. It checks:
  #   - Required fields are present
  #   - Status values are valid according to FHIR R4 specification
  #   - Resource structure is valid JSON
  #
  # Purpose:
  #   - Enforce data quality standards for imported FHIR resources
  #   - Provide detailed error messages for invalid resources
  #   - Prevent invalid data from entering the system
  #
  # Usage:
  #   validator = Validation::Validator.new
  #   errors = validator.validate(fhir_resource)
  #
  # Parameters:
  #   resource [Hash] - A FHIR resource as a hash
  #
  # Returns:
  #   Array of error hashes. Each error contains:
  #     - path: The field path that failed validation
  #     - message: Description of the validation failure
  #
  # Validation Rules:
  #   1. Required Fields:
  #      - Base fields (id, resourceType, subject) for all resources
  #      - Resource-specific required fields from ValidationConfig
  #      - Patient resources exempt from "subject" requirement
  #
  #   2. Status Validation:
  #      - For resources with status fields, validates against FHIR R4 value sets
  #      - Condition and AllergyIntolerance use "clinicalStatus.coding[0].code"
  #      - Other resources use "status" field directly
  #
  # Example:
  #   resource = { "resourceType" => "Observation", "id" => "123" }
  #   errors = validator.validate(resource)
  #   # => [
  #   #   { path: "subject", message: "subject is required for Observation resource" },
  #   #   { path: "code", message: "code is required for Observation resource" },
  #   #   { path: "status", message: "status is required for Observation resource" }
  #   # ]
  #
  # See also:
  #   - Validation::ValidationConfig for validation rules configuration
  #   - JsonPath for field path navigation
  class Validator
    def validate(resource)
      errors = []
      if resource.is_a?(Hash)
        validate_required_fields(resource, errors)
        validate_status(resource, errors)
      else
        errors << { path: "resource", message: "Resource must be a valid JSON object" }
      end

      errors
    end

    private

    def validate_required_fields(resource, errors)
      required_fields = required_fields_for(resource["resourceType"])
      required_fields.each do |field|
        errors.concat(require_path(resource, field))
      end
    end

    def validate_status(resource, errors)
      rt = resource["resourceType"]
      valid_values = ValidationConfig::VALID_STATUS[rt]
      return if valid_values.nil?  # No status validation for this type

      status = [ "Condition", "AllergyIntolerance" ].include?(rt) ? JsonPath.get(resource, "clinicalStatus.coding[0].code") : resource["status"]
      return if status.nil?  # Status not present; required field validation will catch this

      unless valid_values.include?(status)
        errors << { path: "status", message: "invalid status '#{status}' for #{rt}" }
      end
    end

    def required_fields_for(resource_type)
      base_fields = ValidationConfig::REQUIRED_FIELDS["all"]
      # Patient resources don't require subject (they ARE the subject)
      base_fields = base_fields - [ "subject" ] if resource_type == "Patient"

      specific_fields = ValidationConfig::REQUIRED_FIELDS[resource_type] || []
      base_fields + specific_fields
    end

    def require_path(resource, path)
      value = JsonPath.get(resource, path)
      return [] unless value.nil?

      [ { path:, message: "#{path} is required for #{resource["resourceType"]} resource" } ]
    end
  end
end
