class ApplicationController < ActionController::Base
  include Authentication

  # NOTE: Rails' `allow_browser versions: :modern` was removed on purpose.
  # It hard-blocked older browsers with a 406 page ("Your browser is not
  # supported"), which locked out real users on older devices (same issue
  # as agency-system at its launch). This app is server-rendered and does
  # not require modern-only features.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
