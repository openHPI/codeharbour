# frozen_string_literal: true

class ModelSolution < ApplicationRecord
  include FileConcern
  include TransferValues
  include ParentValidation

  belongs_to :task, inverse_of: :model_solutions
  belongs_to :parent, class_name: 'ModelSolution', optional: true
  has_many :files, as: :fileable, class_name: 'TaskFile', dependent: :destroy
  accepts_nested_attributes_for :files, allow_destroy: true
  validates :xml_id, presence: true
  validates :parent_id, uniqueness: {scope: :task}, if: -> { parent_id.present? }
  validate :parent_validation_check
  validate :unique_xml_id, if: -> { !task.nil? && xml_id_changed? }

  def duplicate(set_parent_id: true)
    dup.tap do |model_solution|
      model_solution.files = files.map {|file| file.duplicate(set_parent_id:) }
      if set_parent_id
        model_solution.parent_id = id
      end
    end
  end

  private

  def unique_xml_id
    xml_ids = (task.model_solutions - [self]).map(&:xml_id)
    errors.add(:xml_id, :not_unique) if xml_ids.include? xml_id
  end
end
