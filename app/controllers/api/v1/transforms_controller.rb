module Api
  module V1
    class TransformsController < ApplicationController
      def create
        payload = transform_params.to_h

        data = Transforms::Transformer.new.transform(payload)
        render json: data
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def transform_params
        params.permit(
          resourceTypes: [],
          transformations: [ :action, :field, :as ],
          filters: {}
        )
      end
    end
  end
end
