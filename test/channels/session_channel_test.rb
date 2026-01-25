require "test_helper"

class SessionChannelTest < ActionCable::Channel::TestCase
  test "subscribes with valid session token" do
    session = sessions(:open_one)

    subscribe(session_token: session.token)

    assert subscription.confirmed?
    assert_has_stream "session_#{session.token}"
  end

  test "rejects subscription with invalid token" do
    subscribe(session_token: "nope")

    assert subscription.rejected?
  end
end
