module Moex
  class Contract
    getter code

    def initialize(@code : String)
    end
  end

  class News
    getter url

    def initialize(@url : String)
    end
  end
end
