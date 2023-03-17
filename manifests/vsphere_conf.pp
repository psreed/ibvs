# 
# @summary Manage vSphere configuration file
#
class ibvs::vsphere_conf {
  $confdir = $facts['kernel'] ? {
    'windows' => 'C:\\ProgramData\\PuppetLabs\\puppet\\etc',
    default => '/etc/puppetlabs/puppet',
  }
  file { "${confdir}/vcenter.conf":
    mode    => '0600',
    content => epp('ibvs/vcenter.conf.epp', {
        'host'     => $ibvs::vsphere['host'],
        'user'     => $ibvs::vsphere['user'],
        'password' => $ibvs::vsphere['password'].unwrap,
        'port'     => $ibvs::vsphere['port'],
        'insecure' => $ibvs::vsphere['insecure'],
        'ssl'      => $ibvs::vsphere['ssl'],
    }),
  }
}
