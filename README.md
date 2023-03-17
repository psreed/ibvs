# ibvs


## Description



## Setup


### Setup Requirements 

#### Puppet Modules 
puppetlabs-vsphere
puppetlabs-stdlib

#### All configuration is accomplished via hiera
See data/common.yaml.example for all settings.

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

If using 'puppet apply' for testing, follow this process:

1. in a temporary working directory, create a modules director and 
install the vsphere and stdlib modules. Ensure to use the modulepath
option.
```
mkdir testing
cd testing
mkdir modules
puppet module install puppet-stdlib --modulepath=./modules
puppet module install puppet-vsphere --modulepath=./modules
```
Note: Make sure to install the hocon and rbvmomi gems for vsphere, if 
you have not already done so:
```
/opt/puppetlabs/puppet/bin/gem install rbvmomi --no-rdoc
```
2. Clone this repo/module into the modules directory
```
cd modules
git clone <this repo url>
```
3. Copy ibvs/data/common.yaml.example to ibvs/data/common.yaml
```
cp ibvs/data/common.yaml.example ibvs/data/common.yaml
```
4. Modify the common.yaml for your environment and desired setup
```
vi ibvs/data/common.yaml
```
5. Go back to the root testing directory and create a test puppet file
```
cd ..
vi test.pp
```
The contents should be only 1 line:
```
include ibvs
```
6. Run the 'puppet apply' command with the following options (debug and 
noop are optional) in order to active the module.
```
sudo /opt/puppetlabs/puppet/bin/puppet apply --modulepath=./modules --hiera_config ./modules/ibvs/hiera.yaml test.pp --debug --noop
```
Note: sudo is required to manage and read the vsphere user configuration 
managed by ibvs::vsphere_config. With this method, environment variable are 
not required, however there is a file on disk with password to be managed 
appropriately.

## Usage with Puppet Enterprise (puppet agent mode)

For usage with puppet enterprise, select a node to run ibvs on, create a 
node-level hiera file with the contents of common.yaml.example and classify
the host with ibvs. The host will need to have the rbvmomi and hocon gems 
available.
```
include ibvs
```

## Reference

