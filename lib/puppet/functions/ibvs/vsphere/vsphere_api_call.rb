#################################################################################################
## Infoblox: Generic API Call for vSphere
#################################################################################################
#
Puppet::Functions.create_function(:'ibvs::vsphere::vsphere_api_call') do
  require 'cgi'
  require 'json'
  require 'uri'
  require 'net/http'
  require 'net/https'
  require 'openssl'

  dispatch :func do
    param 'Hash', :vsphere_settings
    param 'String', :session_id
    param 'Hash', :options
  end

  def func(vsphere_settings, session_id, options)
    vsphere_settings['ssl'] ? prefix='https://' : prefix = 'http://'
    vsphere_settings['insecure'] ? ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE : ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    uri = URI(prefix + vsphere_settings['url'] + options['endpoint'])

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
        when 'Delete'
          request = Net::HTTP::Delete.new(uri.request_uri)
        else #assume GET
          request = Net::HTTP::Get.new(uri.request_uri)
      end
      request['Content-Type'] = 'application/json'
      request['Cookie'] = CGI::Cookie.new('vmware-api-session-id',session_id).to_s
      request.body = "#{options['request_body']}" if defined?(options['request_body'])
      https.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      body=response.body.strip.gsub(/\n/, '').gsub(/^\"|\"$/, '')
      begin
        #body.to_json if options['hash_as_string_to_json']
        return JSON.parse(body) if options['json_parse']
      rescue
        fail("vSphere API Call could not parse result body to JSON: '#{response.body}'")
      end
      return '' if response.body == nil
      return response.body.strip.gsub(/^\"|\"$/, '')
    end

    fail("API Call to vSphere failed: #{response.code} - #{response.class}: #{response.message}")
  end
end