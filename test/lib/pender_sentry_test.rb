require_relative '../test_helper'

class PenderSentryTest < ActiveSupport::TestCase
  test "should notify sentry with passed application data" do
    error = StandardError.new('test error')

    scope_mock = mock('scope')
    scope_mock.expects(:set_context).with('application', {thing: 'one', other_thing: 'two'})

    Sentry.expects(:capture_exception).with(error)
    Sentry.stubs(:with_scope).yields(scope_mock).returns(true)

    PenderSentry.notify(error, thing: 'one', other_thing: 'two')
  end

  test ".set_user_info should set API key on user" do
    error = StandardError.new('test error')

    Sentry.expects(:set_user).with(id: 3)

    PenderSentry.set_user_info(api_key: 3)
  end
end
