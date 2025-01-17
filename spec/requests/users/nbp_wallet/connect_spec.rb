# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::NBPWallet::Connect' do
  subject(:connect_request) { get '/users/nbp_wallet/connect' }

  let(:uid) { 'example-uid' }
  let(:session_params) { {saml_uid: uid, omniauth_provider: 'nbp'} }

  before do
    set_session(session_params)
  end

  context 'without errors' do
    context 'with a pending Relationship' do
      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(Enmeshed::Relationship)
      end

      it 'redirects to #finalize' do
        connect_request
        expect(response).to redirect_to nbp_wallet_finalize_users_path
      end
    end

    context 'without a pending Relationship' do
      let(:truncated_reference) { 'RelationshipTemplateExampleTruncatedReferenceA==' }
      let(:relationship_template) do
        instance_double(Enmeshed::RelationshipTemplate,
          expires_at: 12.hours.from_now,
          nbp_uid: uid,
          truncated_reference:,
          url: "nmshd://tr##{truncated_reference}",
          qr_code_path: nbp_wallet_qr_code_users_path(truncated_reference:),
          remaining_validity: 12.hours.from_now - Time.zone.now,
          app_store_link: Settings.dig(:omniauth, :nbp, :enmeshed, :app_store_link),
          play_store_link: Settings.dig(:omniauth, :nbp, :enmeshed, :play_store_link))
      end

      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return([])
        allow(Enmeshed::RelationshipTemplate).to receive(:create!).with(nbp_uid: uid).and_return(relationship_template)
      end

      it 'sets the correct template' do
        connect_request
        expect(response.body).to include 'RelationshipTemplateExampleTruncatedReferenceA=='
      end
    end
  end

  context 'with errors' do
    # `Enmeshed::ConnectorError` is unknown until 'lib/enmeshed/connector.rb' is loaded, because it's defined there
    require 'enmeshed/connector'

    shared_examples 'an erroneous request' do |error_type|
      it 'passes the error reason to Sentry' do
        expect(Sentry).to receive(:capture_exception) do |e|
          expect(e).to be_a error_type
        end
        connect_request
      end

      it 'redirects to #new_user_registration' do
        expect(connect_request).to redirect_to new_user_registration_path
      end

      it 'displays an error message' do
        connect_request
        expect(flash[:alert]).to include I18n.t('common.errors.generic_try_later')
      end
    end

    context 'without the session' do
      let(:session_params) { {} }

      before do
        connect_request
      end

      it_behaves_like 'an unauthorized request'
    end

    context 'when the connector is down' do
      before { allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_raise(Faraday::ConnectionFailed) }

      it_behaves_like 'an erroneous request', Faraday::Error
    end

    context 'with an error when parsing the connector response' do
      before { allow(Enmeshed::Connector).to receive(:pending_relationships).and_raise(Enmeshed::ConnectorError) }

      it_behaves_like 'an erroneous request', Enmeshed::ConnectorError
    end
  end
end
