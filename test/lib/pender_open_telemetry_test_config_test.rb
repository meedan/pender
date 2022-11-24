require_relative '../test_helper'

# Verifying we can use our test-specific open telemetry config --
# not to be confused with OpenTelemetryConfigTest, which
# tests our actual configuration used in non-test environments
class OpenTelemetryTestConfigTest < ActiveSupport::TestCase
  def setup
    isolated_setup
  end

  def teardown
    isolated_teardown
  end

  # This is both a test to make sure our test helpers work,
  # and also an example of how they might be used
  test 'can be used to record reported spans' do
    exporter = Pender::OpenTelemetryTestConfig.current_exporter
    exporter.recording = false
    exporter.export(['fake thing'])

    assert exporter.finished_spans.blank?
    
    exporter.recording = true
    exporter.export(['another fake thing'])
    
    assert exporter.finished_spans.length > 0
  ensure
    exporter.recording = false
  end
end
