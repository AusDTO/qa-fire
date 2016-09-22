require 'rails_helper'

RSpec.describe GithubWebhooksController, :type => :controller do
  let!(:payload) { IO.read('spec/resources/pr.json') }
  let(:repo) { JSON(payload)['repository']['full_name'] }

  describe '#github_pull_request' do
    let(:request) do
      @request.headers['X-GitHub-Event'] = 'pull_request'
      @request.headers['Content-Type'] = 'application/json'
      post :create, body: payload
    end

    context 'with a known project' do
      let!(:project) { Fabricate(:project, repository: repo) }
      it { request; expect(response).to have_http_status(200) }
      it { expect{request}.to have_enqueued_job(ServerLaunchJob) }
    end

    context 'with an unknown project' do
      before { request }
      it { expect(response).to have_http_status(404) }
    end

    context 'with an invalid payload' do
      let!(:payload) { '{}' }
      before { request }
      it { expect(response).to have_http_status(404) }
    end
  end

  describe '#webhook_secret' do
    let(:request) { controller.webhook_secret(ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(payload))) }

    context 'with a known project' do
      let!(:project) { Fabricate(:project, repository: repo) }
      it { expect(request).to eq(project.webhook_secret) }
    end

    context 'with an unknown project' do
      it { expect(request).to eq('') }
    end
  end
end
