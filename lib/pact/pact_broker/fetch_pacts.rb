require 'pact/hal/entity'
require 'pact/hal/http_client'
require 'pact/provider/pact_uri'

module Pact
  module PactBroker
    class FetchPacts
      attr_reader :provider, :tags, :broker_base_url, :http_client_options, :http_client, :index_entity

      ALL_PROVIDER_TAG_RELATION = 'pb:provider-pacts-with-tag'.freeze
      LATEST_PROVIDER_TAG_RELATION = 'pb:latest-provider-pacts-with-tag'.freeze
      LATEST_PROVIDER_RELATION = 'pb:latest-provider-pacts'.freeze
      PACTS = 'pacts'.freeze
      HREF = 'href'.freeze

      def initialize(provider, tags, broker_base_url, http_client_options)
        @provider = provider
        @tags = (tags || []).collect do |tag|
          if tag.is_a?(String)
            { name: tag, all: false, fallback: nil }
          else
            tag
          end
        end
        @http_client_options = http_client_options
        @broker_base_url = broker_base_url
        @http_client = Pact::Hal::HttpClient.new(http_client_options)
      end

      def self.call(provider, tags, broker_base_url, http_client_options)
        new(provider, tags, broker_base_url, http_client_options).call
      end

      def call
        log_message
        if get_index.success?
          if any_tags?
            get_tagged_pacts_for_provider
          else
            get_latest_pacts_for_provider
          end
        else
          raise Pact::Error.new("Error retrieving #{broker_base_url} status=#{index_entity.response.code} #{index_entity.response.raw_body}")
        end
      end

      private

      def any_tags?
        tags && tags.any?
      end

      def get_tagged_pacts_for_provider
        tags.collect do |tag|
          link = get_link(tag)
          urls = get_pact_urls(link.expand(provider: provider, tag: tag[:name]).get)
          if urls == [] && tag[:fallback]
            urls = get_pact_urls(link.expand(provider: provider, tag: tag[:fallback]).get)
          end
          urls
        end.flatten
      end

      def get_link(tag)
        if !tag[:all]
          index_entity._link(LATEST_PROVIDER_TAG_RELATION)
        else
          index_entity._link(ALL_PROVIDER_TAG_RELATION)
        end
      end

      def get_index
        @index_entity = Pact::Hal::Link.new({ "href" => broker_base_url }, http_client).get
      end

      def get_latest_pacts_for_provider
        link = index_entity._link(LATEST_PROVIDER_RELATION)
        get_pact_urls(link.expand(provider: provider).get)
      end

      def get_pact_urls(link_by_provider)
        link_by_provider.fetch(PACTS).collect do |pact|
          Pact::Provider::PactURI.new(pact[HREF], http_client_options)
        end
      end

      def log_message
        message = "INFO: Fetching pacts for #{provider} from #{broker_base_url}"
        if tags.any?
          desc = tags.collect do |tag|
            all_or_latest = tag[:all] ? "all" : "latest"
            name = tag[:fallback] ? "#{tag[:name]} (or #{tag[:fallback]} if not found)" : tag[:name]
            "#{all_or_latest} #{name}"
          end.join(", ")
          message << " for tags: #{desc}"
        end
        Pact.configuration.output_stream.puts message
      end
    end
  end
end
