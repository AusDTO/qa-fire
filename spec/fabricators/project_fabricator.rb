Fabricator(:project) do
  repository { Fabricate.sequence(:repo) { |i| "owner/repo-#{i}" } }
  environment { {foo: :bar} }
  webhook_secret 'webhook_secret'
  user
end