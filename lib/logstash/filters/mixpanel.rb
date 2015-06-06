# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require 'mixpanel_client'

# This example filter will replace the contents of the default 
# message field with whatever you specify in the configuration.
#
# It is only intended to be used as an example.
class LogStash::Filters::Mixpanel < LogStash::Filters::Base

  # Setting the config_name here is required. This is how you
  # configure this filter from your Logstash config.
  #
  # filter {
  #   example {
  #     message => "My message..."
  #   }
  # }
  #
  config_name "mixpanel"
  
  # Replace the message with this value.
  config :api_key, :validate => :string, :required => true
  config :api_secret, :validate => :string, :required => true
  config :where, :validate => :string, :required => true
  config :source, :validate => :string, :default => 'message'
  config :target, :validate => :string, :default => 'mixpanel'


  public
  def register
    @mp = Mixpanel::Client.new(
      api_key: @api_key,
      api_secret: @api_secret
    )
  end # def register

  public
  def filter(event)

    result = fetch_data
    # TODO: remove puts result
    puts result
    event[@target] = result

    # filter_matched should go in the last line of our successful code
    filter_matched(event)
  end # def filter

  private
  def fetch_data
    options = {}
    # options['where'] = @where if @where
    result = @mp.request('engage', options)
    result
  end
end # class LogStash::Filters::Example
