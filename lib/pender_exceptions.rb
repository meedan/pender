module Pender
  class ApiLimitReached < Exception
    def initialize(reset_in)
      @reset_in = reset_in
    end

    def reset_in
      @reset_in
    end
  end
  
  class UnsafeUrl < Exception
  end

  class RetryLater < StandardError
  end
end
