# frozen_string_literal: true

module Api
  module V1
    class RotkiController < Api::V1::BaseController
      before_action :ensure_read_scope, only: [:balances]
      before_action :ensure_write_scope, only: [:connect]

      def balances
        balances_data = Rotki::BalanceCache.new.get_balances(current_resource_owner)
        mapper = Rotki::Mapper.new

        render json: {
          net_worth: mapper.calculate_net_worth(balances_data),
          balances: mapper.map_balances(balances_data),
          cached_at: Time.current
        }
      rescue RotkiServiceError => e
        Rails.logger.error "RotkiController#balances error: #{e.message}"
        render_json({ error: "rotki_error", message: "Unable to fetch balances from Rotki" }, status: :service_unavailable)
      rescue => e
        Rails.logger.error "RotkiController#balances error: #{e.message}"
        render_json({ error: "internal_error", message: "An unexpected error occurred" }, status: :internal_server_error)
      end

      def connect
        password = params.require(:password)
        current_resource_owner.authenticate_with_rotki!(password)
        render json: { status: "connected" }
      rescue RotkiServiceError => e
        Rails.logger.error "RotkiController#connect error: #{e.message}"
        render_json({ error: "connection_failed", message: "Unable to connect to Rotki. Please check your password." }, status: :unprocessable_entity)
      rescue => e
        Rails.logger.error "RotkiController#connect error: #{e.message}"
        render_json({ error: "connection_failed", message: "An unexpected error occurred" }, status: :internal_server_error)
      end

      private

      def ensure_read_scope
        authorize_scope!(:read)
      end

      def ensure_write_scope
        authorize_scope!(:write)
      end
    end
  end
end
