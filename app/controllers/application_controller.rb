class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token
  before_action :add_info_to_trace

  def process_action(*)
    if PenderConfig.get('memory_report', false).to_s == 'true'
     MemoryProfiler.report { super }.pretty_print(detailed_report: true, scale_bytes: true)
    else
      super
    end
  end

  def add_info_to_trace
    TracingService.add_attributes_to_current_span(
      'app.api_key' => ApiKey.current&.id,
    )
  end
end
