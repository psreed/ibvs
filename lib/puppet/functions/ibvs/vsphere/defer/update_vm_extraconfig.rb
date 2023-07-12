# Adapted from: https://github.com/ManageIQ/rbvmomi2/blob/master/examples/extraConfig.rb
# Note: This needs to be run as a Deferred function after VM creation has occurred
#
Puppet::Functions.create_function(:'ibvs::vsphere::defer::update_vm_extraconfig') do
  require 'rbvmomi'

  dispatch :func do
    param 'Hash', :vsphere_settings
    param 'Hash', :vms
    param 'Hash', :vm_profiles
    param 'Hash', :vm_templates
    param 'Tuple', :reserved_ips
    param 'Tuple', :dns_records
    param 'Boolean', :noop
    return_type 'String'
  end

  def func(vsphere_settings, vms, vm_profiles, vm_templates, reserved_ips, dns_records, noop)
    Puppet.debug('ibvs::vsphere::defer::update_vm_extraconfig: Function Started')

    Puppet.debug('ibvs::vsphere::defer::update_vm_extraconfig: NOOP MODE DETECTED') if noop
    return 'root' if noop

    vim = RbVmomi::VIM.connect(
      host: vsphere_settings['host'],
      user: vsphere_settings['user'],
      password: vsphere_settings['password'].unwrap,
      ssl: vsphere_settings['ssl'],
      insecure: vsphere_settings['insecure']
    )

    # Conditions to set extraconfig when the following is true
    # [Condition 1]- VM should exist (hiera check). No need to config VMs that are absent/removed on this run
    # [Condition 2]- VM does exist (vsphere check). Skip if VM ID is not returned
    # [Condition 3]- VM does not have 'guestinfo.puppet.firstrun' set (vshpere check)
    # [Condition 3]- VM does not have 'guestinfo.puppet.firstruncomplete' set (vshpere check)
    vms.each { |v|
      vm=v[1].clone
      vm['name']="#{v[0]}"
      vm_profile=vm_profiles[vm['profile']]

      next if vm['ensure'] != 'present' # [Condition 1]

      dc = vim.serviceInstance.find_datacenter(vm_profile['datacenter']) || fail("Specified datacenter (#{vm_profile['datacenter']}) was not found")
      vmobj = dc.find_vm(vm['name']) || next # [Condition 2]
      #Puppet.debug("#{vm['name']}: #{vm.keys}")   

      # Find reserved IP for vm['name']
      if vm_profile['infoblox_manage_by_dns'] 
        reserved_ip=nil
        dns_records.each { |rip| 
          #Puppet.debug("Testing: '#{rip}' vs '#{vm}'")
          begin reserved_ip = rip['ipv4addrs'][0]['ipv4addr']; break; end if rip['name'] == vm['name'] 
        }
        next if !reserved_ip # Skip this VM if we don't have an address in the reserved list    
      else
        reserved_ip=nil
        reserved_ips.each { |rip| begin reserved_ip = rip['ipv4addr']; break; end if rip['name'] == vm['name'] }
        next if !reserved_ip # Skip this VM if we don't have an address in the reserved list    
      end
      Puppet.debug("Reserved IP: #{reserved_ip}")
      # Get extraconfig
      vmobj.config.extraConfig.each { |x| next if x.key == 'guestinfo.puppet.firstrun' || x.key == 'guestinfo.puppet.firstruncomplete' } # [Condition 3]
      #Puppet.debug("VM Does not have guestinfo key set")

      template=vm_templates[vm_profile['template']]['firstboot_script']
      template.gsub! '<%= $hostname %>', vm['name']
      template.gsub! "<%= $vm['interface'] %>", vm_profile['interface']
      template.gsub! '<%= $ipaddress %>', "#{reserved_ip}/#{vm_profile['network'].split(/\//)[1]}"
      template.gsub! "<%= $vm['gateway'] %>", vm_profile['gateway']
      template.gsub! "<%= join($vm['dns'], ' ') %>", vm_profile['dns'].join(' ')
      template.gsub! "<%= $puppet['server'] %>", vsphere_settings['puppet']
      template.gsub! "<%= $vm['puppet_psk'] %>", vm_profile['puppet_psk']
      template.gsub! "<%= $vm['puppet_role'] %>", vm_profile['puppet_role']

      extra_config = {
        'guestinfo.infoblox.ipaddress' => reserved_ip,
        'guestinfo.infoblox.hostname'  => vm['name'],
        'guestinfo.puppet.firstrun'    => template,
      }

      extraConfig = []
      extra_config.each_pair { |k,v| extraConfig << { key: k, value: v} }
      vmobj.ReconfigVM_Task(spec: RbVmomi::VIM.VirtualMachineConfigSpec(extraConfig: extraConfig)).wait_for_completion
     }

    return 'root' # designed to exit with name of root user (or any other system user that can execute /bin/false)
  end
end