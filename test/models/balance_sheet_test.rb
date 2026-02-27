require "test_helper"

class BalanceSheetTest < ActiveSupport::TestCase
  fixtures :families, :accounts

  setup do
    @family = families(:empty)
  end

  def create_account(family:, balance:, accountable:, name: "Test Account")
    family.accounts.create!(
      name: name,
      balance: balance,
      currency: "USD",
      accountable: accountable
    )
  end

  test "calculates total assets" do
    create_account(family: @family, balance: 1000, accountable: Depository.new)
    create_account(family: @family, balance: 5000, accountable: OtherAsset.new)
    create_account(family: @family, balance: 10000, accountable: CreditCard.new)

    assert_equal 1000 + 5000, BalanceSheet.new(@family).assets.total
  end

  test "calculates total liabilities" do
    create_account(family: @family, balance: 1000, accountable: CreditCard.new)
    create_account(family: @family, balance: 5000, accountable: OtherLiability.new)
    create_account(family: @family, balance: 10000, accountable: Depository.new)

    assert_equal 1000 + 5000, BalanceSheet.new(@family).liabilities.total
  end

  test "calculates net worth" do
    create_account(family: @family, balance: 1000, accountable: CreditCard.new)
    create_account(family: @family, balance: 50000, accountable: Depository.new)

    assert_equal 50000 - 1000, BalanceSheet.new(@family).net_worth
  end

  test "disabled accounts do not affect totals" do
    create_account(family: @family, balance: 1000, accountable: CreditCard.new)
    create_account(family: @family, balance: 10000, accountable: Depository.new)

    @family.accounts.last.update!(status: :disabled)

    assert_equal 10000, BalanceSheet.new(@family).net_worth
  end

  test "calculates asset group totals" do
    create_account(family: @family, balance: 1000, accountable: Depository.new, name: "Checking")
    create_account(family: @family, balance: 5000, accountable: Investment.new, name: "401k")
    create_account(family: @family, balance: 2000, accountable: OtherAsset.new, name: "Car")

    bs = BalanceSheet.new(@family)
    assert_equal 1000, bs.assets.groups.find { |g| g.name == "Depository" }&.total
    assert_equal 5000, bs.assets.groups.find { |g| g.name == "Investment" }&.total
    assert_equal 2000, bs.assets.groups.find { |g| g.name == "Other Assets" }&.total
  end
end
