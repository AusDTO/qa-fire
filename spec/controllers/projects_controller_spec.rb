require 'rails_helper'

RSpec.describe ProjectsController, type: :controller do

  let(:user) { Fabricate(:user) }
  before { sign_in(user) }

  describe '#create' do
    let(:request) { post :create, params: {project: params} }

    context 'with valid params' do
      let(:params) { {repository: 'foo/bar'} }

      before do
        stub_request(:get, "https://api.github.com/repos/foo/bar/collaborators/#{user.username}").
            to_return(:status => 204)
      end

      it { expect{ request }.to change(Project, :count).by(1) }
    end

    context 'with an invalid repo name' do
      let(:params) { {repository: 'foo'} }
      before { request }
      it { is_expected.to set_flash[:alert].to(/invalid/i)}
    end

    context 'with a non-collaborator repo' do
      before do
        stub_request(:get, "https://api.github.com/repos/foo/bar/collaborators/#{user.username}").
            to_return(:status => 404)
      end

      let(:params) { {repository: 'foo/bar'} }
      before { request }
      it { is_expected.to set_flash[:alert].to(/collaborator/i)}
    end

  end
end
