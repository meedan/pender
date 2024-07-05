Rails.application.reloader.to_prepare do
  MetricsService.custom_counter(:media_request_total, 'Count every request made', labels: [:service, :parser, :host, :error])
end
