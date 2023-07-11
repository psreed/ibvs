#
# @summary Infoblox IPAM integration for vShere Deployment
#
# @param infoblox    - Infoblox configuration hash, see common.yaml.example for structure
# @param vsphere     - vSphere configuration hash, see common.yaml.example for structure
# @param templates   - List of VM Templates and metadata, see common.yaml.example for structure
# @param vms         - List of VMs to deplay/maintain/decommission, see common.yaml.example for structure
# @param vm_profiles - List of profiles for VMs, see common.yaml.example for structure
# @param puppet      - Puppet agent configuration settings, see common.yaml.example for structure
#
class ibvs (
  Hash  $infoblox,
  Hash  $vsphere,
  Hash  $templates,
  Hash  $vm_profiles,
  Hash  $vms,
  Hash  $puppet,
) {
  # setup modlue-wide vars based on Hiera config
  $infoblox_settings = {
    'user'     => $ibvs::infoblox['user'],
    'password' => Sensitive($ibvs::infoblox['password'].unwrap),
    'wapi_url' => "${ibvs::infoblox['wapi_host']}/wapi/${ibvs::infoblox['wapi_version']}",
    'noop'     => $facts['clientnoop'],
    'ssl'      => $ibvs::infoblox['ssl'],
    'insecure' => $ibvs::infoblox['insecure'],
  }
  $vsphere_settings = {
    'user'     => $ibvs::vsphere['user'],
    'password' => Sensitive($ibvs::vsphere['password'].unwrap),
    'host'     => $ibvs::vsphere['host'],
    'url'      => "${ibvs::vsphere['host']}/api",
    'noop'     => $facts['clientnoop'],
    'ssl'      => $ibvs::vsphere['ssl'],
    'insecure' => $ibvs::vsphere['insecure'],
    'puppet'   => $ibvs::puppet['server'],
  }

  #Setup stages for order of operations
  stage { 'vsphere_config': }
  stage { 'vm_creation': }
  stage { 'vm_creation_extraconfig': }
  stage { 'vm_creation_networking': }
  Stage['vsphere_config']
  -> Stage['main']
  -> Stage['vm_creation']
  -> Stage['vm_creation_extraconfig']
  -> Stage['vm_creation_networking']

  class { 'ibvs::vsphere_conf': stage => 'vsphere_config' }
  class { 'ibvs::manage_vms': stage => 'vm_creation' }
  class { 'ibvs::update_vm_extraconfig': stage => 'vm_creation_extraconfig' }
  class { 'ibvs::update_vm_networking': stage => 'vm_creation_networking' }
}
