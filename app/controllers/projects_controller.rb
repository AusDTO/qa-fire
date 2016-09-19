class ProjectsController < ApplicationController
  decorates_assigned :project
  before_action :get_project, only: [:show, :update]

  def index
    @projects = Project.all
  end



  def update
    if @project.update(project_params)
      redirect_to project_path(@project)
    else
      render :show
    end
  rescue JSON::ParserError
    flash[:alert] = 'You must input valid JSON'
    render :show
  end


  private
  def project_params
    params.required(:project).permit(:environment_raw)
  end



  def get_project
    @project = Project.find(params[:id])
  end
end