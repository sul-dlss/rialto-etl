# frozen_string_literal: true

require 'rialto/etl/readers/sparql_statement_reader'
require 'rialto/etl/writers/sparql_writer'
settings do
  provide 'writer_class_name', 'Rialto::Etl::Writers::SparqlWriter'
  provide 'reader_class_name', 'Rialto::Etl::Readers::SparqlStatementReader'
  provide 'sparql_writer.update_url', ::Settings.sparql_writer.update_url
end