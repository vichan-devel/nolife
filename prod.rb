require File.join(File.dirname(__FILE__), 'src', 'main')

if File.basename($0) == 'prod.rb'
  run app: Sinatra::Application
end
