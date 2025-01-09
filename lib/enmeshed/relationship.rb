# frozen_string_literal: true

module Enmeshed
  class Relationship < Object
    STATUS_GROUP_SYNONYMS = YAML.safe_load_file(Rails.root.join('lib/enmeshed/status_group_synonyms.yml'))

    delegate :expires_at, :nbp_uid, :truncated_reference, to: :@template
    attr_reader :relationship_changes

    def initialize(json:, template:, changes: [])
      @json = json
      @template = template
      @relationship_changes = changes
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
      raise ConnectorError('Relationship should have exactly one RelationshipChange') if relationship_changes.size != 1

      Rails.logger.debug do
        "Enmeshed::ConnectorApi accepting Relationship for template #{truncated_reference}"
      end

      Connector.respond_to_rel_change(id, relationship_changes.first[:id], 'Accept')
    end

    def reject!
      Rails.logger.debug do
        "Enmeshed::ConnectorApi rejecting Relationship for template #{truncated_reference}"
      end

      @json[:changes].each do |change|
        Connector.respond_to_rel_change(id, change[:id], 'Reject')
      end
    end

    class << self
      def parse(content)
        super
        attributes = {
          json: content,
          template: RelationshipTemplate.parse(content[:template]),
          changes: content[:changes],
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
      # Since the RelationshipTemplate has a `maxNumberOfAllocations` attribute set to 1,
      # you cannot request multiple Relationships with the same template.
      # Further, RelationshipChanges should not be possible before accepting the Relationship.
      raise ConnectorError('Relationship should have exactly one RelationshipChange') if relationship_changes.size != 1

      change_response_items = relationship_changes.first.dig(:request, :content, :response, :items)

      user_provided_attributes = change_response_items.select {|item| item[:@type] == 'ReadAttributeAcceptResponseItem' }

      enmeshed_user_attributes = {}

      user_provided_attributes.each do |item|
        attr_type = item.dig(:attribute, :value, :@type)
        attr_value = item.dig(:attribute, :value, :value)

        enmeshed_user_attributes[attr_type] = attr_value
      end

      {
        email: enmeshed_user_attributes['EMailAddress'],
        first_name: enmeshed_user_attributes['GivenName'],
        last_name: enmeshed_user_attributes['Surname'],
        status_group: parse_status_group(enmeshed_user_attributes['AffiliationRole'].downcase),
      }
    rescue NoMethodError
      raise ConnectorError.new("Could not parse userdata in relationship change: #{relationship_changes.first}")
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
