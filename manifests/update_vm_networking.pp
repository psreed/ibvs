#
class ibvs::update_vm_networking {
  $result = Deferred('ibvs::vsphere::defer::update_vm_networking', [
      $ibvs::vsphere,
      $ibvs::vms,
      $ibvs::vm_profiles,
      $facts['clientnoop'],
  ])
  # NOTE: The next line is required to make sure the deferred function above runs, but will always fail its 'onlyif' check.
  # The user=>$result forces the Deferred function to run, and expects the output of a user that can run '/bin/false'
  exec { 'ibvs::vsphere::defer::update_vm_networking': command => '/bin/true', onlyif => '/bin/false', user => $result }
}
