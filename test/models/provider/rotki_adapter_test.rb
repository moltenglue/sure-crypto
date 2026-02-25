require "test_helper"

class Provider::RotkiAdapterTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @adapter = Provider::RotkiAdapter
  end

  # Factory registration
  test "is registered with Provider::Factory" do
    assert Provider::Factory.registered?("RotkiAccount")
  end

  test "factory returns RotkiAdapter for RotkiAccount" do
    adapter = Provider::Factory.for("RotkiAccount")
    assert_equal Provider::RotkiAdapter, adapter
  end

  # supported_account_types
  test "supported_account_types returns only Crypto" do
    types = @adapter.supported_account_types
    assert_equal %w[Crypto], types
    assert types.include?("Crypto")
    assert_not types.include?("Depository")
    assert_not types.include?("Investment")
  end

  # connection_configs
  test "connection_configs returns empty array when family cannot connect rotki" do
    @family.expects(:can_connect_rotki?).returns(false)
    
    configs = @adapter.connection_configs(family: @family)
    
    assert_equal [], configs
  end

  test "connection_configs returns config when family can connect rotki" do
    @family.expects(:can_connect_rotki?).returns(true)
    
    configs = @adapter.connection_configs(family: @family)
    
    assert_equal 1, configs.length
    config = configs.first
    
    assert_equal "rotki", config[:key]
    assert_equal "Rotki", config[:name]
    assert_equal "Link to your self-hosted Rotki portfolio", config[:description]
    assert config[:can_connect]
    assert config[:new_account_path].is_a?(Proc)
    assert_nil config[:existing_account_path]
  end

  test "connection_configs returns config with callable new_account_path" do
    @family.expects(:can_connect_rotki?).returns(true)
    
    configs = @adapter.connection_configs(family: @family)
    config = configs.first
    
    # Test that new_account_path is callable and returns correct path
    path = config[:new_account_path].call("Crypto", "/dashboard")
    assert path.include?("/rotki_accounts/new")
    assert path.include?("accountable_type=Crypto")
    assert path.include?("return_to=%2Fdashboard")
  end

  # provider_name
  test "provider_name returns rotki" do
    # Create a mock provider account since Base requires one
    mock_account = OpenStruct.new(account: nil, class: OpenStruct.new(name: "RotkiAccount"))
    instance = @adapter.new(mock_account)
    assert_equal "rotki", instance.provider_name
  end

  # Integration with Family
  test "family can check if rotki connection is possible" do
    # Test with user that has rotki configured
    user = users(:family_admin)
    user.update!(rotki_username: "testuser", rotki_encrypted_password: "encrypted")
    
    assert @family.can_connect_rotki?
  end

  test "family cannot connect rotki when no users have credentials" do
    # Remove all rotki credentials from family users
    @family.users.update_all(rotki_username: nil, rotki_encrypted_password: nil)
    
    assert_not @family.can_connect_rotki?
  end

  # Edge cases
  test "connection_configs handles nil family gracefully" do
    assert_raises(NoMethodError) do
      @adapter.connection_configs(family: nil)
    end
  end

  test "supported_account_types returns frozen array" do
    types = @adapter.supported_account_types
    assert types.frozen?
  end

  # Path generation edge cases
  test "new_account_path handles different accountable types" do
    @family.expects(:can_connect_rotki?).returns(true)
    
    configs = @adapter.connection_configs(family: @family)
    config = configs.first
    
    # Test with different accountable types
    path_crypto = config[:new_account_path].call("Crypto", "/accounts")
    assert path_crypto.include?("accountable_type=Crypto")
    
    # Even if called with other types, it should still work (though only Crypto is supported)
    path_other = config[:new_account_path].call("Other", "/test")
    assert path_other.include?("accountable_type=Other")
  end

  test "new_account_path handles special characters in return_to" do
    @family.expects(:can_connect_rotki?).returns(true)
    
    configs = @adapter.connection_configs(family: @family)
    config = configs.first
    
    path = config[:new_account_path].call("Crypto", "/path with spaces & symbols")
    assert path.include?("return_to=")
    # Should be URL encoded
    assert path.include?("%20") || path.include?("+") # spaces
  end
end