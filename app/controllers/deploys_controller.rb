class DeploysController < ApplicationController
  decorates_assigned :project
  before_action :set_project, only: [:new, :index, :create, :destroy]
  before_action :set_deploy, only: [:destroy]


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

  def destroy
    ServerDestroyJob.perform_later(@deploy)
    redirect_to project_path(@project)
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_deploy
    @deploy = Deploy.find(params[:id])
  end

  def deploy_params
    params.required(:deploy).permit([:name, :branch])
  end
end
