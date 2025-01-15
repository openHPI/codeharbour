# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Enmeshed::Relationship do
  let(:connector_api_url) { "#{Settings.dig(:omniauth, :nbp, :enmeshed, :connector_url)}/api/v2"}
  let(:json) do
    JSON.parse(file_fixture('enmeshed/valid_relationship_created.json').read,
               symbolize_names: true)[:result].first
  end
  let(:template) { Enmeshed::RelationshipTemplate.parse(json[:template]) }

  before do
    allow(User).to receive(:omniauth_providers).and_return([:nbp])
  end

  describe '.pending_for' do
    subject(:pending_for) { described_class.pending_for(nbp_uid) }

    let(:nbp_uid) { 'example_uid' }
    let(:reject_request_stub) { stub_request(:put, "#{connector_api_url}/Relationships/RELoi9IL4adMbj92K8dn/Changes/RCHNFJ9JD2LayPxn79nO/Reject") }

    before do
      stub_request(:get, "#{connector_api_url}/Relationships?status=Pending")
        .to_return(body: file_fixture('enmeshed/valid_relationship_created.json'))
    end

    it 'returns the pending relationship with the requested nbp_uid' do
      expect(pending_for.nbp_uid).to eq nbp_uid
    end

    it 'does not reject the relationship' do
      pending_for
      expect(reject_request_stub).not_to have_been_requested
    end

    context 'with an expired relationship' do
      before do
        stub_request(:get, "#{connector_api_url}/Relationships?status=Pending")
          .to_return(body: file_fixture('enmeshed/relationship_expired.json'))
        reject_request_stub
      end

      it 'rejects the relationship' do
        pending_for
        expect(reject_request_stub).to have_been_requested
      end

      it 'returns nothing' do
        expect(pending_for).to be_nil
      end
    end
  end

  describe '#accept!' do
    subject(:accept) { described_class.new(json:, template:, changes: json[:changes]).accept! }

    let(:json) { JSON.parse(file_fixture('enmeshed/valid_relationship_created.json').read, symbolize_names: true)[:result].first }
    let(:template) { Enmeshed::RelationshipTemplate.parse(json[:template]) }
    let(:accept_request_stub) { stub_request(:put, "#{connector_api_url}/Relationships/RELoi9IL4adMbj92K8dn/Changes/RCHNFJ9JD2LayPxn79nO/Accept") }

    before do
      accept_request_stub
    end

    it 'accepts' do
      expect(accept).to be_truthy
      expect(accept_request_stub).to have_been_requested
    end

    context 'without a RelationshipChange' do
      subject(:accept) { described_class.new(json:, template:, changes: []).accept! }

      it 'raises an error' do
        expect { accept }.to raise_error Enmeshed::ConnectorError
      end
    end
  end

  describe '#reject!' do
    subject(:reject) { described_class.new(json:, template:, changes: json[:changes]).reject! }

    let(:json) { JSON.parse(file_fixture('enmeshed/valid_relationship_created.json').read, symbolize_names: true)[:result].first }
    let(:template) { Enmeshed::RelationshipTemplate.parse(json[:template]) }
    let(:reject_request_stub) { stub_request(:put, "#{connector_api_url}/Relationships/RELoi9IL4adMbj92K8dn/Changes/RCHNFJ9JD2LayPxn79nO/Reject") }

    before do
      reject_request_stub
    end

    it 'rejects' do
      expect(reject).to be_truthy
      expect(reject_request_stub).to have_been_requested
    end
  end

  describe '#userdata' do
    subject(:userdata) { described_class.new(json:, template:, changes: json[:changes]).userdata }

    it 'returns the requested data' do
      expect(userdata).to eq({email: 'john.oliver@example103.org', first_name: 'john', last_name: 'oliver', :status_group => :educator})
    end

    context 'with a blank attribute' do
      before do
        json[:@type]
        json[:changes].first[:request][:content][:response][:items].last[:attribute][:value][:value] = ''
      end

      it 'raises an error' do
        expect { userdata }.to raise_error(Enmeshed::ConnectorError, 'AffiliationRole must not be empty')
      end
    end

    context 'with a missing attribute' do
      before do
        json[:changes].first[:request][:content][:response][:items].pop
      end

      it 'raises an error' do
        expect { userdata }.to raise_error(Enmeshed::ConnectorError, 'AffiliationRole must not be empty')
      end
    end

    context 'with more than one RelationshipChange' do
      before do
        json[:changes] += json[:changes]
      end

      it 'raises an error' do
        expect { userdata }.to raise_error(Enmeshed::ConnectorError, 'Relationship should have exactly one RelationshipChange')
      end
    end

    context 'without any provided attributes' do
      before do
        json[:changes].first[:request][:content][:response][:items] = nil
      end

      it 'raises an error' do
        expect { userdata }.to raise_error(Enmeshed::ConnectorError, "Could not parse userdata in relationship change: #{json[:changes].first}")
      end
    end
  end

  describe '#peer' do
    subject(:peer) { described_class.new(json:, template:, changes: json[:changes]).peer }

    it 'returns the peer id' do
      expect(peer).to eq 'id1EvvJ68x6wdHBwYrFTR31XtALHko9fnbyp'
    end
  end
end
