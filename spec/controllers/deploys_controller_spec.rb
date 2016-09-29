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
        it { expect(Deploy.last.full_environment.keys).to include(*project.environment.keys) }
        it { expect(Deploy.last.full_environment.length).to be > 1 }
      end
    end

    context 'with invalid params' do
      let(:params) { { name: '$(bad)', branch: 'branch' } }
      it { expect{request}.not_to change(Deploy, :count) }
    end
  end

  describe '#update' do
    let!(:deploy) { Fabricate(:deploy, project: project) }

    context 'with update project environment' do
      let(:request) { post :update, params: {project_id: project.id, id: deploy.id} }

      before {
        project.environment = { new: :environment }
        project.save
      }

      it 'should update deploys environment' do
        request
        expect(deploy.full_environment.keys).to include(*project.environment.keys)
      end

      it { expect{request}.to have_enqueued_job(ServerLaunchJob).with(deploy) }
    end


    context 'with updated deploy environment' do
      let(:request) {
        put :update, params: {
          project_id: project.id,
          id: deploy.id,
          deploy: { environment_raw: '{"new": "foobar"}' }
        }
      }


      it 'should update deploys environment' do
        request
        expect(Deploy.find(deploy.id).full_environment['new']).to eq('foobar')
      end


      it 'should redirect to project' do
        expect(request).to redirect_to project_path project.id
      end


      it 'should queue a deploy' do
        expect { request }.to have_enqueued_job(ServerLaunchJob).with(deploy)
      end
    end
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
