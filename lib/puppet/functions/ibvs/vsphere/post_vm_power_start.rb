# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm/vm/poweractionstart/post/
Puppet::Functions.create_function(:'ibvs::vsphere::post_vm_power_start') do
    dispatch :func do
      param 'Hash', :vsphere
      param 'String', :session_id
      param 'String', :vm_id
      return_type 'Boolean'
    end
    
    def func(vsphere, session_id, vm_id)
      fn='ibvs::vsphere::post_vm_power_start'
      Puppet.debug("#{fn}: Function Started")

      vsphere['ssl'] ? uri="https://#{vsphere['host']}/api/vcenter/vm" : uri="http://#{vsphere['host']}/api/vcenter/vm"   
      cmd = []
      cmd << "/opt/puppetlabs/puppet/bin/curl -s"
      cmd << "--insecure" if vsphere['insecure']
      cmd << "-X POST"
      cmd << "--cookie 'vmware-api-session-id=#{session_id}'"
      cmd << "-w \"%{http_code}\""
      cmd << "'#{uri}/#{vm_id}/power?action=start'"
      cmdstring = cmd.join(' ')

      #Puppet.debug("#{fn}: Request: '#{cmdstring}'")

      result = %x[ #{cmdstring} ]

      Puppet.debug("#{fn}: Result: '#{result}'")
      
      return true if result.downcase().include? "already_in_desired_state"
      return true if result.to_i < 300 && result.to_i > 199

      fail("#{fn}\n********\nERROR: Could not power on VM, message follows:\n#{result}\n********\n\n")
      
    end
  end