//= require "jquery"
//= require "ws"

m = (p...)->
  $(window).on(p...)
  
send = (p...)->
   window.send(p...)
   
timeout = (a,b)->
  setTimeout(b,a)

LEFT=37
UP=38
RIGHT=39
DOWN=40
ENTER=13
CTRL=17
SHIFT=16

DIRS = [LEFT, UP, RIGHT, DOWN]

keyState = {};

window.addEventListener 'keydown', (e)->
  if DIRS.includes(e.which)
    for dir in DIRS
      keyState[dir] = false
  keyState[e.which] = true;

window.addEventListener 'keyup', (e)->
  keyState[e.which] = false;

$ ->
  window.execonready()
  
txxy = (x,y)->
  t = {}
  t["left"] = x*16
  t["top"] = y*16
  t
  
txxybar = (x,y)->
  t = {}
  t["left"] = x*16
  t["top"] = y*16-5
  t
  
hpbarup = (hp,bar)->
  if hp == 100
    bar.attr("class", "bar full")
  else if hp < 30
    bar.attr("class", "bar error")
  else if hp < 60
    bar.attr("class", "bar warning")
  else
    bar.attr("class", "bar")
    
  bar.width("#{hp}%")
  
users = {}
  
you = null
  
m "disconnected", (e,msg)->
  timeout 1000, ->
    document.location.reload()
  
m "hello", (e,msg)->
  you = msg.you
  b = $("body").html("")
  
  all = $("<div id='all'>").appendTo(b)
  equipment = $("<div id='equipment'><span>SHIFT to switch, CTRL to use</span>").appendTo(all)
  scene = $("<div id='scene'>").appendTo(all)
  items = $("<div id='items'>").appendTo(all)
  players = $("<div id='players'>").appendTo(all)
  dialogs = $("<div id='dialogs'>").appendTo(all)
  input = $("<input type='text' id='input' autofocus='1'>").appendTo(all)
  $("#input").focus()
  
m "mapupdate", (e,msg)->
  $("#scene").html("")
  for x, yy in msg['map']
    r = $("<div class='sceneline'>").appendTo($("#scene"))
    for y, xx in x
      t = $("<div class='tile #{y['klass']}' id='tile_#{xx}_#{yy}'>").appendTo(r)
      t.html y['text'] if y['text']
      t.html "" unless y['text']
      
m "mapupdateone", (e,msg)->
  t = $("#tile_#{msg['x']}_#{msg['y']}").attr("class", "tile #{msg['klass']}")
  t.html msg['text'] if msg['text']
  t.html "" unless msg['text']
      
m "newplayer", (e,msg)->
  player = $("<div class='player #{msg['dir']}' id='p#{msg['id']}'>").appendTo($("#players"))
  hp = $("<div class='hp' id='hp#{msg['id']}'>").appendTo($("#players"))
  bar = $("<div>").appendTo(hp)
  hpbarup msg['hp'], bar
  hp.css(txxybar(msg['x'], msg['y']))
  player.css(txxy(msg['x'], msg['y']))
  users[msg['id']] = msg
  
m "delplayer", (e,msg)->
  $("#p"+msg['id']).fadeOut ->
    @remove()
  $("#hp"+msg['id']).fadeOut ->
    @remove()
      
m "move", (e,msg)->
  player = $("#p"+msg['id'])
  player.animate(txxy(msg['x'], msg['y']), 200, "linear")
  hp = $("#hp"+msg['id'])
  hp.animate(txxybar(msg['x'], msg['y']), 200, "linear")
  player.attr("class", "player #{msg['dir']}")
  hpbarup msg['hp'], $("#hp"+msg['id']+" .bar")
      
m "chat", (e,msg)->
  pos = $("#p"+msg['id']).position()
  cbox = $("#c"+msg['id']).stop(true)
  cts = (a...)->
    cbox.animate(a...)
  if cbox.length is 0
    cbox = $("<div class='msgbox' id='c#{msg['id']}'>").appendTo($("#dialogs"))
    cts = (a...)->
      cbox.css(a...)
    
  h = cbox.html()
  h and h += "<br>"
  h += " " + msg['msg']
  cbox.html(h)
  
  pos['left'] -= cbox.width()/2 - 4
  pos['top'] -= cbox.height() + 10
  
  pos['opacity'] = 0.7
  
  cts pos
    
  users[msg['id']].chat_fadeout and clearTimeout users[msg['id']].chat_fadeout
  users[msg['id']].chat_fadeout = timeout 5000, ->
    users[msg['id']].chat_fadeout = undefined
    cbox.fadeOut ->
      cbox.remove()
      
m "equpdate", (e,msg)->
  active = msg['active']
  eq = msg['eq']
  $("#equipment>div").remove()
  for i in eq
    e = $("<div>").appendTo($("#equipment"))
    if i['klass'] == active
      e.addClass("active")
      
    icon = $("<div class='#{i['klass']} item icon'>&nbsp;</div>").appendTo(e)
    name = $("<div class='text'>").html(i['text']).appendTo(e)
    count = $("<div class='count'>").html(i['count']).appendTo(e)

itemat = {}

m "newitem", (e,msg)->
  it = $("#items")
  i = $("<div class='item #{msg['klass']}' id='it#{msg['id']}'></div>").appendTo(it)
  itemat[[msg['x'],msg['y']]] ?= 0
  k = txxy(msg['x'], msg['y'])
  k['top'] -= itemat[[msg['x'],msg['y']]] * 2
  itemat[[msg['x'],msg['y']]] += 1
  i.css(k)
  
m "delitem", (e,msg)->
  itemat[[msg['x'],msg['y']]] -= 1
  $("#it#{msg['id']}").fadeOut ->
    $("#it#{msg['id']}").remove()
    
m "arrow", (e,msg)->
  xa = $("<div class='xarrow' id='xa#{msg['id']}'>").css(txxy(msg['fromx'],msg['fromy'])).appendTo("#items")
  xa.animate(txxy(msg['tox'],msg['toy']), msg['len']*50, "linear")
  
m "endarrow", (e,msg)->
  $("#xa#{msg['id']}").remove()

teardown = false
exhaust = 0

move = (dir)->
  send("move", "dir": dir)

  teardown = true
  exhaust = 0
  timeout 200, ->
    teardown = false

setInterval ->
  for k, v of keyState
    if !v
      continue

    handled = true

    switch parseInt(k)
      when LEFT
        move "left" unless teardown
      when RIGHT
        move "right" unless teardown
      when UP
        move "up" unless teardown
      when DOWN
        move "down" unless teardown
      when CTRL
        v = $("#input").val()
        $("#input").val("")
        send("doit", "text": v)
        keyState[k] = false
      when SHIFT
        send("switch")
        keyState[k] = false
      when ENTER
        v = $("#input").val()
        $("#input").val("")
        if v
          send("chat", "msg": v)
        $("#input").focus()
        keyState[k] = false
      else
        handled = false
, 1
