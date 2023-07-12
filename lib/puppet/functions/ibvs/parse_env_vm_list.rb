# Get Environment Variables
Puppet::Functions.create_function(:'ibvs::parse_env_vm_list') do
  
  dispatch :func do
    param 'String', :vm_list
    param 'String', :vm_profile
    param 'String', :action
    param 'String', :action_accept_irreversible
    return_type 'Hash'
  end

  def func(vm_list, vm_profile, action, action_accept_irreversible)
    vms = {}
    vm_list.split(',').each { |vm| 
      # make sure the accept_action_irreversible is set for destroy actions
      next if action == 'destroy' and action_accept_irreversible != 'true'
      
      # Ensure VMs are FQDN format
      next if !vm.match(/(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)/) 

      ens = 'present' if action == 'create'
      ens = 'absent' if action == 'destroy'

      vms[vm] = { ensure: ens, profile: vm_profile }
      #Puppet.debug("Environment VM LIST: #{vms}")
    }
    return vms
  end
end