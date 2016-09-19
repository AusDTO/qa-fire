class User < ApplicationRecord
  devise :omniauthable, :timeoutable, :rememberable, :trackable,
         :omniauth_providers => [:github]

  def self.from_omniauth(auth, strategy)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = valid_email(strategy)
      raise Exceptions::NoValidEmailError unless user.email
      user.github_token = auth.credentials.token
    end
  end

  private

  # return primary email if it matches regexp. Otherwise, try and find one that matches.
  def self.valid_email(strategy)
    email_hash = strategy.emails.sort_by { |email| email['primary'] ? 0 : 1 }.find {|email| valid_email?(email)}
    email_hash['email'] if email_hash
  end

  def self.valid_email?(email)
    email['verified'] && email['email'] =~ Devise.email_regexp
  end
end
