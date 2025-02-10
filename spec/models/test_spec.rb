# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Test do
  describe 'validations' do
    it { is_expected.to belong_to(:task) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:xml_id) }

    context 'when a task is created with multiple tests' do
      before { build(:task, tests: [test, build(:test, xml_id: 'same')]) }

      let(:test) { build(:test, xml_id: 'same') }

      it 'validates xml_id correctly' do
        test.validate
        expect(test.errors.full_messages).to include "#{described_class.human_attribute_name('xml_id')} #{I18n.t('activerecord.errors.messages.not_unique')}"
      end
    end

    it_behaves_like 'parent validation with parent_id', :test
  end

  describe '#duplicate' do
    subject(:duplicate) { test.duplicate }

    let(:test) { create(:test, task: create(:task), files: build_list(:task_file, 2, :exportable)) }

    it 'creates a new test' do
      expect(duplicate).not_to be test
    end

    it 'has the same attributes' do
      expect(duplicate).to have_attributes(test.attributes.except('created_at', 'updated_at', 'id', 'fileable_id', 'parent_id'))
    end

    it 'creates new files' do
      expect(duplicate.files).not_to match_array test.files
    end

    it 'creates new files with the same attributes' do
      expect(duplicate.files).to match_array(test.files.map do |file|
                                               have_attributes(file.attributes.except('created_at', 'updated_at', 'id', 'fileable_id', 'parent_id'))
                                             end)
    end
  end

  describe '#transfer_multiple_entities' do
    it_behaves_like 'transfer multiple entities', described_class
    it_behaves_like 'transfer files', described_class
  end
end
