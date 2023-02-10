module Pender
  module Exception
    class ApiLimitReached < ::Exception
      def initialize(reset_in)
        @reset_in = reset_in
      end

      def reset_in
        @reset_in
      end
    end
  end
end
