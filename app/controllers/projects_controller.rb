class ProjectsController < ApplicationController
  decorates_assigned :project
  decorates_assigned :manual_deploys
  decorates_assigned :github_deploys

  before_action :get_project, only: [:show, :update, :destroy, :edit]

  def index
    @projects = Project.all.order(:repository)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(new_project_params)
    unless collaborator?(@project.repository)
      render :new and return
    end
    @project.user = current_user
    if @project.save
      redirect_to project_path(@project)
    else
      render :new
    end
  end

  def update
    @project.assign_attributes(edit_project_params)

    # Ensure we have a valid form before re-assigning ownership
    if @project.save
      if params[:claim_ownership]
        if collaborator?(@project.repository)
          @project.update(user: current_user)
        end
      end

      redirect_to project_path(@project)
    else
      render :edit
    end
  end

  def destroy
    if @project.deploys.blank?
      @project.destroy
    else
      @project.update(delete_flag: true)

      @project.deploys.each do |deploy|
        ServerDestroyJob.perform_later(deploy)
      end

      flash[:notice] = 'The Project will be removed after all deploys have been deleted'
    end

    redirect_to projects_path
  end

  private
  def edit_project_params
    params.required(:project).permit(:environment_raw, :webhook_secret)
  end

  def new_project_params
    params.required(:project).permit(:repository, :environment_raw, :webhook_secret)
  end

  def get_project
    @project = Project.find(params[:id])
    @manual_deploys = @project.deploys.by_manual
    @github_deploys = @project.deploys.by_github
  end

  # TODO: pull this out in User.rb
  def collaborator?(repo)
    if Octokit::Client.new(access_token: current_user.github_token).collaborator?(repo, current_user.username)
      return true
    else
      flash[:alert] = 'You must be a collaborator of the repository'
      return false
    end
  rescue Octokit::Forbidden
    flash[:alert] = 'You must be a collaborator of the repository'
    return false
  rescue Octokit::InvalidRepository
    flash[:alert] = 'Invalid repository name'
    return false
  end
end