# frozen_string_literal: true

module ProformaService
  class ConvertProformaTaskToTask < ServiceBase
    def initialize(proforma_task:, user:, task: nil)
      super()
      @proforma_task = proforma_task
      @user = user
      @task = task || Task.new
      @file_xml_ids = []
    end

    def execute
      ActiveRecord::Base.transaction do
        import_task
      end
      @task
    end

    private

    def import_task
      @task.assign_attributes(
        user:,
        title: @proforma_task.title,
        description:,
        internal_description: @proforma_task.internal_description,
        programming_language:,
        uuid:,
        parent_uuid:,
        language: @proforma_task.language,
        meta_data: @proforma_task.meta_data,

        submission_restrictions: @proforma_task.submission_restrictions,
        external_resources: @proforma_task.external_resources,
        grading_hints: @proforma_task.grading_hints
      )
      Pundit.authorize @user, @task, :create?

      @task.save!

      manage_objects
    end

    def manage_objects
      # delete files that do not exist in imported task
      unreferenced_files.each(&:destroy)
      @task.reload
      # Move only relocated files to the task, avoiding updates to the updated_at of untouched files.
      move_relocated_files_to_task
      set_tests
      set_model_solutions

      @task.reload
      upsert_files @proforma_task, @task
      delete_removed_objects
      @task.save!
    end

    def move_relocated_files_to_task
      @task.files = @task.all_files(cached: false).filter do |file|
        # Move files to the task if they belong directly to it or if the parent's xml_id differs from the current parent's xml_id.
        parent_id(file.xml_id) == 'task' || (file.fileable.respond_to?(:xml_id) && file.fileable.xml_id) != parent_id(file.xml_id)
      end
    end

    def parent_id(xml_id)
      [@proforma_task, *@proforma_task.model_solutions, *@proforma_task.tests].find do |object|
        object.files.any? {|file| file.id == xml_id }
      end.then {|object| object.respond_to?(:id) ? object.id : 'task' }
    end

    def all_proforma_files
      [@proforma_task.files + @proforma_task.tests.map(&:files) + @proforma_task.model_solutions.map(&:files)].flatten
    end

    def unreferenced_files
      @task.all_files.reject do |f|
        all_proforma_files.map {|pf| pf.id.to_s }.include?(f.xml_id)
      end
    end

    def parent_uuid
      @proforma_task.parent_uuid || @task.parent_uuid
    end

    def user
      @task.user || @user
    end

    def uuid
      @task.uuid || @proforma_task.uuid
    end

    def description
      Kramdown::Document.new(@proforma_task.description || '', html_to_native: true, line_width: -1).to_kramdown.strip
    end

    def upsert_files(collection, fileable)
      collection.files.map {|task_file| upsert_file_from_proforma_file(task_file, fileable) }
    end

    def upsert_file_from_proforma_file(proforma_task_file, fileable)
      task_file = (@file_xml_ids.exclude?(proforma_task_file.id) && ch_record_for(@task.all_files, proforma_task_file.id)) || TaskFile.new
      task_file.assign_attributes(file_attributes(proforma_task_file, fileable))
      attach_file_content(proforma_task_file, task_file)
      task_file
    end

    def attach_file_content(proforma_task_file, task_file)
      if proforma_task_file.binary
        task_file.attachment.attach(
          io: StringIO.new(proforma_task_file.content),
          filename: proforma_task_file.filename,
          content_type: proforma_task_file.mimetype
        )
        task_file.use_attached_file = 'true'
      else
        task_file.content = proforma_task_file.content
        task_file.use_attached_file = 'false'
      end
    end

    def xml_file_id(xml_id)
      return xml_id unless @file_xml_ids.include?(xml_id)

      offset = 2
      offset += 1 while @file_xml_ids.include?("#{xml_id}-#{offset}")
      "#{xml_id}-#{offset}"
    end

    def file_attributes(proforma_task_file, fileable)
      xml_id = xml_file_id proforma_task_file.id
      @file_xml_ids << xml_id
      {
        full_file_name: proforma_task_file.filename,
        internal_description: proforma_task_file.internal_description,
        used_by_grader: proforma_task_file.used_by_grader,
        visible: proforma_task_file.visible,
        usage_by_lms: proforma_task_file.usage_by_lms,
        mime_type: proforma_task_file.mimetype,
        xml_id:,
        fileable:,
      }
    end

    def set_tests
      @proforma_task.tests.each do |test|
        ch_test = find_or_initialize_ch_test test
        ch_test.task = @task
        upsert_files test, ch_test
        ch_test.assign_attributes(
          title: test.title,
          description: test.description,
          internal_description: test.internal_description,
          test_type: test.test_type,
          meta_data: test.meta_data,
          configuration: test.configuration
        )
        ch_test.save!
      end
    end

    def find_or_initialize_ch_test(test)
      ch_record_for(@task.tests, test.id) || Test.new(xml_id: test.id)
    end

    def programming_language # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      proglang_name = @proforma_task.proglang&.dig(:name).try(:downcase)
      proglang_version = @proforma_task.proglang&.dig(:version).try(:downcase)&.to_s
      return @task.programming_language if proglang_name.nil? || proglang_version.nil?

      ProgrammingLanguage.where('LOWER(language) = ? AND LOWER(version) = ?', proglang_name, proglang_version).first_or_initialize do |pl|
        pl.language = @proforma_task.proglang&.dig(:name)
        pl.version = @proforma_task.proglang&.dig(:version)
      end
    end

    def set_model_solutions
      @proforma_task.model_solutions.each do |model_solution|
        ch_model_solution = ch_record_for(@task.model_solutions, model_solution.id) || ModelSolution.new(xml_id: model_solution.id)
        ch_model_solution.task = @task
        upsert_files model_solution, ch_model_solution
        ch_model_solution.assign_attributes(
          description: model_solution.description,
          internal_description: model_solution.internal_description
        )
        ch_model_solution.save!
      end
    end

    def ch_record_for(collection, xml_id)
      collection.select {|record| record.xml_id == xml_id }&.first
    end

    def delete_removed_objects
      delete_removed_tests
      delete_removed_model_solutions
    end

    def delete_removed_tests
      remaining_test_ids = @proforma_task.tests.map {|t| t.id.to_s }
      @task.tests.reject {|test| remaining_test_ids.include? test.xml_id }.each(&:destroy)
    end

    def delete_removed_model_solutions
      remaining_model_solution_ids = @proforma_task.model_solutions.map {|ms| ms.id.to_s }
      @task.model_solutions.reject {|model_solution| remaining_model_solution_ids.include? model_solution.xml_id }.each(&:destroy)
    end
  end
end
