# require File.absolute_path(File.join(File.dirname(__FILE__), 'lib/logstash/filters/mixpanel'))
# require 'lib/logstash/filters/mixpanel'


class MixpanelTest
  def initialize
    require 'rubygems'
    require 'mixpanel_client'
    @mp = Mixpanel::Client.new(
        api_key: ENV['MP_PROJECT_KEY'],
        api_secret: ENV['MP_PROJECT_SECRET']
    )
  end

  def run
    result = fetch_data
    result
  end

  private
  def fetch_data
    result = @mp.request('engage', {})
    result
  end
end

# mpt = MixpanelTest.new
# mpt.config
# res = mpt.run
# puts res.inspect

test_hash = {
    'filter' {
        'languagedetect' => {
            'api_key' => ENV['MP_PROJECT_KEY'],
            'api_secret' => ENV['MP_PROJECT_SECRET'],
            'where' => '123'
        }
    }
}

test_string = test_hash.to_s
puts test_string