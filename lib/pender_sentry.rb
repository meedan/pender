class PenderSentry
  class << self
    def notify(e, data = {})
      Sentry.with_scope do |scope|
        scope.set_context('application', data)
        Sentry.capture_exception(e)
      end
    end

    def set_user_info(api_key: nil)
      Sentry.set_user(id: api_key)
    end
  end
end
