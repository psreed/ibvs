# 
Puppet::Functions.create_function(:'ibvs::vsphere::check_vm_in_list') do
    dispatch :func do
      param 'Tuple', :vm_list
      param 'String', :vm_name
      return_type 'Boolean'
    end
    
    def func(vm_list, vm_name)
      fn='ibvs::vsphere::check_vm_in_list'
      #Puppet.debug("#{fn}: Function Started")

      vm_list.each { |v| return true if v['name'] == vm_name }

      return false
    end
  end
