module Api
  module V1
    class AnalyticsController < ApplicationController
      def show
        render json: Analytics::AnalyticsReport.new.build
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end
