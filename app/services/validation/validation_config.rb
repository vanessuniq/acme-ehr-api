module Validation
  # Configuration module for FHIR resource validation rules.
  #
  # This module defines validation rules for FHIR resources, including:
  #   - Required fields for each resource type
  #   - Valid status values based on FHIR R4 specification
  #
  # Purpose:
  #   - Centralize validation configuration in one location
  #   - Ensure FHIR resources meet minimum data quality requirements
  #   - Validate status codes against FHIR R4 specification
  #
  # Configuration Structure:
  #   REQUIRED_FIELDS:
  #     - "all": Fields required for all resource types
  #     - [ResourceType]: Additional fields required for specific types
  #
  #   VALID_STATUS:
  #     - [ResourceType]: Array of valid status/clinicalStatus codes
  #
  # Usage:
  #   required = ValidationConfig::REQUIRED_FIELDS["Observation"]
  #   valid_statuses = ValidationConfig::VALID_STATUS["Observation"]
  #
  # Special Cases:
  #   - Patient resources don't require "subject" field (they ARE the subject)
  #   - Condition and AllergyIntolerance use "clinicalStatus" instead of "status"
  #
  # See also:
  #   - Validation::Validator for validation implementation
  #   - FHIR R4 specification: https://hl7.org/fhir/R4/
  module ValidationConfig
    # Required fields for each resource type.
    #
    # Structure:
    #   - "all": Base fields required for all resource types
    #   - [ResourceType]: Additional required fields for specific types
    #
    # Note: "all" fields are applied to every resource type unless explicitly
    # excluded (e.g., Patient resources don't require "subject")
    REQUIRED_FIELDS = {
      "all" => [ "id", "resourceType", "subject" ],
      "Observation" => [ "code", "status" ],
      "MedicationRequest" => [ "medicationCodeableConcept", "status" ],
      "Procedure" => [ "code", "status" ],
      "Condition" => [ "code", "clinicalStatus" ],
      "Patient" => [ "name", "active" ], # FHIR Patient normally don't require subject field
      "AllergyIntolerance" => [ "code", "clinicalStatus" ],
      "DiagnosticReport" => [ "code", "status" ]
    }.freeze

    # Valid status values for resources that have status or clinicalStatus fields.
    #
    # Based on FHIR R4 specification value sets:
    #   - ObservationStatus
    #   - MedicationRequestStatus
    #   - EventStatus (for Procedure)
    #   - ConditionClinicalStatusCodes
    #   - DiagnosticReportStatus
    #   - AllergyIntoleranceClinicalStatusCodes
    #
    # Structure: { ResourceType => Array of valid status codes }
    VALID_STATUS = {
      "Observation" => %w[
        registered preliminary final amended corrected
        cancelled entered-in-error unknown
      ],
      "MedicationRequest" => %w[
        active on-hold cancelled completed entered-in-error
        stopped draft unknown
      ],
      "Procedure" => %w[
        preparation in-progress not-done on-hold stopped
        completed entered-in-error unknown
      ],
      "Condition" => %w[
        active recurrence relapse inactive remission resolved
      ], # For Condition.clinicalStatus
      "DiagnosticReport" => %w[
        registered partial preliminary final amended corrected
        appended cancelled entered-in-error unknown
      ],
      "AllergyIntolerance" => %w[
        active inactive resolved
      ] # For AllergyIntolerance.clinicalStatus
    }.freeze
  end
end
