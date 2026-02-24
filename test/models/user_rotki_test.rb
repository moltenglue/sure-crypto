require "test_helper"

class UserRotkiTest < ActiveSupport::TestCase
  setup do
    @user = users(:empty)
  end

  test "syncs user to Rotki on creation" do
    RotkiService.any_instance.expects(:create_user).with(@user.email, anything)
    
    @user.rotki_password = "password123"
    @user.save!
    
    assert_not_nil @user.rotki_encrypted_password
  end

  test "authenticates with Rotki on login" do
    @user.rotki_encrypted_password = "password123"
    RotkiService.any_instance.expects(:login).with(@user.email, "password123")
    
    @user.authenticate_with_rotki!("password123")
  end
end
