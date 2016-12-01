require 'rails_helper'

RSpec.shared_examples 'correct payload' do
  it 'makes the right request' do
    expect(CloudFoundry.create_app_body('foo', manifest, nil)).to eq(expected_payload)
  end
end

RSpec.describe CloudFoundry, type: :service do
  describe '::create_app_body' do
    let(:buildpack) { 'https://github.com/cloudfoundry/ruby-buildpack.git' }
    let(:build_command) { 'npm install -g gulp && npm run build && bin/cf-start.sh' }

    let(:manifest) {
      { applications: [ {
          buildpack: buildpack,
          memory: manifest_memory,
          instances: 2,
          command: 'bin/cf-start.sh'
        } ],
        qafire: {
          command: build_command,
          health_check_type: manifest_health_check
        }
      }.with_indifferent_access
    }

    let(:expected_payload) {
      payload = {
        name: 'foo',
        space_guid: nil,
        buildpack: buildpack,
        memory: requested_memory,
        instances: 2,
        command: build_command
      }
      if requested_health_check.present?
        payload[:health_check_type] = requested_health_check
      end
      payload
    }

    context 'health check disabled' do
      let(:manifest_health_check) { 'none' }
      let(:requested_health_check) { 'none' }

      context '200 megabytes' do
        let(:manifest_memory) { '200' }
        let(:requested_memory) { 200 }

        it_behaves_like 'correct payload'
      end

      context '1 gigabyte' do
        let(:manifest_memory) { '1G' }
        let(:requested_memory) { 1024 }

        it_behaves_like 'correct payload'
      end
    end

    # This actually *is* a double negative :)
    context 'without health check disabled' do
      let(:manifest_health_check) { 'invalid-value' }
      let(:requested_health_check) { nil }
      let(:manifest_memory) { '100' }
      let(:requested_memory) { 100 }

      it_behaves_like 'correct payload'
    end
  end
end
