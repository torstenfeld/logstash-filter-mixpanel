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
  config_name 'mixpanel'

  # Replace the message with this value.
  config :api_key, :validate => :string, :required => true
  config :api_secret, :validate => :string, :required => true
  config :where, :validate => :array, :required => true
  config :source, :validate => :string, :default => 'message'
  config :target, :validate => :string, :default => 'mixpanel'
  config :tag_on_failure, :validate => :array, :default => ['_mixpanelfilterfailure']


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
    if !result.nil?
      event[@target] = result

      # filter_matched should go in the last line of our successful code
      filter_matched(event)
    else
      @tag_on_failure.each do |tag|
        event['tags'] ||= []
        event['tags'] << tag unless event["tags"].include?(tag)
      end
    end
  end # def filter

  private
  def fetch_data
    options = {}
    options['where'] = prepare_where @where if @where

    response = @mp.request('engage', options)
    if response['results'].size >= 1
      single_res = response['results'][0]
    else
      return nil
    end
    distinct_id = single_res['$distinct_id']
    result = single_res['$properties']
    result['$distinct_id'] = distinct_id
    result
  end

  private
  def prepare_where wheredata
    special_properties = %w(email first_name last_name last_seen created)
    res_array = []
    wheredata.each { |constraint|
      constraint.each { |key, value|
        # prepend key with dollar sigh if key is in special_properties
        # TODO: add test for special properties without dollar sign
        key = "$#{key}" if special_properties.include? key

        res_array.push "properties[\"#{key}\"] == \"#{value}\""
      }
    }
    res_array.join ' and '
  end
end # class LogStash::Filters::Example
