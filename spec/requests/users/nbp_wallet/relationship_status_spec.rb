# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::NBPWallet::RelationshipStatus' do
  subject(:relationship_status_request) { get '/users/nbp_wallet/relationship_status' }

  let(:uid) { 'example-uid' }
  let(:session_params) { {saml_uid: uid, omniauth_provider: 'nbp'} }

  before do
    set_session(session_params)
  end

  context 'without errors' do
    context 'with a Relationship' do
      before { allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(Enmeshed::Relationship) }

      it 'returns a json with the ready status' do
        relationship_status_request
        expect(response.parsed_body['status']).to eq 'ready'
      end
    end

    context 'without a Relationship' do
      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return([])
      end

      it 'returns a json with the waiting status' do
        relationship_status_request
        expect(response.parsed_body['status']).to eq 'waiting'
      end
    end
  end

  context 'with errors' do
    # `Enmeshed::ConnectorError` is unknown until 'lib/enmeshed/connector.rb' is loaded, because it's defined there
    require 'enmeshed/connector'

    context 'without the session' do
      let(:session_params) { {} }

      before do
        relationship_status_request
      end

      it_behaves_like 'an unauthorized request'
    end

    context 'when the connector is down' do
      before { allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_raise(Faraday::ConnectionFailed) }

      it 'redirects to the connect page' do
        relationship_status_request
        expect(response).to redirect_to(nbp_wallet_connect_users_path)
      end
    end

    context 'with an error when parsing the connector response' do
      before { allow(Enmeshed::Connector).to receive(:pending_relationships).and_raise(Enmeshed::ConnectorError) }

      it 'redirects to the connect page' do
        relationship_status_request
        expect(response).to redirect_to(nbp_wallet_connect_users_path)
      end
    end
  end
end
