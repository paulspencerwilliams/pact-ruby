require_relative 'response'

module Pact
  module Consumption
    class Interaction

      attr_reader :request, :response

      def initialize request
        @request = request
      end

      def will_respond_with(response)
        @response = Response.new(response)
      end

      def to_hash
        {
          :request => @request,
          :response => @response
        }
      end

      def to_reified_hash
        {
          :request => @request,
          :response => @response.reify
        }
      end
    end
  end
end