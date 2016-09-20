Fabricator(:user) do
  email { Fabricate.sequence(:email) { |i| "user-#{i}@digital.gov.au" } }
  provider 'github'
  uid { Faker::Number.number(7) }
  username { Faker::Internet.user_name }
  github_token { Faker::Number.hexadecimal(40) }
end