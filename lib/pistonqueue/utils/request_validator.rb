module Pistonqueue
  module RequestValidator
    def enabled?(parameter_name:, value: false)
      raise ArgumentError, "The '#{parameter_name}' parameter must be a boolean." unless [true, false].include?(value)

      value
    end
  end
end