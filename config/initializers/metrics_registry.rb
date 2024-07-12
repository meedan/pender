Rails.application.reloader.to_prepare do
  MetricsService.custom_counter(:parser_requests_total, 'Count every parsing request made', labels: [:service_name, :parser_name, :parsed_host, :parsing_status])
  MetricsService.custom_counter(:parser_requests_success, 'Count every successful parsing request made', labels: [:service_name, :parser_name, :parsed_host])
  MetricsService.custom_counter(:parser_requests_error, 'Count every errored parsing request made', labels: [:service_name, :parser_name, :parsed_host])
end
