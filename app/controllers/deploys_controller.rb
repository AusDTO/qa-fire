class DeploysController < ApplicationController
  decorates_assigned :project
  before_action :set_project, only: [:new, :index, :create, :update, :destroy]
  before_action :set_deploy, only: [:update, :destroy]


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

  def update
    ServerLaunchJob.perform_later(@deploy)
    flash[:notice] = "Redeploying #{@deploy.full_name}"
    redirect_to project_path(@project)
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
