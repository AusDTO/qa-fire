require 'rails_helper'

RSpec.describe DeployDecorator, type: :decorator do
  describe '#url' do
    let(:deploy) { Fabricate(:deploy) }
    subject { deploy.decorate.url }
    it { expect{URI.parse(subject)}.not_to raise_error }
  end
end