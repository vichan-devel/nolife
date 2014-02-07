module Zygote
  def self.spawn
    loop do
      saved = `stty -g`
      if pid = fork
        Process.wait pid
	`stty #{saved}`
	puts "Continue (n to stop)? "
	exit! if gets[0] == ?n
      else
        break
      end
    end
  end
end
