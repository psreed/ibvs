# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm/get/
Puppet::Functions.create_function(:'ibvs::vsphere::get_vm_hardware_ethernet') do
    dispatch :func do
      param 'Hash', :vsphere
      param 'String', :session_id
      param 'String', :vm_id
      param 'Integer', :nic_number
      return_type 'Hash'
    end
    
    def func(vsphere, session_id, vm_id,nic_number)
      fn='ibvs::vsphere::get_vm_hardware_ethernet'
      Puppet.debug("#{fn}: Function Started")

      vsphere['ssl'] ? uri="https://#{vsphere['host']}/api/vcenter/vm" : uri="http://#{vsphere['host']}/api/vcenter/vm"   
      cmd = []
      cmd << "/opt/puppetlabs/puppet/bin/curl -s"
      cmd << "--insecure" if vsphere['insecure']
      cmd << "-X GET"
      cmd << "--cookie \"vmware-api-session-id=#{session_id}\""
      cmd << "\"#{uri}/#{vm_id}/hardware/ethernet\""
      cmdstring = cmd.join(' ')
      result = %x[ #{cmdstring} ]
      result.gsub!(/^\"|\"$/, '')

      begin 
        js=JSON.parse(result)
        if js[nic_number]['nic'] != ""
          Puppet.debug("#{fn}: Result: '#{result}'")
          return js[nic_number]
        end
      rescue
      end
      fail("#{fn}\n********\nERROR: Could not fetch requested data from vSphere, message follows:\n#{result}\n********\n\n")
    end
  end
