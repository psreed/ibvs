
# Adapted From: 
# API Documentation: https://www.infoblox.com/wp-content/uploads/infoblox-deployment-infoblox-rest-api.pdf
Puppet::Functions.create_function(:'ibvs::infoblox::add_host_with_next_ip') do
  dispatch :func do
    param 'String', :hostname
    param 'String', :network
    param 'String', :dns_view
    param 'String', :network_view
    param 'String', :zone_auth
    param 'Hash', :infoblox
    return_type 'String'
  end
  
  def func(hostname, network, dns_view, network_view, zone_auth, infoblox)
    url = infoblox['wapi_url'] + "/record:host?_return_fields%2B=name,ipv4addrs&_return_as_object=1"
    params = {
      'name' => hostname, 
      'ipv4addrs' => [{
        'ipv4addr' => 'func:nextavailableip:' + network + ',' + network_view
      }],
      'network_view' => network_view,
      'view' => dns_view,
      'zone_auth' => zone_auth,
    }

    cmd = []
    cmd << "/opt/puppetlabs/puppet/bin/curl -s --insecure"
    cmd << "-H 'content-type: application/json'"
    cmd << "-X POST"
    cmd << "-u #{infoblox['user']}:#{infoblox['password'].unwrap}"
    cmd << "-d '#{params.to_json}'"
    cmd << "\"#{url}\""

    cmdstring = cmd.join(' ')
    res = JSON.parse( %x[ #{cmdstring} ])
    if res['Error']
      fail("Error Follows:\n\n   **** Infoblox Error: #{res['text']}\n   **** Infoblox Error: #{res['code']}\n\nCommand String: #{cmdstring}")
    end
    if res['result']
      return res['result']['ipv4addrs'][0]['ipv4addr']
    end
    fail("Puppet could not get curl result from Infoblox")
  end
end

###################################
## API Output Examples:
###################################
#
### 'Successfully Created' Example Output:
#
# "result": {
#         "_ref": "record:host/ZG5zLmhvc3QkLl9kZWZhdWx0LmNhLnBhdWxyZWVkLnR3aWxpZ2h0LnRlc3RjcmVhdGU:host.example.com/default", 
#         "ipv4addrs": [
#             {
#                 "_ref": "record:host_ipv4addr/ZG5zLmhvc3RfYWRkcmVzcyQuX2RlZmF1bHQuY2EucGF1bHJlZWQudHdpbGlnaHQudGVzdGNyZWF0ZS4xMC4wLjAuMi4:10.0.0.2/host.example.com/default", 
#                 "configure_for_dhcp": false, 
#                 "host": "host.example.com", 
#                 "ipv4addr": "10.0.0.2"
#             }
#         ], 
#         "name": "host.example.com", 
#         "view": "default"
#     }
# }
#
### 'Hostname Already Exists' Example Output:
#
# { "Error": "AdmConDataError: None (IBDataConflictError: IB.Data.Conflict:The record 'host.example.com' already exists.)", 
#   "code": "Client.Ibap.Data.Conflict", 
#   "text": "The record 'host.example.com' already exists."
# }
#
### 'Invalid Domain' Example Output:
# { "Error": "AdmConDataError: None (IBDataConflictError: IB.Data.Conflict:The action is not allowed. A parent was not found.)", 
#   "code": "Client.Ibap.Data.Conflict", 
#   "text": "The action is not allowed. A parent was not found."
# }