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
end