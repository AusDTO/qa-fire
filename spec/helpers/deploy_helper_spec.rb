require 'rails_helper'

RSpec.describe DeployHelper, type: :helper do
  describe '#time_since_timestamp' do
    it { expect(time_since_timestamp(1.minute.ago)).to eq('1 minute') }
  end

  describe '#time_since_timestamp_in_nanoseconds' do
    it { expect(time_since_timestamp_in_nanoseconds(1.minute.ago.to_i * 10**9)).to eq('1 minute') }
  end
end