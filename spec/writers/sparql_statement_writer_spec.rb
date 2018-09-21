# frozen_string_literal: true

require 'rialto/etl/writers/sparql_statement_writer'
require 'rdf'

RSpec.describe Rialto::Etl::Writers::SparqlStatementWriter do
  # @note This is the module that defines the `#sparql_execute!` method
  include SparqlHelper

  subject(:repository) do
    # Be aware: With default implementation of repository, named graphs are created by performing an insert
    # to the named graph. A delete to a named graph prior to that named graph being created will result in an
    # error.
    RDF::Repository.new
  end

  let(:writer) { described_class.new(empty_traject_config) }
  let(:empty_traject_config) { {} }
  let(:graph) { RDF::Graph.new }

  describe 'simple inserts and deletes' do
    before do
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'], Rialto::Etl::Vocabs::SKOS['prefLabel'], 'Justin']
      execute_sparql!(writer.graph_to_insert(graph, Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH))
    end

    describe '#graph_to_insert' do
      it { is_expected.to have_same_triples(graph) }
    end

    describe '#graph_to_delete' do
      it 'produces delete' do
        expect do
          execute_sparql!(writer.graph_to_delete(graph, Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH))
        end.to change { repository.size }.from(1).to(0)
      end
    end
  end

  describe '#add_type_assertions' do
    let(:first_statements) do
      writer.add_type_assertions(Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'],
                                 [
                                   Rialto::Etl::Vocabs::FOAF['Agent'],
                                   Rialto::Etl::Vocabs::FOAF['Organization']
                                 ],
                                 Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
    end

    let(:second_statements) do
      writer.add_type_assertions(Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'],
                                 [
                                   Rialto::Etl::Vocabs::FOAF['Agent'],
                                   Rialto::Etl::Vocabs::FOAF['Person']
                                 ],
                                 Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH)
    end

    before do
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'], RDF.type, Rialto::Etl::Vocabs::FOAF['Agent']]
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'], RDF.type, Rialto::Etl::Vocabs::FOAF['Person']]
      execute_sparql!(first_statements)
      execute_sparql!(second_statements)
    end

    it { is_expected.to have_same_triples(graph) }
  end

  describe '#serialize' do
    let(:first_hash) do
      {
        '@id' => Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'].to_s,
        '@graph' => Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH.to_s,
        '@type' => [Rialto::Etl::Vocabs::FOAF['person'], Rialto::Etl::Vocabs::VIVO['Librarian']],
        Rialto::Etl::Vocabs::VIVO['overview'].to_s => 'Justin Littman is a software developer and librarian.',
        Rialto::Etl::Vocabs::VCARD['hasEmail'].to_s => 'jlittypo@example.org',
        '#advisee' => {
          '@id' => Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'].to_s,
          '@graph' => Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH.to_s,
          '@type' => [Rialto::Etl::Vocabs::FOAF['Person']],
          Rialto::Etl::Vocabs::VCARD['hasName'].to_s => Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['188882']
        }
      }
    end

    let(:second_hash) do
      {
        '@id' => Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'].to_s,
        '@graph' => Rialto::Etl::NamedGraphs::STANFORD_PEOPLE_GRAPH.to_s,
        '@type' => [Rialto::Etl::Vocabs::FOAF['person'], Rialto::Etl::Vocabs::VIVO['Librarian']],
        "!#{Rialto::Etl::Vocabs::VCARD['hasEmail']}" => true,
        Rialto::Etl::Vocabs::VCARD['hasEmail'].to_s => 'jlit@example.org'
      }
    end

    let(:first_statements) { writer.serialize_hash(first_hash) }

    let(:second_statements) { writer.serialize_hash(second_hash) }

    before do
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'], RDF.type, Rialto::Etl::Vocabs::FOAF['person']]
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'], RDF.type, Rialto::Etl::Vocabs::VIVO['Librarian']]
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'],
                Rialto::Etl::Vocabs::VIVO['overview'],
                'Justin Littman is a software developer and librarian.']
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['1234'],
                Rialto::Etl::Vocabs::VCARD['hasEmail'],
                'jlit@example.org']
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'], RDF.type, Rialto::Etl::Vocabs::FOAF['Person']]
      graph << [Rialto::Etl::Vocabs::RIALTO_PEOPLE['188882'],
                Rialto::Etl::Vocabs::VCARD['hasName'],
                Rialto::Etl::Vocabs::RIALTO_CONTEXT_NAMES['188882']]

      execute_sparql!(first_statements)
      execute_sparql!(second_statements)
    end

    it { is_expected.to have_same_triples(graph) }
  end
end
