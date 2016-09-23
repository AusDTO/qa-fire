require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  describe '#new_session_path' do
    it { expect(controller.new_session_path(nil)).to eq(new_user_session_path) }
  end

  describe '#after_sign_out_path_for' do
    it { expect(controller.after_sign_out_path_for(nil)).to eq(new_user_session_path) }
  end
end