# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TaskService::PushExternal do
  describe '.new' do
    subject(:push_external) { described_class.new(zip:, account_link:) }

    let(:zip) { ProformaService::ExportTask.call(task: build(:task)) }
    let(:account_link) { build(:account_link) }

    it 'assigns zip' do
      expect(push_external.instance_variable_get(:@zip)).to be zip
    end

    it 'assigns account_link' do
      expect(push_external.instance_variable_get(:@account_link)).to be account_link
    end
  end

  describe '#execute' do
    subject(:push_external) { described_class.call(zip:, account_link:) }

    let(:zip) { ProformaService::ExportTask.call(task: build(:task)) }
    let(:account_link) { build(:account_link) }
    let(:status) { 200 }
    let(:response) { '' }

    before { stub_request(:post, account_link.push_url).to_return(status:, body: response) }

    it 'calls the correct url' do
      expect(push_external).to have_requested(:post, account_link.push_url)
    end

    it 'submits the correct headers' do
      expect(push_external).to have_requested(:post, account_link.push_url)
        .with(headers: {content_type: 'application/zip',
                        authorization: "Bearer #{account_link.api_key}",
                        content_length: zip.string.length})
    end

    it 'submits the correct body' do
      expect(push_external).to have_requested(:post, account_link.push_url)
        .with(body: zip.string)
    end

    context 'when response status is success' do
      it { is_expected.to be_nil }

      context 'when response status is 500' do
        let(:status) { 500 }
        let(:response) { 'an error occured' }

        it { is_expected.to be response }
      end

      context 'when response status is 401' do
        let(:status) { 401 }
        let(:response) { I18n.t('tasks.export_external_confirm.not_authorized', account_link: account_link.name) }

        it { is_expected.to eq response }
      end
    end

    context 'when an error occurs' do
      before { allow(Faraday).to receive(:new).and_raise(StandardError) }

      it { is_expected.not_to be_nil }
    end
  end
end
