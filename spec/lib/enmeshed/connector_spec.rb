# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enmeshed::Connector do
  let(:connector) { described_class }

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
    before do
      allow(User).to receive(:omniauth_providers).and_return([:nbp])
    end

    it 'returns a Faraday connection' do
      expect(connector.send(:connection)).to be_a(Faraday::Connection)
    end

    context 'when the config is invalid' do
      before do
        allow(User).to receive(:omniauth_providers).and_return([])
      end

      it 'raises an error' do
        expect { connector.send(:connection) }.to raise_error(Enmeshed::ConnectorError)
      end
    end
  end
end
