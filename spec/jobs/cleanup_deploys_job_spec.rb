require 'rails_helper'

RSpec.describe CleanupDeploysJob, type: :job do
  let!(:project) { Fabricate(:project) }
  let!(:deploy_open) { Fabricate(:deploy, project: project, trigger: 'github', pr: 1) }
  let!(:deploy_closed) { Fabricate(:deploy, project: project, trigger: 'github', pr: 2) }

  before { stub_github_pulls([1]) }

  subject do
    described_class.perform_now
  end

  it { expect{subject}.to have_enqueued_job(ServerDestroyJob).with(deploy_closed) }
  it { expect{subject}.not_to have_enqueued_job(ServerDestroyJob).with(deploy_open) }
end