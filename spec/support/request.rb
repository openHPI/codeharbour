# frozen_string_literal: true

module Testing
  # Since RSpec 3.5, controller specs are deprecated. The official recommendation of the Rails team and the RSpec core
  # team is to write request specs instead. They involve the router, the middleware stack, and both rack requests and
  # responses. Thus, it's not possible to set the session variables beforehand anymore. Instead, a request spec should
  # call the sign in endpoint before calling the actual endpoint under test, when the session is needed.

  # To avoid the complexity of SSO and SLOs during request tests, this helper introduces the option to set the session
  # variables via a designated endpoint for tests.
  # https://gist.github.com/dteoh/99721c0321ccd18286894a962b5ce584?permalink_comment_id=4188995#gistcomment-4188995

  class SessionsController < ApplicationController
    skip_before_action :require_user!
    skip_after_action :verify_authorized
    def create
      vars = params.permit(session_vars: {})
      vars[:session_vars]&.each do |var, value|
        session[var] = value
      end
      head :created
    end
  end

  module RequestSessionHelper
    def set_session(vars = {})
      post testing_session_path, params: {session_vars: vars}
      expect(response).to have_http_status(:created)

      vars.each_key do |var|
        expect(session[var]).to be_present
      end
    end
  end
end

RSpec.configure do |config|
  config.include Testing::RequestSessionHelper

  config.before(:all, type: :request) do
    Rails.application.routes.send(:eval_block, proc do
      namespace :testing do
        resource :session, only: %i[create]
      end
    end)
  end
end
