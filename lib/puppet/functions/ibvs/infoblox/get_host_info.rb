# Adapted from:
# API Documentation: https://www.infoblox.com/wp-content/uploads/infoblox-deployment-infoblox-rest-api.pdf
Puppet::Functions.create_function(:'ibvs::infoblox::get_host_info') do
  dispatch :func do
    param 'String', :host
    param 'Hash', :infoblox
    return_type 'Hash'
  end
  
  def func(host, infoblox)
    Puppet.debug("Starting Infoblox Lookup via API (get_host_info) for Host: '#{host}'")

    url = infoblox['wapi_url'] + "/record:host?name=#{host}&_return_as_object=1"
    cmd = []
    cmd << "/opt/puppetlabs/puppet/bin/curl -s --insecure"
    cmd << "-H 'content-type: application/json'"
    cmd << "-X GET"
    cmd << "-u #{infoblox['user']}:#{infoblox['password'].unwrap}"
    cmd << "\"#{url}\""

    cmdstring = cmd.join(' ')
    result = %x[ #{cmdstring} ]
    Puppet.debug("Infoblox Result (get_host_info): '#{result}'")

    if result == ""
      return { 'code' => '1', 'data' => "No info returned for #{host}\n#{cmdstring}" }
    end

    res = JSON.parse(result)
    if result == "[]" || res['result'].to_json == "[]"
      return { 'code' => '2', 'data' => "No info returned for #{host}\n#{cmdstring}" }
    end

    if result =~ /^{ "Error":/ && res['Error']
      return { 'code' => '3', 'data' => res['result'].to_json }
    end
    return { 'code' => 0, 'data' => res['result'].to_json, 'ip' => res['result'][0]['ipv4addrs'][0]['ipv4addr'] }
  end
end
###################################
## API Output Examples:
###################################
#
### 'Success' Example Output:
# {
#     "result": [
#         {
#             "_ref": "record:host/ZG5zLmhvc3QkLl9kZWZhdWx0LmNhLnBhdWxyZWVkLnR3aWxpZ2h0LnRlc3RjcmVhdGU0:host.example.com/default", 
#             "ipv4addrs": [
#                 {
#                     "_ref": "record:host_ipv4addr/ZG5zLmhvc3RfYWRkcmVzcyQuX2RlZmF1bHQuY2EucGF1bHJlZWQudHdpbGlnaHQudGVzdGNyZWF0ZTQuMTAuMC4wLjYu:10.0.0.6/host.example.com/default", 
#                     "configure_for_dhcp": false, 
#                     "host": "host.example.com", 
#                     "ipv4addr": "10.0.0.6"
#                 }
#             ], 
#             "name": "host.example.com", 
#             "view": "default"
#         }
#     ]
# }