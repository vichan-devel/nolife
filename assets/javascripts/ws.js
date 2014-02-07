window['socket_connect'] = function(host, port) {
  var socket = new WebSocket("ws://"+host+":"+port+"/");

  socket['onopen'] = function() {
    $(window).trigger("connected", socket);
    console.log("connected");
  };

  socket['onmessage'] = function(message) {
    msg = JSON.parse(message['data']);
    console.log("received: ", msg);
    if (msg['family']) {
      $(window).trigger(msg['family'], msg);
    }
  };

  socket['onclose'] = function() {
    $(window).trigger("disconnected", socket);
    console.log("closed");
  };

  socket['onerror'] = function() {
    $(window).trigger("sockerror", socket);
    console.log("error");
  };

  window.send = function(family, rest) {
    rest = rest || {};
    rest['family'] = family;

    socket.send(JSON.stringify(rest));
    console.log("sent: ", rest);
  };

  return socket;
}
