# frozen_string_literal: true

module Api
  module V1
    class RotkiController < Api::V1::BaseController
      before_action :ensure_read_scope, only: [:balances]
      before_action :ensure_write_scope, only: [:connect, :disconnect]
      before_action :validate_password, only: [:connect]

      def balances
        unless current_resource_owner.rotki_configured?
          return render_json(
            { error: "not_configured", message: "Rotki is not configured for this user" },
            status: :precondition_required
          )
        end

        balances_data = Rotki::BalanceCache.new.get_balances(current_resource_owner)
        mapper = Rotki::Mapper.new

        render json: {
          net_worth: mapper.calculate_net_worth(balances_data),
          balances: mapper.map_balances(balances_data),
          cached_at: Time.current.iso8601
        }
      rescue Rotki::RotkiServiceError => e
        Rails.logger.error "RotkiController#balances error: #{e.message}"
        render_json(
          { error: "rotki_error", message: "Unable to fetch balances from Rotki" },
          status: :service_unavailable
        )
      rescue => e
        Rails.logger.error "RotkiController#balances error: #{e.message}"
        render_json(
          { error: "internal_error", message: "An unexpected error occurred" },
          status: :internal_server_error
        )
      end

      def connect
        result = current_resource_owner.authenticate_with_rotki!(
          params[:username],
          params[:password]
        )

        render json: { status: "connected", message: result["message"] }.compact
      rescue RotkiUserConcern::RotkiConnectionError => e
        Rails.logger.error "RotkiController#connect error: #{e.message}"
        render_json(
          { error: "connection_failed", message: "Unable to connect to Rotki. Please check your credentials." },
          status: :unprocessable_entity
        )
      rescue => e
        Rails.logger.error "RotkiController#connect error: #{e.message}"
        render_json(
          { error: "connection_failed", message: "An unexpected error occurred" },
          status: :internal_server_error
        )
      end

      def disconnect
        if current_resource_owner.disconnect_rotki!
          render json: { status: "disconnected" }
        else
          render_json(
            { error: "disconnect_failed", message: "Unable to disconnect from Rotki" },
            status: :unprocessable_entity
          )
        end
      rescue => e
        Rails.logger.error "RotkiController#disconnect error: #{e.message}"
        render_json(
          { error: "disconnect_failed", message: "An unexpected error occurred" },
          status: :internal_server_error
        )
      end

      private

      def ensure_read_scope
        authorize_scope!(:read)
      end

      def ensure_write_scope
        authorize_scope!(:write)
      end

      def validate_password
        password = params[:password]

        if password.blank?
          return render_json(
            { error: "validation_error", message: "Password is required" },
            status: :unprocessable_entity
          )
        end

        if password.length < 6
          return render_json(
            { error: "validation_error", message: "Password must be at least 6 characters" },
            status: :unprocessable_entity
          )
        end

        if params[:username].blank?
          return render_json(
            { error: "validation_error", message: "Username is required" },
            status: :unprocessable_entity
          )
        end
      end
    end
  end
end