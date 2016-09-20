class DeploysController < ApplicationController
  decorates_assigned :project
  before_action :set_project, only: [:new, :index, :create]


  def new
    @deploy = Deploy.new
    @deploy.trigger = 'manual'
    @deploy.project = @project
  end


  def create
    @deploy = Deploy.new(deploy_params)
    @deploy.project = @project
    @deploy.trigger = 'manual'

    if @deploy.save
      ServerLaunchJob.perform_later(@deploy)
      redirect_to project_path(@project)
    else
      render :new
    end
  end


  private
  def set_project
    @project = Project.find(params[:project_id])
  end


  def deploy_params
    params.required(:deploy).permit([:name, :branch])
  end
end
