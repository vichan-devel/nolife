set :assets,        Sprockets::Environment.new(settings.root)
set :precompile,    [ /\w+\.(?!js|css).+/, /application.(css|js)$/, /preload.css$/ ]
set :assets_prefix, '/assets'
set :digest_assets, false
set :assets_path,   -> { File.join public_folder, assets_prefix }

configure do
  # Setup Sprockets
  ['javascripts', 'stylesheets', 'images', 'sass', 'scss', 'fonts', 'lib', 'ui', ''].each do |type|
    settings.assets.append_path "assets/#{type}"
    #settings.assets.append_path Compass::Frameworks['bootstrap'].templates_directory + "/../vendor/assets/#{type}"
    
    vendor = Dir[File.expand_path("../../../vendor/*/#{type}", __FILE__)]
    vendor.each do |i|
      settings.assets.append_path i
    end
  end
  settings.assets.append_path 'assets/font'
  
  #settings.assets.js_compressor = Closure::Compiler.new(:process_jquery_primitives => true, :compilation_level => 'SIMPLE_OPTIMIZATIONS')
 
  # Configure Sprockets::Helpers (if necessary)
  Sprockets::Helpers.configure do |config|
    config.environment = settings.assets
    config.prefix      = settings.assets_prefix
    config.digest      = settings.digest_assets
    config.public_path = settings.public_folder
  end
  Sprockets::Sass.add_sass_functions = false 
end

helpers do
  include Sprockets::Helpers
end
