require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  describe '#github' do
    let(:auth) { RecursiveOpenStruct.new(JSON.parse(File.read('spec/resources/github-oauth.json'))) }
    let(:valid_email) { 'valid@digital.gov.au' }
    let(:invalid_email) { 'bad@example.com' }
    let(:request) { post :github }

    before do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      @request.env['omniauth.auth'] = auth
      @request.env['omniauth.strategy'] = fake_github_strategy(emails)
    end

    context 'with a valid email' do
      let(:emails) { [
              { 'primary' => true,  'verified' => true, 'email' => invalid_email },
              { 'primary' => false, 'verified' => true, 'email' => valid_email },
      ] }

      it { expect{ request }.to change(User, :count).by(1) }

      context do
        before { request }
        it { is_expected.to set_flash[:notice].to(/github/i) }
        it { is_expected.to redirect_to('/') }
      end
    end

    context 'without a valid email' do
      let(:emails) { [{'primary' => true,  'verified' => true, 'email' => invalid_email }] }

      it { expect{ request }.not_to change(User, :count) }

      context do
        before { request }
        it { is_expected.to set_flash[:alert].to(/email/i) }
        it { is_expected.to redirect_to(new_user_session_path) }
      end
    end
  end
end
