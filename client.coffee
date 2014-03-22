requestAnimationFrame = window.requestAnimationFrame or
  window.webkitRequestAnimationFrame or
  window.mozRequestAnimationFrame or
  window.oRequestAnimationFrame or
  window.msRequestAnimationFrame or
  (callback) ->
    window.setTimeout(callback, 1000 / 60)

class Boilerplate
  colors =
    #solid: 'hsl(29, 100%, 7%)'
    solid: 'hsl(184, 49%, 7%)'
    nothing: 'white'
    shuttle: 'hsl(44, 87%, 52%)'
    thinshuttle: 'hsl(44, 87%, 72%)'
    negative: 'hsl(17, 98%, 36%)'
    positive: 'hsl(170, 49%, 51%)'
    thinsolid: 'lightgrey'
    bridge: '#08f'

  enclosingRect = (a, b) ->
    tx: Math.min a.tx, b.tx
    ty: Math.min a.ty, b.ty
    tw: Math.abs(b.tx-a.tx) + 1
    th: Math.abs(b.ty-a.ty) + 1

  line = (x0, y0, x1, y1, f) ->
    dx = Math.abs x1-x0
    dy = Math.abs y1-y0
    ix = if x0 < x1 then 1 else -1
    iy = if y0 < y1 then 1 else -1
    e = 0
    for i in [0..dx+dy]
      f x0, y0
      e1 = e + dy
      e2 = e - dx
      if Math.abs(e1) < Math.abs(e2)
        x0 += ix
        e = e1
      else
        y0 += iy
        e = e2
    return

  constructor: (initial_data, @mode) ->
    @size = 20
    @scroll_x = -2
    @scroll_y = -1

    @simulator = new Simulator initial_data
    @limit = width: 20, height: 20
    @resetSwitches()
    @simulator.set @limit.width, 1, 'thinsolid'
    for y in [1..@limit.height - 2]
      @simulator.set @limit.width + 1, y, 'nothing'
      @simulator.set @limit.width + 2, y, 'shuttle'

    @el = document.createElement 'div'
    @canvas = @el.appendChild document.createElement 'canvas'
    @uiCanvas = @el.appendChild document.createElement 'canvas'
    @uiCanvas.style.pointerEvents = 'none'

  grid: ->
    g = {}
    for k, v of @simulator.grid
      {x:tx,y:ty} = parseXY k
      g[k] = v if @withinLimit tx, ty
    g

  on: (event, func) ->
    (@listeners ?= []).push {event, func}
    window.addEventListener event, func

  unregister: ->
    for {event, func} in @listeners ? []
      window.removeEventListener event, func

  # given pixel x,y returns tile x,y
  screenToWorld: (px, py) ->
    return {tx:null, ty:null} unless px?
    # first, the top-left pixel of the screen is at |_ scroll * size _| px from origin
    px += Math.floor(@scroll_x * @size)
    py += Math.floor(@scroll_y * @size)
    # now we can simply divide and floor to find the tile
    tx = Math.floor(px / @size)
    ty = Math.floor(py / @size)
    {tx,ty}

  # given tile x,y returns the pixel x,y,w,h at which the tile resides on the screen.
  worldToScreen: (tx, ty) ->
    return {px:null, py:null} unless tx?
    px: tx * @size - Math.floor(@scroll_x * @size)
    py: ty * @size - Math.floor(@scroll_y * @size)

  withinLimit: (x, y) ->
    0 <= x < @limit.width and 0 <= y < @limit.height

  resizeTo: (width, height) ->
    @uiCanvas.width = @canvas.width = width * devicePixelRatio
    @uiCanvas.height = @canvas.height = height * devicePixelRatio
    @canvas.style.width = @uiCanvas.style.width = width + 'px'
    @canvas.style.height = @uiCanvas.style.height = height + 'px'
    @ctx = @canvas.getContext '2d'
    @ctx.scale devicePixelRatio, devicePixelRatio

    # TODO: set @size so we fit within {width, height}
    @draw()

  resetSwitches: ->
    for number in [0...8]
      @simulator.set -1, number * 2 + 1, 'thinsolid'
      @current_key_state = {}
      keys = {}; keys[i] = false for i in [0..9]
      @record?[@frame_num] = keys
    return


  #########################
  # EDITING               #
  #########################
  edit: ->
    @draw()
    @mode = 'editing'
    @mouse = {x:null,y:null, mode:null}
    @placing = 'nothing'
    @imminent_select = false
    @selectedA = @selectedB = null
    @selectOffset = null
    @selection = null

    @on 'keydown', (e) =>
      kc = e.keyCode

      switch kc
        when 16 # shift
          @imminent_select = true
        when 27 # esc
          @selection = @selectOffset = null

        when 88 # x
          @flip 'x' if @selection
        when 89 # y
          @flip 'y' if @selection
        when 77 # m
          @mirror() if @selection

      pressed = ({
        # 1-8
        49: 'nothing'
        50: 'solid'
        51: 'positive'
        52: 'negative'
        53: 'shuttle'
        54: 'thinshuttle'
        55: 'thinsolid'
        56: 'bridge'

        80: 'positive' # p
        78: 'negative' # n
        83: 'shuttle' # s
        65: 'thinshuttle' # a
        69: 'nothing' # e
        71: 'thinsolid' # g
        68: 'solid' # d
        66: 'bridge' # b
      })[kc]
      if pressed?
        @placing = if pressed is 'solid' then null else pressed

      @draw()
    @on 'keyup', (e) =>
      if e.keyCode == 16 # shift
        @imminent_select = false
        @draw()
    @on 'blur', =>
      @mouse.mode = null
      @imminent_select = false
    @canvas.onmousemove = (e) =>
      @mouse.from = {tx: @mouse.tx, ty: @mouse.ty}
      @mouse.x = e.offsetX
      @mouse.y = e.offsetY
      {tx:@mouse.tx, ty:@mouse.ty} = @screenToWorld @mouse.x, @mouse.y
      switch @mouse.mode
        when 'paint' then @paint()
        when 'select' then @selectedB = @screenToWorld @mouse.x, @mouse.y
      @draw()
    @canvas.onmousedown = (e) =>
      if @imminent_select
        @mouse.mode = 'select'
        @selection = @selectOffset = null
        @selectedA = @screenToWorld @mouse.x, @mouse.y
        @selectedB = @selectedA
      else if @selection
        @paste()
      else
        @mouse.mode = 'paint'
        @mouse.from = {tx:@mouse.tx, ty:@mouse.ty}
        @paint()
      @draw()

    @canvas.onmouseup = =>
      if @mouse.mode is 'select'
        @selection = @copySubgrid enclosingRect @selectedA, @selectedB
        @selectOffset =
          tx:@selectedB.tx - Math.min @selectedA.tx, @selectedB.tx
          ty:@selectedB.ty - Math.min @selectedA.ty, @selectedB.ty

      @mouse.mode = null
      @imminent_select = false

    @on 'copy', (e) ->
      if @selection
        console.log e.clipboardData.setData 'text', JSON.stringify selection
      e.preventDefault()

    @on 'paste', (e) ->
      data = e.clipboardData.getData 'text'
      if data
        try
          @selection = JSON.parse data
          @selectOffset = {tx:0, ty:0}
  paint: ->
    throw 'Invalid placing' if @placing is 'move'
    {tx, ty} = @mouse
    {tx:fromtx, ty:fromty} = @mouse.from
    fromtx ?= tx
    fromty ?= ty

    line fromtx, fromty, tx, ty, (x, y) =>
      @simulator.set x, y, @placing if @withinLimit x, y

  copySubgrid: (rect) ->
    {tx, ty, tw, th} = rect
    subgrid = {tw,th}
    for y in [ty..ty+th]
      for x in [tx..tx+tw]
        if s = @simulator.grid[[x,y]]
          subgrid[[x-tx,y-ty]] = s
    subgrid

  flip: (dir) ->
    return unless @selection
    new_selection = {tw:tw = @selection.tw, th:th = @selection.th}
    for k,v of @selection
      {x:tx,y:ty} = parseXY k
      tx_ = if 'x' in dir then tw-1 - tx else tx
      ty_ = if 'y' in dir then th-1 - ty else ty
      new_selection[[tx_,ty_]] = v
    @selection = new_selection

  mirror: ->
    return unless @selection
    new_selection = {tw:tw = @selection.th, th:th = @selection.tw}
    for k,v of @selection
      {x:tx,y:ty} = parseXY k
      new_selection[[ty,tx]] = v
    @selection = new_selection

  paste: ->
    throw new Error 'tried to paste without a selection' unless @selection
    {tx:mtx, ty:mty} = @screenToWorld @mouse.x, @mouse.y
    mtx -= @selectOffset.tx
    mty -= @selectOffset.ty
    for y in [0...@selection.th]
      for x in [0...@selection.tw]
        tx = mtx+x
        ty = mty+y
        if (s = @selection[[x,y]]) != @simulator.get tx,ty
          @simulator.set tx, ty, s if @withinLimit tx, ty





  #########################
  # RUNNING               #
  #########################

  run: (on_step) ->
    return if @running?
    @initial_state = @simulator
    @simulator = new Simulator JSON.parse JSON.stringify @initial_state.grid

    @frame_num = 0
    @record = {}
    @current_key_state = {}

    @on 'keydown', (e) =>
      if 49 <= e.keyCode <= 57
        number = e.keyCode - 49
        @simulator.set -1, number * 2 + 1, 'negative'
        if not @current_key_state[number]
          (@record[@frame_num] ?= {})[number] = true
          @current_key_state[number] = true
        @draw()
    @on 'keyup', (e) =>
      if 49 <= e.keyCode <= 57
        number = e.keyCode - 49
        @simulator.set -1, number * 2 + 1, 'thinsolid'
        if @current_key_state[number]
          (@record[@frame_num] ?= {})[number] = false
          @current_key_state[number] = false
        @draw()

    @on 'blur', =>
      @resetSwitches()

    @running = setInterval =>
      @simulator.step()
      @draw()
      @frame_num++
      on_step?()
    , 200

  stop: ->
    return unless @running?
    clearInterval @running
    @unregister()
    @running = null

  reset: ->
    @simulator = @initial_state
    @record = {}
    @initial_state = null


  is_solved: ->
    'shuttle' is @simulator.get @limit.width + 1, 2





  #########################
  # DRAWING               #
  #########################

  draw: ->
    return if @needsDraw
    @needsDraw = true
    requestAnimationFrame =>
      @drawReal()
      @needsDraw = false

  drawReal: ->
    @ctx.fillStyle = colors['solid']
    @ctx.fillRect 0, 0, @canvas.width, @canvas.height

    @drawGrid()

    if @mode is 'editing'
      @drawEditControls()

  drawGrid: ->
    # Draw the tiles
    pressure = @simulator.getPressure()
    for k,v of @simulator.grid
      {x:tx,y:ty} = parseXY k
      {px, py} = @worldToScreen tx, ty
      if px+@size >= 0 and px < @canvas.width and py+@size >= 0 and py < @canvas.height
        @ctx.fillStyle = colors[v]
        @ctx.fillRect px, py, @size, @size
        if v is 'nothing' and (v2 = @simulator.get(tx,ty-1)) != 'nothing'
          @ctx.fillStyle = colors[v2 ? 'solid']
          @ctx.globalAlpha = 0.3
          @ctx.fillRect px, py, @size, @size*0.2
          @ctx.globalAlpha = 1

        if (p = pressure[k]) and p != 0
          @ctx.fillStyle = if p < 0 then 'rgba(255,0,0,0.2)' else 'rgba(0,255,0,0.2)'
          @ctx.fillRect px, py, @size, @size

    zeroPos = @worldToScreen 0, 0
    @ctx.lineWidth = 3
    @ctx.strokeStyle = 'yellow'
    @ctx.strokeRect zeroPos.px, zeroPos.py, @limit.width * @size, @limit.height * @size

  drawEditControls: ->
    mx = @mouse.x
    my = @mouse.y
    {tx:mtx, ty:mty} = @screenToWorld mx, my
    {px:mpx, py:mpy} = @worldToScreen mtx, mty


    if @mouse.mode is 'select'
      sa = @selectedA
      sb = @selectedB
    else if @imminent_select
      sa = sb = {tx:mtx, ty:mty}

    @ctx.lineWidth = 1
    if sa
      {tx, ty, tw, th} = enclosingRect sa, sb
      {px, py} = @worldToScreen tx, ty
      @ctx.fillStyle = 'rgba(0,0,255,0.5)'
      @ctx.fillRect px, py, tw*@size, th*@size

      @ctx.strokeStyle = 'rgba(0,255,255,0.5)'
      @ctx.strokeRect px, py, tw*@size, th*@size
    else if @selection
      @ctx.globalAlpha = 0.8
      for y in [0...@selection.th]
        for x in [0...@selection.tw]
          {px, py} = @worldToScreen x+mtx-@selectOffset.tx, y+mty-@selectOffset.ty
          if px+@size >= 0 and px < @canvas.width and py+@size >= 0 and py < @canvas.height
            v = @selection[[x,y]]
            @ctx.fillStyle = if v then colors[v] else colors['solid']
            @ctx.fillRect px, py, @size, @size
      @ctx.strokeStyle = 'rgba(0,255,255,0.5)'
      @ctx.strokeRect mpx - @selectOffset.tx*@size, mpy - @selectOffset.ty*@size, @selection.tw*@size, @selection.th*@size
      @ctx.globalAlpha = 1
    else if mpx?
      # Mouse hover
      @ctx.fillStyle = colors[@placing ? 'solid']
      @ctx.fillRect mpx + @size/4, mpy + @size/4, @size/2, @size/2

      @ctx.strokeStyle = if @simulator.get(mtx, mty) then 'black' else 'white'
      @ctx.strokeRect mpx + 1, mpy + 1, @size - 2, @size - 2


    return
