module SharedStubs
  def stub_cloud_foundry
    class_double('CloudFoundry',
                 login: true,
                 create_service: true,
                 push: true,
                 start_app: true,
                 stop_app: true,
                 delete_app: true,
                 delete_service: true,
                 get_app_logs: []).as_stubbed_const
  end

  def stub_github_collaborators(status=204)
    stub_request(:get, %r{https://api\.github\.com/repos/foo/bar/collaborators/.+}).
        to_return(:status => status)
  end

  # stub as much of the github result as required
  def stub_github_pulls(open=[])
    stub_request(:get, %r{https://api\.github\.com/repos/\S*/\S*/pulls}).
        to_return(body: open.map{|id| {number: id}}.to_json, headers: {'Content-Type'=> 'application/json'})
  end

  def fake_github_strategy(emails={})
    OpenStruct.new(emails: emails)
  end
end

RSpec.configure do |config|
  config.include SharedStubs
  config.before(:each, type: :controller) do
    stub_cloud_foundry
    stub_github_collaborators
  end
end