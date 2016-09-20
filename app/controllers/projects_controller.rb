class ProjectsController < ApplicationController
  decorates_assigned :project
  before_action :get_project, only: [:show, :update, :destroy]

  def index
    @projects = Project.all
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
    if @project.update(edit_project_params)
      redirect_to project_path(@project)
    else
      render :show
    end
  rescue JSON::ParserError
    flash[:alert] = 'You must input valid JSON'
    render :show
  end

  def destroy
    @project.destroy
    redirect_to projects_path
  end

  private
  def edit_project_params
    params.required(:project).permit(:environment_raw)
  end

  def new_project_params
    params.required(:project).permit(:repository, :webhook_secret)
  end

  def get_project
    @project = Project.find(params[:id])
  end

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