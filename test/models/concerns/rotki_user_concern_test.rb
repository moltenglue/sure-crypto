require "test_helper"

class RotkiUserConcernTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
  end

  # rotki_configured? tests
  test "rotki_configured? returns true when both fields are set" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    assert @user.rotki_configured?
  end

  test "rotki_configured? returns false when username is missing" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: "encrypted")
    assert_not @user.rotki_configured?
  end

  test "rotki_configured? returns false when password is missing" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: nil)
    assert_not @user.rotki_configured?
  end

  test "rotki_configured? returns false when both are missing" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: nil)
    assert_not @user.rotki_configured?
  end

  # rotki_service tests
  test "rotki_service returns service when configured" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    @user.expects(:decrypt_rotki_password).returns("password123")

    service = @user.rotki_service

    assert_instance_of RotkiService, service
    assert_equal "testuser", service.instance_variable_get(:@username)
  end

  test "rotki_service returns nil when not configured" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: nil)
    assert_nil @user.rotki_service
  end

  test "rotki_service returns nil when password decryption fails" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    @user.expects(:decrypt_rotki_password).returns(nil)

    assert_nil @user.rotki_service
  end

  # authenticate_with_rotki! tests
  test "authenticate_with_rotki! stores encrypted password on success" do
    mock_service = mock("rotki_service")
    mock_service.expects(:login).with("testuser", "password123").returns({ "success" => true })
    RotkiService.expects(:new).returns(mock_service)

    @user.authenticate_with_rotki!("testuser", "password123")

    assert_equal "testuser", @user.reload.rotki_username
    assert @user.rotki_encrypted_password.present?
  end

  test "authenticate_with_rotki! raises on connection failure" do
    mock_service = mock("rotki_service")
    mock_service.expects(:login).raises(StandardError, "Connection failed")
    RotkiService.expects(:new).returns(mock_service)

    assert_raises(RotkiUserConcern::RotkiConnectionError) do
      @user.authenticate_with_rotki!("testuser", "password123")
    end
  end

  # disconnect_rotki! tests
  test "disconnect_rotki! clears credentials" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")

    assert @user.disconnect_rotki!
    assert_nil @user.reload.rotki_username
    assert_nil @user.rotki_encrypted_password
  end

  test "disconnect_rotki! returns true when already disconnected" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: nil)
    assert @user.disconnect_rotki!
  end

  # sync_to_rotki tests
  test "sync_to_rotki creates user in Rotki" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    @user.expects(:decrypt_rotki_password).returns("password123")

    mock_service = mock("rotki_service")
    mock_service.expects(:create_user).with(@user.email, "password123").returns({ "result" => true })
    RotkiService.expects(:new).returns(mock_service)

    result = @user.sync_to_rotki
    assert_equal({ "result" => true }, result)
  end

  test "sync_to_rotki does nothing when not configured" do
    @user.update!(rotki_username: nil, rotki_encrypted_password: nil)
    RotkiService.expects(:new).never

    assert_nil @user.sync_to_rotki
  end

  test "sync_to_rotki handles errors gracefully" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    @user.expects(:decrypt_rotki_password).returns("password123")

    mock_service = mock("rotki_service")
    mock_service.expects(:create_user).raises(StandardError, "API Error")
    RotkiService.expects(:new).returns(mock_service)

    result = @user.sync_to_rotki
    assert_nil result
  end

  # Scope tests
  test "with_rotki_configured scope returns only configured users" do
    configured_user = users(:family_admin)
    configured_user.update!(rotki_username: "test", rotki_encrypted_password: "pass")

    unconfigured_user = users(:empty)
    unconfigured_user.update!(rotki_username: nil, rotki_encrypted_password: nil)

    results = User.with_rotki_configured

    assert_includes results, configured_user
    assert_not_includes results, unconfigured_user
  end
end