require 'rails_helper'

RSpec.describe CloudFoundry, type: :service do
  describe '::push' do
    let(:existing_apps) { { resources: []}.with_indifferent_access }

    let(:buildpack) { 'https://github.com/cloudfoundry/ruby-buildpack.git' }
    let(:build_command) { 'npm install -g gulp && npm run build && bin/cf-start.sh' }

    let(:manifest) {
      { applications: [ {
          buildpack: buildpack,
          memory: '1G',
          instances: 2,
          command: 'bin/cf-start.sh'
        } ],
        qafire: {
          command: build_command,
          health_check_type: 'none'
        }
      }.with_indifferent_access }

    let(:expected_payload) {
      { name: 'foo',
        space_guid: nil,
        buildpack: buildpack,
        memory: 1,
        instances: 2,
        command: build_command,
        health_check_type: 'process'
      }.to_json }

    let(:metadata_guid) {
      { metadata: {
        guid: 123
      } }.with_indifferent_access }

    it 'whatever' do
      allow(CloudFoundry).to receive(:find_app) { existing_apps }

      expect(RestClient).to receive(:post).with(
        '/v2/apps', expected_payload, nil).and_return(
        double(body: metadata_guid.to_json))

      allow(CloudFoundry).to receive(:find_shared_domains) {
        double(first: metadata_guid) }

      expect(RestClient).to receive(:get).with(
        '/v2/routes?inline-relations-depth=1&q=host:foo;domain_guid:', nil).and_return(
        double(body: { resources: [ metadata_guid ] }.to_json))

      expect(RestClient).to receive(:put).with(
        '/v2/apps/123/routes/123', {}, nil)

      expect(RestClient).to receive(:put).with(
        '/v2/apps/123/bits?async=true', any_args).and_return(
        double(body: { entity: { status: 'done' } }.to_json))

      CloudFoundry.push('foo', manifest, __FILE__)
    end
  end
end
