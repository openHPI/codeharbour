# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enmeshed::RelationshipTemplate do
  let(:connector_api_url) { "#{Settings.omniauth.nbp.enmeshed.connector_url}/api/v2" }
  let(:get_relationship_templates_stub) { stub_request(:get, "#{connector_api_url}/RelationshipTemplates?isOwn=true") }

  before do
    allow(User).to receive(:omniauth_providers).and_return([:nbp])
  end

  describe '.create!' do
    subject(:new_template) { described_class.create!(nbp_uid: 'example_uid') }

    before do
      allow(Enmeshed::Connector).to receive(:create_relationship_template)
                                      .and_return('RelationshipTemplateExampleTruncatedReferenceA==')
    end

    it 'sets the truncated reference' do
      new_template
      expect(Enmeshed::Connector).to have_received(:create_relationship_template)
      expect(new_template.truncated_reference).to eq 'RelationshipTemplateExampleTruncatedReferenceA=='
    end
  end

  describe '.display_name_attribute' do
    subject(:display_name_attribute) { described_class.display_name_attribute }

    before do
      stub_request(:get, "#{connector_api_url}/Account/IdentityInfo")
        .to_return(body: file_fixture('enmeshed/get_enmeshed_address.json'))
    end

    context 'with a cached display name' do
      before do
        identity_attribute = Enmeshed::Attribute::Identity.new(type: 'DisplayName', value: 'cached_display_name')
        identity_attribute.instance_variable_set(:@id, 'cached_id')
        Enmeshed::RelationshipTemplate.instance_variable_set(:@display_name_attribute, identity_attribute)
      end

      after do
        Enmeshed::RelationshipTemplate.instance_variable_set(:@display_name_attribute, nil)
      end

      it 'does not set a new display name id' do
        expect(display_name_attribute.id).to eq('cached_id')
      end
    end

    context 'without a cached display name' do
      before do
        Enmeshed::RelationshipTemplate.instance_variable_set(:@display_name_attribute, nil)
      end

      context 'with an existing display name' do
        before do
          stub_request(:get, "#{connector_api_url}/Attributes?content.@type=IdentityAttribute&content.owner=id_of_an_example_enmeshed_address_AB&content.value.@type=DisplayName")
            .to_return(body: file_fixture('enmeshed/existing_display_name.json'))
        end

        it 'returns the id of the existing attribute' do
          expect(display_name_attribute.id).to eq 'ATT_id_of_exist_name'
        end
      end

      context 'with no existing display name' do
        before do
          stub_request(:get, "#{connector_api_url}/Attributes?content.@type=IdentityAttribute&content.owner=id_of_an_example_enmeshed_address_AB&content.value.@type=DisplayName")
            .to_return(body: file_fixture('enmeshed/no_existing_display_name.json'))
          stub_request(:post, "#{connector_api_url}/Attributes")
            .to_return(body: file_fixture('enmeshed/display_name_created.json'))
        end

        it 'returns the id of a new attribute' do
          expect(display_name_attribute.id).to eq 'ATT_id_of_a_new_name'
        end
      end
    end
  end

  describe '#initialize' do
    it 'raises an error if neither a truncated reference nor a NBP UID is given' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    context 'when a truncated reference is given' do
      subject(:new_template) { described_class.new(truncated_reference:) }

      let(:truncated_reference) { 'RelationshipTemplateExampleTruncatedReferenceA==' }

      it 'populates the object with the given attribute' do
        expect(new_template.truncated_reference).to eq truncated_reference
      end

      it 'does not fetch the existing template' do
        expect(new_template.nbp_uid).to be_nil
      end

      context 'when fetching details is enabled' do
        subject(:new_template) { described_class.fetch(truncated_reference) }

        before do
          stub_request(:get, "#{connector_api_url}/RelationshipTemplates?isOwn=true")
            .to_return(body: file_fixture('enmeshed/relationship_template.json'))
        end

        it 'populates the object with the given attribute' do
          expect(new_template.truncated_reference).to eq truncated_reference
        end

        it 'fetches the existing template' do
          expect(new_template.nbp_uid).to eq 'example_uid'
        end

        context 'when no relationship template was found' do
          before do
            get_relationship_templates_stub.to_return(body: file_fixture('enmeshed/no_relationship_templates_yet.json'))
          end

          it 'populates the object with the given attribute' do
            expect(new_template.truncated_reference).to eq truncated_reference
          end

          it 'does not throw an error' do
            expect { new_template.nbp_uid }.not_to raise_error
          end

          it 'returns nil for the unavailable attributes' do
            expect(new_template.nbp_uid).to be_nil
          end
        end

        context 'when the connector is down' do
          before { get_relationship_templates_stub.to_timeout }

          it 'raises an error' do
            expect { new_template }.to raise_error(Faraday::ConnectionFailed)
          end
        end
      end
    end
  end

  describe '#app_store_link' do
    subject(:app_store_link) { described_class.new(nbp_uid: 'example_uid').app_store_link }

    it 'returns the app store link' do
      expect(app_store_link).to eq Settings.dig(:omniauth, :nbp, :enmeshed, :app_store_link)
    end
  end

  describe '#play_store_link' do
    subject(:play_store_link) { described_class.new(nbp_uid: 'example_uid').play_store_link }

    it 'returns the app store link' do
      expect(play_store_link).to eq Settings.dig(:omniauth, :nbp, :enmeshed, :play_store_link)
    end
  end

  describe '#qr_code' do
    subject(:qr_code) do
      described_class.new(truncated_reference: 'RelationshipTemplateExampleTruncatedReferenceA==').qr_code
    end

    it 'returns the QR code' do
      expect(qr_code).to be_an_instance_of ChunkyPNG::Image
    end
  end

  describe '#qr_code_path' do
    subject(:qr_code_path) do
      described_class.new(truncated_reference: 'RelationshipTemplateExampleTruncatedReferenceA==').qr_code_path
    end

    it 'returns a link to the platforms qr code view action' do
      expect(qr_code_path).to eq '/users/nbp_wallet/qr_code' \
                                   '?truncated_reference=RelationshipTemplateExampleTruncatedReferenceA%3D%3D'
    end
  end

  describe '#remaining_validity' do
    subject(:remaining_validity) { described_class.new(nbp_uid: 'example_uid').remaining_validity }

    it 'returns the remaining time the template is valid' do
      expect(remaining_validity).to be_within(1.second).of(12.hours.to_i)
    end
  end


  describe '#to_json' do
    subject(:template) { described_class.new(truncated_reference: 'example_truncated_reference') }

    before do
      stub_request(:get, "#{connector_api_url}/Account/IdentityInfo")
        .to_return(body: file_fixture('enmeshed/get_enmeshed_address.json'))

      stub_request(:get, "#{connector_api_url}/Attributes?content.@type=IdentityAttribute&content.owner=id_of_an_example_enmeshed_address_AB&content.value.@type=DisplayName")
        .to_return(body: file_fixture('enmeshed/existing_display_name.json'))
    end

    context 'when certificate requests are enabled' do
      before do
        allow(Settings).to receive(:dig).with(:omniauth, :nbp, :enmeshed, :allow_certificate_request).and_return(true)
      end

      it 'returns the expected JSON' do
        expect(described_class).to receive(:allow_certificate_request).and_call_original
        expect(template.to_json).to include('CreateAttributeRequestItem', 'ShareAttributeRequestItem', 'ReadAttributeRequestItem')
      end
    end

    context 'when certificate requests are not enabled' do
      before do
        allow(Settings).to receive(:dig).with(:omniauth, :nbp, :enmeshed, :allow_certificate_request).and_return(false)
      end

      it 'returns the expected JSON' do
        expect(described_class).not_to receive(:allow_certificate_request)
        expect(template.to_json).not_to include('CreateAttributeRequestItem')
        expect(template.to_json).to include('ShareAttributeRequestItem', 'ReadAttributeRequestItem')
      end
    end
  end
end
