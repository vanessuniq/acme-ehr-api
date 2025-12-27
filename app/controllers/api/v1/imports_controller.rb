module Api
  module V1
    class ImportsController < ApplicationController
      # POST /api/v1/import
      # Accepts:
      # - JSONL payload in request body or
      # - Multipart form with file upload
      def create
        jsonl = extract_jsonl_payload
        if jsonl.blank?
          render json: { error: "No data provided for import" }, status: :bad_request
          return
        end

        run = Importers::JsonlImporter.new.import(jsonl)

        render json: run, except: [ :created_at, :updated_at ], status: :ok
      rescue => e
        render json: { error: "Import failed: #{e.message}" }, status: :internal_server_error
      end

      private

      def extract_jsonl_payload
        if params[:file].present?
          params[:file].try(:read)
        else
          request.raw_post
        end
      end
    end
  end
end
