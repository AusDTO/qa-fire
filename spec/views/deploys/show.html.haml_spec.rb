require 'rails_helper'

RSpec.describe 'deploys/show.html.haml' do

  it 'shows None when @logs is nil' do
    assign(:logs, nil)
    assign(:deploy, Fabricate(:deploy))

    render

    expect(rendered).to match /None/
  end
end