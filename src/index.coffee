context = null
node = null
sampleDuration = null
t = 0
volume = 0.1
bufferSize = 4096

window.potzy = new class
  constructor: ->
    @readyCallbacks = []
  init: =>
    try
      window.AudioContext ?= window.webkitAudioContext
      context = new AudioContext()
      sampleDuration = 1 / context.sampleRate
      node = context.createScriptProcessor(bufferSize, 1, 1)
      node.loop = false
      node.onaudioprocess = (e) =>
        output = e.outputBuffer.getChannelData(0)
        for i in [0...output.length]
          t += sampleDuration
          output[i] = volume * @fn(t)
      @ready = true
      cb() for cb in @readyCallbacks
      delete @readyCallbacks
    catch e
      @ready = false
      alert 'Web Audio API is not supported in this browser'

  play: ->
    node.connect(context.destination)

  pause: ->
    node.disconnect()

  fn: (t) ->
    return Math.sin(2 * Math.PI * t * 440)

  onReady: (fn) ->
    if @ready
      setTimeout fn, 0
    else
      @readyCallbacks.push fn

window.addEventListener 'load', window.potzy.init, false
