# frozen_string_literal: true

require 'rqrcode'

module Users
  class NbpWalletController < ApplicationController
    skip_after_action :verify_authorized

    def connect
      if Enmeshed::Relationship.pending_for(@provider_uid).present?
        redirect_to nbp_wallet_finalize_users_path and return
      end

      @template = Enmeshed::RelationshipTemplate.create!(nbp_uid: @provider_uid)
    rescue Enmeshed::ConnectorError, Faraday::Error => e
      Sentry.capture_exception(e)
      Rails.logger.debug { e }
      redirect_to new_user_registration_path, alert: t('common.errors.generic_try_later')
    end

    def qr_code
      truncated_reference = params[:truncated_reference]
      send_data Enmeshed::RelationshipTemplate.new(truncated_reference:).qr_code, type: 'image/png'
    end

    def relationship_status
      if Enmeshed::Relationship.pending_for(@provider_uid).present?
        render json: {status: :ready}
      else
        render json: {status: :waiting}
      end
    rescue Enmeshed::ConnectorError, Faraday::Error => e
      Sentry.capture_exception(e)
      Rails.logger.debug { e }
      redirect_to nbp_wallet_connect_users_path, alert: t('common.errors.generic')
    end

    def finalize
      relationship = Enmeshed::Relationship.pending_for(@provider_uid)
      abort_and_refresh(relationship) and return if relationship.blank?

      accept_and_create_user(relationship)
    rescue Enmeshed::ConnectorError, Faraday::Error => e
      Sentry.capture_exception(e)
      Rails.logger.debug { e }
      abort_and_refresh(relationship)
    end

    private

    def accept_and_create_user(relationship) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      if relationship.userdata[:status_group].blank?
        abort_and_refresh(
          relationship,
          t('common.errors.model_not_created', model: User.model_name.human, errors: t('users.nbp_wallet.unrecognized_role'))
        ) and return
      end

      user = User.new_from_omniauth(relationship.userdata, 'nbp', @provider_uid)
      user.identities << UserIdentity.new(omniauth_provider: 'enmeshed', provider_uid: relationship.peer)
      user.skip_confirmation_notification!

      ApplicationRecord.transaction do
        unless user.save
          abort_and_refresh(
            relationship,
            t('common.errors.model_not_created', model: User.model_name.human, errors: user.errors.full_messages.join(', '))
          ) and raise ActiveRecord::Rollback
        end

        if relationship.accept!
          user.send_confirmation_instructions
          redirect_to home_index_path, notice: t('devise.registrations.signed_up_but_unconfirmed')
        else
          abort_and_refresh(relationship)
          raise ActiveRecord::Rollback
        end
      end
    end

    def abort_and_refresh(relationship, reason = t('common.errors.generic'))
      Rails.logger.debug { "NbpWalletController calling abort_and_refresh() due to: #{reason}" }
      relationship&.reject!
    rescue Enmeshed::ConnectorError, Faraday::Error => e
      # We still need to capture and handle an HTTP error caused by rejecting the template.
      Sentry.capture_exception(e)
      Rails.logger.debug { e }
    ensure
      redirect_to nbp_wallet_connect_users_path, alert: reason
    end

    def require_user!
      @provider_uid = session[:saml_uid]
      raise Pundit::NotAuthorizedError unless @provider_uid.present? && session[:omniauth_provider] == 'nbp'
    end
  end
end
