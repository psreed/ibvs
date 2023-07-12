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
# Environment overrides
# @param env_vms     - Provide an input VM List. This expects a comma seperated list of FQDNs.
#                      Designed for use with Puppet Apply, See README.md
#                      The module will use the Hiera list "ibvs::vms" if this is left empty. 
#                      Default is the string value '_use_hiera_'
# @param env_vm_profile - Environment override for VM Profile to use with "env_vms". 
#                         Defaults to "default"
# @param env_action  - Environment override action to perform on "env_vms" list, valid actions are 'create' or 'destroy'. 
#                      Defaults to 'present'
# @param env_accept_irreversible_action - Environment override used when "env_action"=="absent" to make sure you really want to destroy. 
#                      Defaults to 'false', must be explicitly set to 'true' for 'env_action'='destroy' to work.
#
class ibvs (
  Hash $infoblox,
  Hash $vsphere,
  Hash $templates,
  Hash $vm_profiles,
  Hash $vms,
  Hash $puppet,
  String $env_vms = '_use_hiera_',
  String $env_vm_profile = 'default',
  String $env_action = 'create',
  String $env_accept_irreversible_action = 'false'

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

  # Check if we're using environment overrides and prepare the VM List
  if $env_vms != '_use_hiera_' {
    $vmlist = ibvs::parse_env_vm_list($env_vms, $env_vm_profile, $env_action, $env_accept_irreversible_action)
  } else { $vmlist = $vms }
  ibvs::debug_message("VM Input List: ${vmlist}")

  # Check environment for VMlist override
  class { 'ibvs::vsphere_conf': stage => 'vsphere_config' }
  class { 'ibvs::manage_vms': vmlist => $vmlist, stage  => 'vm_creation', }
  class { 'ibvs::update_vm_extraconfig': stage => 'vm_creation_extraconfig' }
  class { 'ibvs::update_vm_networking': stage => 'vm_creation_networking' }
}
