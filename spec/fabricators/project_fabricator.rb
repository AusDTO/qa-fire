Fabricator(:project) do
  repository { Fabricate.sequence(:repo) { |i| "owner/repo-#{i}" } }
  webhook_secret 'webhook_secret'
  user
end