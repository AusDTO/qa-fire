require 'rails_helper'

RSpec.describe Server, type: :service do
  let(:pr) do
    {
      number: 123,
      head: {}
    }
  end

  subject(:server) { described_class.new(pr) }
end
