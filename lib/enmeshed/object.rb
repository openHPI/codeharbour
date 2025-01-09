# frozen_string_literal: true

module Enmeshed
  class Object
    delegate :klass, to: :class

    class << self
      def parse(content)
        validate! content
      end

      def klass
        name&.demodulize
      end

      def schema
        @schema ||= Connector::API_SCHEMA.schema(klass)
      end

      def validate!(instance)
        raise ConnectorError.new("Invalid #{klass} schema") unless schema.valid?(instance)
      end
    end
  end
end
