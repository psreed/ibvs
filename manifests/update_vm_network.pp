#
# @param vm_name
# @param network_label
# @param nic_id
class ibvs::update_vm_network (
  String $vm_name,
  String $network_label = 'VM Network',
  Integer $nic_id = 0
) {
  $vsphere=$ibvs::vsphere
  $sid=ibvs::vsphere::post_session($vsphere)
  if $sid.length == 32 {
    $vms=ibvs::vsphere::get_vm_list($vsphere, $sid)
    $vm_id=ibvs::vsphere::get_vm_id($vms, $vm_name)
    $vm=ibvs::vsphere::get_vm($vsphere, $sid, $vm_id)
    $vm_nic=ibvs::vsphere::get_vm_hardware_ethernet($vsphere, $sid, $vm_id, $nic_id)
    $networks=ibvs::vsphere::get_network_list($vsphere, $sid)
    $network=ibvs::vsphere::get_network($networks, $network_label)
    $patch_result=ibvs::vsphere::patch_vm_hardware_ethernet_nic($vsphere, $sid, $vm_id, $vm_nic, $network)
    if $patch_result {
      $post_result=ibvs::vsphere::post_vm_power_start($vsphere, $sid, $vm_id)
    }
  }
}
