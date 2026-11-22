require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # rack_test needs no browser binary, so system tests run the same way
  # locally and in CI. JavaScript-heavy flows are covered by controller
  # and integration tests instead.
  driven_by :rack_test
end
