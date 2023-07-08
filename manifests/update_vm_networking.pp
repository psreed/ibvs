#
class ibvs::update_vm_networking (
) {
  $ibvs::vms.each | $hostname, $vm | {
    $result = Deferred('ibvs::vsphere::update_vm_network_labels', [$ibvs::vsphere, $ibvs::vms])
  }
}
