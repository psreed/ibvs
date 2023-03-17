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
  contain ibvs::vsphere_conf
  contain ibvs::manage_vms

  Class['ibvs::vsphere_conf']
  -> Class['ibvs::manage_vms']
}
