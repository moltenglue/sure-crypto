require "test_helper"

class Settings::RotkiControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @user = users(:family_admin)
  end

  test "connect redirects to providers with alert when username blank" do
    post settings_rotki_connect_path, params: { rotki_username: "", password: "password123" }

    assert_redirected_to settings_providers_path
    assert_equal "Username is required", flash[:alert]
  end

  test "connect redirects to providers with alert when password blank" do
    post settings_rotki_connect_path, params: { rotki_username: "testuser", password: "" }

    assert_redirected_to settings_providers_path
    assert_equal "Password is required", flash[:alert]
  end

  test "connect successfully authenticates and saves credentials" do
    RotkiService.any_instance.expects(:login).with("testuser", "password123").returns({ "success" => true })

    post settings_rotki_connect_path, params: { rotki_username: "testuser", password: "password123" }

    assert_redirected_to settings_providers_path
    assert_equal "Connected to Rotki successfully", flash[:notice]
    assert_equal "testuser", @user.reload.rotki_username
    assert_equal "password123", @user.reload.rotki_encrypted_password
  end

  test "connect handles RotkiConnectionError" do
    RotkiService.any_instance.expects(:login).raises(Settings::RotkiController::RotkiConnectionError.new("Connection failed"))

    post settings_rotki_connect_path, params: { rotki_username: "testuser", password: "password123" }

    assert_redirected_to settings_providers_path
    assert_equal "Unable to connect to Rotki. Please check your credentials.", flash[:alert]
  end

  test "connect handles unexpected errors" do
    RotkiService.any_instance.expects(:login).raises(StandardError.new("Unexpected error"))

    post settings_rotki_connect_path, params: { rotki_username: "testuser", password: "password123" }

    assert_redirected_to settings_providers_path
    assert_equal "An unexpected error occurred", flash[:alert]
  end

  test "disconnect clears rotki credentials" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    post settings_rotki_disconnect_path

    assert_redirected_to settings_providers_path
    assert_equal "Disconnected from Rotki", flash[:notice]
    assert_nil @user.reload.rotki_username
    assert_nil @user.reload.rotki_encrypted_password
  end

  test "disconnect handles errors gracefully" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    User.any_instance.expects(:update!).raises(StandardError.new("Database error"))

    post settings_rotki_disconnect_path

    assert_redirected_to settings_providers_path
    assert_equal "Failed to disconnect from Rotki", flash[:alert]
  end
end
