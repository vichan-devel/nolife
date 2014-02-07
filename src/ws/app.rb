
h = Handler

pls = {}
chan = EM::Channel.new

boundx = 50
boundy = 30

scene = []
boundy.times do
  a = []
  boundx.times do
    a << {klass: "grass", text: nil}
  end
  scene << a
end

accum = 0

update_eq = ->(ws) do
  pl = pls[ws]
  
  # prune
  pl.eq.delete_if { |k,v| v[:count] <= 0 }
  unless pl.eq_active and pl.eq[pl.eq_active]
    pl.eq_active = pl.eq.keys.first
  end
  
  # update
  eq = pl.eq.map do |k,v|
    v[:text] = case k
    when :grasstool
      "Grass Tool"
    when :axe
      "Axe"
    when :texttool
      "Text Tool"
    when :health
      "First Aid"
    when :seeds
      "Seeds"
    when :arrow
      "Arrow"
    end
    v[:klass] = k
    v
  end
  
  h.send_msg(ws, :equpdate, active: pl.eq_active, eq: eq)
end

xybounds = ->(x,y) do
  if x < 0 or y < 0 or x >= boundx or y >= boundy
    false
  else
    true
  end
end

ndir = ->(dir) do
  case dir
  when "up"
    [0,-1]
  when "down"
    [0,1]
  when "left"
    [-1,0]
  when "right"
    [1,0]
  else
    [0,0]
  end
end

xydir = ->(x,y,dir) do
  xx, yy = ndir.(dir)
  [xx+x, yy+y]
end

player_at = ->(x,y,pp=nil) do
  pls.find do |ws,pl|
    pl.x == x and pl.y == y and pl != pp
  end.first rescue nil
end

insert_item = ->() do
  # a lightweight thread xD
  Fiber.new do
    loop do
      item = [:axe, :health, :grasstool, :texttool, :seeds, :arrow].shuffle.first
      # yes :arrow
      
      #update_items.()
      x,y = nil, nil
      loop do
        x = rand boundx
        y = rand boundy
        if not player_at.(x,y) and scene[y][x][:klass] != "tree"
          break
        end
        EM::Synchrony.sleep(0.1)
      end
      
      scene[y][x][:items] ||= []
      scene[y][x][:items] << {id: accum+=1, klass: item}
      
      chan << [:newitem, x: x, y: y, id: accum, klass: item]
      
      EM::Synchrony.sleep(20.0/(pls.length + 1))
    end
  end.resume
end

damage = ->(ws,hp) do
  pl = pls[ws]
  pl.hp -= hp
  
  if pl.hp <= 0
    ws.close
  else  
    chan << [:move, id: pl.id, x: pl.x, y: pl.y, hp: pl.hp, dir: pl.dir]
  end
end

arrow_fib = ->(from,to,dir,id) do
  dir = ndir.(dir)
  Fiber.new do
    EM::Synchrony.sleep(0.05)
    loop do
      break if from == to
      from[0] += dir[0]
      from[1] += dir[1]
      
      pl = nil
      if pl = player_at.(*from)
        damage.(pl, 40)
        break
      elsif scene[from[1]][from[0]][:klass] == "tree"
        break
      end
      
      break if from == to
      EM::Synchrony.sleep(0.05)
    end
    chan << [:endarrow, id: id]
  end.resume
end

insert_item.()

h.on(:connected) do |ws|
  pl = OpenStruct.new
  pls[ws] = pl
  pl.id = (accum+=1)
  
  pl.x = rand boundx
  pl.y = rand boundy
  pl.hp = 100
  pl.dir = "down"
  pl.eq = {}
  pl.eq_active = nil
  
  chan << [:newplayer, id: pl.id, x: pl.x, y: pl.y, hp: 100, dir: "down"]
  
  pl.cid = chan.subscribe { |e| h.send_msg(ws, *e) }
  
  h.send_msg(ws, :hello, id: pl.id)
  
  h.send_msg(ws, :mapupdate, map: scene)
  xitems = []
  scene.each_index do |i|
    scene[i].each_index do |j|
      if scene[i][j][:items]
        scene[i][j][:items].each do |k|
          k = k.clone
          k[:x] = j
          k[:y] = i
          xitems << k
        end
      end
    end
  end
  xitems.each do |i|
    h.send_msg(ws, :newitem, i)
  end
  pls.each_value do |pl|
    h.send_msg(ws, :newplayer, id: pl.id, x: pl.x, y: pl.y, hp: 100, dir: "down")
  end
end

h.on(:disconnected) do |ws|
  pl = pls.delete(ws)
  chan.unsubscribe(pl.cid)
  chan << [:delplayer, id: pl.id]
  pl[:eq].each do |i,j|
    j[:count].times do
      scene[pl.y][pl.x][:items] ||= []
      scene[pl.y][pl.x][:items] << {id: accum+=1, klass: i}
      chan << [:newitem, x: pl.x, y: pl.y, id: accum, klass: i]
    end
  end
end

