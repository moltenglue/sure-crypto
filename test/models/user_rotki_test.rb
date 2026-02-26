require "test_helper"

class UserRotkiTest < ActiveSupport::TestCase
  setup do
    @user = users(:empty)
  end

  test "syncs user to Rotki on creation when rotki_password is set" do
    # Must mock RotkiService since sync_to_rotki calls it
    mock_service = mock("rotki_service")
    mock_service.expects(:create_user).returns({ "result" => true })
    RotkiService.expects(:new).returns(mock_service)
    
    new_user = User.new(
      email: "newuser#{Time.now.to_i}@example.com",
      password: "SecurePass123!",
      password_confirmation: "SecurePass123!",
      first_name: "Test",
      last_name: "User",
      family: @user.family,
      rotki_password: "password123",
      rotki_username: "testuser",
      rotki_encrypted_password: "encrypted"
    )
    new_user.save!
  end

  test "does not sync to Rotki when rotki_password is blank" do
    RotkiService.expects(:new).never
    
    new_user = User.new(
      email: "newuser2#{Time.now.to_i}@example.com",
      password: "SecurePass123!",
      password_confirmation: "SecurePass123!",
      first_name: "Test",
      last_name: "User",
      family: @user.family,
      rotki_password: nil,
      rotki_username: nil,
      rotki_encrypted_password: nil
    )
    new_user.save!
  end

  test "authenticate_with_rotki! authenticates and stores credentials" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:login, { "success" => true }, ["testuser", "password123"])
    RotkiService.stub(:new, mock_service) do
      @user.authenticate_with_rotki!("testuser", "password123")
    end

    assert_equal "testuser", @user.reload.rotki_username
    assert @user.rotki_encrypted_password.present?
  end

  test "disconnect_rotki! clears all Rotki credentials" do
    @user.update!(
      rotki_username: "testuser",
      rotki_encrypted_password: "encrypted_password"
    )

    @user.disconnect_rotki!

    assert_nil @user.reload.rotki_username
    assert_nil @user.rotki_encrypted_password
  end

  test "rotki_configured? returns true only when both fields present" do
    assert_not @user.rotki_configured?

    @user.update!(rotki_username: "testuser", rotki_encrypted_password: nil)
    assert_not @user.rotki_configured?

    @user.update!(rotki_username: nil, rotki_encrypted_password: "encrypted")
    assert_not @user.rotki_configured?

    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    assert @user.rotki_configured?
  end

  test "rotki_service requires decryption to work" do
    @user.update!(
      rotki_username: "testuser",
      rotki_encrypted_password: "encrypted_password"
    )

    @user.expects(:decrypt_rotki_password).returns("decrypted_password")

    service = @user.rotki_service
    assert_instance_of RotkiService, service
  end

  test "rotki_service returns nil when decryption fails" do
    @user.update!(
      rotki_username: "testuser",
      rotki_encrypted_password: "encrypted_password"
    )

    @user.expects(:decrypt_rotki_password).returns(nil)

    assert_nil @user.rotki_service
  end
end