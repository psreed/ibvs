# Show a debug message
Puppet::Functions.create_function(:'ibvs::debug_message') do
  
    dispatch :func do
      param 'String', :message
    end
  
    def func(message)
      Puppet.debug(message)
    end
  end