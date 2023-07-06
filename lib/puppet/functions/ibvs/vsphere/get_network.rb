#
Puppet::Functions.create_function(:'ibvs::vsphere::get_network') do
    dispatch :func do
      param 'Tuple', :networks
      param 'String', :network_name
      return_type 'Hash'
    end
    
    def func(networks, network_name)
      fn='ibvs::vsphere::get_network'
      Puppet.debug("#{fn}: Function Started")

      networks.each { |n| return n if n['name'] == network_name }

      fail("#{fn}\n********\nERROR: Could not retrieve Network from Networks List (Network not in list?)\n********\n\n")
    end
  end
