class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def github
    @user = User.from_omniauth(request.env["omniauth.auth"])
    sign_in_and_redirect(@user, :event => :authentication)
    set_flash_message(:notice, :success, :kind => "Github") if is_navigational_format?
  end
end