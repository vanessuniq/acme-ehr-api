module Extraction
  # Defines which fields should be extracted from FHIR resources.
  # This configuration-driven approach makes it easy to modify extraction rules
  # without changing code.
  #
  # Usage:
  #   Fhir::ExtractionConfig.fields_for("Observation")
  #   => ["id", "resourceType", "subject", "code", "status", "effectiveDateTime", "valueQuantity", "component"]
  module ExtractionConfig
    # FHIR Resource Field Extraction Configuration
    #
    # This configuration defines which fields should be extracted from each FHIR resource type.
    # Fields are organized by scope: universal (all resources), common (shared), and resource-specific.
    #
    # Configuration Structure:
    # - Keys: FHIR field paths (string identifiers)
    # - Values: Either "all" (extract from all resources) or Array of resource types
    #
    # Design Principles:
    # 1. Universal fields provide base metadata for all resources
    # 2. Common fields are shared strategically across related clinical domains
    # 3. Resource-specific fields capture unique clinical data per resource type
    # 4. Field selection balances completeness with practical data extraction needs
    FIELDS = {
      # Universal fields - extracted from all resource types
      "id" => "all",
      "resourceType" => "all",
      "subject" => "all",

      # Common fields - extracted from specific resource types
      "code" => [ "Observation", "Condition", "Procedure", "AllergyIntolerance", "DiagnosticReport" ],
      "status" => [ "Observation", "Procedure", "MedicationRequest", "DiagnosticReport" ],
      "category" => [ "Condition", "AllergyIntolerance", "DiagnosticReport" ],
      "clinicalStatus" => [ "Condition", "AllergyIntolerance" ],
      "verificationStatus" => [ "Condition", "AllergyIntolerance" ],
      "onsetDateTime" => [ "Condition", "AllergyIntolerance" ],
      "performer" => [ "Procedure", "DiagnosticReport" ],
      "effectiveDateTime" => [ "Observation", "DiagnosticReport" ],

      # Observation-specific fields
      "valueQuantity" => [ "Observation" ],
      "component" => [ "Observation" ],

      # Procedure-specific fields
      "performedDateTime" => [ "Procedure" ],
      "location" => [ "Procedure" ],

      # MedicationRequest-specific fields
      "dosageInstruction" => [ "MedicationRequest" ],
      "medicationCodeableConcept" => [ "MedicationRequest" ],
      "intent" => [ "MedicationRequest" ],
      "authoredOn" => [ "MedicationRequest" ],
      "requester" => [ "MedicationRequest" ],

      # Patient-specific fields
      "name" => [ "Patient" ],
      "gender" => [ "Patient" ],
      "active" => [ "Patient" ],
      "birthDate" => [ "Patient" ],
      "address" => [ "Patient" ],
      "telecom" => [ "Patient" ],

      # AllergyIntolerance-specific fields
      "criticality" => [ "AllergyIntolerance" ],
      "type" => [ "AllergyIntolerance" ],
      "reaction" => [ "AllergyIntolerance" ],
      "recordedDate" => [ "AllergyIntolerance" ],
      "recorder" => [ "AllergyIntolerance" ],

      # DiagnosticReport-specific fields
      "issued" => [ "DiagnosticReport" ],
      "result" => [ "DiagnosticReport" ],
      "conclusion" => [ "DiagnosticReport" ]
    }.freeze

    def self.fields_for(resource_type)
      FIELDS.select do |_k, v|
        v == "all" || Array(v).include?(resource_type)
      end.keys
    end
  end
end
