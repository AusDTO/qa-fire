class DeploysController < ApplicationController
  before_action :set_project

  def index
    @deploys = @project.deploys.all
  end


  private
  def set_project
    @project = Project.find(params[:project_id])
  end
end
