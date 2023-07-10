#################################################################################################
## Infoblox: Generic API Call for Infoblox
#################################################################################################
#
Puppet::Functions.create_function(:'ibvs::infoblox::infoblox_api_call') do
  require 'cgi'
  require 'json'
  require 'uri'
  require 'net/http'
  require 'net/https'
  require 'openssl'

  dispatch :func do
    param 'Hash', :infoblox_settings
    param 'Hash', :options
  end

  def func(infoblox_settings, options)
    infoblox_settings['ssl'] ? prefix='https://' : prefix = 'http://'
    infoblox_settings['insecure'] ? ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE : ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    url = prefix + infoblox_settings['wapi_url'] + options['endpoint'] + '&_return_as_object=1'
    uri = URI(url)

    response = Net::HTTP.start(uri.host, uri.port, 
      :read_timeout => 5,
      :open_timeout => 5,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => ssl_verify_mode) do |https|
      case options['request_type'].upcase
        when 'POST'
          request = Net::HTTP::Post.new(uri.request_uri)
        when 'PATCH'
          request = Net::HTTP::Patch.new(uri.request_uri)
        when 'PUT'
          request = Net::HTTP::Put.new(uri.request_uri)
        when 'DELETE'
          request = Net::HTTP::Delete.new(uri.request_uri)
        else #assume GET
          request = Net::HTTP::Get.new(uri.request_uri)
      end
      request['Content-Type'] = 'application/json'
      begin 
        request.basic_auth(infoblox_settings['user'],infoblox_settings['password'].unwrap)
      rescue
        request.basic_auth(infoblox_settings['user'],infoblox_settings['password'])
      end
      request.body = "#{options['request_body']}" if defined?(options['request_body'])
      https.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      begin
        return JSON.parse( response.body.strip.gsub(/\n/, '').gsub(/^\"|\"$/, '')) if options['json_parse']
      rescue
        fail("Infoblox API Call could not parse result body to JSON: '#{response.body}'")
      end
      return '' if response.body == nil
      return response.body.strip.gsub(/^\"|\"$/, '')
    end

    fail("API Call to Infoblox failed: #{response.code} - #{response.class}: #{response.message}")
  end
end