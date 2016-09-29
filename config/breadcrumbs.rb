crumb :root do
  link "Home", root_path
end

crumb :project do |project|
  link project.repository, project_path(project)
  parent :root
end

crumb :deploy do |deploy|
  link deploy.name, project_deploy_path(deploy)
  parent :project, deploy.project
end

crumb :new_project do
  link 'New project', new_project_path
  parent :root
end

crumb :edit_project do |project|
  link 'Edit project', edit_project_path(project)
  parent :project, project
end

crumb :edit_deploy do |deploy|
  link 'Edit deploy', edit_project_deploy_path(project_id: deploy.project.id, id: deploy.id)
  parent :project, deploy.project
end