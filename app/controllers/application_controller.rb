class ApplicationController < ActionController::Base
  allow_browser versions: :all

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
