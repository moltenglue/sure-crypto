require "test_helper"

class UserRotkiTest < ActiveSupport::TestCase
  setup do
    @user = users(:empty)
  end

  test "syncs user to Rotki on creation when rotki_password is set" do
    skip "Requires Rotki service mocking"
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
    skip "Requires Rotki service"
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