module Importers
  # JSONL Importer for processing line-delimited JSON data
  # Each line is expected to be a valid JSON object representing a FHIR resource.
  # The importer validates, extracts, and stores records in the database,
  # while maintaining an import run log with statistics and errors.
  class JsonlImporter
    attr_reader :validator, :extractor

    def initialize(validator: Validation::Validator.new, extractor: Extraction::Extractor.new)
      @validator = validator
      @extractor = extractor
    end

    def import(jsonl_text)
      raise ArgumentError, "Input cannot be nil" if jsonl_text.nil?

      import_run = create_import_run
      context = ImportContext.new

      process_lines(jsonl_text, import_run, context)
      finalize_import_run(import_run, context)

      import_run
    rescue StandardError => e
      handle_import_failure(import_run, e) if import_run
      raise e
    end

    private

    def create_import_run
      ImportRun.create!(status: "processing")
    end

    def process_lines(jsonl_text, import_run, context)
      lines = jsonl_text.to_s.each_line
      context.total_lines = jsonl_text.to_s.lines.count

      lines.each_with_index do |line, idx|
        line_number = idx + 1
        next if line.blank?

        process_line(line, line_number, import_run, context)
      end
    end

    def process_line(line, line_number, import_run, context)
      resource = parse_json_safely(line, line_number, context)
      return unless resource

      resource_type = extract_resource_type(resource)
      context.increment_seen(resource_type)

      # without valid resource type, skip further processing
      return unless validate_resource(resource, resource_type, line_number, context)

      extracted_data = extract_data(resource, resource_type, line_number, context)

      record = build_record_attributes(resource, resource_type, extracted_data, import_run)
      if record_inserted?(record, line_number, context)
        context.increment_imported(resource_type)
      end
    end

    def parse_json_safely(line, line_number, context)
      JSON.parse(line)
    rescue JSON::ParserError => e
      context.add_error(
        line: line_number,
        path: "$",
        message: "Invalid JSON: #{e.message}",
        resourceType: nil
      )
      nil
    end

    def extract_resource_type(resource)
      return nil unless resource.is_a?(Hash)
      resource["resourceType"]
    end

    def validate_resource(resource, resource_type, line_number, context)
      validation_errors = validator.validate(resource)

      if validation_errors.any?
        context.increment_errors(resource_type)
        validation_errors.each do |error|
          context.add_error(error.merge(line: line_number, resourceType: resource_type))
        end
        return false
      end

      true
    end

    def extract_data(resource, resource_type, line_number, context)
      extracted_data, warnings = extractor.extract(resource)

      warnings.each do |warning|
        context.add_warning(warning.merge(line: line_number, resourceType: resource_type))
        context.increment_missing_field(resource_type, warning[:field])
      end

      extracted_data
    end

    def build_record_attributes(resource, resource_type, extracted_data, import_run)
      {
        resource_id: resource["id"],
        resource_type: resource_type,
        subject_reference: extract_subject_reference(resource),
        extracted_data: extracted_data,
        raw_data: resource,
        import_run_id: import_run.id
      }
    end

    def extract_subject_reference(resource)
      JsonPath.get(resource, "subject.reference")
    rescue StandardError => e
      Rails.logger.warn("Failed to extract subject reference: #{e.message}")
      nil
    end

    def record_inserted?(record_attrs, line_num, context)
      Record.find_or_create_by!(
        resource_id: record_attrs[:resource_id],
        resource_type: record_attrs[:resource_type]
      ) do |r|
        r.subject_reference = record_attrs[:subject_reference]
        r.extracted_data = record_attrs[:extracted_data]
        r.raw_data = record_attrs[:raw_data]
        r.import_run_id = record_attrs[:import_run_id]
      end

      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to insert record: #{e.message}")
      context.add_error(
        line: line_num,
        path: "$",
        message: "Failed to insert record: #{e.message}",
        resourceType: record_attrs[:resource_type]
      )

      false
    end

    def finalize_import_run(import_run, context)
      statistics = build_statistics(import_run, context)

      import_run.update!(
        total_lines: context.total_lines,
        successful_records: context.total_imported,
        validation_errors: context.errors,
        warnings: context.warnings,
        statistics: statistics,
        status: "completed"
      )
    end

    def build_statistics(import_run, context)
      {
        by_resource_type: context.build_type_statistics,
        unique_subjects: count_unique_subjects(import_run)
      }
    end

    def count_unique_subjects(import_run)
      Record.where(import_run_id: import_run.id)
            .where.not(subject_reference: nil)
            .distinct
            .count(:subject_reference)
    end

    def handle_import_failure(import_run, error)
      import_run.update(
        status: "failed",
        validation_errors: import_run.validation_errors + [ { message: "Import failed: #{error.message}" } ]
      )
    rescue StandardError => e
      Rails.logger.error("Failed to update import run status: #{e.message}")
    end
  end
end
