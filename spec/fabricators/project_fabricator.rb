Fabricator(:project) do
  repository { Fabricate.sequence(:repo) { |i| "owner/repo-#{i}" } }
  user
end