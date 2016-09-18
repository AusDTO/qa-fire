class ProjectsController < ApplicationController
  decorates_assigned :project

  def index
    @projects = Project.all
  end


  def show
    @project = Project.find(params[:id])
  end
end