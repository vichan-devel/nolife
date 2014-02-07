WebSocket::EventMachine::Server.start(host: "0.0.0.0", port: 12138) do |ws|
  ws.onopen do
    puts "Client connected"
    
    @fiber ||= {}
    
    @fiber[ws] = Fiber.new &FiberLoop
    @fiber[ws].resume
    @fiber[ws].resume ws
    @fiber[ws].resume :connected
    #Handler.trigger ws, :connected
  end

  ws.onmessage do |msg, type|
    puts "Received message: #{msg} (#{type})"

    begin
      json = JSON.parse(msg)
    rescue Exception => e
      @fiber[ws].resume :badcode, e
    else
      if json['family'] and json['family'] != 'connected' and json['family'] != 'disconnected' and json['family'][0..1] != 'x-'
        @fiber[ws].resume json['family'], json
      end
    end
  end

  ws.onclose do
    puts "Client disconnected"
    @fiber[ws].resume :disconnected if @fiber[ws]
  end
end

FiberLoop = proc do
  ws = Fiber.yield
  begin
    loop do
      msg = Fiber.yield
      
      Fiber.new do
        Handler.trigger ws, *msg
      end.resume
      
      if msg == :badcode
        ws.close
      elsif msg == :disconnected
        break
      end
    end
  rescue Exception => e
    $errors ||= []
    $errors << e
    puts "*** Fatal error, exception happened in websocket fiber: #{e.to_s}"
    Handler.trigger ws, :badcode, e
    ws.close
    
    loop do # errors shouldn't happen, but when they happen
            # i don't want the Fiber.resumes to do bad job
      Fiber.yield
    end
  end
end

class Handler
  def self.on msgtype, &block
    @handlers ||= {}
    @handlers[msgtype.to_s] ||= []
    @handlers[msgtype.to_s].push(block)
  end

  def self.trigger s, msgtype, content={}
    return unless @handlers and @handlers[msgtype.to_s]
    @handlers[msgtype.to_s].each do |i|
      i.call(s, content);
    end
  end

  def self.send_msg s, family, rest={}
    rest["family"] = family
    s.send(JSON.generate(rest), type: :text)
  end
end

require "ws/app"