h.on(:move) do |ws,m|
  okay = true
  om = m
  m = ndir.(m["dir"])
  okay = false if m == [0,0]
  
  pl = pls[ws]
  old = [pl.x, pl.y, pl.dir]
  pl.dir = om["dir"] if okay
  pl.x += m[0]
  pl.y += m[1]
  pl.x = 0 if pl.x < 0
  pl.y = 0 if pl.y < 0
  pl.x = boundx - 1 if pl.x >= boundx
  pl.y = boundy - 1 if pl.y >= boundy
  if scene[pl.y][pl.x][:klass] == "tree" or player_at.(pl.x,pl.y,pl)
    pl.x = old[0]
    pl.y = old[1]
  end
  if scene[pl.y][pl.x][:items]
    scene[pl.y][pl.x][:items].reverse.each do |i|
      chan << [:delitem, i]
      pl.eq_active = i[:klass]
      pl.eq[i[:klass]] ||= {count: 0}
      pl.eq[i[:klass]][:count] += 1
    end
    update_eq.(ws)
    scene[pl.y][pl.x].delete(:items)
  end
  if [pl.x, pl.y, pl.dir] != old
    chan << [:move, id: pl.id, x: pl.x, y: pl.y, hp: pl.hp, dir: pl.dir]
    EM::Synchrony.sleep(0.3)
  end
end

h.on(:chat) do |ws,m|
  pl = pls[ws]
  msg = m["msg"].gsub("<", "&lt;").gsub(">", "&gt;")
  chan << [:chat, id: pl.id, msg: msg]
end

h.on(:switch) do |ws,m|
  pl = pls[ws]
  if pl.eq.length > 0 and pl.eq_active
    i = pl.eq.keys.index(pl.eq_active)
    pl.eq_active = pl.eq.keys[(i + 1) % pl.eq.keys.length]
  end
  update_eq.(ws)
end

h.on(:doit) do |ws,m|
  pl = pls[ws]
  
  if pl.eq_active == :texttool
    if m['text'] and m['text'].length > 0
      text = m['text'][0]
      scene[pl.y][pl.x] = {klass: "text", text: text}
    else
      scene[pl.y][pl.x] = {klass: "text", text: " "}
    end
    chan << [:mapupdateone, klass: scene[pl.y][pl.x][:klass], text: scene[pl.y][pl.x][:text],
                            x: pl.x, y: pl.y]
    
    pl.eq[pl.eq_active][:count] -= 1
    update_eq.(ws)
  elsif pl.eq_active == :grasstool
    nx,ny = xydir.(pl.x, pl.y, pl.dir)
    if xybounds.(nx,ny) and p=player_at.(nx,ny)
      damage.(p,30)
      
      pl.eq[pl.eq_active][:count] -= 1
      update_eq.(ws)
    else
      scene[pl.y][pl.x] = {klass: "grass", text: nil}
      
      chan << [:mapupdateone, klass: scene[pl.y][pl.x][:klass], text: scene[pl.y][pl.x][:text],
                              x: pl.x, y: pl.y]
      
      pl.eq[pl.eq_active][:count] -= 1
      update_eq.(ws)
    end
  elsif pl.eq_active == :seeds
    nx,ny = xydir.(pl.x, pl.y, pl.dir)
    unless player_at.(nx,ny) or not xybounds.(nx,ny)
      scene[ny][nx] = {klass: "tree", text: nil}
      chan << [:mapupdateone, klass: scene[ny][nx][:klass], text: scene[ny][nx][:text], x: nx, y: ny]
      
      pl.eq[pl.eq_active][:count] -= 1
      update_eq.(ws)
    end
  elsif pl.eq_active == :health
    pl.hp = 100
    chan << [:move, id: pl.id, x: pl.x, y: pl.y, hp: pl.hp, dir: pl.dir]
    pl.eq[pl.eq_active][:count] -= 1
    update_eq.(ws)
  elsif pl.eq_active == :axe
    nx,ny = xydir.(pl.x, pl.y, pl.dir)
    if xybounds.(nx,ny) and p=player_at.(nx,ny)
      damage.(p,40)
      
      pl.eq[pl.eq_active][:count] -= 1
      update_eq.(ws)
    elsif xybounds.(nx,ny) and scene[ny][nx][:klass] == "tree"
      scene[ny][nx] = {klass: "grass", text: nil}
      chan << [:mapupdateone, klass: scene[ny][nx][:klass], text: scene[ny][nx][:text], x: nx, y: ny]
      
      pl.eq[pl.eq_active][:count] -= 1
      update_eq.(ws)
    end
  elsif pl.eq_active == :arrow
    beg = [pl.x,pl.y]
    ent = [0,0]
    len = 0
    case pl.dir
    when "left"
      ent = [0, pl.y]
      len = pl.x
    when "right"
      ent = [boundx-1, pl.y]
      len = boundx-pl.x+1
    when "up"
      ent = [pl.x, 0]
      len = pl.y
    when "down"
      ent = [pl.x, boundy-1]
      len = boundx-pl.y+1
    end
    chan << [:arrow, fromx: beg[0], fromy: beg[1], tox: ent[0], toy: ent[1], id: accum+=1, len: len]
    arrow_fib.(beg, ent, pl.dir, accum)
    pl.eq[pl.eq_active][:count] -= 1
    update_eq.(ws)
  end
  
  
end

$binding = binding
