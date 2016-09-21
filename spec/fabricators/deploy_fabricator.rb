Fabricator(:deploy) do
  name { Fabricate.sequence(:pr) { |i| "deploy-#{i}" } }
  trigger 'manual'
  branch 'master'
  project
end