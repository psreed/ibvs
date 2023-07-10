# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/cis/api/session/post/
Puppet::Functions.create_function(:'ibvs::vsphere::post_session') do
  require 'cgi'
  require 'json'
  require 'uri'
  require 'net/http'
  require 'net/https'
  require 'openssl'

  dispatch :func do
    param 'Hash', :vsphere
    return_type 'String'
  end

  #################################################################################################
  # Function Name : vsphere_session_start
  # Description   : This function will attempt to start a vSphere session using provided credentials
  # Returns       : A valid vSphere session ID or will fail 
  #################################################################################################
  def func(vsphere_settings)
    vsphere_settings['ssl'] ? prefix='https://' : prefix = 'http://'
    vsphere_settings['insecure'] ? ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE : ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    uri = URI(prefix + vsphere_settings['url'] + '/session')
    response = Net::HTTP.start(uri.host, uri.port, 
      :use_ssl => uri.scheme == 'https',
      :verify_mode => ssl_verify_mode) do |https|
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      begin 
        request.basic_auth(vsphere_settings['user'],vsphere_settings['password'].unwrap)
      rescue
        request.basic_auth(vsphere_settings['user'],vsphere_settings['password'])
      end
      https.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      begin
        sid = response.body.strip.gsub!(/^\"|\"$/, '')
        fail("vSphere Session ID is invalid: '#{sid}'") if sid.length != 32
        return sid
      rescue
        # Nothing to do in rescue. If we get an exception, we will contiue and fail out the function regarless, but with our own error message
      end
    end
  
    fail("Failed to connect to vSphere: #{response.code} - #{response.class}: #{response.message}")
  end
end
