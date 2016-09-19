class ProjectsController < ApplicationController
  decorates_assigned :project
  before_action :get_project, only: [:show, :update]

  def index
    @projects = Project.all
  end



  def update
    #json_input = JSON.parse(project_params[:environment_raw])
    @project.environment = project_params[:environment]
    if @project.save
      redirect_to :show
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