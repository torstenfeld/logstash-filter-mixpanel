require File.absolute_path(File.join(File.dirname(__FILE__), '../../spec/spec_helper'))
require File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/logstash/filters/mixpanel'))
require 'mixpanel_client'
require 'mixpanel-ruby'
require 'ffaker'
require 'base64'


describe LogStash::Filters::Mixpanel do
  before(:all) do
    @mp = Mixpanel::Tracker.new(ENV['MP_PROJECT_TOKEN'])

    @user_id = FFaker::Guid.guid
    @user_ip = FFaker::Internet.ip_v4_address
    @user_data = {
        :$first_name => FFaker::NameDE.first_name,
        :$last_name => FFaker::NameDE.last_name,
        :$email => FFaker::Internet.safe_email
    }
    @mp.people.set(@user_id, @user_data, ip=@user_ip)
    @mp.track(@user_id, 'user created')
  end


  describe 'first test' do
    let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '123'
          api_secret => '123'
          where => '123'
        }
      }
    CONFIG
    end

    sample("message" => "test") do
      expect(subject).to include('message')
      expect(subject['message']).to eq('test')
    end
  end
end
