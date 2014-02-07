# doesn't work with Stdlib Readline

require 'rb-readline'
require 'fiber'
require 'eventmachine'
 
module NbKeyboard
  def post_init
    @ostdin = $stdin
    $stdin  = self
    @buffer = ""
  end
 
  def receive_data(d)
    @buffer << d
    @waiting && @waiting[:cnt] <= @buffer.length && @waiting[:fiber].resume
  end
 
  def read(cnt)
    if EM.reactor_running?
      if @buffer.length < cnt
        @waiting = {:cnt => cnt, :fiber => Fiber.current}
        Fiber.yield
      end
      data, @buffer = @buffer[0...cnt], @buffer[cnt..-1]
      data
    else
      @ostdin.read cnt
    end
  end

  def getc
    read 1
  end
 
  def unbind
    $stdin = @ostdin
  end
 
  def method_missing(meth, *args, &blk)
    @ostdin.send(meth, *args, &blk)
  end
end
