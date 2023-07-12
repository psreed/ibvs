#
class ibvs::update_vm_extraconfig {
  # Loop through VMs and get required info for extraconfigs

  $reserved_ips=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
      'request_type' => 'GET',
      'endpoint'     => '/fixedaddress?_return_fields%2B=ipv4addr,name,comment',
      'request_body' => '{ "mac": "00:00:00:00:00:00", "comment": "Managed by Puppet" }',
      'json_parse'   => true,
  })['result']

#/record:host?_return_fields%2B=name,comment,ipv4addrs&_return_as_object=1
  $dns_records=ibvs::infoblox::infoblox_api_call($ibvs::infoblox_settings, {
      'request_type' => 'GET',
      'endpoint'     => '/record:host?_return_fields%2B=name,comment,ipv4addrs',
      'request_body' => '{ "comment": "Managed by Puppet" }',
      'json_parse'   => true,
  })['result']

  $result = Deferred('ibvs::vsphere::defer::update_vm_extraconfig',
    [
      $ibvs::vsphere_settings,
      $ibvs::vms,
      $ibvs::vm_profiles,
      $ibvs::templates,
      $reserved_ips,
      $dns_records,
      $facts['clientnoop'],
  ])
  # NOTE: The next line is required to make sure the deferred function above runs, but will always fail its 'onlyif' check.
  # The user=>$result forces the Deferred function to run, and expects the output of a user that can run '/bin/false'
  exec { 'ibvs::vsphere::defer::update_vm_extraconfig': command => '/bin/true', onlyif => '/bin/false', user => $result }
}
