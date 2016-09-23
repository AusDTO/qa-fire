require 'rails_helper'

RSpec.describe Deploy, type: :model do
  describe '#full_name' do
    let!(:deploy) { Fabricate(:deploy) }
    subject { deploy.full_name }
    it { is_expected.to include(deploy.name) }
    it { is_expected.to include(deploy.project.name) }
  end

  describe '#name' do
    it { is_expected.to allow_values('good', 'good-things', 'good_things').for(:name) }
    it { is_expected.not_to allow_values('bad things', 'bad/things').for(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
  end

  describe '#branch' do
    it { is_expected.to allow_values('good', 'good-things', 'good_things', 'good/things', 'shell$(things)').for(:branch) }
    it { is_expected.not_to allow_values('bad things').for(:branch) }
  end
end
