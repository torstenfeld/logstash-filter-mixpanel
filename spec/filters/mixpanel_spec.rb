require File.absolute_path(File.join(File.dirname(__FILE__), '../../spec/spec_helper'))
require File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/logstash/filters/mixpanel'))
require 'mixpanel_client'
require 'mixpanel-ruby'
require 'ffaker'
require 'base64'


describe LogStash::Filters::Mixpanel do
  before(:all) do
    @mp = Mixpanel::Tracker.new(ENV['MP_PROJECT_TOKEN'])

    @user_1_id = FFaker::Guid.guid
    @user_1_ip = FFaker::Internet.ip_v4_address
    @user_1_email = FFaker::Internet.safe_email
    @user_1_first_name = FFaker::NameDE.first_name
    @user_1_last_name = FFaker::NameDE.last_name
    @user_1_data = {
        :$first_name => @user_1_first_name,
        :$last_name => @user_1_last_name,
        :$email => @user_1_email,
        'Device ID' => @user_1_id
    }
    @mp.people.set(@user_1_id, @user_1_data, ip=@user_1_ip)
    @mp.track(@user_1_id, 'user 1 created')

    @user_2_id = FFaker::Guid.guid
    @user_2_ip = FFaker::Internet.ip_v4_address
    @user_2_email = FFaker::Internet.safe_email
    @user_2_first_name = @user_1_first_name
    @user_2_last_name = @user_1_last_name
    @user_2_data = {
        :$first_name => @user_2_first_name,
        :$last_name => @user_2_last_name,
        :$email => @user_2_email,
        'Device ID' => @user_2_id
    }
    @mp.people.set(@user_2_id, @user_2_data, ip=@user_2_ip)
    @mp.track(@user_2_id, 'user 2 created')


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
            'where' => [{'Device ID' => @user_1_id}]
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
            'where' => [{'Device ID' => @user_1_id}]
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
    context 'by device id' do
      let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'Device ID' => '#{@user_1_id}'}]
        }
      }
      CONFIG
      end

      sample("message" => "123") do
        expect(subject).to include('mixpanel')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to include('$email')
        expect(subject['mixpanel']).to include('$last_name')
        expect(subject['mixpanel']).to include('Device ID')
        insist { subject['tags'] }.nil?
      end
    end

    context 'by email' do
      let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'email' => '#{@user_1_email}'}]
        }
      }
      CONFIG
      end

      sample("message" => "123") do
        expect(subject).to include('mixpanel')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to include('$email')
        expect(subject['mixpanel']).to include('$last_name')
        expect(subject['mixpanel']).to include('Device ID')
        insist { subject['tags'] }.nil?
      end
    end
  end

  context 'test on multiple returns' do
    let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'first_name' => '#{@user_1_first_name}'}]
        }
      }
    CONFIG
    end

    sample("message" => "123") do
      expect(subject).to include('mixpanel')
      expect(subject['mixpanel']).to include('Device ID')
      expect(subject['mixpanel']).to include('$distinct_id')
      expect(subject['mixpanel']).to include('$email')
      expect(subject['mixpanel']).to include('$last_name')
      expect(subject['mixpanel']).to include('Device ID')
      insist { subject['tags'] }.nil?
    end
  end

  context 'test on no returns' do
    let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'first_name' => 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}]
        }
      }
    CONFIG
    end

    sample("message" => "123") do
      insist { subject["tags"] }.include?('_mixpanelfilterfailure')
      reject { subject }.include?('mixpanel')
    end
  end

  after(:all) do
    @mp.people.delete_user(@user_1_id)
    @mp.people.delete_user(@user_2_id)
  end
end
