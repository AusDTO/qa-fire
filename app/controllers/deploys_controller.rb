class DeploysController < ApplicationController
  decorates_assigned :project

  def index
    @project = Project.find(params[:project_id])
  end
end
