class User < ApplicationRecord
  devise :omniauthable, :timeoutable, :rememberable, :trackable,
         :omniauth_providers => [:github]

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.github_token = auth.credentials.token
    end
  end
end
