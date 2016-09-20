class User < ApplicationRecord
  devise :omniauthable, :timeoutable, :rememberable, :trackable,
         :omniauth_providers => [:github]

  def self.from_omniauth(auth, strategy)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.update(username: auth.info.nickname, email: valid_email(strategy), github_token: auth.credentials.token)
    user
  end

  private

  # return primary email if it matches regexp. Otherwise, try and find one that matches.
  def self.valid_email(strategy)
    email_hash = strategy.emails.sort_by { |email| email['primary'] ? 0 : 1 }.find {|email| valid_email?(email)}
    if email_hash
      email_hash['email']
    else
      raise Exceptions::NoValidEmailError
    end
  end

  def self.valid_email?(email)
    email['verified'] && email['email'] =~ Devise.email_regexp
  end
end
