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
        :$email => FFaker::Internet.safe_email,
        'Device ID' => @user_id
    }
    @mp.people.set(@user_id, @user_data, ip=@user_ip)
    @mp.track(@user_id, 'user created')
  end

  context 'raise error' do
    context 'on wrong api key config' do
      subject {
        config = {
            'api_key' => 123
        }
        filter = LogStash::Filters::Mixpanel.new config
      }

      it 'should raise error on invalid api key config' do
        insist { subject.register }.raises(LogStash::ConfigurationError)
      end
    end

    context 'on wrong api secret config' do
      subject {
        config = {
            'api_secret' => 123
        }
        filter = LogStash::Filters::Mixpanel.new config
      }

      it 'should raise error on invalid api secret config' do
        insist { subject.register }.raises(LogStash::ConfigurationError)
      end
    end

    context 'on invalid api key' do
      subject {
        config = {
            'api_key' => '123',
            'api_secret' => '123',
            'where' => [{'Device ID' => @user_id}]
        }
        filter = LogStash::Filters::Mixpanel.new config
        filter.register
        filter.filter LogStash::Event.new
      }

      it 'should raise error on invalid api key' do
        insist { subject.filter.flush }.raises(Mixpanel::HTTPError)
      end
    end

    context 'on invalid api secret' do
      subject {
        config = {
            'api_key' => ENV['MP_PROJECT_KEY'],
            'api_secret' => '123',
            'where' => [{'Device ID' => @user_id}]
        }
        filter = LogStash::Filters::Mixpanel.new config
        filter.register
        filter.filter LogStash::Event.new
        # filter.filter LogStash::Event.new({'message' => 'test'})
      }

      it 'should raise error on invalid api secret' do
        insist { subject.filter.flush }.raises(Mixpanel::HTTPError)
      end
    end
  end

  context 'fetch created user' do
    let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'Device ID' => '#{@user_id}'}]
        }
      }
    CONFIG
    end

    # sample("message" => "123") do
    #   expect(subject).to include('mixpanel')
    # end

    context 'by property' do
      sample("message" => "123") do
        expect(subject).to include('mixpanel')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to have_at_least(1).items
      end
    end
  end

  after(:all) do
    @mp.people.delete_user(@user_id)
  end
end
