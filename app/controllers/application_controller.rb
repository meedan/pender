class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token

  def process_action(*)
    MemoryProfiler.report { super }.pretty_print(detailed_report: true, scale_bytes: true)
  end
end
