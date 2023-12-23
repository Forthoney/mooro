# frozen_string_literal: true

module Mooro
  module Plugin
    module HTTP
      Ok = Data.define(:result) do
        def unwrap
          yield result
        end
      end

      Err = Data.define(:error) do
        def unwrap(&block)
          self
        end
      end
    end
  end
end
