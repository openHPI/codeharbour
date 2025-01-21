# frozen_string_literal: true

module Enmeshed
  class Relationship < Object
    STATUS_GROUP_SYNONYMS = YAML.safe_load_file(Rails.root.join('lib/enmeshed/status_group_synonyms.yml'))

    delegate :expires_at, :nbp_uid, :truncated_reference, to: :@template
    attr_reader :response_items

    def initialize(json:, template:, response_items: [])
      @json = json
      @template = template
      @response_items = response_items
    end

    def peer
      @json[:peer]
    end

    def userdata
      @userdata ||= parse_userdata
    end

    def valid?
      # Templates can only be scanned in their validity period but can theoretically be submitted infinitely late.
      # Thus, we sanitize here.
      if expires_at < (RelationshipTemplate::VALIDITY_PERIOD * 2).ago
        reject!
        false
      else
        true
      end
    end

    def id
      @json[:id]
    end

    def accept!
      Rails.logger.debug do
        "Enmeshed::ConnectorApi accepting Relationship for template #{truncated_reference}"
      end

      Connector.accept_relationship(id)
    end

    def reject!
      Rails.logger.debug do
        "Enmeshed::ConnectorApi rejecting Relationship for template #{truncated_reference}"
      end

      Connector.reject_relationship(id)
    end

    class << self
      def parse(content)
        super
        attributes = {
          json: content,
          template: RelationshipTemplate.parse(content[:template]),
          response_items: content[:creationContent][:response][:items],
        }
        new(**attributes)
      end

      def pending_for(nbp_uid)
        relationships = Connector.pending_relationships

        # We want to call valid? for all relationships, because it internally rejects invalid relationships
        relationships.select(&:valid?).find {|relationship| relationship.nbp_uid == nbp_uid }
      end
    end

    private

    def parse_userdata # rubocop:disable Metrics/AbcSize
      user_provided_attributes = response_items.select do |item|
        item[:@type] == 'ReadAttributeAcceptResponseItem'
      end

      enmeshed_user_attributes = {}

      user_provided_attributes.each do |item|
        attr_type = item.dig(:attribute, :value, :@type)
        attr_value = item.dig(:attribute, :value, :value)

        enmeshed_user_attributes[attr_type] = attr_value
      end

      check_for_required_attributes! enmeshed_user_attributes

      {
        email: enmeshed_user_attributes['EMailAddress'],
        first_name: enmeshed_user_attributes['GivenName'],
        last_name: enmeshed_user_attributes['Surname'],
        status_group: parse_status_group(enmeshed_user_attributes['AffiliationRole'].downcase),
      }
    rescue NoMethodError
      raise ConnectorError.new("Could not parse userdata in the response items: #{response_items}")
    end

    def check_for_required_attributes!(enmeshed_user_attributes)
      blank_attributes = enmeshed_user_attributes.select {|_, v| v.blank? }.keys
      missing_attributes = Enmeshed::RelationshipTemplate::REQUIRED_ATTRIBUTES - enmeshed_user_attributes.keys

      if blank_attributes.any? || missing_attributes.any?
        raise ConnectorError.new("#{(blank_attributes << missing_attributes).flatten.join(', ')} must not be empty")
      end
    end

    def parse_status_group(affiliation_role)
      if STATUS_GROUP_SYNONYMS['learner'].any? {|synonym| synonym.downcase.include? affiliation_role }
        :learner
      elsif STATUS_GROUP_SYNONYMS['educator'].any? {|synonym| synonym.downcase.include? affiliation_role }
        :educator
      end
    end
  end
end
