http = require 'http'
express = require 'express'
WebSocket = require 'ws'
WebSocketServer = WebSocket.Server

device = new class
  constructor: ->
    @sockets = []
    @state = {}
  addWebsocket: (ws) =>
    console.log "Got websocket connection"
    @sockets.push ws
    ws.on 'close', => @removeWebsocket(ws)
    @sendState(ws)
  removeWebsocket: (ws) =>
    console.log "Lost websocket connection"
    # Should definitely exist, unless there's a bug somewhere.
    @sockets.splice(@sockets.indexOf(ws), 1)
  sendState: (ws) ->
    ws.send JSON.stringify(@state), -> # ignore errors

app = express()
server = http.createServer app
app.use express.static __dirname
wss = new WebSocketServer server:server
wss.on 'connection', device.addWebsocket

server.listen 1337
