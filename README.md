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
the setting of IP address information, hostname and installing the 
puppet agent automatically from details provided through Hiera.
The following should be added to a new file named 
`/etc/cron.d/puppet_first_run`:
```
@reboot root vmtoolsd --cmd "info-get guestinfo.puppet.firstrun" | /bin/bash -s
```
NOTE: This file can be removed afterward once connected to the 
network on it's new IP.

For Windows based VM templates, a similar job should be added to scheduled 
tasks to run on boot.

## Puppet Agent Requirements (v7.17.0 & preprocess_deferred=false)

In order to support the use of the `preprocess_deferred=false` configuration option
Puppet Agent v7.17.0 or above must be used.

The Puppet agent used to run this module must have the `preprocess_deferred` set 
to `false`. By default, this setting is `true` and will cause items to run out of 
order and create unexpected results.

This can be accomplished on the agent side by running the following command:
 ```
 sudo puppet config set --section=main preprocess_deferred false
 ```

## Using with 'puppet apply ...'

If using `puppet apply` for testing on a workstation, follow this process:

1. in a temporary working directory, create a `modules` directory and 
install the `puppetlabs-vsphere` and `puppetlabs-stdlib` modules. Ensure to
use the `--modulepath=./modules` option.
```
mkdir testing
cd testing
mkdir modules
puppet module install puppetlabs-stdlib --modulepath=./modules
puppet module install puppetlabs-vsphere --modulepath=./modules
```
Note: Make sure to install the `hocon` and `rbvmomi2` gems which are required
for use with the `puppetlabs-vsphere` module. Note, this should be done using sudo:
```
sudo /opt/puppetlabs/puppet/bin/gem install hocon
sudo /opt/puppetlabs/puppet/bin/gem install rbvmomi2
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
4. Modify the `common.yaml` for your environment and desired setup. All entries which
are encased in angled brackets `< >` must be set to your environment specifics.
Note: Passwords and other strings with special characters should be enclosed in 
single quotes:
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

