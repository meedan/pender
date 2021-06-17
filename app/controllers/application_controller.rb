class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token

  def process_action(*)
    MemoryProfiler.report { super }.pretty_print(retained_strings: 0, allocated_strings: 0, detailed_report: true)
  end
end
