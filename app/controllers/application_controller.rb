class ApplicationController < ActionController::Base
  def process_action(*)
    if PenderConfig.get('memory_report', false).to_s == 'true'
     MemoryProfiler.report { super }.pretty_print(detailed_report: true, scale_bytes: true)
    else
      super
    end
  end
end
