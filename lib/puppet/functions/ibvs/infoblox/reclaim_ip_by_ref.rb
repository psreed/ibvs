
# Adapted from:
# API Documentation: https://www.infoblox.com/wp-content/uploads/infoblox-deployment-infoblox-rest-api.pdf
Puppet::Functions.create_function(:'ibvs::infoblox::reclaim_ip_by_ref') do
  dispatch :func do
    param 'String', :ref
    param 'Hash', :infoblox
    return_type 'String'
  end
  
  def func(ref, infoblox)
    url = infoblox['wapi_url'] + "/#{ref}&_return_as_object=1"

    cmd = []
    cmd << "/opt/puppetlabs/puppet/bin/curl -s --insecure"
    cmd << "-H 'content-type: application/json'"
    cmd << "-X DELETE"
    cmd << "-u #{infoblox['user']}:#{infoblox['password'].unwrap}"
    cmd << "\"#{url}\""

    cmdstring = cmd.join(' ')
    if !infoblox['noop']
      result = %x[ #{cmdstring} ]
    else
      res = ""  
    end
    res = JSON.parse(result)
    Puppet.debug("Infoblox Result: '#{result}'")
    ## Empty Result Failure
    if result == "[]"
      Puppet.warning('\n\n    **** Infoblox result was empty, _ref likely does not exist or IP was already reclaimed.\n\n')
    end
    if result =~ /^{ "Error":/ && res['Error']
      fail("Error Follows:\n\n   **** Infoblox Error: #{res['text']}\n   **** Infoblox Error: #{res['code']}\n\n")
    end
    ## Couldn't find an associates ref
#    fail('\n\n    **** Infoblox result: Unable to retrieve reference from Infoblox.\n\n')
    res.to_json
  end
end
###################################
## API Output Examples:
###################################
#
### 'Success' Example Output:
# [
#     {
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
#     },
#     {
#         "_ref": "network/ZG5zLm5ldHdvcmskMTAuMC4wLjAvMjQvMA:10.0.0.0/24/default",
#         "network": "10.0.0.0/24",
#         "network_view": "default"
#     }
# ]
### 'Success, but IP not in use / Network object returned' Example Output:
# [{"_ref":"network/ZG5zLm5ldHdvcmskMTAuMC4wLjAvMjQvMA:10.0.0.0/24/default","network":"10.0.0.0/24","network_view":"default"}]