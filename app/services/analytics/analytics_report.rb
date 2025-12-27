module Analytics
  # Service for generating comprehensive analytics reports on imported FHIR data.
  #
  # This service provides aggregated statistics across all imported records and import runs,
  # including counts by resource type, patient statistics, import success/failure rates,
  # and detailed error summaries.
  #
  # Usage:
  #   report = Analytics::AnalyticsReport.new.build
  #
  # Returns a hash containing:
  #   {
  #     total_records: Integer,              # Total count of all records in the database
  #     records_by_type: Hash,                # Count of records grouped by FHIR resource type
  #     unique_patients: Integer,             # Count of unique patient subjects
  #     records_per_patient: Hash,            # Count of records for each patient reference
  #     imports_summary: {
  #       total_imports: Integer,             # Total number of import runs
  #       successful_imports: Integer,        # Import runs with "completed" status
  #       failed_imports: Integer,            # Import runs with "failed" status
  #       imports_with_errors: Integer,       # Import runs containing validation errors
  #       error_summary: Array                # Detailed breakdown of errors by import run
  #     }
  #   }
  #
  # Error Summary Structure:
  #   Each error summary entry contains:
  #   - import_id: The ImportRun ID
  #   - error_count: Total number of validation errors in that import
  #   - errors: Hash grouped by resourceType, with path/message counts
  #
  # Example:
  #   report = Analytics::AnalyticsReport.new.build
  #   puts "Total records: #{report[:total_records]}"
  #   puts "Unique patients: #{report[:unique_patients]}"
  #   puts "Failed imports: #{report[:imports_summary][:failed_imports]}"
  class AnalyticsReport
    def build
      {
        total_records: Record.count,
        records_by_type: Record.group(:resource_type).count,
        unique_patients: Record.unique_subjects_count,
        imports_summary:,
        # Custom statistics
        records_per_patient: Record.where.not(resource_type: "Patient").group(:subject_reference).count
      }
    end

    private

    def imports_summary
      {
        total_imports: ImportRun.count,
        successful_imports: ImportRun.completed.count,
        failed_imports: ImportRun.failed.count,
        imports_with_errors: ImportRun.with_errors.count,
        error_summary: error_summary
      }
    end

    def error_summary
      ImportRun.with_errors.map do |run|
        {
          import_id: run.id,
          error_count: run.validation_errors.length,
          errors: format_errors(run)
        }
      end
    end

    # Format errors for reporting
    def format_errors(run)
      summary_by_type = {}

      run.validation_errors
        .group_by { |e| e["resourceType"] || e[:resourceType] || "unknown" }
        .each do |resource_type, errors|
        summary_by_type[resource_type] = {
          count: errors.length,
          error_summary: errors
            .group_by do |e|
              path = e["path"] || e[:path] || "$"
              msg  = e["message"] || e[:message] || "unknown error"
              "#{path}|#{msg}"
            end
            .map do |k, arr|
              path, msg = k.split("|", 2)
              { path: path, message: msg, count: arr.length }
            end
            .sort_by { |h| -h[:count] }
        }
      end

      summary_by_type
    end
  end
end
