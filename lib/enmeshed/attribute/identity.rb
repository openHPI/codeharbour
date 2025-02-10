# frozen_string_literal: true

module Enmeshed
  class Attribute::Identity < Attribute

    # Serialize the Identity object to fit the content requirements when creating
    # an IdentityAttribute via the Connector API (available under Connector::CONNECTOR_URL)
    #
    # @return [String] JSON
    def to_json(*)
      {
        content: {
          value: {
            '@type': @type,
            value: @value,
          },
        },
      }.to_json(*)
    end

    private

    def additional_attributes
      {}
    end
  end
end
