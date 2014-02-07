post "/upload/" do
  filename = params['file']['filename']
  ext = filename.split(".").pop
  name = (Time.now.to_f*100).to_i.to_s << "." << ext
  f = nil
  
  EM.defer(-> {
    File.copy(params['file'][:tempfile], "img/#{filename}")
  }, -> {
    f.resume
  });
  
  f = Fiber.suspend
  
  
  ["img/#{filename}"].to_json
end

get "/img/:img" do |img|
  img = img.gsub(/[^0-9a-zA-Z.]/, '')
  send_file 'img/#{img}', disposition: 'inline'
end
