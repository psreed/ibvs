# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm/vm/hardware/ethernet/nic/patch/
Puppet::Functions.create_function(:'ibvs::vsphere::patch_vm_hardware_ethernet_nic') do
    dispatch :func do
      param 'Hash', :vsphere
      param 'String', :session_id
      param 'String', :vm_id
      param 'Hash', :vm_nic
      param 'Hash', :network
      return_type 'Boolean'
    end
    
    def func(vsphere, session_id, vm_id, vm_nic, network)
      fn='ibvs::vsphere::patch_vm_hardware_ethernet_nic'
      Puppet.debug("#{fn}: Function Started")

      payload={ 
        "backing" => {
          "network" => network['network'],
          "type"=> network['type'],
        },
        "start_connected" => true,
        "wake_on_lan_enabled" => true,
      }.to_json

      vsphere['ssl'] ? uri="https://#{vsphere['host']}/api/vcenter/vm" : uri="http://#{vsphere['host']}/api/vcenter/vm"   
      cmd = []
      cmd << "/opt/puppetlabs/puppet/bin/curl -s"
      cmd << "--insecure" if vsphere['insecure']
      cmd << "-X PATCH"
      cmd << "-H 'Content-Type: application/json'"
      cmd << "--cookie 'vmware-api-session-id=#{session_id}'"
      cmd << "-d '#{payload}'"
      cmd << "-w \"%{http_code}\""
      cmd << "'#{uri}/#{vm_id}/hardware/ethernet/#{vm_nic['nic']}'"
      cmdstring = cmd.join(' ')

      #Puppet.debug("#{fn}: Request: '#{cmdstring}'")

      result = %x[ #{cmdstring} ]

      Puppet.debug("#{fn}: Result: '#{result}'")

      return true if result.to_i < 300 && result.to_i > 199

      fail("#{fn}\n********\nERROR: Could not update NIC, message follows:\n#{result}\n********\n\n")
      
    end
  end
