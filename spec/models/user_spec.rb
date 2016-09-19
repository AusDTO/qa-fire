require 'rails_helper'
require 'exceptions'

RSpec.describe User, type: :model do
  describe '#from_omniauth' do
    let(:auth) { RecursiveOpenStruct.new(JSON.parse(File.read('spec/resources/github-oauth.json'))) }
    let(:valid_email) { 'valid@digital.gov.au' }
    let(:invalid_email) { 'bad@example.com' }
    # Fake a github oauth strategy object as we're only using it for the emails
    let(:strategy) { OpenStruct.new(emails: emails) }

    subject { User.from_omniauth(auth, strategy) }

    context 'with a valid email' do
      let(:emails) do
        [
            { 'primary' => true,  'verified' => true, 'email' => invalid_email },
            { 'primary' => false, 'verified' => true, 'email' => valid_email },
        ]
      end
      context 'creates the user' do
        it { expect{ subject }.to change(User, :count).by(1) }

        it 'with the right email' do
          subject
          expect(User.last.email).to eq(valid_email)
        end
      end
    end

    context 'without a valid email' do
      let(:emails) { [{'primary' => true,  'verified' => true, 'email' => invalid_email }]}
      it { expect{ subject }.to raise_exception(Exceptions::NoValidEmailError) }
      context 'does not create the user' do
        it { expect{ subject rescue nil }.not_to change(User, :count) }
      end
    end
  end
end
