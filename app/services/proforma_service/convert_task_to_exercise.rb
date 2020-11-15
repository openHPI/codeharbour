# frozen_string_literal: true

module ProformaService
  class ConvertTaskToExercise < ServiceBase
    def initialize(task:, user:, exercise:)
      @task = task
      @user = user
      @exercise = exercise || Exercise.new
    end

    def execute
      import_exercise
      @exercise
    end

    private

    def import_exercise
      @exercise.assign_attributes(
        user: @user,
        title: @task.title,
        private: @exercise.private.nil? ? true : @exercise.private,
        descriptions: new_descriptions,
        instruction: @task.internal_description,
        execution_environment: execution_environment,
        tests: tests,
        exercise_files: task_files.values,
        state_list: @exercise.persisted? ? 'updated' : 'new',
        deleted: false
      )
    end

    def new_descriptions
      descriptions = @exercise.descriptions.presence || [Description.new(primary: true)]
      primary = descriptions.select(&:primary?).first
      primary.assign_attributes(text: transform_description(@task.description), language: @task.language)
      descriptions
    end

    def transform_description(description)
      Kramdown::Document.new(description || '', html_to_native: true).to_kramdown.strip
    end

    def task_files
      @task_files ||= Hash[
        @task.all_files.reject { |file| file.id == 'ms-placeholder-file' }.map do |task_file|
          [task_file.id, exercise_file_from_task_file(task_file)]
        end
      ]
    end

    def exercise_file_from_task_file(task_file)
      exercise_file = ExerciseFile.new({
                                         full_file_name: task_file.filename,
                                         read_only: read_only(task_file),
                                         hidden: task_file.visible != 'yes',
                                         role: role(task_file)
                                       })
      if task_file.binary
        exercise_file.attachment.attach(io: StringIO.new(task_file.content), filename: task_file.filename, content_type: task_file.mimetype)
      else
        exercise_file.content = task_file.content unless task_file.binary
      end
      exercise_file
    end

    def read_only(task_file)
      task_file.usage_by_lms.in?(%w[display download])
    end

    def role(task_file)
      model_solution_files.include?(task_file) ? 'reference_implementation' : task_file.internal_description
    end

    def tests
      @task.tests.select { |proforma_test| proforma_test.files.count.positive? }.map do |test_object|
        Test.new(
          exercise_file: test_file(test_object)
        ).tap do |test|
          if test_object.meta_data
            test.feedback_message = test_object.meta_data['feedback-message']
            test.testing_framework = testing_framework(test_object)
          end
        end
      end
    end

    def testing_framework(test_object)
      TestingFramework.where(
        name: test_object.meta_data['testing-framework'],
        version: test_object.meta_data['testing-framework-version']
      ).first_or_initialize
    end

    def test_file(test_object)
      file = test_object.files.first
      entry_point = test_object.configuration&.dig('entry-point')
      file = test_object.files.select { |f| f.filename == entry_point }.first || file if entry_point.present?

      hide_unused_test_files(file, test_object)

      task_files.delete(file.id).tap { |f| f.purpose = 'test' }
    end

    def hide_unused_test_files(file, test_object)
      test_object.files.reject { |f| f == file }.each { |f| f.visible = 'no' }
    end

    def execution_environment
      proglang_name = @task.proglang&.dig :name
      proglang_version = @task.proglang&.dig :version
      return @exercise.execution_environment if proglang_name.nil? || proglang_version.nil?

      ExecutionEnvironment.where(language: proglang_name, version: proglang_version).first_or_initialize
    end

    def model_solution_files
      @task.model_solutions.map(&:files).filter(&:present?).flatten
    end
  end
end
