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
        unless schema.valid?(instance)
          error = schema.validate(instance).first.fetch('error')
          Rails.logger.debug(error)
          raise ConnectorError.new("Invalid #{klass} schema: #{error}") unless KNOWN_API_ISSUES.include? error
        end
      end

      KNOWN_API_ISSUES = ['value at `/auditLog/0/createdBy` does not match format: date-time'].freeze
    end
  end
end
