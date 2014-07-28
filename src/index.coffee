unless window.potzy?
  context = null
  node = null
  sampleRate = null
  sampleDuration = null
  t = 0
  volume = 0.1
  bufferSize = 4096

  premade = [
    "afternoon walk"
    "early morning"
    "got some 303"
    "icecream"
    "late morning"
    "mind swift"
    "morning"
    "need more 303"
    "on the verge"
    "on the verge tech mix"
    "polytropon"
    "polytropon astral mix"
    "pwm and stuff"
    "simple sine"
    "subwah"
    "unexpected token"
    "yay"
  ]

  $ = (id) ->
    document.getElementById(id)

  window.potzy = potzy = new class
    constructor: ->
      @readyCallbacks = []
      @state = {}
      @_state = {}
      @setState
        L0: 0.5
        P0: 0.5
        P1: 0.5
        P2: 0.5
        P3: 0.5
        P4: 0.5
        TIME: 1
        VOL: 0.3

    smooth: (newVal, oldVal) ->
      return newVal unless oldVal?
      oldRatio = 1
      newVal = (oldRatio * oldVal + newVal)/(1 + oldRatio)
      return oldVal unless Math.abs(oldVal - newVal) >= 0.01
      return newVal

    superSmooth: (newVal, oldVal) ->
      return newVal unless oldVal?
      return oldVal unless Math.abs(oldVal - newVal) >= 0.02
      return parseFloat(newVal.toFixed(2))

    setState: (state) ->
      for k, v of state
        if k is 'TIME'
          @_state[k] = @state[k] = @superSmooth(v, @state[k])
        else
          @_state[k] = @state[k] = @smooth(v, @state[k])
      if @_state.VOL?
        volume = Math.min(1, Math.max(0, parseFloat(@_state.VOL)))
      return

    init: =>
      @headingsContainer = document.getElementById 'vars-names'
      @valuesContainer = document.getElementById 'vars-values'
      @headingsContainer.addEventListener 'mousewheel', @mouseWheel, false
      @valuesContainer.addEventListener 'mousewheel', @mouseWheel, false
      fp = $("file-picker")
      list = document.createElement 'ul'
      for file in premade then do (file) =>
        li = document.createElement 'li'
        li.textContent = file
        li.onclick = => @load(file)
        li.ondblclick = => @load(file, true)
        list.appendChild li
      fp.appendChild list
      $("play").addEventListener 'click', @play, false
      $("pause").addEventListener 'click', @pause, false
      @editor = CodeMirror document.getElementById("editor"),
        mode: "javascript"
        value: """
          function dsp(t) {
            return Math.sin(2 * Math.PI * t * 440);
          }
          """
      @editor.setSize("100%", "100%")
      @editor.on "change", @import
      if localStorage.getItem('_current')?
        @load(localStorage.getItem('_current'))
      else
        @load "basic"
      @import()
      @editor.focus()
      @updateValueStatusBar()
      try
        window.AudioContext ?= window.webkitAudioContext
        context = new AudioContext()
        sampleRate = context.sampleRate
        sampleDuration = 1 / sampleRate
        node = context.createScriptProcessor(bufferSize, 1, 1)
        node.loop = false
        node.onaudioprocess = (e) =>
          output = e.outputBuffer.getChannelData(0)
          for i in [0...output.length]
            t += sampleDuration * @_state.TIME
            output[i] = volume * @fn(t)
        @ready = true
        cb() for cb in @readyCallbacks
        delete @readyCallbacks
      catch e
        @ready = false
        alert 'Web Audio API is not supported in this browser'

    load: (file, force) ->
      @currentFile = file
      localStorage.setItem('_current', file)
      if force and confirm("Delete local modifications to '#{file}'?")
        localStorage.removeItem(file)

      if !localStorage.getItem(file)? and file in premade
        xhr = new XMLHttpRequest
        xhr.onreadystatechange = =>
          if xhr.readyState is 4
            @editor.setValue(xhr.responseText)
            @import()
        xhr.open 'GET', "premade/#{file}", true
        xhr.send null
      else
        @editor.setValue(localStorage.getItem(file) ? """
          function dsp(t) {
            return Math.sin(2 * Math.PI * t * 440);
          }
          """
        )
        @import()

    import: =>
      js = @editor.getValue().replace /@([A-Za-z0-9]+)/gm, 'this.$1', 'gm'
      messagesContainer = document.getElementById 'messages'
      try
        str = """
          (function() {
            var sampleRate = #{sampleRate};
            var P0 = this.P0;
            var P1 = this.P1;
            var P2 = this.P2;
            var P3 = this.P3;
            var P4 = this.P4;
            var L0 = this.L0;
            #{js}
            return dsp;
          })()
          """
        fn = eval str
        fn.call(@_state, 0) # Test
        fn.call(@_state, 1) # Test
        fn.call(@_state, 100.499) # Test
        messagesContainer.classList.remove 'error'
        messagesContainer.innerHTML = 'OK!'
        localStorage.setItem(@currentFile, js)
        @_fn = fn
      catch e
        console.error e
        messagesContainer.classList.add 'error'
        messagesContainer.innerHTML = 'Error: ' + e.message

    play: =>
      @import()
      node.connect(context.destination)

    pause: =>
      node.disconnect()

    _fn: -> 0

    fn: (t) ->
      try
        return @_fn.call(@_state, t)
      catch e
        return 0

    onReady: (fn) ->
      if @ready
        setTimeout fn, 0
      else
        @readyCallbacks.push fn

    updateValueStatusBar: =>
      headings = []
      values = []

      for key, value of @state
        headings.push "<th data-key=\"#{key}\">@#{key}</th>"
        #values.push "<td>#{Math.round(value * 1000) / 1000}</td>"
        values.push "<td data-key=\"#{key}\">#{formatValue(value)}</td>"
      @headingsContainer.innerHTML = headings.join ''
      @valuesContainer.innerHTML = values.join ''
      window.requestAnimationFrame @updateValueStatusBar

    mouseWheel: (e) =>
      e.preventDefault()
      key = e.target.getAttribute("data-key")
      if key
        v = @state[key]
        if v
          obj = {}
          obj[key] = parseFloat(v) - (e.wheelDelta / 100)
          @setState obj
      return false

  formatValue = (input) ->
    roundedStr = (Math.round(input * 100) / 100) + ''
    return roundedStr + "0.00".substr(roundedStr.length)

  window.addEventListener 'load', window.potzy.init, false

  try
    ws = new WebSocket('ws://'+window.location.host)
    ws.onmessage = (e) ->
      try
        state = JSON.parse e.data
        state.TIME = Math.sqrt(0.25 + state.P4 * 3.75)
        potzy.setState state
