# frozen_string_literal: true

require "test_helper"

class TransactionFlowIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    @account = accounts(:empty_checking)
    @category = categories(:empty_uncategorized)
    sign_in(@user)
  end

  test "user can create a transaction" do
    assert_difference("Transaction.count") do
      post account_transactions_path(@account), params: {
        transaction: {
          name: "Grocery Store",
          amount: 50.00,
          currency_code: "USD",
          date: Date.today.to_s,
          category_id: @category.id
        }
      }
    end
    assert_redirected_to account_path(@account)
  end

  test "user can view transaction list" do
    get account_transactions_path(@account)
    assert_response :success
  end

  test "user can update a transaction" do
    transaction = transactions(:empty_one)
    patch transaction_path(transaction), params: {
      transaction: {
        name: "Updated Name",
        amount: 75.00
      }
    }
    assert_redirected_to account_path(transaction.account)
    transaction.reload
    assert_equal "Updated Name", transaction.name
  end

  test "user can delete a transaction" do
    transaction = transactions(:empty_one)
    assert_difference("Transaction.count", -1) do
      delete transaction_path(transaction)
    end
    assert_redirected_to account_path(transaction.account)
  end

  test "transaction creation with invalid data shows errors" do
    post account_transactions_path(@account), params: {
      transaction: {
        name: "",
        amount: nil
      }
    }
    assert_response :unprocessable_entity
  end

  test "user can search transactions" do
    get transactions_path, params: { q: "grocery" }
    assert_response :success
  end

  test "user can filter transactions by date range" do
    get transactions_path, params: {
      start_date: Date.today - 30.days,
      end_date: Date.today
    }
    assert_response :success
  end
end