# frozen_string_literal: true

require 'rialto/etl/transformers/people/positions'
require 'rialto/etl/transformers/people/names'
require 'rialto/etl/namespaces'

module Rialto
  module Etl
    module Transformers
      # Transformers for a Person
      class People
        # Transform titles from the CAP people api response to positions in the IR
        # @param titles [Array] a list of titles the person has
        # @param profile_id [String] the identifier for the person profile
        # @return [Array<Hash>] a list of vivo positions described in our IR
        def self.construct_stanford_positions(titles:, profile_id:)
          Positions.new.construct_stanford_positions(titles: titles, profile_id: profile_id)
        end

        # Create a position associating a person and organization.
        # @param org_name [String] name of the organization, which will be resolved or created.
        # @param person_id [String] id of the person holding the position
        # @return [Hash] a hash representing the position
        def self.construct_position(org_name:, person_id:)
          Positions.new.construct_position(org_name: org_name, person_id: person_id)
        end

        # Transform names into the hash for a name Vcard
        # @param id [String] an id to use to construct the Vcard URI. If omitted, one will be constructed.
        # @param given_name [String] first name
        # @param middle_name [String] middle name
        # @param family_name [String] last name
        # @return [Hash] a hash representing the Vcard
        def self.construct_name_vcard(id: nil, given_name:, middle_name: nil, family_name:)
          Names.new.construct_name_vcard(id: id, given_name: given_name, middle_name: middle_name, family_name: family_name)
        end

        # Transform names into a full (concatenated) name
        # @param given_name [String] first name
        # @param middle_name [String] middle name
        # @param family_name [String] last name
        # @return [String] the full name
        def self.fullname_from_names(given_name:, middle_name: nil, family_name:)
          Names.new.fullname_from_names(given_name: given_name, middle_name: middle_name, family_name: family_name)
        end

        # Transform names into variations
        # @param given_name [String] first name
        # @param middle_name [String] middle name
        # @param family_name [String] last name
        # @return [String] the full name
        def self.name_variations_from_names(given_name:, middle_name: nil, family_name:)
          Names.new.name_variations_from_names(given_name: given_name, middle_name: middle_name, family_name: family_name)
        end

        # Transform names into the hash for person, including types, labels, and name Vcard
        # @param id [String] an id to use to construct URIs. If omitted, one will be constructed.
        # @param given_name [String] first name
        # @param middle_name [String] middle name
        # @param family_name [String] last name
        # @return [Hash] a hash representing the person
        # rubocop:disable Metrics/MethodLength
        def self.construct_person(id: nil, given_name:, middle_name: nil, family_name:)
          names_constructor = Names.new
          id ||= names_constructor.id_from_names(given_name, family_name)
          full_name = names_constructor.fullname_from_names(given_name: given_name,
                                                            middle_name: middle_name,
                                                            family_name: family_name)
          person = {
            '@id' => Rialto::Etl::Vocabs::RIALTO_PEOPLE[id],
            '@type' => [RDF::Vocab::FOAF.Agent, RDF::Vocab::FOAF.Person],
            RDF::Vocab::SKOS.prefLabel.to_s => full_name,
            RDF::Vocab::RDFS.label.to_s => full_name,
            # Name VCard
            RDF::Vocab::VCARD.hasName.to_s => names_constructor.construct_name_vcard(id: id,
                                                                                     given_name: given_name,
                                                                                     middle_name: middle_name,
                                                                                     family_name: family_name)
          }
          name_variations = name_variations_from_names(given_name: given_name, middle_name: middle_name, family_name: family_name)
          person[RDF::Vocab::SKOS.altLabel.to_s] = name_variations if name_variations
          person
        end
        # rubocop:enable Metrics/MethodLength

        # Resolve a person, otherwise construct a hash for a person.
        # @param given_name [String] first name
        # @param family_name [String] last name
        # @param addl_params [Hash] additional parameters for resolving a person.
        # @return [Hash] a hash representing the person
        def self.resolve_or_construct_person(given_name:, family_name:, addl_params: {})
          if (resolved_person_hash = resolve_person(given_name: given_name, family_name: family_name, addl_params: addl_params))
            resolved_person_hash
          else
            construct_person(given_name: given_name, family_name: family_name)
          end
        end

        # Resolve a person
        # @param given_name [String] first name
        # @param family_name [String] last name
        # @param addl_params [Hash] additional parameters for resolving a person.
        # @return [Hash] a hash representing the person
        def self.resolve_person(given_name:, family_name:, addl_params: {})
          params = people_params(given_name: given_name, family_name: family_name, addl_params: addl_params)
          resolved_person = Rialto::Etl::ServiceClient::EntityResolver.resolve('person', params)
          return if resolved_person.nil?
          {
            '@id' => resolved_person
          }
        end

        # Construct params from args
        # @param given_name [String] first name
        # @param family_name [String] last name
        # @param addl_params [Hash] additional parameters for resolving a person.
        # @return [Hash] a hash representing the person
        def self.people_params(given_name:, family_name:, addl_params:)
          params = {
            'first_name' => given_name,
            'last_name' => family_name
          }
          params.merge(addl_params)
        end
        private_class_method :people_params
      end
    end
  end
end
