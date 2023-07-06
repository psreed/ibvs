# Adapted from:
# API Documentation: https://developer.vmware.com/apis/vsphere-automation/latest/cis/api/session/post/
Puppet::Functions.create_function(:'ibvs::vsphere::post_session') do
    dispatch :func do
      param 'Hash', :vsphere
      return_type 'String'
    end
    
    def func(vsphere)
      fn='ibvs::vsphere::post_session'
      Puppet.debug("#{fn}: Attempting to connect to vSphere")

      vsphere['ssl'] ? uri="https://#{vsphere['host']}/api" : uri="http://#{vsphere['host']}/api"   
      cmd = []
      cmd << "/opt/puppetlabs/puppet/bin/curl -s"
      cmd << "--insecure" if vsphere['insecure']
      cmd << "-H 'content-type: application/json'"
      cmd << "-X POST"
      begin
        cmd << "-u '#{vsphere['user']}:#{vsphere['password'].unwrap}'"
      rescue
        Puppet.debug("#{fn}: Note: Fell back to unwrapped password")
        cmd << "-u '#{vsphere['user']}:#{vsphere['password']}'"
      end
      cmd << "\"#{uri}/session\""
      cmdstring = cmd.join(' ')
      result = %x[ #{cmdstring} ]
      result.gsub!(/^\"|\"$/, '') # Remove bounding double quotes from output

      if result.length == 32 # Valid session ID has 32 characters
        Puppet.debug("#{fn}: Connected to vSphere: '#{result}'")
        return result
      end
      fail("#{fn}\n********\nERROR: Could not connect to vSphere, message follows:\n#{result}\n********\n\n")
    end
  end
