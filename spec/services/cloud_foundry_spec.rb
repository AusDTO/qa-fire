require 'rails_helper'

RSpec.shared_examples 'correct payload' do
  it 'makes the right request' do
    expect(RestClient).to receive(:post).with(
      '/v2/apps', expected_payload, nil).and_return(
      double(body: metadata_guid.to_json))

    CloudFoundry.push('foo', manifest, __FILE__)
  end
end

RSpec.describe CloudFoundry, type: :service do
  describe '::push' do
    let(:existing_apps) { { resources: []}.with_indifferent_access }

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
        command: build_command }

      if requested_health_check.present?
        payload[:health_check_type] = requested_health_check
      end

      payload.to_json
    }

    let(:metadata_guid) {
      { metadata: {
        guid: 123
      } }.with_indifferent_access
    }

    before do
      # This volume of stubbing is kind of hideoous, I know.
      # But I think it points to a need to refactor. The methods in the
      # CloudFoundry class are quite long.

      allow(CloudFoundry).to receive(:find_app) { existing_apps }

      allow(CloudFoundry).to receive(:find_shared_domains) {
        double(first: metadata_guid) }

      allow(RestClient).to receive(:get).with(
        '/v2/routes?inline-relations-depth=1&q=host:foo;domain_guid:', nil).and_return(
        double(body: { resources: [ metadata_guid ] }.to_json))

      allow(RestClient).to receive(:put).with(
        '/v2/apps/123/routes/123', {}, nil)

      allow(RestClient).to receive(:put).with(
        '/v2/apps/123/bits?async=true', any_args).and_return(
        double(body: { entity: { status: 'done' } }.to_json))
    end

    context 'health check disabled' do
      let(:manifest_health_check) { 'none' }
      let(:requested_health_check) { 'process' }

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
