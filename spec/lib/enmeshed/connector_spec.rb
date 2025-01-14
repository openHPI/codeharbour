# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enmeshed::Connector do
  let(:connector) { described_class }
  let(:connector_api_url) { "#{Settings.dig(:omniauth, :nbp, :enmeshed, :connector_url)}/api/v2" }

  before do
    allow(User).to receive(:omniauth_providers).and_return([:nbp])
  end

  describe '.parse_result' do
    let(:response) { Faraday::Response.new(body:) }
    let(:body) { '{"result": {"foo": "bar"}}' }

    before do
      # Stub the parse_enmeshed_object method and just return the JSON.
      allow(connector).to receive(:parse_enmeshed_object) {|json, _klass| json }
    end

    it 'returns the parsed JSON' do
      expect(connector.send(:parse_result, response, Enmeshed::Object)).to eq(foo: 'bar')
    end

    it 'calls parse_enmeshed_object' do
      expect(connector).to receive(:parse_enmeshed_object).with({foo: 'bar'}, Enmeshed::Object)
      connector.send(:parse_result, response, Enmeshed::Object)
    end

    context 'when the response is not successful' do
      let(:body) { '{"error": {"message": "foobar"}}' }

      it 'raises an error' do
        expect { connector.send(:parse_result, response, Enmeshed::Object) }.to raise_error(Enmeshed::ConnectorError)
      end

      it 'does not call parse_enmeshed_object' do
        expect(connector).not_to receive(:parse_enmeshed_object)
        begin
          connector.send(:parse_result, response, Enmeshed::Object)
        rescue Enmeshed::ConnectorError
          # Ignored
        end
      end
    end

    context 'when an invalid JSON is returned' do
      let(:body) { '"invalid{' }

      it 'raises an error' do
        expect { connector.send(:parse_result, response, Enmeshed::Object) }.to raise_error(Enmeshed::ConnectorError)
      end

      it 'does not call parse_enmeshed_object' do
        expect(connector).not_to receive(:parse_enmeshed_object)
        begin
          connector.send(:parse_result, response, Enmeshed::Object)
        rescue Enmeshed::ConnectorError
          # Ignored
        end
      end
    end
  end

  describe '.connection' do
    it 'returns a Faraday connection' do
      expect(connector.send(:connection)).to be_a(Faraday::Connection)
    end

    context 'when the config is invalid' do
      before do
        # Un-memoize the connection to re-read the config
        connector.instance_variable_set(:@connection, nil)
        allow(User).to receive(:omniauth_providers).and_return([])
      end

      it 'raises an error' do
        expect { connector.send(:connection) }.to raise_error(Enmeshed::ConnectorError)
      end
    end
  end

  describe '.enmeshed_address' do
    subject(:enmeshed_address) { connector.enmeshed_address }

    before do
      stub_request(:get, "#{connector_api_url}/Account/IdentityInfo")
        .to_return(body: file_fixture('enmeshed/get_enmeshed_address.json'))
    end

    it 'returns the parsed address' do
      expect(enmeshed_address).to eq 'id_of_an_example_enmeshed_address_AB'
    end
  end

  describe '.create_relationship_template' do
    subject(:create_relationship_template) { connector.create_relationship_template(relationship_template) }

    let(:relationship_template) { instance_double(Enmeshed::RelationshipTemplate) }

    before do
      stub_request(:post, "#{connector_api_url}/RelationshipTemplates/Own")
        .to_return(body: file_fixture('enmeshed/relationship_template_created.json'))
    end

    it 'returns the truncated reference of the RelationshipTemplate' do
      expect(create_relationship_template).to eq 'RelationshipTemplateExampleTruncatedReferenceA=='
    end
  end

  describe '.pending_relationships' do
    subject(:pending_relationships) { connector.pending_relationships }

    before do
      stub_request(:get, "#{connector_api_url}/Relationships?status=Pending")
        .to_return(body: file_fixture('enmeshed/valid_relationship_created.json'))
    end

    it 'returns a parsed relationship' do
      expect(pending_relationships.first).to be_an Enmeshed::Relationship
    end
  end

  describe '.respond_to_rel_change' do
    subject(:respond_to_rel_change) { connector.respond_to_rel_change(relationship_id, change_id) }

    let(:accept_request_stub) { stub_request(:put, "#{connector_api_url}/Relationships/#{relationship_id}/Changes/#{change_id}/Accept") }

    let(:relationship_id) { 'RELoi9IL4adMbj92K8dn' }
    let(:change_id) { 'RCHNFJ9JD2LayPxn79nO' }

    context 'with a successful response' do
      before do
        accept_request_stub
      end

      it 'is true' do
        expect(respond_to_rel_change).to be_truthy
      end
    end

    context 'with a failed response' do
      before do
        accept_request_stub.to_return(status: 500)
      end

      it 'is false' do
        expect(respond_to_rel_change).to be false
      end
    end
  end

  context 'when the connector is down' do
    before { stub_request(:get, "#{connector_api_url}/Relationships?status=Pending").and_timeout }

    it 'raises an error' do
      expect { connector.pending_relationships }.to raise_error(Faraday::ConnectionFailed)
    end
  end
end
