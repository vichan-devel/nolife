require 'rubygems'
require 'bundler'
Bundler.require

TCPSocket = EventMachine::Synchrony::TCPSocket

if File.basename($0) == 'prod.rb'
  require 'util/zygote'
  Zygote.spawn
end

set :root, File.dirname(File.dirname(__FILE__))
set :public_folder, -> { File.join(root, "public") }
set :views, -> { File.join(root, "views") }

require 'integration/sprockets'
require 'integration/eventmachine'

configure do
  set :erb, :layout => :'layouts/application'
end

