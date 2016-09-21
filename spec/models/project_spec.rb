require 'rails_helper'

RSpec.describe Project, type: :model do

  describe '#name' do
    let(:project) { Fabricate(:project) }
    it { expect(project.repository).to include(project.name) }
  end

  describe '#environment_raw' do
    let(:project) { Fabricate(:project, environment: {'one' => 'uno'}) }

    it { expect(JSON(project.environment_raw)).to eq(project.environment) }
  end

  describe '#environment_raw=' do
    let(:project) { Fabricate(:project, environment: {'one' => 'uno'}) }

    context 'with valid json' do
      before { project.environment_raw = '{"two":"dos"}' }
      it 'should update #environment' do
        expect(project.environment).to eq({'two' => 'dos'})
      end
    end

    context 'with invalid json' do
      before { project.environment_raw = 'bad' }
      it 'should not update #environment' do
        expect(project.environment).to eq({'one' => 'uno'})
      end

      it 'should update #environment_raw' do
        expect(project.environment_raw).to eq('bad')
      end
    end

    context 'with an empty string' do
      before { project.environment_raw = '' }

      it 'should update #environment' do
        expect(project.environment).to eq({})
      end
    end
  end
end
