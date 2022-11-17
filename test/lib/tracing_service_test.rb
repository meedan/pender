require 'test_helper'

class TracingServiceTest < ActiveSupport::TestCase
  test "#add_attributes_to_current_span should set attributes via open telemetry" do
    fake_span = MiniTest::Mock.new
    fake_span.expect :add_attributes, nil, [{'foo' => 'bar'}]

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.add_attributes_to_current_span({'foo' => 'bar'})
    end

    fake_span.verify
  end

  test "#add_attributes_to_current_span discards empty values in hash" do
    fake_span = MiniTest::Mock.new
    fake_span.expect :add_attributes, nil, [{'bar' => 'baz'}]

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.add_attributes_to_current_span({'foo' => nil, 'bar' => 'baz'})
    end

    fake_span.verify
  end
end
