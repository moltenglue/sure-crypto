require "application_system_test_case"

class RotkiPanelTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)
    Rails.application.config.app_mode.stubs(:self_hosted?).returns(true)
  end

  test "rotki panel appears in settings providers" do
    visit settings_providers_path

    assert_selector "#rotki-providers-panel"
    assert_selector "p", text: /Rotki/
  end

  test "rotki panel shows connect form when not connected" do
    visit settings_providers_path

    assert_selector "#rotki-providers-panel"
    assert_selector "form[action='#{settings_rotki_connect_path}']"
    assert_selector 'input[name="rotki_username"]'
    assert_selector 'input[name="password"]'
    assert_selector "button", text: /Connect/
    assert_selector ".w-2.h-2.bg-tertiary" # Not connected status indicator
  end

  test "rotki panel shows connected state when credentials exist" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    visit settings_providers_path

    assert_selector "#rotki-providers-panel"
    assert_selector ".w-2.h-2.bg-success" # Connected status indicator
    assert_selector "button", text: /Disconnect/
    assert_no_selector 'form[action="/settings/rotki/connect"]'
  end

  test "can connect to rotki with valid credentials" do
    RotkiService.any_instance.stubs(:login).returns({ "success" => true })

    visit settings_providers_path

    fill_in "rotki_username", with: "testuser"
    fill_in "password", with: "password123"
    click_button "Connect to Rotki"

    assert_selector ".w-2.h-2.bg-success"
    assert_selector "button", text: /Disconnect/
  end

  test "shows error message when connection fails" do
    RotkiService.any_instance.stubs(:login).raises(Settings::RotkiController::RotkiConnectionError.new("Invalid credentials"))

    visit settings_providers_path

    fill_in "rotki_username", with: "baduser"
    fill_in "password", with: "badpassword"
    click_button "Connect to Rotki"

    assert_selector ".bg-destructive"
    assert_text /Unable to connect/
  end

  test "can disconnect from rotki" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    visit settings_providers_path

    accept_confirm do
      click_button "Disconnect from Rotki"
    end

    assert_selector ".w-2.h-2.bg-tertiary"
    assert_selector 'form[action="/settings/rotki/connect"]'
  end

  test "rotki panel shows setup instructions" do
    visit settings_providers_path

    assert_text /setup.instructions/i
    assert_text /Create an account/i
  end

  test "rotki link appears in accounts new page when configured" do
    @user.update!(rotki_username: "testuser", rotki_encrypted_password: "password123")

    visit new_account_path

    assert_selector "a[href='#{new_rotki_account_path}']", text: /Link with Rotki/i
  end

  test "rotki link does not appear in accounts new page when not configured" do
    visit new_account_path

    assert_no_selector "a[href='#{new_rotki_account_path}']", text: /Link with Rotki/i
  end
end
