# 
Puppet::Functions.create_function(:'ibvs::infoblox::check_for_reserved_ip_in_list') do
    dispatch :func do
      param 'Tuple', :reserved_ips
      param 'String', :name
      param 'String', :network_view
      return_type 'String'
    end
    
    def func(reserved_ips, name, network_view)
      fn='ibvs::infoblox::check_for_reserved_ip_in_list'
      Puppet.debug("#{fn}: Function Started")


      reserved_ips.each { |v| 
        Puppet.debug("Testing: '#{v['name']}' with '#{name}' and '#{v['network_view']}' with '#{network_view}'")
        if v['name'] == name && v['network_view'] == network_view
          Puppet.debug("Found existing IP match! #{v['ipv4addr']}")
          return v['ipv4addr'] 
        end
      }

      return ''
    end
  end
