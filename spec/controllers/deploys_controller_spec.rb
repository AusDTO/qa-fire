require 'rails_helper'

RSpec.describe DeploysController, type: :controller do
  let!(:project) { Fabricate(:project) }

  describe '#new' do
    before { get :new, params: {project_id: project.id} }
    it { expect(assigns(:deploy)).to be_a(Deploy) }
    it { expect(assigns(:deploy).project).to eq(project) }
  end

  describe '#create' do
    let(:request) { post :create, params: {project_id: project.id, deploy: params} }

    context 'with valid params' do
      let(:params) { { name: 'name', branch: 'branch' } }

      it { expect(response).to be_success }
      it { expect{request}.to change(Deploy, :count).by(1) }
      context 'sets the parameters' do
        before { request }
        it { expect(Deploy.last.name).to eq('name') }
        it { expect(Deploy.last.branch).to eq('branch') }
        it { expect(Deploy.last.project).to eq(project) }
        it { expect(Deploy.last.trigger).to eq('manual') }
        it { expect(Deploy.last.environment).to eq(project.environment) }
      end
    end

    context 'with invalid params' do
      let(:params) { { name: '$(bad)', branch: 'branch' } }
      it { expect{request}.not_to change(Deploy, :count) }
    end
  end

  describe '#update' do
    let!(:deploy) { Fabricate(:deploy, project: project) }
    let(:request) { post :update, params: {project_id: project.id, id: deploy.id} }
    it { expect{request}.to have_enqueued_job(ServerLaunchJob).with(deploy) }
  end

  describe '#show' do
    let!(:deploy) { Fabricate(:deploy, project: project) }
    let(:request) { get :show, params: {project_id: project.id, id: deploy.id} }
    before {request}
    it { expect(assigns(:deploy)).to eq(deploy) }
    it { expect(assigns(:logs)).to be_a(Array) }
  end

  describe '#destroy' do
    let!(:deploy) { Fabricate(:deploy, project: project) }
    let(:request) { delete :destroy, params: {project_id: project.id, id: deploy.id} }
    it { expect{request}.to have_enqueued_job(ServerDestroyJob).with(deploy) }
  end
end
