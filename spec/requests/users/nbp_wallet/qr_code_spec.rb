# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users::NBPWallet::QRCode' do
  subject(:qr_code_request) { get '/users/nbp_wallet/qr_code', params: {truncated_reference:} }

  let(:uid) { 'example-uid' }
  let(:session_params) { {saml_uid: uid, omniauth_provider: 'nbp'} }

  let(:truncated_reference) { 'example_truncated_reference' }
  let(:qr_code) { RQRCode::QRCode.new("nmshd://tr##{truncated_reference}").as_png(border_modules: 0) }
  let(:relationship_template) do
    instance_double(Enmeshed::RelationshipTemplate, qr_code:)
  end

  before do
    set_session(session_params)
    allow(Enmeshed::RelationshipTemplate).to receive(:new).with(truncated_reference:).and_return(relationship_template)
  end

  it 'returns a png image' do
    qr_code_request
    expect(response.content_type).to eq 'image/png'
  end

  it 'initializes a RelationshipTemplate' do
    expect(Enmeshed::RelationshipTemplate).to receive(:new)
    qr_code_request
  end

  it 'sends the qr code' do
    qr_code_request
    expect(response.body).to eq qr_code.to_s
  end

  context 'without the session' do
    let(:session_params) { {} }

    before do
      qr_code_request
    end

    it_behaves_like 'an unauthorized request'
  end
end
