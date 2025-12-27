module Api
  module V1
    class TimelinesController < ApplicationController
      def index
        subject = params[:subject].to_s.strip
        raise ArgumentError, "subject is required" if subject.blank?

        resource_types = parse_csv_param(params[:resourceTypes])

        data = Timelines::PatientTimeline.new.build(
          subject: subject,
          resource_types: resource_types, # ALWAYS Array or nil
          from: params[:from],
          to: params[:to],
          limit: parse_limit(params[:limit])
        )

        render json: data
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def parse_csv_param(value)
        return if value.nil?
        items = value.to_s.split(",").map { |s| s.strip }.reject(&:blank?)
        items.presence
      end

      def parse_limit(value)
        limit = value.to_i
        return 100 if limit <= 0
        [ limit, 500 ].min
      end
    end
  end
end
