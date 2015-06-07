require File.absolute_path(File.join(File.dirname(__FILE__), '../../spec/spec_helper'))
require File.absolute_path(File.join(File.dirname(__FILE__), '../../lib/logstash/filters/mixpanel'))
require 'rspec'
require 'mixpanel_client'
require 'mixpanel-ruby'
require 'ffaker'
require 'base64'


describe LogStash::Filters::Mixpanel do
  before(:all) do
    # @mpc = Mixpanel::Client.new(
    #     api_key: ENV['MP_PROJECT_KEY'],
    #     api_secret: ENV['MP_PROJECT_SECRET']
    # )
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
      before {
        @id = FFaker::Guid.guid
        @expected_result = {
            'page' => 0,
            'page_size' => 1000,
            'results' => [{ '$distinc_id' => 123124,
                            '$properties' => { '$created' => '2008-12-12T11:20:47',
                                               '$email' => 'example@mixpanel.com',
                                               '$first_name' => 'Example',
                                               '$last_name' => 'Name',
                                               'Device ID' => @id,
                                               '$last_seen' => '2008-06-09T23:08:40' }
                          }]
        }
        Mixpanel::Client.any_instance.stub(:request).and_return(@expected_result)
      }

      let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'Device ID' => '#{@id}'}]
        }
      }
      CONFIG
      end

      sample('message' => '123') do
        expect(subject).to include('mixpanel')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to include('$email')
        expect(subject['mixpanel']).to include('$last_name')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']['Device ID']).to eq(@id)
        expect(subject['mixpanel']).to eq(@expected_result['results'][0]['$properties'])
        insist { subject['tags'] }.nil?
      end
    end

    # TODO: Create Unit test for "by email if it has no dollar char"
    # context 'by email if it has no dollar char' do
    #   before {
    #     @id = FFaker::Guid.guid
    #     @expected_result = {
    #         'page' => 0,
    #         'page_size' => 1000,
    #         'results' => [{ '$distinc_id' => 123124,
    #                         '$properties' => { '$created' => '2008-12-12T11:20:47',
    #                                            '$email' => 'example@mixpanel.com',
    #                                            '$first_name' => 'Example',
    #                                            '$last_name' => 'Name',
    #                                            'Device ID' => @id,
    #                                            '$last_seen' => '2008-06-09T23:08:40' }
    #                       }]
    #     }
    #     Mixpanel::Client.any_instance.stub(:request).and_return(@expected_result)
    #   }
    #
    #   let(:config) do <<-CONFIG
    #   filter {
    #     mixpanel {
    #       api_key => '#{ENV['MP_PROJECT_KEY']}'
    #       api_secret => '#{ENV['MP_PROJECT_SECRET']}'
    #       where => [{'email' => '#{@id}'}]
    #     }
    #   }
    #   CONFIG
    #   end
    #
    #   sample('message' => '123') do
    #     expect(subject).to include("mixpanel")
    #     expect(subject['mixpanel']).to include('Device ID')
    #     expect(subject['mixpanel']).to include('$distinct_id')
    #     expect(subject['mixpanel']).to include('$email')
    #     expect(subject['mixpanel']).to include('$last_name')
    #     expect(subject['mixpanel']).to include('Device ID')
    #     insist { subject['tags'] }.nil?
    #   end
    # end
    #
    # TODO: Create Unit test for "by email if it has dollar char"
    # context 'by email if it has dollar char' do
    #   let(:config) do <<-CONFIG
    #   filter {
    #     mixpanel {
    #       api_key => '#{ENV['MP_PROJECT_KEY']}'
    #       api_secret => '#{ENV['MP_PROJECT_SECRET']}'
    #       where => [{'$email' => '#{@user_1_email}'}]
    #     }
    #   }
    #   CONFIG
    #   end
    #
    #   sample('message' => '123') do
    #     expect(subject).to include("mixpanel")
    #     expect(subject['mixpanel']).to include('Device ID')
    #     expect(subject['mixpanel']).to include('$distinct_id')
    #     expect(subject['mixpanel']).to include('$email')
    #     expect(subject['mixpanel']).to include('$last_name')
    #     expect(subject['mixpanel']).to include('Device ID')
    #     insist { subject['tags'] }.nil?
    #   end
    # end
  end

  context 'test on multiple returns' do
    context 'with and constraint' do
      before {
        @first_name = FFaker::NameDE.first_name
        @expected_result = {
            'page' => 0,
            'page_size' => 1000,
            'results' => [{ '$distinc_id' => 123124,
                            '$properties' => { '$created' => '2008-12-12T11:20:47',
                                               '$email' => 'example1@mixpanel.com',
                                               '$first_name' => @first_name,
                                               '$last_name' => 'Name1',
                                               'Device ID' => '123',
                                               '$last_seen' => '2008-06-09T23:08:40' }
                          }, { '$distinc_id' => 1231244,
                            '$properties' => { '$created' => '2008-12-12T11:20:47',
                                               '$email' => 'example2@mixpanel.com',
                                               '$first_name' => @first_name,
                                               '$last_name' => 'Name2',
                                               'Device ID' => '1234',
                                               '$last_seen' => '2008-06-09T23:08:40' }
                          }]
        }
        Mixpanel::Client.any_instance.stub(:request).and_return(@expected_result)
      }

      let(:config) do <<-CONFIG
        filter {
          mixpanel {
            api_key => '#{ENV['MP_PROJECT_KEY']}'
            api_secret => '#{ENV['MP_PROJECT_SECRET']}'
            where => [{'first_name' => '#{@first_name}'}]
          }
        }
        CONFIG
      end

      sample('message' => '123') do
        expect(subject).to include("mixpanel")
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to include('$email')
        expect(subject['mixpanel']).to include('$first_name')
        expect(subject['mixpanel']).to include('$last_name')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject).to include('tags')

        expect(subject['tags']).to include('_mixpanelfiltermultiresults')
        expect(subject['mixpanel']).to eq(@expected_result['results'][0]['$properties'])
        # expect(subject['mixpanel']['$first_name']).to eq(@first_name)
        # expect(subject['mixpanel']['$last_name']).to eq('Name1')
      end
    end

    context 'with or constraint' do
      before {
        @email1 = FFaker::Internet.safe_email
        @email2 = FFaker::Internet.safe_email
        @expected_result = {
            'page' => 0,
            'page_size' => 1000,
            'results' => [{ '$distinc_id' => 123124,
                            '$properties' => { '$created' => '2008-12-12T11:20:47',
                                               '$email' => 'example1@mixpanel.com',
                                               '$first_name' => 'Firstname1',
                                               '$last_name' => 'Name1',
                                               'Device ID' => '123',
                                               '$last_seen' => '2008-06-09T23:08:40' }
                          }, { '$distinc_id' => 1231244,
                               '$properties' => { '$created' => '2008-12-12T11:20:47',
                                                  '$email' => 'example1@mixpanel.com',
                                                  '$first_name' => 'Firstname2',
                                                  '$last_name' => 'Name2',
                                                  'Device ID' => '1234',
                                                  '$last_seen' => '2008-06-09T23:08:40' }
                          }]
        }
        Mixpanel::Client.any_instance.stub(:request).and_return(@expected_result)
      }

      let(:config) do <<-CONFIG
        filter {
          mixpanel {
            api_key => '#{ENV['MP_PROJECT_KEY']}'
            api_secret => '#{ENV['MP_PROJECT_SECRET']}'
            where => [{'email' => '#{@email1}'}, {'email' => '#{@email2}'}]
            use_or => true
          }
        }
      CONFIG
      end

      sample('message' => '123') do
        expect(subject).to include('mixpanel')
        expect(subject['mixpanel']).to include('Device ID')
        expect(subject['mixpanel']).to include('$distinct_id')
        expect(subject['mixpanel']).to include('$email')
        expect(subject['mixpanel']).to include('$last_name')
        expect(subject['mixpanel']).to include('Device ID')

        expect(subject).to include('tags')
        expect(subject['tags']).to include('_mixpanelfiltermultiresults')
        expect(subject['mixpanel']).to eq(@expected_result['results'][0]['$properties'])
      end
    end
  end

  context 'test on no returns' do
    before {
      @expected_result = {
          'page' => 0,
          'page_size' => 1000,
          'results' => []
      }
      Mixpanel::Client.any_instance.stub(:request).and_return(@expected_result)
    }

    let(:config) do <<-CONFIG
      filter {
        mixpanel {
          api_key => '#{ENV['MP_PROJECT_KEY']}'
          api_secret => '#{ENV['MP_PROJECT_SECRET']}'
          where => [{'$first_name' => 'thisfirstnameshouldneverbeseen123'}]
        }
      }
    CONFIG
    end

    sample('message' => '123') do
      insist { subject['tags'] }.include?('_mixpanelfilterfailure')
      reject { subject }.include?('mixpanel')
    end
  end

  after(:all) do
    # @mp.people.delete_user(@user_1_id)
    # @mp.people.delete_user(@user_2_id)
  end
end
