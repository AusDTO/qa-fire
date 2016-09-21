require 'rails_helper'

RSpec.describe Deploy, type: :model do
  describe '#full_name' do
    let!(:deploy) { Fabricate(:deploy) }
    subject { deploy.full_name }
    it { is_expected.to include(deploy.name) }
    it { is_expected.to include(deploy.project.name) }
  end
end
