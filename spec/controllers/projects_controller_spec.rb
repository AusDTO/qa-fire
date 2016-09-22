require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do

  let(:user) { Fabricate(:user) }
  before { sign_in(user) }

  shared_examples 'non-collaborator' do
    it do
      request
      expect(controller).to set_flash[:alert].to(/collaborator/i)
    end
  end

  describe '#index' do
    let!(:project_b) { Fabricate(:project, repository: 'b/b') }
    let!(:project_a) { Fabricate(:project, repository: 'a/a') }
    before { get :index }
    it { expect(assigns(:projects)).to match_array([project_a, project_b]) }
  end

  describe '#new' do
    before { get :new }
    it { expect(assigns(:project)).to be_a(Project) }
  end

  describe '#create' do
    let(:request) { post :create, params: {project: params} }

    context 'with valid params' do
      let(:params) { {repository: 'foo/bar', environment_raw: '{"one":"two"}'} }

      it { expect{ request }.to change(Project, :count).by(1) }
      it do
        request
        expect(Project.last.environment).to eq({'one' => 'two'})
      end
    end

    context 'with an invalid repo name' do
      let(:params) { {repository: 'foo'} }
      before { request }
      it { is_expected.to set_flash[:alert].to(/invalid/i)}
    end

    context 'with a non-collaborator repo' do
      let(:params) { {repository: 'foo/bar'} }

      context 'returning 404' do
        before { stub_github_collaborators(404) }
        include_examples 'non-collaborator'
      end

      context 'returning 403' do
        before { stub_github_collaborators(403) }
        include_examples 'non-collaborator'
      end
    end

    context 'with invalid environment json' do
      let(:params) { {repository: 'foo/bar', environment_raw: 'bad'} }

      it { expect(request).to render_template(:new) }
    end
  end

  describe '#update' do
    let(:project) { Fabricate(:project, repository: 'foo/bar') }
    let(:request) { post :update, params: {id: project.id, project: params} }

    context 'with valid params' do
      let(:params) { {environment_raw: '{"one":"two"}'} }


      it { expect{ request; project.reload }.to change(project, :environment).to({'one' => 'two'}) }
    end

    context 'with invalid environment json' do
      let(:params) { {environment_raw: 'bad'} }

      it { expect{request; project.reload}.not_to change(project, :environment) }
      it { expect(request).to render_template(:edit) }
    end

    context 'claiming ownership' do
      let(:request) { post :update, params: {id: project.id, claim_ownership: true, project: {environment_raw: ''}} }
      context 'with access' do
        it { expect{request; project.reload}.to change(project, :user).to(user) }
      end

      context 'without access' do
        before { stub_github_collaborators(404) }
        it { expect{request; project.reload}.not_to change(project, :user) }
      end
    end
  end

  describe '#destroy' do
    context 'without deploys' do
      let!(:project) { Fabricate(:project, repository: 'foo/bar') }
      let(:request) { delete :destroy, params: {id: project.id} }
      it { expect{request}.to change(Project, :count).from(1).to(0) }
    end

    context 'with deploys' do
      let(:deploy) { Fabricate(:deploy) }
      let(:request) { delete :destroy, params: {id: deploy.project.id} }

      it 'enqueues destroy jobs' do
        expect{request}.to have_enqueued_job(ServerDestroyJob).with(deploy)
      end
    end
  end
end
