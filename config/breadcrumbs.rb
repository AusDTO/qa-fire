crumb :root do
  link "Home", root_path
end

crumb :project do |project|
  link project.repository, ''
  parent :root
end