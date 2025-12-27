module Importers
  # Value object to encapsulate import state during a JSONL import run.
  #
  # This class maintains statistics, errors, and warnings throughout the import process,
  # providing a centralized state management for import operations.
  #
  # Purpose:
  #   - Track resource counts by type (seen, imported, errors)
  #   - Collect validation errors and warnings
  #   - Track missing field occurrences by resource type
  #   - Generate statistical summaries for import runs
  #
  # Usage:
  #   context = Importers::ImportContext.new
  #   context.increment_seen("Observation")
  #   context.increment_imported("Observation")
  #   context.add_error({ line: 42, message: "Invalid resource" })
  #   stats = context.build_type_statistics
  #
  # Tracked Metrics:
  #   - seen_by_type: Resources encountered in the import file
  #   - imported_by_type: Resources successfully saved to database
  #   - errors_by_type: Resources that failed validation
  #   - missing_fields_by_type: Count of missing fields per resource type
  #   - errors: Array of validation error hashes
  #   - warnings: Array of warning hashes (e.g., missing optional fields)
  #   - total_lines: Total number of lines processed
  #
  # Methods:
  #   - increment_seen(resource_type): Increment count of resources seen
  #   - increment_imported(resource_type): Increment count of resources imported
  #   - increment_errors(resource_type): Increment count of errors
  #   - increment_missing_field(resource_type, field): Track missing field occurrence
  #   - add_error(error): Add a validation error
  #   - add_warning(warning): Add a warning
  #   - total_imported: Get total count of imported resources
  #   - build_type_statistics: Generate statistics hash grouped by resource type
  #
  # Example:
  #   context = ImportContext.new
  #   context.increment_seen("Patient")
  #   context.increment_imported("Patient")
  #   context.add_warning({ field: "telecom", message: "missing expected field" })
  #   puts context.total_imported  # => 1
  class ImportContext
      attr_accessor :total_lines
      attr_reader :errors, :warnings

      def initialize
        @seen_by_type = Hash.new(0)
        @imported_by_type = Hash.new(0)
        @errors_by_type = Hash.new(0)
        @missing_fields_by_type = Hash.new { |h, k| h[k] = Hash.new(0) }
        @errors = []
        @warnings = []
        @total_lines = 0
      end

      def increment_seen(resource_type)
        @seen_by_type[resource_type] += 1 if resource_type
      end

      def increment_imported(resource_type)
        @imported_by_type[resource_type] += 1 if resource_type
      end

      def increment_errors(resource_type)
        @errors_by_type[resource_type] += 1 if resource_type
      end

      def increment_missing_field(resource_type, field)
        @missing_fields_by_type[resource_type][field] += 1 if resource_type && field
      end

      def add_error(error)
        @errors << error
      end

      def add_warning(warning)
        @warnings << warning
      end

      def total_imported
        @imported_by_type.values.sum
      end

      def build_type_statistics
        all_types = @seen_by_type.keys | @imported_by_type.keys | @errors_by_type.keys

        all_types.each_with_object({}) do |resource_type, stats|
          stats[resource_type] = {
            seen: @seen_by_type[resource_type],
            imported: @imported_by_type[resource_type],
            errors: @errors_by_type[resource_type],
            missing_fields: @missing_fields_by_type[resource_type]
          }
        end
      end
  end
end
