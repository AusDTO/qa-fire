class ApplicationController < ActionController::Base
  def new_session_path(_scope)
    new_user_session_path
  end
end
