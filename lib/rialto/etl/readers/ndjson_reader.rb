# frozen_string_literal: true

module Rialto
  module Etl
    module Readers
      # Read newline-delimited JSON file, where each line is a json object.
      # UTF-8 encoding is required.
      class NDJsonReader
        include Enumerable

        def initialize(input_stream, settings)
          @settings = settings
          @input_stream = input_stream
        end

        def logger
          @logger ||= (@settings[:logger] || Yell.new(STDERR, level: 'gt.fatal')) # null logger)
        end

        def each
          return enum_for(:each) unless block_given?

          @input_stream.each_with_index do |json, i|
            yield decode(json, i)
          end
        end

        def decode(row, line_number)
          JSON.parse(row)
        rescue JSON::ParserError => e
          logger.error("Problem with JSON record on line #{line_number}: #{e.message}")
        end
      end
    end
  end
end
