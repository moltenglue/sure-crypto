# frozen_string_literal: true

require "test_helper"

class BrakemanSecurityTest < ActionDispatch::IntegrationTest
  test "brakeman reports no high confidence warnings" do
    skip unless ENV["RUN_BRAKEMAN_IN_TESTS"]
    
    require "brakeman"
    
    tracker = Brakeman.run(
      app_path: Rails.root.to_s,
      quiet: true,
      run_checks: Brakeman::Checks.checks_to_run.map(&:name)
    )
    
    high_confidence_warnings = tracker.warnings.select do |w|
      w.confidence == Brakeman::Confidence::HIGH
    end
    
    assert_equal 0, high_confidence_warnings.count,
                 "High confidence security warnings found: #{high_confidence_warnings.map(&:message).join(', ')}"
  end
end