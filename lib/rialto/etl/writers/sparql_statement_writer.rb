# frozen_string_literal: true

require 'rdf'
require 'traject'
require 'uuid'
require 'sparql/client'
require 'rialto/etl/namespaces'

module Rialto
  module Etl
    # Holds writers for use in Traject mappings
    module Writers
      # rubocop:disable Metrics/ClassLength
      # Write Sparql statement records
      class SparqlStatementWriter < Traject::LineWriter
        extend Rialto::Etl::Vocabs
        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        # Overrides the serialization routine from superclass
        #
        # @param context [Traject::Indexer::Context] a Traject context
        #   object containing the output of the mapping
        # @return [String] Sparql representation of the mapping
        def serialize(context)
          # serialize_hash is a separate method to allow for recursion
          serialize_hash(context.output_hash).flatten.join(";\n") + ";\n"
        end

        # rubocop:disable Metrics/CyclomaticComplexity
        def serialize_hash(hash, graph_name = nil)
          statements = []
          subject_id = hash['@id'].to_s
          subject = RDF::URI.new(hash['@id_ns'] + subject_id)
          graph_name ||= hash['@graph']

          # Always add a valid date
          statements << values_to_delete_insert(subject, Vocabs::DCTERMS['valid'], Time.now.to_date, graph_name, true)

          # Type
          statements << values_to_delete_insert(subject, RDF.type, hash['@type'], graph_name, hash.key?('!type'))

          # Label
          # SKOS.prefLabel & VCARD.fn
          statements << values_to_delete_insert(subject,
                                                [Vocabs::SKOS['prefLabel'],
                                                 Vocabs::FOAF['fn']], hash['@label'],
                                                graph_name,
                                                hash.key?('!label'))

          # Person name vcard
          statements << person_name_to_statements(subject, hash, graph_name) if hash.key?('@person_name')

          # Person address vcard
          statements << person_address_to_statements(subject, hash, graph_name) if hash.key?('@person_address')

          # Advisees
          statements << advisees_to_statements(subject, subject_id, hash, graph_name) if hash.key?('@advisees') &&
                                                                                         !hash['@advisees'].empty?

          # Advisees
          statements << positions_to_statements(subject, subject_id, hash, graph_name) if hash.key?('@positions') &&
                                                                                          !hash['@positions'].empty?

          # All other
          statements << hash_to_delete_insert(subject, hash, graph_name)
        end
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        def graph_to_insert(graph, graph_name)
          SPARQL::Client::Update::InsertData.new(graph, graph: graph_name).to_s.chomp
        end

        def graph_to_delete(graph, graph_name)
          # Note: Cannot perform insert in deleteinsert because insert is only performed when the where clause is
          # satisfied. Thus, it works for an update but not an initial insert.
          SPARQL::Client::Update::DeleteInsert.new(graph,
                                                   nil,
                                                   nil,
                                                   graph: graph_name).to_s.chomp
        end

        # rubocop:disable Metrics/MethodLength
        def values_to_delete_insert(subject, predicates, values, graph_name, delete = false)
          statements = []
          Array(predicates).each do |predicate|
            # Each delete needs to be a separate statement.
            statements << graph_to_delete([[subject, predicate, nil]], graph_name) if delete
          end
          graph = RDF::Graph.new
          Array(predicates).each do |predicate|
            Array(values).each do |value|
              graph << [subject, predicate, value]
            end
          end
          statements << graph_to_insert(graph, graph_name) unless graph.empty?
          statements
        end
        # rubocop:enable Metrics/MethodLength

        def hash_to_delete_insert(subject, hash, graph_name)
          statements = []
          hash.each_pair do |field, values|
            # Ignore any @fields or !fields
            next if field.start_with?('@', '!')
            statements << values_to_delete_insert(subject,
                                                  RDF::URI.new(field),
                                                  values,
                                                  graph_name,
                                                  hash.key?('!' + field))
          end
          statements
        end

        def hash_to_insert(subject, hash, graph_name, graph = nil)
          graph ||= RDF::Graph.new
          hash.each_pair do |field, values|
            # Ignore any @fields or !fields
            next if field.start_with?('@', '!')
            Array(values).each do |value|
              graph << [subject, RDF::URI.new(field), value]
            end
          end
          graph_to_insert(graph, graph_name) unless graph.empty?
        end

        # rubocop:disable Metrics/MethodLength
        def person_name_to_statements(subject, hash, graph_name)
          statements = []
          vcard = Vocabs::RIALTO_CONTEXT_NAMES[hash['@id']]
          if hash.key?('!person_name')
            statements << graph_to_delete([[subject,
                                            Vocabs::VCARD['hasName'],
                                            nil]],
                                          graph_name)
            statements << graph_to_delete([[vcard, nil, nil]], graph_name)
          end
          graph = RDF::Graph.new
          graph << [subject, Vocabs::VCARD['hasName'], vcard]
          graph << [vcard, RDF.type, Vocabs::VCARD.Name]
          statements << hash_to_insert(vcard,
                                       hash['@person_name'].first,
                                       graph_name,
                                       graph)
          statements
        end
        # rubocop:enable Metrics/MethodLength

        # rubocop:disable Metrics/MethodLength
        def person_address_to_statements(subject, hash, graph_name)
          statements = []
          vcard = Vocabs::RIALTO_CONTEXT_ADDRESSES[hash['@id']]
          if hash.key?('!person_address')
            statements << graph_to_delete([[subject,
                                            Vocabs::VCARD['hasAddress'],
                                            nil]],
                                          graph_name)
            statements << graph_to_delete([[vcard, nil, nil]], graph_name)
          end
          graph = RDF::Graph.new
          graph << [subject, Vocabs::VCARD['hasAddress'], vcard]
          graph << [vcard, RDF.type, Vocabs::VCARD.Address]
          statements << hash_to_insert(vcard,
                                       hash['@person_address'].first,
                                       graph_name, graph)
          statements
        end
        # rubocop:enable Metrics/MethodLength

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def advisees_to_statements(advisor, advisor_id, hash, graph_name)
          statements = []
          hash['@advisees'].each do |advisee_hash|
            statements << serialize_hash(advisee_hash, graph_name)
            graph = RDF::Graph.new
            advisee_id = advisee_hash['@id'].to_s
            relationship = Vocabs::RIALTO_CONTEXT_RELATIONSHIPS[advisee_id + '_' + advisor_id]
            graph << [relationship, RDF.type, Vocabs::VIVO['AdvisingRelationship']]
            advisor_role = Vocabs::RIALTO_CONTEXT_ROLES['AdvisorRole']
            graph << [advisor_role, RDF.type, Vocabs::VIVO['AdvisorRole']]
            advisee_role = Vocabs::RIALTO_CONTEXT_ROLES['AdviseeRole']
            graph << [advisee_role, RDF.type, Vocabs::VIVO['AdviseeRole']]
            graph << [advisor, Vocabs::VIVO['relatedBy'], relationship]
            advisee = RDF::URI.new(advisee_hash['@id_ns'] + advisee_id)
            graph << [advisee, Vocabs::VIVO['relatedBy'], relationship]
            graph << [relationship, Vocabs::DCTERMS['valid'], RDF::Literal::Date.new(Time.now.to_date)]
            graph << [advisor, Vocabs::OBO['RO_0000053'], advisor_role]
            graph << [advisor_role, Vocabs::OBO['RO_0000052'], advisor]
            graph << [advisee, Vocabs::OBO['RO_0000053'], advisee_role]
            graph << [advisee_role, Vocabs::OBO['RO_0000052'], advisee]
            statements << graph_to_insert(graph, graph_name)
          end
          statements
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Metrics/AbcSize
        def positions_to_statements(subject, subject_id, hash, graph_name)
          statements = []
          hash['@positions'].each do |position_hash|
            graph = RDF::Graph.new
            position = Vocabs::RIALTO_CONTEXT_POSITIONS["#{position_hash['@org_code']}_#{subject_id}"]
            graph << [position, RDF.type, Vocabs::VIVO['Position']]
            graph << [subject, Vocabs::VIVO['relatedBy'], position]
            graph << [position, Vocabs::VIVO['relates'], subject]
            graph << [position_hash['@organization'], Vocabs::VIVO['relatedBy'], position]
            graph << [position, Vocabs::VIVO['relates'], position_hash['@organization']]
            graph << [position, Vocabs::DCTERMS['valid'], RDF::Literal::Date.new(Time.now.to_date)]
            statements << graph_to_insert(graph, graph_name)
            statements << values_to_delete_insert(position,
                                                  Vocabs::RDFS['label'],
                                                  position_hash['@label'],
                                                  graph_name,
                                                  position_hash.key?('!label'))
            statements << hash_to_delete_insert(position, position_hash, graph_name)
          end
          statements
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/MethodLength
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end