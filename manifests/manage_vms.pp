#
# @summary Create a VM with Infoblox IPAM and vSphere
# - All configuration managed through hiera 
# - See 'data/common.yaml' for default/example configuration options
#
# @param vmlist
#   List of VMs in the form { $hostname { ensure=>absent/present, profile=>default} }
#   Default: Will obtain list from hiera (common.yaml)
class ibvs::manage_vms (
  Hash $vmlist = $ibvs::vms
) {
  #lint:ignore:140chars
  $noop = $facts['clientnoop']

  $infoblox_settings = $ibvs::infoblox_settings
  $vsphere_settings = $ibvs::vsphere_settings

  # Open a vSphere session, get list of VMs and Networks available
  $vsphere_session = ibvs::vsphere::post_session($vsphere_settings)

  $vsphere_vm_list = ibvs::vsphere::vsphere_api_call($vsphere_settings,$vsphere_session, {
      'request_type'           => 'GET',
      'endpoint'               => '/vcenter/vm',
      'json_parse'             => true,
  })

  $vsphere_network_list = ibvs::vsphere::vsphere_api_call($vsphere_settings,$vsphere_session, {
      'request_type'           => 'GET',
      'endpoint'               => '/vcenter/network',
      'json_parse'             => true,
  })

  $infoblox_reserved_ips = ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
      'request_type' => 'GET',
      'endpoint'     => '/fixedaddress?_return_fields%2B=ipv4addr,name,comment',
      'request_body' => '{ "mac": "00:00:00:00:00:00", "comment": "Managed by Puppet" }',
      'json_parse'   => true,
  })['result']

  # Loop through defined VMs
  $vmlist.each | $hostname, $vm | {
    # Get VM Profile
    $vm_profile = $ibvs::vm_profiles[$vm['profile']]

    # Check if VM exists
    $vm_exists = ibvs::vsphere::check_vm_in_list($vsphere_vm_list, $hostname)

    # Check if IP reservation exists for host
    $existing_ip = ibvs::infoblox::check_for_reserved_ip_in_list($infoblox_reserved_ips, $hostname, $vm_profile['infoblox_network_view'])
    $ip_exists = $existing_ip ? { '' => false, default => true }
    ibvs::debug_message("[${hostname}] - Existing IP?: ${ip_exists}")

    # Check for existing DNS Record for host
    if $vm_profile['infoblox_manage_by_dns'] {
      $existing_dns_record=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
          'request_type' => 'GET',
          'endpoint'     => '/record:host?_return_fields%2B=name,comment,ipv4addrs',
          'request_body' => "{
            \"name\": \"${hostname}\",
            \"comment\": \"Managed by Puppet\",
            \"view\": \"${vm_profile['infoblox_dns_view']}\"
          }",
          'json_parse'   => true,
      })['result']
      $dns_record_exists = $existing_dns_record[0] ? { undef => false, default => true }
      ibvs::debug_message("[${hostname}] - Existing DNS Record?: ${dns_record_exists}")
    }

    ## Set Conditions
    if $vm_exists and $vm['ensure'] == 'present' { $vm_condition = 'vm_exists_and_should_exist' } # Check IP and DNS are present
    if !$vm_exists and $vm['ensure'] == 'absent' { $vm_condition = 'vm_does_not_exist_and_should_not_exist' } # Check IP and DNS are absent
    if !$vm_exists and $vm['ensure'] == 'present' { $vm_condition = 'vm_does_not_exist_and_should_exist' } # Create VM, Check IP and DNS are present
    if $vm_exists and $vm['ensure'] == 'absent' { $vm_condition = 'vm_exists_and_should_not_exist' }  # Destroy VM, Check IP and DNS are absent
    ibvs::debug_message("[${hostname}] - VM Condition: ${vm_condition}")

    ## Manage IP Address Reservation
    ### IP Create
    if ($vm_condition == 'vm_exists_and_should_exist' or $vm_condition == 'vm_does_not_exist_and_should_exist')
    and !$ip_exists
    and !$vm_profile['infoblox_manage_by_dns'] {
      ibvs::debug_message("[${hostname}] - IP Condition: IP Needs to be created")
      if $noop { notify { "[${hostname}] - [NOOP] - Would have created IP reservation": } }
      else {
        $reserved_ip_result=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
            'request_type' => 'POST',
            'endpoint'     => '/fixedaddress?_return_fields%2B=ipv4addr',
            'request_body' => "{
              \"ipv4addr\": \"func:nextavailableip:${vm_profile['network']},${vm_profile['infoblox_network_view']}\",
              \"mac\": \"00:00:00:00:00:00\",
              \"network_view\": \"${vm_profile['infoblox_network_view']}\",
              \"name\": \"${hostname}\",
              \"comment\": \"Managed by Puppet\"
            }",
            'json_parse'   => true,
        })['result']
        notify { "[${hostname}] - Created IP Address Reservation": message=> "Result: ${reserved_ip_result}" }
        $reserved_ip=$reserved_ip_result['ipv4addr']
      }
    } elsif !$vm_profile['infoblox_manage_by_dns'] {
      $reserved_ip = $existing_ip # Needed in the offchance the IP already exists, but the VM needs to be created
    }

    ### IP Destroy 
    if ($vm_condition == 'vm_does_not_exist_and_should_not_exist' or $vm_condition == 'vm_exists_and_should_not_exist' ) and $ip_exists {
      ibvs::debug_message("[${hostname}] - IP Condition: IP Needs to be destroyed")
      ibvs::debug_message("[${hostname}] - Reclaiming IP: ${existing_ip}")
      $ips_to_remove=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
          'request_type' => 'GET',
          'endpoint'     => "/search?address=${existing_ip}&_return_fields%2B=_ref,ipv4addr,comment,name",
          'json_parse'   => true,
      })['result']
      # Delete any record that matches criteria: VM name, comment and is a fixedaddress record
      $ips_to_remove.each |$k, $v| {
        if $v['name'] == $hostname and $v['comment']=='Managed by Puppet' and $v['_ref'] =~ /^fixedaddress.*/ {
          if $noop { notify { "[${hostname}] - [NOOP] - Would have removed IP reservation: ${v['_ref']}": } }
          else {
            $removed_ip_result=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
                'request_type' => 'DELETE',
                'endpoint'     => "/${v['_ref']}",
                'json_parse'   => false,
            })
            notify { "[${hostname}] - Removed IP Address Reservation": message=> "Removed: ${v}\nResult: ${removed_ip_result}" }
          }
        }
      }
    }

    ## Manage DNS Record
    if $vm_profile['infoblox_manage_by_dns'] {
      ### DNS Create
      if ($vm_condition == 'vm_exists_and_should_exist' or $vm_condition == 'vm_does_not_exist_and_should_exist') and !$dns_record_exists {
        ibvs::debug_message("[${hostname}] - DNS Record Condition: DNS Record Needs to be created")
        if $noop { notify { "[${hostname}] - [NOOP] - Would have created DNS Host Record": } }
        else {
          $dns_record_result=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
              'request_type' => 'POST',
              'endpoint'     => '/record:host?_return_fields%2B=name,comment,ipv4addrs',
              'request_body' => "{
                \"name\": \"${hostname}\",
                \"ipv4addrs\": [{
                    \"ipv4addr\": \"func:nextavailableip:${vm_profile['network']},${vm_profile['infoblox_network_view']}\",
                    \"mac\": \"00:00:00:00:00:00\"
                }],              
                \"comment\": \"Managed by Puppet\",
                \"view\": \"${vm_profile['infoblox_dns_view']}\"
              }",
              'json_parse'   => true,
          })['result']
          notify { "[${hostname}] - Created DNS Host Record": message=> "Result: ${dns_record_result}" }
        }
      }

      ### DNS Destroy
      if ($vm_condition == 'vm_does_not_exist_and_should_not_exist' or $vm_condition == 'vm_exists_and_should_not_exist' ) and $dns_record_exists {
        ibvs::debug_message("[${hostname}] - DNS Record Condition: DNS Record Needs to be destroyed")
        if $existing_dns_record[0] != undef and $existing_dns_record[0]['_ref'] != undef {
          ibvs::debug_message("[${hostname}] - Removing DNS Host Record: ${existing_dns_record[0]}")
          if $noop { notify { "[${hostname}] - [NOOP] - Would have removed DNS Host Record: ${existing_dns_record[0]}": } }
          else {
            $dns_record_remove_result=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
                'request_type' => 'DELETE',
                'endpoint'     => "/${existing_dns_record[0]['_ref']}",
                'json_parse'   => false,
            })
            notify { "[${hostname}] - Removed DNS Host Record": message=> "Removed: ${existing_dns_record[0]}\nResult: ${dns_record_remove_result}" }
          }
        }
      }
    }

    ## Manage vSphere VM
    ## Destroy VM
    if $vm_condition == 'vm_exists_and_should_not_exist' {
      if $noop { notify { "[${hostname}] - Would have destroyed VM: '${hostname}' (noop)": } }
      else {
        vsphere_vm { "/${vm_profile['datacenter']}/vm/${hostname}": ensure => absent, }
      }
    }

    ## Create VM
    if $vm_condition == 'vm_does_not_exist_and_should_exist' {
      #preflight checks
      if $ibvs::templates[$vm['template']] == '' {
        fail("Invalid template selected for host: ${hostname}, template: ${ibvs::templates[$vm_profile['template']]}")
      }

      # Create the VM
      if $noop { notify { "[${hostname}] - [NOOP] - Would have created vSphere VM": } }
      else {
        vsphere_vm { "/${vm_profile['datacenter']}/vm/${hostname}":
          ensure        => 'stopped',
          cpus          => $vm_profile['cpus'],
          memory        => $vm_profile['memory'],
          resource_pool => $vm_profile['resource_pool'],
          source        => $ibvs::templates[$vm_profile['template']]['path'],
        }
      }
    }
  }
  #lint:endignore
}
