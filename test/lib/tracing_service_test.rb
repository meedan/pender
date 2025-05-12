require 'test_helper'

class TracingServiceTest < ActiveSupport::TestCase
  # These integration tests are just meant to make sure that we don't see any issues
  # our unit tests don't cover, since those tests are mostly stubs because of issues accessing
  # set attributes on the recorded spans.
  test "add_attributes_to_current_span works for real" do
    assert_nothing_raised do
      TracingService.add_attributes_to_current_span({'foo' => 'bar'})
    end
  end

  test "#record_exception works for real" do
    assert_nothing_raised do
      TracingService.record_exception(StandardError.new("some fake error"), attributes: {'foo' => 'bar'})
    end
  end

  test "#set_error_status works for real" do
    assert_nothing_raised do
      TracingService.set_error_status("some fake error", attributes: {'foo' => 'bar'})
    end
  end

  # Unit tests below
  test "#add_attributes_to_current_span should set attributes via open telemetry" do
    fake_span = Minitest::Mock.new
    fake_span.expect :add_attributes, nil, [{'foo' => 'bar'}]

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.add_attributes_to_current_span({'foo' => 'bar'})
    end

    fake_span.verify
  end

  test "#add_attributes_to_current_span discards empty values in hash" do
    fake_span = Minitest::Mock.new
    fake_span.expect :add_attributes, nil, [{'bar' => 'baz'}]

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.add_attributes_to_current_span({'foo' => nil, 'bar' => 'baz'})
    end

    fake_span.verify
  end

  test "#record_exception reports passed exception its default message to open telemetry span" do
    exception = StandardError.new('exception message')
    fake_span = Minitest::Mock.new
    fake_status = Minitest::Mock.new

    fake_span.expect :record_exception, nil, [exception], attributes: {}
    fake_span.expect :status=, nil, [fake_status]

    arguments_checker = Proc.new do |message|
      assert_equal 'exception message', message
      fake_status
    end

    OpenTelemetry::Trace::Status.stub(:error, arguments_checker) do
      OpenTelemetry::Trace.stub(:current_span, fake_span) do
        TracingService.record_exception(exception)
      end
    end

    fake_span.verify
  end

  test "#record_exception discards empty values in attribute hash" do
    fake_span = Minitest::Mock.new
    exception = StandardError.new('exception message')
    fake_span.expect :record_exception, nil, [exception], attributes: {'bar'=>'baz'}
    def fake_span.status=(val); nil; end

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.record_exception(exception, attributes: {'foo' => nil, 'bar' => 'baz'})
    end

    fake_span.verify
  end

  test "#record_exception passes along custom error message if provided" do
    exception = StandardError.new('exception message')
    fake_span = Minitest::Mock.new
    fake_status = Minitest::Mock.new

    fake_span.expect :record_exception, nil, [exception], attributes: {}
    fake_span.expect :status=, nil, [fake_status]

    arguments_checker = Proc.new do |message|
      assert_equal 'my custom message', message
      fake_status
    end

    OpenTelemetry::Trace::Status.stub(:error, arguments_checker) do
      OpenTelemetry::Trace.stub(:current_span, fake_span) do
        TracingService.record_exception(exception, 'my custom message')
      end
    end

    fake_span.verify
  end

  test "#set_error_status sets error status with provided message on current span" do
    fake_span = Minitest::Mock.new
    fake_status = Minitest::Mock.new

    fake_span.expect :status=, nil, [fake_status]

    arguments_checker = Proc.new do |message|
      assert_equal 'my error message', message
      fake_status
    end

    OpenTelemetry::Trace::Status.stub(:error, arguments_checker) do
      OpenTelemetry::Trace.stub(:current_span, fake_span) do
        TracingService.set_error_status('my error message')
      end
    end

    fake_span.verify
  end

  test "#set_error_status adds any passed attributes" do
    fake_span = Minitest::Mock.new
    fake_span.expect :add_attributes, nil, [{'foo' => 'bar'}]
    def fake_span.status=(val); nil; end

    OpenTelemetry::Trace.stub(:current_span, fake_span) do
      TracingService.set_error_status('my error message', attributes: {'foo' => 'bar'})
    end

    fake_span.verify
  end
end
