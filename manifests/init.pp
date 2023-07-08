#
# @summary Infoblox IPAM integration for vShere Deployment
#
# @param infoblox   - Infoblox configuration hash, see common.yaml.example for structure
# @param vsphere    - vSphere configuration hash, see common.yaml.example for structure
# @param templates  - List of VM Templates and metadata, see common.yaml.example for structure
# @param vms        - List of VMs to deplay/maintain/decommission, see common.yaml.example for structure
# @param puppet     - Puppet agent configuration settings, see common.yaml.example for structure
#
class ibvs (
  Hash  $infoblox,
  Hash  $vsphere,
  Hash  $templates,
  Hash  $vms,
  Hash  $puppet,
) {
  #Setup stages for order of operations
  stage { 'vsphere_config': }
  stage { 'vm_creation_pre': }
  stage { 'vm_creation': }
  stage { 'vm_creation_post': }
  Stage['vsphere_config']
  -> Stage['main']
  -> Stage['vm_creation_pre']
  -> Stage['vm_creation']
  -> Stage['vm_creation_post']

  class { 'ibvs::vsphere_conf': stage => 'vsphere_config' }
  class { 'ibvs::manage_vms': stage => 'vm_creation' }
  class { 'ibvs::update_vm_networking': stage => 'vm_creation_post' }
}
