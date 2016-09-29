class DeploysController < ApplicationController
  before_action :set_project, only: [:new, :edit, :index, :create, :destroy]
  before_action :set_deploy, only: [:update, :show, :destroy, :edit]
  decorates_assigned :project
  decorates_assigned :deploy


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
    if params.include? :deploy
      unless params[:deploy][:environment_raw].nil?
        @deploy.update_attributes(
          { environment_raw: params[:deploy][:environment_raw] }
        )

        if !@deploy.save
          render :edit and return
        end
      end
    end

    ServerLaunchJob.perform_later(@deploy)
    flash[:notice] = "Redeploying #{@deploy.full_name}"
    redirect_to project_path(@deploy.project)
  end


  def show
    CloudFoundry.login
    @logs = CloudFoundry.get_app_logs(@deploy.full_name)
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
    params.required(:deploy).permit([:name, :branch, :environment_raw])
  end
end
