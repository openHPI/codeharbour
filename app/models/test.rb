# frozen_string_literal: true

class Test < ApplicationRecord
  include FileConcern
  include TransferValues
  include ParentValidation

  belongs_to :task, inverse_of: :tests
  belongs_to :testing_framework, optional: true
  belongs_to :parent, class_name: 'Test', optional: true
  validates :title, presence: true
  validates :xml_id, presence: true
  validates :parent_id, uniqueness: {scope: :task}, if: -> { parent_id.present? }
  validate :parent_validation_check
  validate :unique_xml_id, if: -> { !task.nil? && xml_id_changed? }

  def configuration_as_xml
    Dachsfisch::JSON2XMLConverter.perform(json: configuration.to_json)
  end

  def duplicate(set_parent_id: true)
    dup.tap do |test|
      test.files = files.map {|file| file.duplicate(set_parent_id:) }
      if set_parent_id
        test.parent_id = id
      end
    end
  end

  private

  def unique_xml_id
    xml_ids = (task.tests - [self]).map(&:xml_id)
    errors.add(:xml_id, :not_unique) if xml_ids.include? xml_id
  end
end
