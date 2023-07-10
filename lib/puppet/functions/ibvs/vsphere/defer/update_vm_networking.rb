#################################################################################################
## Update VM Networking Labels
#################################################################################################
##
## Note: This function is designed to work as a deferred function and requires the Puppet agent
##       to be configured with the "preprocess_deferred" option as "false". 
##       See module notes in README.md for full details.
##
## TODO: Implement --noop capability
## TODO: Add support for external vSphere credential retrieval (i.e. Vault, Azure Keystore, SSM, etc.)
#
Puppet::Functions.create_function(:'ibvs::vsphere::defer::update_vm_networking') do
  require 'cgi'
  require 'json'
  require 'uri'
  require 'net/http'
  require 'net/https'
  require 'openssl'

  dispatch :func do
    param 'Hash', :vsphere
    param 'Hash', :vms
    return_type 'String'
  end

  #################################################################################################
  # Function Name : vsphere_session_start
  # Description   : This function will attempt to start a vSphere session using provided credentials
  # Returns       : A valid vSphere session ID or will fail 
  #################################################################################################
  def vsphere_session_start(vsphere)
    vsphere['ssl'] ? prefix='https://' : prefix = 'http://'
    vsphere['insecure'] ? ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE : ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    uri = URI(prefix + vsphere['host'] + '/api/session')
    response = Net::HTTP.start(uri.host, uri.port, 
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      begin 
        request.basic_auth(vsphere['user'],vsphere['password'].unwrap)
      rescue
        request.basic_auth(vsphere['user'],vsphere['password'])
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

  #################################################################################################
  # Function Name : vsphere_api_call
  # Description   : Function to make an API call to vSphere using a previously obtained session ID
  # Returns       : API Call Output, in JSON format depending on input options
  #################################################################################################
  def vsphere_api_call(vsphere, options={})
    vsphere['ssl'] ? prefix='https://' : prefix = 'http://' 
    vsphere['insecure'] ? ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE : ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    url = prefix + vsphere['host'] + '/api' + options[:endpoint]
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, 
      :use_ssl => uri.scheme == 'https',
      :verify_mode => ssl_verify_mode) do |https|
      case options[:request_type].upcase
        when 'POST'
          request = Net::HTTP::Post.new(uri.request_uri)
        when 'Put'
          request = Net::HTTP::Patch.new(uri.request_uri)
        when 'PATCH'
          request = Net::HTTP::Patch.new(uri.request_uri)
        else #assume GET
          request = Net::HTTP::Get.new(uri.request_uri)
      end
      request['Cookie'] = CGI::Cookie.new('vmware-api-session-id',vsphere['session_id']).to_s
      request['Content-Type'] = 'application/json'
      request.body = "#{options[:request_body]}" if defined?(options[:request_body])
      https.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      begin
        return JSON.parse(response.body.strip.gsub(/^\"|\"$/, '')) if options[:json_parse]
      rescue
        fail("API Call could not parse result body to JSON: '#{response.body}'")
      end
      return '' if response.body == nil
      return response.body.strip.gsub(/^\"|\"$/, '')
    end

    fail("API Call to vSphere failed: #{response.code} - #{response.class}: #{response.message}")
  end
    
  #################################################################################################
  # Main function
  #################################################################################################
  def func(vsphere, vms)
    fn='ibvs::vsphere::defer::update_vm_networking'
    Puppet.debug("#{fn}: Function Started")

    ## Connect to vSphere and get Session ID
    vsphere['session_id']=vsphere_session_start(vsphere)  

    ## Get List of vSphere VMs
    vm_list=vsphere_api_call(vsphere, { request_type: 'GET', endpoint: '/vcenter/vm', json_parse: true })
    #vm_list.each { |v| Puppet.debug("#{fn}: VM Found: #{v['name']} - #{v['vm']}")}

    ## Get List of Networks
    network_list=vsphere_api_call(vsphere, { request_type: 'GET', endpoint: '/vcenter/network', json_parse: true })
    #network_list.each { |n| Puppet.debug("#{fn}: vSphere Network Found: #{n['name']}")}

    ## Loop through VMs and update vSphere VM network backings
    vms.each { |vmdef|
      vm_name = vmdef[0]
      vm_details = vmdef[1].clone

      ### Check if VM is set for 'ensure => present'
      next if vm_details['ensure'] != 'present' 

      ### Get VM ID
      vm_id = ""
      vm_list.each { |v| vm_id = v['vm'] if v['name'] == vm_name }
      fail("#{fn}: Could not get vSphere VM ID from list. Does the VM exist?\nvm_name=#{vm_name}\nlist=#{vm_list}") if vm_id == ""
      #Puppet.debug("#{fn}: VM ID: #{vm_id}")

      ### Get Network by Label
      network = ""
      network_list.each { |n| network = n if n['name'] == vm_details['network_label'] }
      fail("#{fn}: Could not get vSphere Network from list. Does the network exist?\nvm_name=#{vm_name}\nnetwork_label=#{vm_details['network_label']}\nlist=#{networks_list}") if network == ""
      #Puppet.debug("#{fn}: NETWORK: #{network}")

      ### Get Hardware Ethernet details for VM
      vm_hwe = vsphere_api_call(vsphere, { request_type: 'GET', endpoint: "/vcenter/vm/#{vm_id}/hardware/ethernet", json_parse: true })
      vm_hwe_nic = ""
      begin 
        if vm_hwe[0]['nic'] != ""
          vm_hwe_nic=vm_hwe[0]
        end
      rescue
        # Nothing to do in rescue. We want to continue regardless of an exception, which won't matter since we test the variable after this begin/rescue block.
      end
      fail ("#{fn}: Could not get VM Hardware Ethernet Nic Info for VM: #{vm_name}") if vm_hwe_nic == ""
      
      ### Set Hardware Ethernet NIC 0
      #### Get Current Network for Hardware Ethernet NIC
      vm_hwe_nic_details=vsphere_api_call(vsphere, { request_type: 'GET', endpoint: "/vcenter/vm/#{vm_id}/hardware/ethernet/#{vm_hwe_nic['nic']}", json_parse: true })
      network_already_set = false
      begin
        network_already_set = true if vm_hwe_nic_details['backing']['network']==network['network']
      rescue
        # Nothing to do in rescue. If we get an exception, we will try to set the network backing regardless based on 'network_already_set' being 'false'
      end
      
      if !network_already_set
        vsphere_api_call(vsphere, { 
          request_type: 'PATCH', 
          endpoint: "/vcenter/vm/#{vm_id}/hardware/ethernet/#{vm_hwe_nic['nic']}", 
          json_parse: false,
          request_body: { 
            "backing" => {
              "network" => network['network'],
              "type"=> network['type'],
            },
            "start_connected" => true,
            "wake_on_lan_enabled" => true,
          }.to_json
        })
      end

      ### PowerOn Virtual Machine
      #### Check if already powered on
      powered_on=false
      power = vsphere_api_call(vsphere, { request_type: 'GET', endpoint: "/vcenter/vm/#{vm_id}/power", json_parse: true })
      begin 
        powered_on=true if power['state'].downcase == 'powered_on'
      rescue
        # Nothing to do in rescue. If we get an exception, we will try to set the power state of the VM anyway (based on the value of 'powered_on' being 'false')
      end

      #### Power on VM
      power_result = vsphere_api_call(vsphere, { request_type: 'POST', endpoint: "/vcenter/vm/#{vm_id}/power?action=start", json_parse: false }) if !powered_on
    }

    ## Return gracefully
    return 'root' # designed to exit with name of root user (or any other system user that can execute /bin/false)
    
  end
end