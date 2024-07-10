Rails.application.reloader.to_prepare do
  MetricsService.custom_counter(:parsing_requests_total, 'Count every request made', labels: [:service_name, :parser_name, :parsed_host, :parsing_status])
end
