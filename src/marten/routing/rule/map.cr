module Marten
  module Routing
    module Rule
      class Map < Base
        @regex : Regex
        @path_for_interpolation : String
        @parameters : Hash(String, Parameter::Base)
        @endpoint_reversers : Nil | Array(EndpointReverser)

        getter name

        def initialize(@path : String, @map : Marten::Routing::Map, @name : String)
          @regex, @path_for_interpolation, @parameters = path_to_regex(@path)
        end

        def resolve(path : String) : Nil | Match
          match = @regex.match(path)
          return if match.nil?

          kwargs = {} of String => Parameter::Types
          match.named_captures.each do |name, value|
            param_handler = @parameters[name]
            kwargs[name] = param_handler.loads(value.to_s)
          end

          new_path = path[match.end..]
          sub_match = @map.rules.each do |rule|
            matched = rule.resolve(new_path)
            break matched unless matched.nil?
          end

          return if sub_match.nil?

          Match.new(sub_match.view, kwargs.merge(sub_match.kwargs))
        end

        def endpoint_reversers : Array(EndpointReverser)
          @endpoint_reversers ||= @map.endpoint_reversers.values.map do |reverser|
            EndpointReverser.new(
              "#{@name}:#{reverser.name}",
              @path_for_interpolation + reverser.path_for_interpolation,
              @parameters.merge(reverser.parameters)
            )
          end
        end
      end
    end
  end
end
