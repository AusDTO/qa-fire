class ApplicationController < ActionController::Base
  def new_session_path(_scope)
    new_user_session_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end
end
