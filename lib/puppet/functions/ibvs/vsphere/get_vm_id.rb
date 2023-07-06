# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm
Puppet::Functions.create_function(:'ibvs::vsphere::get_vm_id') do
    dispatch :func do
      param 'Tuple', :vms
      param 'String', :vm_name
      return_type 'String'
    end
    
    def func(vms, vm_name)
      fn='ibvs::vsphere::get_vm_id'
      Puppet.debug("#{fn}: Function Started")

      vms.each { |v| return v['vm'] if v['name'] == vm_name }

      fail("#{fn}\n********\nERROR: Could not retrieve VM ID from VM List (VM not in list?)\n********\n\n")
    end
  end
