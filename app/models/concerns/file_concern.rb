# frozen_string_literal: true

module FileConcern
  extend ActiveSupport::Concern

  included do
    has_many :files, as: :fileable, class_name: 'TaskFile', dependent: :destroy, inverse_of: :fileable
    accepts_nested_attributes_for :files, allow_destroy: true
  end

  def files
    # We need to overwrite the `files` association method to allow moving files between the polymorphic associations.
    # In the default case, a moved file would still be associated with the old record until saved (despite a correct inverse relationship).
    # Therefore, we need to filter the files by the fileable type and only return those are belong to the current record.
    # To minimize the impact and still allow method chaining, we filter only files if the association is already loaded.
    # See https://github.com/openHPI/codeharbor/pull/1606 for more details.
    return super unless association(:files).loaded?

    association(:files).reader.records.filter {|file| file.fileable == self }
  end

  # For the transfer of files between two records, we need to overwrite the getter and setter methods for the files association.
  # We cannot use the `files` method defined above, since it would return a copy of the respective files as an array.
  # Hence, we define a dedicated getter and setter method for the files association used in the context of task contributions.
  def files_collection
    association(:files).reader
  end

  def files_collection=(files)
    association(:files).writer files
  end
end
