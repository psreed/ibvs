# ibvs


## Description

This module is intended to ease the user of management of VMs with the 
puppetlabs-vsphere, while including the use of integrated IPAM with Infoblox.

## Setup

### Required Puppet Modules 

* puppetlabs-vsphere
* puppetlabs-stdlib

### All vSphere, Infoblox, VM, VM Template and Puppet config is managed via Hiera

See `data/common.yaml.example` for all settings and options.

## VM Template Preperation

Linux based VM templates should have the following line added to their
crontab in order to activate the integration fully. This will include 
he setting of IP address information, hostname and installing the 
puppet agent automatically.
```
@reboot vmtoolsd --cmd "info-get guestinfo.puppet.firstrun" | /bin/bash -s
```

For Windows based VM templates, a similar job should be added to scheduled 
tasks to run on boot.

## Using with 'puppet apply ...'

If using `puppet apply` for testing on a workstation, follow this process:

1. in a temporary working directory, create a `modules` directory and 
install the `puppetlabs-vsphere` and `puppetlabs-stdlib` modules. Ensure to
use the `--modulepath=./` option.
```
mkdir testing
cd testing
mkdir modules
puppet module install puppet-stdlib --modulepath=./modules
puppet module install puppet-vsphere --modulepath=./modules
```
Note: Make sure to install the `hocon` and `rbvmomi` gems which are required
for use with the `puppetlabs-vsphere` module:
```
/opt/puppetlabs/puppet/bin/gem install hocon --no-rdoc
/opt/puppetlabs/puppet/bin/gem install rbvmomi --no-rdoc
```
2. Clone this repository/module into the `modules` directory
```
cd modules
git clone https://github.com/psreed/ibvs.git
```
3. While still in the `modules` directory, Copy `ibvs/data/common.yaml.example`
to `ibvs/data/common.yaml`:
```
cp ibvs/data/common.yaml.example ibvs/data/common.yaml
```
4. Modify the `common.yaml` for your environment and desired setup
```
vi ibvs/data/common.yaml
```
5. Go back to the testing directory and run the 'puppet apply' command with the 
following options (debug and noop are optional) in order to active the module.
```
cd ..
sudo /opt/puppetlabs/puppet/bin/puppet apply \
  --modulepath=./modules \
  --hiera_config ./modules/ibvs/hiera.yaml \
  -e 'include ibvs' --debug --noop
```
Note: sudo is required to manage and read the vsphere user configuration 
managed by ibvs::vsphere_config. With this method, environment variable are 
not required, however there is a file on disk with password to be managed 
appropriately.

## Usage with Puppet Enterprise (puppet agent mode)

For usage with puppet enterprise, select a node to run `ibvs` on, create a 
node-level hiera file with the contents of `common.yaml.example` (modify as
needed) and then classify the host with `ibvs`. The host will need to have 
the `rbvmomi` and `hocon` gems available as per the note above in the 
'puppet apply' section.

## Reference

