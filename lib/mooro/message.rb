# frozen_string_literal: true

module Mooro
  module Message
    Terminate = Data.define
    Answer = Data.define(:content)
    Question = Data.define(:content)
    Log = Data.define(:content)
  end
end
