module Api
  module V1
    class RecordsController < ApplicationController
      # GET /api/v1/records
      # Query params:
      # - resourceType: filter by FHIR resource type
      # - subject: filter by subject reference
      # - fields: comma-separated list of fields to return
      def index
        records = Record.filter(
          resource_type: params[:resourceType],
          subject: params[:subject]
        ).limit(500)

        render json: records.map { |r| serialize_record(r, params[:fields]) }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/records/:id
      # where :id is the Record ID
      # Query params:
      # - fields: comma-separated list of fields to return

      def show
        record = Record.find(params[:id])
        render json: serialize_record(record, params[:fields])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not_found" }, status: :not_found
      end

      private

      def serialize_record(record, fields_param)
        extracted = record.extracted_data

        if fields_param.present?
          requested = fields_param.split(",").map(&:strip)
          # Always include resourceType
          requested << "resourceType" unless requested.include?("resourceType")
          extracted.slice(*requested)
        else
          extracted
        end
      end
    end
  end
end
