
# Adapted from:
# API Documentation: https://www.infoblox.com/wp-content/uploads/infoblox-deployment-infoblox-rest-api.pdf
Puppet::Functions.create_function(:'ibvs::infoblox::get_network_ref') do
  dispatch :func do
    param 'String', :network
    param 'Hash', :infoblox
    return_type 'String'
  end
  
  def func(network, infoblox)
    url = infoblox['wapi_url'] + "/network?network=#{network}"

    cmd = []
    cmd << "/opt/puppetlabs/puppet/bin/curl -s --insecure"
    cmd << "-H 'content-type: application/json'"
    cmd << "-X GET"
    cmd << "-u #{infoblox['user']}:#{infoblox['password'].unwrap}"
    cmd << "\"#{url}\""

    cmdstring = cmd.join(' ')
    result = %x[ #{cmdstring} ]
    res = JSON.parse(result)
    Puppet.debug("Infoblox Result: '#{result}'")
    ## Empty Result Failure
    if result == "[]"
      fail("\n\n    **** Infoblox API resultset was empty, IP address is likely unused, but network likely exists.\n    **** Failing so downstream results are not unexpected.\n\n")
    end
    if result =~ /^{ "Error":/ && res['Error']
      fail("Error Follows:\n\n   **** Infoblox Error: #{res['text']}\n   **** Infoblox Error: #{res['code']}\n\n")
    end
    ## Loop through results to find proper _ref
    res[0].each { |r|
      Puppet.debug("REF: #{r}")
      if r[0] == '_ref' && r[1] =~ /^network\//
        return r[1]
      end
    }
    fail("\n\n    **** Infoblox result: Unable to retrieve reference from Infoblox.\n\n")
  end
end
###################################
## API Output Examples:
###################################
#
### 'Success' Example Output:
# [
#   {
#     "_ref": "ipv4address/Li5pcHY0X2FkZHJlc3MkMTAuMC4wLjIvMA:10.0.0.2", 
#     "ip_address": "10.0.0.2", 
#     "is_conflict": false, 
#     "mac_address": "", 
#     "names": [
#       "host.example.com"
#     ], 
#     "network": "10.0.0.0/24", 
#     "network_view": "default", 
#     "objects": [
#       "record:host/ZG5zLmhvc3QkLl9kZWZhdWx0LmNhLnBhdWxyZWVkLnR3aWxpZ2h0LnRlc3RjcmVhdGU:host.example.com/default"
#     ], 
#     "status": "USED", 
#     "types": [
#       "HOST"
#     ], 
#     "usage": [
#       "DNS"
#     ]
#   }
# ]