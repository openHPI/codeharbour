# frozen_string_literal: true

module Enmeshed
  class Attribute < Object
    delegate :enmeshed_address, to: Enmeshed::Connector

    attr_reader :owner, :type, :value

    def initialize(type:, value:, owner: enmeshed_address, singleton: true, id: nil)
      # Only subclasses of `Enmeshed::Attribute` should be instantiated
      @owner = owner
      @singleton = singleton
      @type = type
      @value = value
      @id = id
    end

    def self.parse(content)
      super

      attribute_type = content.dig(:content, :@type)
      desired_klass = descendants.find {|descendant| descendant.klass == attribute_type }
      raise ConnectorError.new("Unknown attribute type: #{attribute_type}") unless desired_klass

      attributes = {
        id: content[:id],
        owner: content.dig(:content, :owner),
        key: content.dig(:content, :key), # only for RelationshipAttributes
        type: content.dig(:content, :value, :@type),
        value: content.dig(:content, :value, :value),
      }
      desired_klass.new(**attributes.compact)
    end

    def to_h
      default_attributes.deep_merge(additional_attributes)
    end

    def id
      @id ||= persistent_id
    end

    def persistent_id
      return create! unless @singleton

      # We need to synchronize the creation of the attribute.
      # Otherwise, we could end up with multiple attributes with the same value.
      self.class.synchronize { fetch_existing || create! }
    end

    def self.klass
      if subclasses.empty?
        # The `klass` method is called for a *subclass* of `Enmeshed::Attribute`.
        # Return values are `IdentityAttribute` and `RelationshipAttribute`.
        "#{super}#{superclass&.klass}"
      else
        # The `klass` method is called for `Enmeshed::Attribute` itself.
        # This is only used for parsing JSON responses received.
        super
      end
    end

    private

    def default_attributes
      {
        '@type': klass,
        owner: @owner,
        value: {
          '@type': @type,
          value: @value,
        },
      }
    end

    def additional_attributes
      raise NotImplementedError
    end

    def fetch_existing
      Connector.fetch_existing_attribute self
    end

    def create!
      Connector.create_attribute self
    end

    class << self
      def mutex
        @mutex ||= Mutex.new
      end

      def synchronize(&)
        mutex.synchronize(&)
      end
    end
  end
end
