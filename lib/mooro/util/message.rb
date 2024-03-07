# frozen_string_literal: true

module Mooro
  module Util
    module Message
      Terminate = Data.define
      Answer = Data.define(:content)
      Question = Data.define(:content)
      Log = Data.define(:content)

      class Info < Log; end
      class Debug < Log; end
      class Warn < Log; end
      class Error < Log; end
      class Fatal < Log; end
    end
  end
end
