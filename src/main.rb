dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)
vendor = Dir[File.expand_path('../../vendor/*/lib', __FILE__)]
$LOAD_PATH.push *(vendor - $LOAD_PATH)

require "appconfig"
require "fileupload"

get "/" do
  @domain = request.env["HTTP_HOST"].split(":").first unless request.env["HTTP_HOST"].nil?
  erb :index
end
