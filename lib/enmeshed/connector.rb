# frozen_string_literal: true

module Enmeshed
  class ConnectorError < StandardError; end

  class Connector
    API_KEY = Settings.dig(:omniauth, :nbp, :enmeshed, :connector_api_key)
    CONNECTOR_URL = Settings.dig(:omniauth, :nbp, :enmeshed, :connector_url)
    API_SCHEMA = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join('lib/enmeshed/api_schema.yml'), permitted_classes: [Time, Date]))

    class << self
      # @return [String] The address of the enmeshed account.
      def enmeshed_address
        return @enmeshed_address if @enmeshed_address.present?

        identity = parse_result(connection.get('/api/v2/Account/IdentityInfo'), IdentityInfo)
        @enmeshed_address = identity.address
      end

      # @return [String] The ID of the created attribute.
      def create_attribute(attribute)
        response = connection.post('/api/v2/Attributes') do |request|
          request.body = {content: attribute.to_h}.to_json
        end
        parse_result(response, Attribute).id
      end

      # @return [String, nil] The ID of the existing attribute or nil if none was found.
      def fetch_existing_attribute(attribute)
        response = connection.get('/api/v2/Attributes') do |request|
          request.params['content.@type'] = attribute.klass
          request.params['content.owner'] = attribute.owner
          request.params['content.value.@type'] = attribute.type
        end
        parse_result(response, Attribute).find {|attr| attr.value == attribute.value }&.id
      end

      # @return [String] The truncated reference of the created relationship template.
      def create_relationship_template(relationship_template)
        response = connection.post('/api/v2/RelationshipTemplates/Own') do |request|
          request.body = relationship_template.to_json
        end
        new_template = parse_result(response, RelationshipTemplate)

        Rails.logger.debug do
          "Enmeshed::ConnectorApi RelationshipTemplate created: #{new_template.truncated_reference}"
        end
        new_template.truncated_reference
      end

      # @return [RelationshipTemplate, nil] The relationship template with the given truncated reference or nil if none
      #  was found.
      def fetch_existing_relationship_template(truncated_reference)
        response = connection.get('/api/v2/RelationshipTemplates') do |request|
          request.params['isOwn'] = true
        end
        parse_result(response, RelationshipTemplate).find do |template|
          template.truncated_reference == truncated_reference
        end
      end

      # @return [Array<Relationship>] All relationships that are pending and await further processing.
      def pending_relationships
        response = connection.get('/api/v2/Relationships') do |request|
          request.params['status'] = 'Pending'
        end
        parse_result(response, Relationship)
      end

      # @return [Boolean] Whether the relationship change was changed (accepted or rejected) successfully.
      def respond_to_rel_change(relationship_id, change_id, action = 'Accept')
        response =
          connection.put("/api/v2/Relationships/#{relationship_id}/Changes/#{change_id}/#{action}") do |request|
            request.body = {content: {}}.to_json
          end
        Rails.logger.debug do
          "Enmeshed::ConnectorApi responded to RelationshipChange with: #{action}; " \
            "connector response status is #{response.status}"
        end

        response.status == 200
      end

      private

      # @return [klass, Array<klass>]
      # @raise [ConnectorError] If the response contains an error or cannot be parsed.
      def parse_result(response, klass)
        json = JSON.parse(response.body).deep_symbolize_keys

        if json.include?(:error)
          raise ConnectorError.new(
            "Enmeshed connector response contained error: #{json[:error][:message]}. " \
            "Full response was: #{response.body}"
          )
        end

        parse_enmeshed_object(json[:result], klass)
      rescue JSON::ParserError
        raise ConnectorError.new("Enmeshed connector response could not be parsed. Received: #{response.body}")
      end

      # @return [klass, Array<klass>] The parsed object or array of objects.
      def parse_enmeshed_object(content, klass)
        if content.is_a?(Array)
          content.map {|object| klass.parse(object) }
        else
          klass.parse(content)
        end
      end

      # @return [Faraday::Connection] The connection to the enmeshed connector.
      # @raise [ConnectorError] If the connector is not configured as expected.
      def connection
        return @connection if @connection.present?

        unless User.omniauth_providers.include?(:nbp) && CONNECTOR_URL.present? && API_KEY.present? \
          && RelationshipTemplate::DISPLAY_NAME.present?
          raise ConnectorError.new('NBP provider or enmeshed connector not configured as expected')
        end

        @connection = Faraday.new(CONNECTOR_URL, headers:)
      end

      # @return [Hash] The headers for the enmeshed connection.
      def headers
        {'X-API-KEY': API_KEY, 'content-type': 'application/json', accept: 'application/json'}
      end
    end
  end
end
