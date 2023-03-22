class PenderSentry
  def self.notify(e, data = {})
    Sentry.with_scope do |scope|
      scope.set_tags(data)
      Sentry.capture_exception(e)
    end
  end
end
