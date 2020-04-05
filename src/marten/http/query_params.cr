module Marten
  module HTTP
    class QueryParams
      class ImmutableStateError < Exception; end

      def initialize(@params : ::HTTP::Params, @mutable = false)
        if !Marten.settings.request_max_parameters &&
          @params.size > Marten.settings.request_max_parameters.as(Int32)
          raise Errors::TooManyParametersReceived.new("The number of parameters that were received is too large")
        end
      end

      # Returns the first value associated with the passed parameter name.
      def [](name : String | Symbol)
        @params[name.to_s]
      end

      # Returns the first value associated with the passed parameter name or `nil` if the parameter is not present.
      def []?(name : String | Symbol)
        @params[name.to_s]?
      end

      # Sets the first value for a given parameter name.
      def []=(name : String | Symbol, value)
        with_ensured_mutability do
          @params[name.to_s] = value.to_s
        end
      end

      # Returns `true` if the parameter with the provided name exists.
      def has_key?(name : String | Symbol) # ameba:disable Style/PredicateName
        @params.has_key?(name.to_s)
      end

      # Returns the first value for the specified parameter name or fallback to the provided default value ( which is
      # `nil` by default).
      def fetch(name : String | Symbol, default = nil)
        @params.fetch(name.to_s, default)
      end

      # Returns all the values for a specified parameter name.
      def fetch_all(name : String | Symbol)
        @params.fetch_all(name.to_s)
      end

      # Sets all the values associated with a specific parameter name.
      def set_all(name : String | Symbol, values)
        with_ensured_mutability do
          @params.set_all(name.to_s, values)
        end
      end

      # Returns the number of parameters.
      delegate size, to: @params

      # Returns `true` if no parameters are present.
      delegate empty?, to: @params

      # Returns the serialized version of the parameters.
      delegate to_s, to: @params

      private def mutable?
        @mutable
      end

      private def with_ensured_mutability
        raise ImmutableStateError.new("THis QueryParams instance is immutable") unless mutable?
        yield
      end
    end
  end
end
