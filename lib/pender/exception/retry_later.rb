module Pender
  module Exception
    # This class is ignored by Sentry, and will be
    # retried until the Sidekiq retry limit is exhausted.
    #
    # We should subclass custom errors form this so that
    # we get retry behavior but still have information about
    # what the error means.
    class RetryLater < StandardError; end
  end
end
