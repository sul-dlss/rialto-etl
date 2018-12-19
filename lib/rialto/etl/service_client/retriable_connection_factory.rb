# frozen_string_literal: true

require 'active_support/core_ext/class/attribute'
require 'faraday'

module Rialto
  module Etl
    module ServiceClient
      # Builds Faraday connections with retry and long timeouts
      class RetriableConnectionFactory
        DEFAULT_MAX_RETRIES = 6
        DEFAULT_MAX_INTERVAL = Float::MAX
        class_attribute :logger

        # rubocop:disable Metrics/MethodLength
        def self.build(uri:, headers:, logger: default_logger, max_retries: nil, max_interval: nil)
          self.logger = logger

          Faraday.new(uri, headers: headers) do |connection|
            connection.request :retry, max: max_retries || DEFAULT_MAX_RETRIES,
                                       max_interval: max_interval || DEFAULT_MAX_INTERVAL,
                                       interval: 5.0,
                                       interval_randomness: 0.01,
                                       backoff_factor: 2.0,
                                       methods: retriable_methods, exceptions: retriable_exceptions, retry_block: retry_block,
                                       retry_statuses: retry_statuses

            connection.ssl.update(verify: true, verify_mode: OpenSSL::SSL::VERIFY_PEER)
            # Use :net_http instead of :net_http_persistent to avoid getaddrbyinfo errors with DNS resolution
            connection.adapter :net_http
            connection.options.timeout = 500
            connection.options.open_timeout = 10
          end
        end
        # rubocop:enable Metrics/MethodLength

        def self.retriable_methods
          Faraday::Request::Retry::IDEMPOTENT_METHODS + [:post]
        end
        private_class_method :retriable_methods

        def self.retriable_exceptions
          Faraday::Request::Retry::DEFAULT_EXCEPTIONS + [Faraday::ConnectionFailed, ErrorResponse]
        end
        private_class_method :retriable_exceptions

        def self.retry_block
          lambda { |env, _opts, retries, exception|
            logger.warn "retrying connection (#{retries} remaining) to #{env.url}: (#{exception.class}) #{exception.message}"
          }
        end
        private_class_method :retry_block

        def self.default_logger
          Yell.new(STDERR)
        end
        private_class_method :default_logger

        def self.retry_statuses
          [429, 500, 502, 503, 504, 599]
        end
        private_class_method :retry_statuses
      end
    end
  end
end
