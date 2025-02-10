# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProformaService::Import do
  describe '.new' do
    subject(:imported_task) { described_class.new(zip:, user:) }

    let(:zip) { Tempfile.new('proforma_test_zip_file') }
    let(:user) { build(:user) }

    it 'assigns zip' do
      expect(imported_task.instance_variable_get(:@zip)).to be zip
    end

    it 'assigns user' do
      expect(imported_task.instance_variable_get(:@user)).to be user
    end
  end

  describe '#execute' do
    subject(:imported_task) { described_class.call(zip: zip_file, user: import_user) }

    let(:user) { build(:user) }
    let(:import_user) { user }
    let(:zip_file) { Tempfile.new('proforma_test_zip_file', encoding: 'ascii-8bit') }
    let(:task) do
      create(:task,
        :with_content,
        programming_language:,
        meta_data:,
        files:,
        tests:,
        model_solutions:,
        uuid:,
        user:,
        submission_restrictions:,
        external_resources:,
        grading_hints:)
    end

    let(:uuid) {}
    let(:programming_language) { build(:programming_language, :ruby) }
    let(:meta_data) { {} }
    let(:submission_restrictions) {}
    let(:external_resources) {}
    let(:grading_hints) {}
    let(:files) { [] }
    let(:model_solutions) { [] }
    let(:tests) { [] }
    let(:exporter) { ProformaService::ExportTask.call(task: task.reload).string }

    before do
      zip_file.write(exporter)
      zip_file.rewind
      task.reload
    end

    it { is_expected.to be_an_equal_task_as task }

    it 'sets the uuid' do
      expect(imported_task.uuid).not_to be_blank
    end

    context 'when task is imported by a different user, but is admin' do
      let(:import_user) { build(:admin) }

      it 'does not overwrite existing owner' do
        expect(imported_task.user).to eql user
      end
    end

    context 'when no task exists' do
      before { task.destroy }

      it { is_expected.to be_valid }

      it 'sets the correct user as owner of the task' do
        expect(imported_task.user).to eq user
      end

      it 'sets the uuid' do
        expect(imported_task.uuid).not_to be_blank
      end

      context 'when task has a uuid' do
        let(:uuid) { SecureRandom.uuid }

        it 'sets the uuid' do
          expect(imported_task.uuid).to eql uuid
        end
      end
    end

    context 'when task has meta_data' do
      let(:meta_data) { attributes_for(:task, :with_meta_data)[:meta_data] }

      it 'sets the meta_data' do
        expect(imported_task.meta_data).to eql meta_data
      end
    end

    context 'when task has submission_restrictions' do
      let(:submission_restrictions) { attributes_for(:task, :with_submission_restrictions)[:submission_restrictions] }

      it 'sets the submission_restrictions' do
        expect(imported_task.submission_restrictions).to eql submission_restrictions
      end
    end

    context 'when task has external_resources' do
      let(:external_resources) { attributes_for(:task, :with_external_resources)[:external_resources] }

      it 'sets the external_resources' do
        expect(imported_task.external_resources).to eql external_resources
      end
    end

    context 'when task has grading_hints' do
      let(:grading_hints) { attributes_for(:task, :with_grading_hints)[:grading_hints] }

      it 'sets the grading_hints' do
        expect(imported_task.grading_hints).to eql grading_hints
      end
    end

    context 'when task has a file' do
      let(:files) { [file] }
      let(:file) { build(:task_file, :exportable) }

      it { is_expected.to be_an_equal_task_as task }

      context 'when the mainfile is very large' do
        let(:file) { build(:task_file, :exportable, content: 'test' * (10**5)) }

        it { is_expected.to be_an_equal_task_as task }
      end

      context 'when file has an attachment' do
        let(:file) { build(:task_file, :exportable, :with_attachment, mime_type: 'image/bmp') }

        it { is_expected.to be_an_equal_task_as task }
      end
    end

    context 'when task has a model_solution' do
      let(:model_solutions) { build_list(:model_solution, 1, files: build_list(:task_file, 1, :exportable)) }

      it { is_expected.to be_an_equal_task_as task }
    end

    context 'when task has multiple files with role reference implementation' do
      let(:model_solutions) { [model_solution, model_solution2] }
      let(:model_solution) { build(:model_solution, :with_content, files: build_list(:task_file, 1, :exportable)) }
      let(:model_solution2) { build(:model_solution, :with_content, files: build_list(:task_file, 1, :exportable)) }

      it { is_expected.to be_an_equal_task_as task }
    end

    context 'when task has a test' do
      let(:tests) { build_list(:test, 1, :with_content, meta_data: test_meta_data, configuration: test_configuration) }
      let(:test_meta_data) {}
      let(:test_configuration) {}

      it { is_expected.to be_an_equal_task_as task }

      context 'when test has meta_data' do
        let(:test_meta_data) { attributes_for(:test, :with_meta_data)[:meta_data] }

        it 'sets the meta_data' do
          expect(imported_task.tests.first.meta_data).to eql test_meta_data
        end
      end

      context 'when test has configuration' do
        let(:test_configuration) do
          attributes_for(:test, :with_unittest)[:unittest]
        end

        it 'sets the configuration' do
          expect(imported_task.tests.first.configuration).to eql test_configuration
        end
      end
    end

    context 'when task has multiple tests' do
      let(:tests) { build_list(:test, 2, :with_content) }

      it { is_expected.to be_an_equal_task_as task }
    end

    context 'when zip contains multiple tasks' do
      let(:exporter) { ProformaService::ExportTasks.call(tasks: [task, task2]).string }

      let(:task2) do
        create(:task,
          programming_language:,
          files: [],
          tests: [],
          user:)
      end

      before { task2.reload }

      it 'imports the tasks from zip containing multiple zips' do
        expect(imported_task).to all be_an(Task)
      end

      it 'imports the zip exactly how they were exported' do
        expect(imported_task).to all be_an_equal_task_as(task).or be_an_equal_task_as(task2)
      end

      context 'when a task has files and tests' do
        let(:files) { build_list(:task_file, 2, :exportable) }
        let(:tests) { build_list(:test, 2, test_type: 'test_type') }

        it 'imports the zip exactly how the were exported' do
          expect(imported_task).to all be_an_equal_task_as(task).or be_an_equal_task_as(task2)
        end
      end
    end

    context 'when task in zip has a different uuid' do
      let(:uuid) { SecureRandom.uuid }
      let(:new_uuid) { SecureRandom.uuid }

      before do
        task.update(uuid: new_uuid)
      end

      it 'creates a new task' do
        expect(imported_task.id).not_to be task.id
      end
    end

    context 'when task in zip has the same uuid and nothing has changed' do
      let(:uuid) { SecureRandom.uuid }

      it 'updates the old task' do
        expect(imported_task.id).to be task.id
      end

      context 'when another user imports the task' do
        let(:import_user) { create(:user) }

        it 'creates a new task' do
          expect(imported_task.id).not_to be task.id
        end
      end
    end
  end
end
