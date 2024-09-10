require 'test_helper'

class MetricsServiceTest < ActiveSupport::TestCase
  test "custom_counter works for real" do
    assert_nothing_raised do
      MetricsService.custom_counter(:custom_counter, 'Custom counter test', labels: [:service_name, :test])
    end
  end

  test "increment_counter works for real" do
    MetricsService.custom_counter(:custom_counter_2, 'Custom counter test', labels: [:service_name, :test])

    assert_nothing_raised do
      MetricsService.increment_counter(:custom_counter_2, labels: [:test])
    end
  end

  test "get_counter works for real" do
    custom_counter = MetricsService.custom_counter(:custom_counter_3, 'Custom counter test', labels: [:service_name, :test])

    assert_nothing_raised do
      MetricsService.get_counter(custom_counter, labels: [:test])
    end
  end
end
