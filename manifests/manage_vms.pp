#
# @summary Create a VM with Infoblox IPAM and vSphere
# - All configuration managed through hiera 
# - See 'data/common.yaml' for default/example configuration options
#
class ibvs::manage_vms {
  $infoblox_settings=$ibvs::infoblox_settings
  $vsphere_settings=$ibvs::vsphere_settings

  # Open a vSphere session, get list of VMs and Networks available
  $vsphere_session=ibvs::vsphere::post_session($vsphere_settings)

  $vsphere_vm_list=ibvs::vsphere::vsphere_api_call($vsphere_settings,$vsphere_session, {
      'request_type'           => 'GET',
      'endpoint'               => '/vcenter/vm',
      'json_parse'             => true,
  })

  $vsphere_network_list=ibvs::vsphere::vsphere_api_call($vsphere_settings,$vsphere_session, {
      'request_type'           => 'GET',
      'endpoint'               => '/vcenter/network',
      'json_parse'             => true,
  })

  $infoblox_reserved_ips=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
      'request_type' => 'GET',
      'endpoint'     => '/fixedaddress?_return_fields%2B=ipv4addr,name,comment',
      'request_body' => '{ "mac": "00:00:00:00:00:00", "comment": "Managed by Puppet" }',
      'json_parse'   => true,
  })['result']

  # Loop through defined VMs
  $ibvs::vms.each | $hostname, $vm | {
    $vm_exists=ibvs::vsphere::check_vm_in_list($vsphere_vm_list, $hostname)

    ## Case 1: vm exists, and should exist
    if $vm_exists and $vm['ensure'] == 'present' {
      $vm_id=ibvs::vsphere::get_vm_id($vsphere_vm_list, $hostname)
      #notify { "Case 1: VM exists, and should exist (${hostname})": }
      $create_condition=false
      $destroy_condition=false
    }
    ## Case 2: vm does not exist, and should not exist
    if !$vm_exists and $vm['ensure'] == 'absent' {
      #notify { "Case 2: VM does not exist, and should not exist (${hostname})": }
      $create_condition=false
      $destroy_condition=false
    }
    ## Case 3: vm does not exist, and should exist
    if !$vm_exists and $vm['ensure'] == 'present' {
      #notify { "Case 3: VM does not exist, and should exist (${hostname})": }
      $create_condition=true
      $destroy_condition=false
    }
    ## Case 3: vm exists, and should not exist
    if $vm_exists and $vm['ensure'] == 'absent' {
      #notify { "Case 4: VM exist, and should not exist (${hostname})": }
      $create_condition=false
      $destroy_condition=true
    }

    $vm_profile= $ibvs::vm_profiles[$vm['profile']]

    ## Destroy VM and remove IP reservation
    if $destroy_condition and !$facts['clientnoop'] {
      # Get existing IP reservation (if it exists)
      $existing_ip=ibvs::infoblox::check_for_reserved_ip_in_list($infoblox_reserved_ips, $hostname, $vm_profile['infoblox_network_view'])
      if $existing_ip != '' {
        # Get list of matching IP records in Infoblox
        $ips_to_remove=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
            'request_type' => 'GET',
            'endpoint'     => "/search?address=${existing_ip}&_return_fields%2B=_ref,ipv4addr,comment,name",
            'json_parse'   => true,
        })['result']
        # Delete any record that matches criteria: VM name, comment and is a fixedaddress record
        $ips_to_remove.each |$k, $v| {
          if $v['name'] == $hostname and $v['comment']=='Managed by Puppet' and $v['_ref'] =~ /^fixedaddress.*/ {
            notify { "Removing IP Reservation: ${v['_ref']}": }
            $remove_ip_result=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
                'request_type' => 'DELETE',
                'endpoint'     => "/${v['_ref']}",
                'json_parse'   => false,
            })
            notify { "Removing IP Reservation ${v['ipv4addr']} Result: ${remove_ip_result}": }
          }
        }
      }
      # Destroy the VM
      # TODO: rewrite this as a direct API call to remove dependancy on pupeptlabs-vsphere module
      vsphere_vm { "/${vm_profile['datacenter']}/vm/${hostname}": ensure => absent, }
    }
    if $destroy_condition and $facts['clientnoop'] {
      notify { "Would have destroyed VM: '${hostname}' (noop)": }
    }

    ## Create VM
    if $create_condition and !$facts['clientnoop'] {
      # Get Infoblox Network _ref for which the VM is/will be a member
      $ib_network=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
          'request_type' => 'GET',
          'endpoint'     => "/network?network=${vm_profile['network']}",
          'json_parse'   => true,
      })['result'][0]['_ref']
      #notify { "ib_network_view: '${ib_network'": }

      # Check if IP reservation already exists
      $existing_ip=ibvs::infoblox::check_for_reserved_ip_in_list($infoblox_reserved_ips, $hostname, $vm_profile['infoblox_network_view'])

      if $existing_ip == '' {
        # Reserve Next IP   
        $ib_reserved_ip=ibvs::infoblox::infoblox_api_call($infoblox_settings, {
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
        })['result']['ipv4addr']
        notify { "ib_reserved_ip (new): '${ib_reserved_ip}'": }
      } else {
        $ib_reserved_ip=$existing_ip
        notify { "ib_reserved_ip (existing): '${ib_reserved_ip}'": }
      }

      #preflight checks
      if $ibvs::templates[$vm['template']] == '' {
        fail("Invalid template selected for host: ${hostname}, template: ${ibvs::templates[$vm_profile['template']]}")
      }

      if $ib_reserved_ip != '' {
        notify { "Creating VM (${hostname})": }

        # Create the VM
        # TODO: rewrite this as a direct API call to remove dependancy on pupeptlabs-vsphere module
        vsphere_vm { "/${vm_profile['datacenter']}/vm/${hostname}":
          ensure        => 'stopped',
          #cpus          => 2,
          #memory        => 512,
          resource_pool => $vm['resource_pool'],
          source        => $ibvs::templates[$vm_profile['template']]['path'],
        }
      }
    }
    if $create_condition and $facts['clientnoop'] {
      notify { "Would have created VM: '${hostname}' (noop)": }
    }
  }
}
