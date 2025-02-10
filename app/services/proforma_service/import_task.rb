# frozen_string_literal: true

module ProformaService
  class ImportTask < ServiceBase
    def initialize(proforma_task:, user:)
      super()
      @proforma_task = proforma_task
      @user = user
    end

    def execute
      ConvertProformaTaskToTask.call(proforma_task: @proforma_task, user: @user, task: base_task)
    end

    private

    def base_task
      task = Task.find_by(uuid: @proforma_task.uuid)
      if task
        return task if Pundit.policy(@user, task).manage?

        return Task.new(uuid: SecureRandom.uuid)
      end

      Task.new(uuid: @proforma_task.uuid || SecureRandom.uuid)
    end
  end
end
