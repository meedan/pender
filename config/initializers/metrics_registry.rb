Rails.application.config.after_initialize do
  MetricsService.custom_counter(:pender_parser_requests_total, 'Count parsing requests, gets the full total - does not break them by labels', labels: [:service_name])
  MetricsService.custom_counter(:pender_parser_requests_success, 'Count successful parsing requests', labels: [:service_name])
  MetricsService.custom_counter(:pender_parser_requests_error, 'Count errored parsing requests', labels: [:service_name])

  MetricsService.custom_counter(:pender_parser_requests_per_parser, 'Count parsing requests per parser', labels: [:service_name, :parser_name, :parsing_status])
  MetricsService.custom_counter(:pender_parser_requests_success_per_parser, 'Count successful parsing requests per parser', labels: [:service_name, :parser_name])
  MetricsService.custom_counter(:pender_parser_requests_error_per_parser, 'Count errored parsing requests per parser', labels: [:service_name, :parser_name])

  MetricsService.custom_counter(:pender_parser_requests, 'Count parsing requests - broken by labels', labels: [:service_name, :parser_name, :parsed_host, :parsing_status])
end
