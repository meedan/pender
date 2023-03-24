class PenderSentry
  class << self
    def notify(e, data = {})
      Sentry.with_scope do |scope|
        scope.set_context('application', data)
        Sentry.capture_exception(e)
      end
    end
  end
end
