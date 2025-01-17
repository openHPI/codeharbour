# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::NBPWallet::Finalize' do
  subject(:finalize_request) { get '/users/nbp_wallet/finalize' }

  let(:uid) { 'example-uid' }
  let(:session_params) { {saml_uid: uid, omniauth_provider: 'nbp'} }

  before do
    set_session(session_params)
  end

  context 'without any errors' do
    let(:relationship) do
      instance_double(Enmeshed::Relationship,
        accept!: true,
        userdata: {
          email: 'john.oliver@example103.org',
          first_name: 'john',
          last_name: 'oliver',
          status_group: 'learner',
        })
    end

    before do
      allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(relationship)
      allow(relationship).to receive(:peer).and_return('id1EvvJ68x6wdHBwYrFTR31XtALHko9fnbyp')
    end

    it 'creates a user' do
      expect { finalize_request }.to change(User, :count).by(1)
    end

    it 'creates two UserIdentities' do
      expect { finalize_request }.to change(UserIdentity, :count).by(2)
    end

    it 'accepts the Relationship' do
      expect(relationship).to receive(:accept!)
      finalize_request
    end

    it 'sends a confirmation mail' do
      expect { finalize_request }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it 'does not create a confirmed user' do
      finalize_request
      expect(User.order(:created_at).last).not_to be_confirmed
    end

    it 'asks the user to verify the email address' do
      finalize_request
      expect(response).to redirect_to home_index_path
      expect(flash[:notice]).to include I18n.t('devise.registrations.signed_up_but_unconfirmed')
    end
  end

  context 'with errors' do
    shared_examples 'a handled erroneous request' do |error_message|
      it 'does not create a user' do
        expect { finalize_request }.not_to change(User, :count)
      end

      it 'creates no UserIdentities' do
        expect { finalize_request }.not_to change(UserIdentity, :count)
      end

      it 'redirects to the connect page' do
        finalize_request
        expect(response).to redirect_to nbp_wallet_connect_users_path
      end

      it 'displays an error message' do
        finalize_request
        expect(flash[:alert]).to eq error_message
      end

      it 'does not send a confirmation mail' do
        expect { finalize_request }.not_to change(ActionMailer::Base, :deliveries)
      end
    end

    shared_examples 'a documented erroneous request' do |error|
      it 'passes the error reason to Sentry' do
        expect(Sentry).to receive(:capture_exception) do |e|
          expect(e).to be_a error
        end
        finalize_request
      end
    end

    context 'without the session' do
      let(:session_params) { {} }

      before do
        finalize_request
      end

      it_behaves_like 'an unauthorized request'
    end

    context 'when the connector is down' do
      before { allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_raise(Faraday::ConnectionFailed) }

      it 'redirects to the connect page' do
        finalize_request
        expect(response).to redirect_to(nbp_wallet_connect_users_path)
      end
    end

    context 'when an attribute is missing' do
      # `Enmeshed::ConnectorError` is unknown until 'lib/enmeshed/connector.rb' is loaded, because it's defined there
      require 'enmeshed/connector'

      let(:relationship) do
        instance_double(Enmeshed::Relationship, accept!: false, reject!: true)
      end

      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(relationship)
        allow(relationship).to receive(:userdata).and_raise(Enmeshed::ConnectorError, 'EMailAddress must not be empty')
      end

      it_behaves_like 'a handled erroneous request', I18n.t('common.errors.generic')
      it_behaves_like 'a documented erroneous request', Enmeshed::ConnectorError
    end

    context 'with an invalid status group' do
      let(:relationship) do
        instance_double(Enmeshed::Relationship,
          reject!: true,
          userdata: {
            email: 'john.oliver@example103.org',
            first_name: 'john',
            last_name: 'oliver',
            status_group: nil,
          })
      end

      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(relationship)
      end

      it_behaves_like 'a handled erroneous request', 'Could not create User: Unknown role. Please select either ' \
                                                     '"Teacher" or "Student" as your role.'
    end

    context 'when the User cannot be saved' do
      let(:relationship) do
        instance_double(Enmeshed::Relationship,
          reject!: true,
          userdata: {
            email: 'john.oliver@example103.org',
            first_name: 'john',
            last_name: 'oliver',
            status_group: 'learner',
          })
      end

      before do
        create(:user, email: relationship.userdata[:email])
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(relationship)
        allow(relationship).to receive(:peer).and_return('id1EvvJ68x6wdHBwYrFTR31XtALHko9fnbyp')
      end

      it_behaves_like 'a handled erroneous request', 'Could not create User: Email has already been taken'
    end

    context 'when the RelationshipChange cannot be accepted' do
      let(:relationship) do
        instance_double(Enmeshed::Relationship,
          accept!: false,
          reject!: true,
          userdata: {
            email: 'john.oliver@example103.org',
            first_name: 'john',
            last_name: 'oliver',
            status_group: 'learner',
          })
      end

      before do
        allow(Enmeshed::Relationship).to receive(:pending_for).with(uid).and_return(relationship)
        allow(relationship).to receive(:peer).and_return('id1EvvJ68x6wdHBwYrFTR31XtALHko9fnbyp')
      end

      it_behaves_like 'a handled erroneous request', I18n.t('common.errors.generic')

      it 'rejects the Relationship' do
        expect(relationship).to receive(:reject!)
        finalize_request
      end

      context 'when the RelationshipChange cannot be rejected either' do
        before { allow(relationship).to receive(:reject!).and_raise(Faraday::ConnectionFailed) }

        it_behaves_like 'a handled erroneous request', I18n.t('common.errors.generic')
        it_behaves_like 'a documented erroneous request', Faraday::ConnectionFailed

        it 'does not create a user' do
          expect { finalize_request }.not_to change(User, :count)
        end

        it 'creates no UserIdentities' do
          expect { finalize_request }.not_to change(UserIdentity, :count)
        end

        it 'does not try to reject the Relationship again' do
          expect(relationship).to receive(:reject!).once
          finalize_request
        end
      end
    end
  end
end
