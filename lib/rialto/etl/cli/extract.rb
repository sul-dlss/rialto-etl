# frozen_string_literal: true

require 'active_support/core_ext/hash/keys'
require 'rialto/etl/extractors'

module Rialto
  module Etl
    module CLI
      # Extract subcommand
      class Extract < Thor
        option :institution,
               required: false,
               banner: 'INSTITUTION',
               desc: 'Institution name (for WebOfScience)',
               aliases: '-i'

        option :since,
               required: false,
               banner: 'SINCE',
               desc: 'Load records since... (for WebOfScience)'

        option :range,
               required: false,
               banner: 'RANGE',
               desc: 'Publication range, e.g., 2018-01-01+2021-12-31... (for WebOfScience)'

        option :sunetid,
               required: false,
               banner: 'SUNETID',
               desc: 'SUNet ID (for SeRA API)',
               aliases: '-s'

        desc 'call NAME', "Call named extractor (`#{@package_name} list` to see available names)"
        # Call a extractor by name
        def call(name)
          extractor(name).each do |out|
            say out
          end
        end

        desc 'list', 'List callable extractors'
        # List callable extractors
        def list
          callable_extractors = Rialto::Etl::Extractors.constants.map(&:to_s).sort
          say "Extractors supported: #{callable_extractors.join(', ')}"
        end

        private

        def extractor(name)
          Rialto::Etl::Extractors.const_get(name).new(options.symbolize_keys)
        end
      end
    end
  end
end
