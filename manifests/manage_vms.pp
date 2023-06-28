#
# @summary Create a VM with Infoblox IPAM and vSphere
# - All configuration managed through hiera 
# - See 'data/common.yaml' for default/example configuration options
#
class ibvs::manage_vms {
  # Setup Infoblox settings hash:
  $infoblox_settings = {
    'user' => $ibvs::infoblox['user'],
    'password'=> Sensitive($ibvs::infoblox['password'].unwrap),
    'wapi_url' => "https://${ibvs::infoblox['wapi_host']}/wapi/${ibvs::infoblox['wapi_version']}",
    'view' => $ibvs::infoblox['view'],
    'noop' => $facts['clientnoop'],
  }

  $ibvs::vms.each | $hostname, $vm | {
    $host_info=ibvs::infoblox::get_host_info($hostname,$infoblox_settings)

    # Set Action Conditions for VM:
    # Case 1: Exists and should (do nothing)
    if $vm['ensure'] == 'present' and $host_info['code'] == 0 {
      $create_condition=false
      $destroy_condition=false
    }
    #Case 2: Exists and should not:
    if $vm['ensure'] == 'absent' and $host_info['code'] == 0 {
      $create_condition=false
      $destroy_condition=true
    }
    #Case 3: Does not exist and should:
    if $host_info['code'] != 0 and $vm['ensure'] == 'present' {
      $create_condition=true
      $destroy_condition=false
    }
    #Case 4: Does not exist and should not:
    if $host_info['code'] != 0 and $vm['ensure'] == 'absent' {
      $create_condition=false
      $destroy_condition=false
    }

    # Remove VMs
    if $destroy_condition and !$facts['clientnoop'] {
      notify { "Removing VM (${hostname}) from vSphere": }
      vsphere_vm { "/${vm['datacenter']}/vm/${hostname}":
        ensure=> absent,
      }
      notify { "Reclaiming IP (${host_info['ip']}) to Infoblox": }
      $reclaim_ip_ref=ibvs::infoblox::get_ip_ref($host_info['ip'], $infoblox_settings)
      $reclaim_result=ibvs::infoblox::reclaim_ip_by_ref($reclaim_ip_ref,$infoblox_settings)
    }
    if $destroy_condition and $facts['clientnoop'] {
      notify { "Would have removed VM (${hostname}) from vSphere": }
      notify { "Would have reclaimed IP (${host_info['ip']}) to Infoblox": }
    }

    # Create VMs and Set IPs
    if $create_condition and !$facts['clientnoop'] {
      #preflight checks
      if $ibvs::templates[$vm['template']] == '' {
        fail("Invalid template selected for host: ${hostname}, template: ${ibvs::templates[$vm['template']]}")
      }
      $epp_template=$ibvs::templates[$vm['template']]['firstboot_script']

      notify { "Reserving IP from Infoblox for '${hostname}' on network: '${vm['network']}' with network_view: '${$vm['infoblox_network_view']}' and dns_view: '${$vm['infoblox_dns_view']}'": } #lint:ignore:140chars
      $newip=ibvs::infoblox::add_host_with_next_ip(
        $hostname, $vm['network'],
        $vm['infoblox_dns_view'],
        $vm['infoblox_network_view'],
        $infoblox_settings
      )
      if $newip != '' {
        notify { "Creating VM (${hostname})": }
        vsphere_vm { "/${vm['datacenter']}/vm/${hostname}":
          ensure        => present,
          cpus          => 2,
          memory        => 512,
          resource_pool => $vm['resource_pool'],
          source        => "/${vm['datacenter']}/vm/${ibvs::templates[$vm['template']]['path']}",
          extra_config  => {
            'guestinfo.infoblox.ipaddress' => $newip,
            'guestinfo.infoblox.hostname'  => $hostname,
            'guestinfo.puppet.firstrun'    => inline_epp($epp_template, {
                'hostname'  => $hostname,
                'ipaddress' => "${newip}/${split($vm['network'],/\//)[1]}",
                'puppet'    => $ibvs::puppet,
            }),
          },
        }
      }
    }
    if $create_condition and $facts['clientnoop'] {
      notify { "Would have reserved IP from Infoblox for '${hostname}' on network: '${vm['network']}' ": }
      notify { "Would have created VM (${hostname})": }
    }
  }
}
