# frozen_string_literal: true

require 'rialto/etl/namespaces'
require 'rialto/etl/logging'
require 'rialto/etl/transformers/organizations'
require 'rialto/etl/organizations'

module Rialto
  module Etl
    module Transformers
      class People
        # Position transformer for the CAP Person API
        class Positions
          include Rialto::Etl::Vocabs
          include Rialto::Etl::Logging

          # Transform titles from the CAP people api response to positions in the IR
          # @param titles [Array] a list of titles the person has
          # @param profile_id [String] the identifier for the person profile
          # @return [Array<Hash>] a list of vivo positions described in our IR
          # rubocop:disable Metrics/MethodLength
          def construct_stanford_positions(titles:, profile_id:)
            titles_array = Array(titles)
            if titles_array.empty?
              logger.warn("#{profile_id} has no Stanford positions because no titles")
              return []
            end
            positions = titles_array.map do |title_json|
              org_code = title_json['organization']['orgCode']
              org_id = orgs_map[org_code]
              if org_id.nil?
                logger.warn("Unmapped organization: #{org_code}")
                construct_dummy_position(profile_id: profile_id, title_json: title_json)
              else
                position_for(position_id: "#{org_code}_#{profile_id}",
                             org_id: org_id,
                             hr_title: title_json['title'],
                             label: title_json['label']['text'],
                             person_id: profile_id,
                             valid: true)
              end
            end
            positions.compact
          end
          # rubocop:enable Metrics/MethodLength

          # Create a position associating a person and organization.
          # @param org_name [String] name of the organization, which will be resolved or created.
          # @param person_id [String] id of the person holding the position
          # @return [Hash] a hash representing the position
          def construct_position(org_name:, person_id:)
            # Resolve org.
            # If org doesn't exist, then need to create.
            org = Organizations.resolve_or_construct_org(org_name: org_name)
            org_id = remove_vocab_from_uri(RIALTO_ORGANIZATIONS, org['@id'])
            position = position_for(position_id: "#{org_id}_#{person_id}",
                                    org_id: org_id,
                                    person_id: person_id)
            # If creating org, then add as #.
            position['#organization'] = org if org.key?('@type')
            position
          end

          private

          def construct_dummy_position(profile_id:, title_json:)
            # Add a dummy department
            dummy_dept = construct_dummy_department
            position = position_for(position_id: "stanford_unmapped_dept_#{profile_id}",
                                    org_id: 'stanford_unmapped_dept',
                                    hr_title: title_json['title'],
                                    label: title_json['label']['text'],
                                    person_id: profile_id,
                                    valid: true)
            position['#dummy_dept'] = dummy_dept
            position
          end

          def construct_dummy_department
            dummy_org = Rialto::Etl::Transformers::Organizations.construct_org(org_name: 'Stanford Unmapped Department',
                                                                               org_id: 'stanford_unmapped_dept')
            dummy_org['@type'] << VIVO.Department
            dummy_org
          end

          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, ParameterLists
          def position_for(position_id:, org_id:, hr_title: nil, label: nil, person_id:, valid: false)
            position = {
              '@id' => RIALTO_CONTEXT_POSITIONS[position_id],
              '@type' => VIVO.Position,
              VIVO.relates.to_s => [RIALTO_PEOPLE[person_id], RIALTO_ORGANIZATIONS[org_id]],
              '#position_person_relatedby' => {
                '@id' => RIALTO_PEOPLE[person_id],
                VIVO.relatedBy.to_s => RIALTO_CONTEXT_POSITIONS[position_id]
              },
              '#position_org_relatedby' => {
                '@id' => RIALTO_ORGANIZATIONS[org_id],
                VIVO.relatedBy.to_s => RIALTO_CONTEXT_POSITIONS[position_id]
              }

            }
            if valid
              position["!#{RDF::Vocab::DC.valid}"] = true
              position[RDF::Vocab::DC.valid.to_s] = Time.now.to_date
            end
            if hr_title
              position["!#{VIVO.hrJobTitle}"] = true
              position[VIVO.hrJobTitle.to_s] = hr_title
            end
            if label
              position["!#{RDF::RDFS.label}"] = true
              position[RDF::RDFS.label.to_s] = label
            end

            position
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, ParameterLists

          def orgs_map
            @orgs_map ||= Traject::TranslationMap.new('stanford_org_codes_to_organizations')
          end
        end
      end
    end
  end
end
