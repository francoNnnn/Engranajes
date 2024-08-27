# By Frank Leenaars
# University of Twente - Department of Instructional Technology
# Licensed under the MIT license
"use strict"

# TODO:
# - use "for element, i in ..." where appropriate
# - chained comparisons: 1 < x < 100
# - disallow chains crossing gears' axes? (if gear on higher level)
# - allow gears to overlap other gears' axes when the larger gear is on a higher level?

# imports
Point = window.gearsketch.Point
ArcSegment = window.gearsketch.ArcSegment
LineSegment = window.gearsketch.LineSegment
Util = window.gearsketch.Util
Gear = window.gearsketch.model.Gear
Chain = window.gearsketch.model.Chain
Board = window.gearsketch.model.Board
Game = window.gearsketch.model.Game
ValidationResult = window.gearsketch.model.ValidationResult

# -- constants --
FPS = 60
MIN_GEAR_TEETH = 8
MIN_MOMENTUM = 0.2

# ---------------------------
# -------- GearSketch -------
# ---------------------------
class GearSketch
  # -- imported constants --
  MODULE = Util.MODULE
  AXIS_RADIUS = Util.AXIS_RADIUS

  BUTTON_INFO = [
    ["backButton", "backButton.png"]
    ["playButton", "PlayIcon.png"]
#    ["clearButton", "ClearIcon.png"]
#    ["cloudButton", "CloudIcon.png"]
    ["helpButton", "HelpIcon.png"]
#    ["addTeethButton", "Gear.png"]
#    ["removeTeethButton", "Gear.png"]
#    ["rpmUpButton", "Gear.png"]
#    ["rpmDownButton", "Gear.png"]
#    ["drawMenuButton", "menu.png"]
    ["selectInputGear", "GearInput.png"]
    ["selectOutputGear", "GearOutput.png"]
    ["showFormulas","flask.png"]
  ]

  EXTENDED_BUTTON_INFO = [
    ["showObjectives","info.png"]
    ["tryVerify","verify.png"]
  ]

  MovementAction =
    PEN_DOWN: "penDown"
    PEN_UP: "penUp"
    PEN_TAP: "penTap"

  MovementType =
    STRAIGHT: "straight"
    CIRCLE: "circle"
    LEFT_HALF_CIRCLE: "leftHalfCircle"
    RIGHT_HALF_CIRCLE: "rightHalfCircle"

  Action =
    DRAGGING: "dragging"
    SETTING_MOMENTUM: "settingMomentum"
    STROKING: "stroking"

  buttons: {}
  loadedButtons: 0
  areButtonsLoaded: false

  gearImages: {}

  currentAction: null
  isPenDown: false
  stroke: []
  offset: new Point()
  isPlaying: false

  isDrawingMenu: false

  message: ""
  messageColor: "black"

  # usage demo
  pointerLocation: new Point()
  currentDemoMovement: 0
  movementCompletion: 0
  restTimer: 0

  # Passing false to showButtons will hide them, unless the demo is
  # playing. This comes handy when adding controls outside the canvas.
  constructor: (showButtons = true, @simpleMenu = false) ->
    @loadBoard()
    @loadButtons()
    @showButtons = showButtons
    @loadDemoPointer()
    @loadGameMenus(@game)
    @canvas = document.getElementById("gearsketch_canvas")
    @canvasOffsetX = @canvas.getBoundingClientRect().left
    @canvasOffsetY = @canvas.getBoundingClientRect().top
    @isDemoPlaying = false
    @updateCanvasSize()
    @addCanvasListeners()
    @lastUpdateTime = new Date().getTime()
    @updateAndDraw()

  buttonLoaded: ->
    total = BUTTON_INFO.length
    total += EXTENDED_BUTTON_INFO.length if not @simpleMenu
    @loadedButtons++
    if @loadedButtons is BUTTON_INFO.length
      @areButtonsLoaded = true

  loadButtons: ->
    x = y = 20
    AllButtons = BUTTON_INFO
    AllButtons = AllButtons.concat EXTENDED_BUTTON_INFO if not @simpleMenu
    for [name, file] in AllButtons
      button = new Image()
      button.name = name
      button.onload = => @buttonLoaded()
      button.src = "img/" + file
      button.location = new Point(x, y)
      button.padding = 3
      @buttons[name] = button
      #console.log(button.src + x)
      x += 80


  loadDemoPointer: ->
    image = new Image()
    image.onload = => @pointerImage = image
    image.src = "img/hand.png"

  loadBoard: ->
    @game=if parent.location.hash.length > 1
      try
        hash = parent.location.hash.substr(1)
        gameJSON = Util.sendGetRequest("boards/#{hash}.json")
        console.log JSON.parse(gameJSON)
        Game.fromObject(JSON.parse(gameJSON))
      catch error
        console.log(error)
        @displayMessage("Error: could not load game", "red", 2000)
        @simpleMenu = true
        new Game()
    else
      @simpleMenu = true
      new Game(new Board())

    @game.key = parent.location.hash.substr(1)
    @board = @game.board
    @initTime= new Date().getTime()
    @addGearImage(gear) unless id is @board.getInputGear()?.id or id is @board.getOutputGear()?.id  for id, gear of @board.getGears()

  displayMessage: (message, color = "black", time = 0) ->
    @message = message
    @messageColor = color
    if time > 0
      setTimeout((=> @clearMessage()), time)

  clearMessage: ->
    @message = ""

  shouldShowButtons: ->
    return @showButtons or @isDemoPlaying

  # Input callback methods
  addCanvasListeners: ->
    canvasEventHandler = Hammer(@canvas, {drag_min_distance: 1})
    canvasEventHandler.on("touch", ((e) => @forwardPenDownEvent.call(this, e)))
    canvasEventHandler.on("drag", ((e) => @forwardPenMoveEvent.call(this, e)))
    canvasEventHandler.on("release", ((e) => @forwardPenUpEvent.call(this, e)))

  forwardPenDownEvent: (event) ->
    event.gesture.preventDefault()
    if @isDemoPlaying
      @stopDemo()
    else
      x = event.gesture.center.pageX - @canvasOffsetX
      y = event.gesture.center.pageY - @canvasOffsetY
      @handlePenDown(x, y)

  forwardPenMoveEvent: (event) ->
    event.gesture.preventDefault()
    unless @isDemoPlaying
      x = event.gesture.center.pageX - @canvasOffsetX
      y = event.gesture.center.pageY - @canvasOffsetY
      @handlePenMove(x, y)

  forwardPenUpEvent: (event) ->
    unless @isDemoPlaying
      @handlePenUp()

  handlePenDown: (x, y) ->
    point = new Point(x, y)
    ###########
    #console.log(point)
    #console.log(@selectedGear)
    #console.log("RPM="+@selectedGear?.rpm)
    #console.log("RPM1="+@selectedGear?.momentum*60/(2*Math.PI))
    if @isPenDown
      # pen released outside of canvas
      @handlePenUp()
    else
      #@isDrawingMenu = false
      @isPlaying = false
      button = @getButtonAt(x, y)
      if button
        if button.name is "playButton"
          @isPlaying = true
          if @board.getGearList().every((g) -> g.momentum is 0)
            @displayMessage("Add some arrows!", "black", 2000)
        else if button.name is "clearButton"
          # remove hash from url and clear board
          parent.location.hash = ""
          @board.clear()
        else if button.name is "cloudButton"
          @uploadBoard()
        else if button.name is "helpButton"
          @playDemo()
        else if button.name is "addTeethButton"
          @addTeeth @selectedGear
        else if button.name is "removeTeethButton"
          @removeTeeth @selectedGear
        else if button.name is "rpmUpButton"
          @rpmUp @selectedGear
        else if button.name is "rpmDownButton"
          @rpmDown @selectedGear
        else if button.name is "drawMenuButton"
          @isDrawingMenu = true
        else if button.name is "selectInputGear"
          @selectInputGear()
        else if button.name is "selectOutputGear"
          @selectOutputGear()
        else if button.name is "showObjectives"
          @showObjectivesModal()
        else if button.name is "tryVerify"
          @showSubmitAnswerModal()
        else if button.name is "showFormulas"
          @showFormulasModal()
        else if button.name is "backButton"
          @showBackConfirmationModal()

      else
        @removeMenu()
        @isDrawingMenu = false

        {gear, selection} = @gearAt(x,y)
        if gear
          @selectedGear = gear
          if selection is "center"
            @currentAction = Action.DRAGGING
            @offset = point.minus(@selectedGear.location)
          else
            @currentAction = Action.SETTING_MOMENTUM
            @selectedGear.momentum = 0
            @selectedGearMomentum = @calculateMomentumFromCoords(@selectedGear, x, y)
        else
          @currentAction = Action.STROKING
          @stroke.push(point)
        @isPenDown = true


  handlePenMove: (x, y) ->
    point = new Point(x, y)
    if @isPenDown
      if @currentAction is Action.DRAGGING
        goalLocation = point.minus(@offset)
        canPlaceGear = @board.placeGear(@selectedGear, goalLocation)
        if canPlaceGear
          @goalLocationGear = null
        else
          @goalLocationGear =
            new Gear(goalLocation, @selectedGear.rotation, @selectedGear.numberOfTeeth, @selectedGear.id)
      else if @currentAction is Action.SETTING_MOMENTUM
        @selectedGearMomentum = @calculateMomentumFromCoords(@selectedGear, x, y)
      else if @currentAction is Action.STROKING
        @stroke.push(point)

  handlePenUp: ->
    @board.calculateRPM()
    if @isPenDown
      if @currentAction is Action.SETTING_MOMENTUM
        if Math.abs(@selectedGearMomentum) > MIN_MOMENTUM
          #@selectedGear.momentum = @selectedGearMomentum  #original momentum
          @selectedGear.momentum = @rpmToMomentum Math.round @momentumToRPM @selectedGearMomentum
          #settingrpms  ####
          #@board.calculateRPM(@selectedGear,@selectedGearMomentum,{})
          #@selectedGear.rpm = @momentumToRPM(@selectedGearMomentum)
        else
          @selectedGear.momentum = 0
        @selectedGearMomentum = 0
        #@board.calculateRPM()
      else if @currentAction is Action.STROKING
        @processStroke()
      # MINGO fijarse que no haya efectos adversos por comentar la linea que sigue
      #@selectedGear = null
      @goalLocationGear = null
      @isPenDown = false
      @currentAction = null

  isButtonAt: (x, y, button) ->
    x > button.location.x and
    x < button.location.x + button.width + 2 * button.padding and
    y > button.location.y and
    y < button.location.y + button.height + 2 * button.padding

  getButtonAt: (x, y) ->
    if not @shouldShowButtons()
        return null

    for own buttonName, button of @buttons
      if @isButtonAt(x, y, button)
        return button
    null

  gearAt: (x, y) ->
    point = new Point(x, y)
    gear = @board.getGearAt(point)
    if not gear
      {gear: null}
    else if gear.location.distance(point) < 0.5 * gear.outerRadius
      {gear: gear, selection: "center"}
    else
      {gear: gear, selection: "edge"}

  normalizeStroke: (stroke) ->
    MIN_POINT_DISTANCE = 10
    normalizedStroke = []
    if stroke.length > 0
      [p1, strokeTail...] = stroke
      normalizedStroke.push(p1)
      for p2 in strokeTail
        if p1.distance(p2) > MIN_POINT_DISTANCE
          normalizedStroke.push(p2)
          p1 = p2
    normalizedStroke

  createGearFromStroke: (stroke) ->
    numberOfPoints = stroke.length
    if numberOfPoints > 0
      sumX = 0
      sumY = 0
      minX = Number.MAX_VALUE
      maxX = Number.MIN_VALUE
      minY = Number.MAX_VALUE
      maxY = Number.MIN_VALUE
      for p in stroke
        sumX += p.x
        sumY += p.y
        minX = Math.min(minX, p.x)
        maxX = Math.max(maxX, p.x)
        minY = Math.min(minY, p.y)
        maxY = Math.max(maxY, p.y)
      width = maxX - minX
      height = maxY - minY
      t = Math.floor(0.5 * (width + height) / MODULE)

      # find area, based on http://stackoverflow.com/questions/451426
      # /how-do-i-calculate-the-surface-area-of-a-2d-polygon
      doubleArea = 0
      for p1, i in stroke
        p2 = stroke[(i + 1) % numberOfPoints]
        doubleArea += p1.cross(p2)

      # create a new gear if the stroke is sufficiently circle-like and large enough
      area = Math.abs(doubleArea) / 2
      radius = 0.25 * ((maxX - minX) + (maxY - minY))
      idealTrueAreaRatio = (Math.PI * Math.pow(radius, 2)) / area
      if idealTrueAreaRatio > 0.80 and idealTrueAreaRatio < 1.20 and t > MIN_GEAR_TEETH
        x = sumX / numberOfPoints
        y = sumY / numberOfPoints
        return new Gear(new Point(x, y), 0, t)
    null

  removeStrokedGears: (stroke) ->
    @selectedGear = null
    for own id, gear of @board.getTopLevelGears()
      if Util.pointPathDistance(gear.location, stroke, false) < gear.innerRadius
        @board.removeGear(gear)

  gearImageLoaded: (numberOfTeeth, image) ->
    @gearImages[numberOfTeeth] = image

  addGearImage: (gear) ->
    # draw gear on temporary canvas
    gearCanvas = document.createElement("canvas")
    size = 2 * (gear.outerRadius + MODULE) # slightly larger than gear diameter
    gearCanvas.height = size
    gearCanvas.width = size
    ctx = gearCanvas.getContext("2d")
    gearCopy = new Gear(new Point(0.5 * size, 0.5 * size), 0, gear.numberOfTeeth, gear.id)
    @drawGear(ctx, gearCopy)

    # convert canvas to png
    image = new Image()
    #image.color = color
    image.onload = => @gearImageLoaded(gear.numberOfTeeth, image)
    image.src = gearCanvas.toDataURL("image/png")

  isChainStroked: (stroke) ->
    for own id, chain of @board.getChains()
      if chain.intersectsPath(stroke)
        return true
    false

  removeStrokedChains: (stroke) ->
    for own id, chain of @board.getChains()
      if chain.intersectsPath(stroke)
        @board.removeChain(chain)

  processStroke: ->
    normalizedStroke = @normalizeStroke(@stroke)
    if normalizedStroke.length >= 3
      if Util.findGearsInsidePolygon(normalizedStroke, @board.getGears()).length > 0
        chain = new Chain(normalizedStroke)
        @board.addChain(chain)
      else
        gear = @createGearFromStroke(normalizedStroke)
        if gear?
          if @board.addGear(gear) and !(gear.numberOfTeeth of @gearImages)
            @addGearImage(gear)
        else if @isChainStroked(normalizedStroke)
          @removeStrokedChains(normalizedStroke)
        else
          @removeStrokedGears(normalizedStroke)
    @stroke = []

  calculateMomentumFromCoords: (gear, x, y) ->
    angle = Math.atan2(y - gear.location.y, x - gear.location.x)
    angleFromTop = angle + 0.5 * Math.PI
    if angleFromTop < Math.PI
      angleFromTop
    else
      angleFromTop - 2 * Math.PI

  # -- updating --
  updateAndDraw: =>
    setTimeout((=>
      requestAnimationFrame(@updateAndDraw)
      @update()
      @draw()
    ), 1000 / FPS)

  update: =>
    updateTime = new Date().getTime()
    delta = updateTime - @lastUpdateTime
    if @isPlaying
      @board.rotateAllTurningObjects(delta)
    if @isDemoPlaying
      @updateDemo(delta)
    @lastUpdateTime = updateTime

  # -- rendering --
  drawGear: (ctx, gear, color = "black") ->
    {x, y} = gear.location
    rotation = gear.rotation
    #@game.validate()
    numberOfTeeth = gear.numberOfTeeth
    if gear is @selectedGear
      color="green"
    if gear.id is @board.getInputGear()?.id
      color="blue"
    if gear.id is @board.getOutputGear()?.id
      color="violet"
    gearImage = @gearImages[gear.numberOfTeeth]
    if color is "black" and gearImage?
      # use predrawn image instead of drawing it again
      gearImage = @gearImages[gear.numberOfTeeth]
      ctx.save()
      ctx.translate(x, y)
      ctx.rotate(rotation)
      ctx.drawImage(gearImage, -0.5 * gearImage.width, -0.5 * gearImage.height)
      ctx.restore()
      return

    # draw teeth
    angleStep = 2 * Math.PI / numberOfTeeth
    innerPoints = []
    outerPoints = []
    for i in [0...numberOfTeeth]
      for r in [0...4]
        if r is 0 or r is 3
          innerPoints.push(Point.polar((i + 0.25 * r) * angleStep, gear.innerRadius))
        else
          outerPoints.push(Point.polar((i + 0.25 * r) * angleStep, gear.outerRadius))
    ctx.save()
    ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.translate(x, y)
    ctx.rotate(rotation)
    ctx.beginPath()
    ctx.moveTo(gear.innerRadius, 0)
    for i in [0...numberOfTeeth * 2]
      if i % 2 is 0
        ctx.lineTo(innerPoints[i].x, innerPoints[i].y)
        ctx.lineTo(outerPoints[i].x, outerPoints[i].y)
      else
        ctx.lineTo(outerPoints[i].x, outerPoints[i].y)
        ctx.lineTo(innerPoints[i].x, innerPoints[i].y)
    ctx.closePath()
    ctx.fill()
    ctx.stroke()

    # draw axis
    ctx.beginPath()
    ctx.moveTo(AXIS_RADIUS, 0)
    ctx.arc(0, 0, AXIS_RADIUS, 0, 2 * Math.PI, true)
    ctx.closePath()
    ctx.stroke()

    # draw rotation indicator line
    ctx.beginPath()
    ctx.moveTo(AXIS_RADIUS, 0)
    ctx.lineTo(gear.innerRadius, 0)
    ctx.closePath()
    ctx.stroke()
    ctx.restore()

  drawButton: (ctx, button) ->
    {x, y} = button.location
    padding = button.padding
    ctx.save()
    ctx.translate(x, y)
    ctx.beginPath()

    # draw a round rectangle
    radius = 10
    width = button.width + 2 * padding
    height = button.height + 2 * padding
    ctx.moveTo(radius, 0)
    ctx.lineTo(width - radius, 0)
    ctx.quadraticCurveTo(width, 0, width, radius)
    ctx.lineTo(width, height - radius)
    ctx.quadraticCurveTo(width, height, width - radius, height)
    ctx.lineTo(radius, height)
    ctx.quadraticCurveTo(0, height, 0, height - radius);
    ctx.lineTo(0, radius)
    ctx.quadraticCurveTo(0, 0, radius, 0);

    if button.name is @selectedButton
      ctx.fillStyle = "rgba(50, 150, 255, 0.8)"
    else
      ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
    ctx.fill()
    ctx.lineWidth = 1
    ctx.strokeStyle = "black"
    ctx.stroke()
    ctx.drawImage(button, padding, padding)
    ctx.restore()

  drawMomentum: (ctx, gear, momentum, color = "red") ->
    pitchRadius = gear.pitchRadius
    top = new Point(gear.location.x, gear.location.y - pitchRadius)
    ctx.save()
    ctx.lineWidth = 5
    ctx.lineCap = "round"
    ctx.strokeStyle = color
    ctx.translate(top.x, top.y)

    # draw arc
    ctx.beginPath()
    ctx.arc(0, pitchRadius, pitchRadius, -0.5 * Math.PI, momentum - 0.5 * Math.PI, momentum < 0)
    ctx.stroke()

    # draw arrow head
    length = 15
    angle = 0.2 * Math.PI
    headX = -Math.cos(momentum + 0.5 * Math.PI) * pitchRadius
    headY = pitchRadius - Math.sin(momentum + 0.5 * Math.PI) * pitchRadius
    head = new Point(headX, headY)
    sign = Util.sign(momentum)
    p1 = head.minus(Point.polar(momentum + angle, sign * length))
    ctx.beginPath()
    ctx.moveTo(headX, headY)
    ctx.lineTo(p1.x, p1.y)
    ctx.stroke()
    p2 = head.minus(Point.polar(momentum - angle, sign * length))
    ctx.beginPath()
    ctx.moveTo(headX, headY)
    ctx.lineTo(p2.x, p2.y)
    ctx.stroke()
    ctx.restore()


  drawChain: (ctx, chain) ->
    ctx.save()
    ctx.lineWidth = Chain.WIDTH
    ctx.lineCap = "round"
    ctx.strokeStyle = "rgb(0, 0, 255)"
    ctx.moveTo(chain.segments[0].start.x, chain.segments[0].start.y)
    for segment in chain.segments
      if segment instanceof ArcSegment
        isCounterClockwise = (segment.direction is Util.Direction.COUNTER_CLOCKWISE)
        ctx.beginPath()
        ctx.arc(segment.center.x, segment.center.y, segment.radius,
          segment.startAngle, segment.endAngle, isCounterClockwise)
        ctx.stroke()
      else
        ctx.beginPath()
        ctx.moveTo(segment.start.x, segment.start.y)
        ctx.lineTo(segment.end.x, segment.end.y)
        ctx.stroke()
    ctx.fillStyle = "white"
    for point in chain.findPointsOnChain(25)
      ctx.beginPath()
      ctx.arc(point.x, point.y, 3, 0, 2 * Math.PI, true)
      ctx.fill()
    ctx.restore()

  drawDemoPointer: (ctx, location) ->
    ctx.drawImage(@pointerImage, location.x - 0.5 * @pointerImage.width, location.y)

  draw: ->
    if @canvas.getContext?
      @removePlusButton()
      #@updateCanvasSize()
      ctx = @canvas.getContext("2d")
      ctx.clearRect(0, 0, @canvas.width, @canvas.height)

      # draw gears
      sortedGears = @board.getGearsSortedByGroupAndLevel()
      arrowsToDraw = []
      for i in [0...sortedGears.length]
        gear = sortedGears[i]
        momentum = gear.momentum
        if gear is @selectedGear and @goalLocationGear
          @drawGear(ctx, gear, "grey")
          if momentum
            arrowsToDraw.push([gear, momentum, "grey"])
        else
          @drawGear(ctx, gear)
          if momentum
            arrowsToDraw.push([gear, momentum, "red"])

        # draw chains and arrows when all the gears in current group on current level are drawn
        shouldDrawChainsAndArrows =
          (i is sortedGears.length - 1) or
          (@board.getLevelScore(gear) isnt @board.getLevelScore(sortedGears[i + 1]))
        if shouldDrawChainsAndArrows
          for chain in @board.getChainsInGroupOnLevel(gear.group, gear.level)
            @drawChain(ctx, chain)
          for arrow in arrowsToDraw
            @drawMomentum(ctx, arrow[0], arrow[1], arrow[2])
          arrowsToDraw = []

      # draw goalLocationGear
      if @goalLocationGear
        @drawGear(ctx, @goalLocationGear, "red")

      #if @outputGear?
      #  @drawGear(ctx, @outputGear, "violet")

      #else if @inputGear?
      #  @drawGear(ctx, @inputGear, "blue")

      #else if @selectedGear?
      #  @drawGear(ctx, @selectedGear, "blue")

      # draw selected gear momentum
      if @selectedGear? and @selectedGearMomentum
        @drawMomentum(ctx, @selectedGear, @selectedGearMomentum)

      # draw stroke
      if @stroke.length > 0
        ctx.save()
        ctx.strokeStyle = "black"
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(@stroke[0].x, @stroke[0].y)
        for i in [1...@stroke.length]
          ctx.lineTo(@stroke[i].x, @stroke[i].y)
        ctx.stroke()
        ctx.restore()

      # draw menu mingo
      if @isDrawingMenu
        @drawMenu ctx, @selectedGear
      else if @selectedGear?
        @drawPlusButton @selectedGear

      # draw buttons
      if @areButtonsLoaded and @shouldShowButtons()
        for own buttonName of @buttons
          @drawButton(ctx, @buttons[buttonName])

      # draw message
      if @message.length > 0
        ctx.save()
        ctx.fillStyle = @messageColor
        ctx.font = "bold 20px Arial"
        ctx.fillText(@message, 20, 120)
        ctx.restore()

      if @game?.title.length > 0
        ctx.save()
        ctx.fillStyle = @messageColor
        ctx.font = "bold 32px Arial"
        ctx.fillText(@game.title, 200, 50)
        ctx.restore()

      # draw Ratio message
      ratio=@board.getOutputGear()?.rpm/@board.getInputGear()?.rpm
      if typeof ratio is 'number' and not isNaN(ratio)
      #= @canvas.parentElement.getBoundingClientRect().width
        ctx.save()
        ctx.fillStyle = @messageColor
        ctx.font = "bold 20px Arial"
        ctx.fillText('I= '+ratio,  @canvas.width-250, 120)
        ctx.restore()

      # draw demo text and pointer
      if @isDemoPlaying and @pointerImage
        @drawDemoPointer(ctx, @pointerLocation)



  updateCanvasSize: () ->
    @canvas.width = @canvas.parentElement.getBoundingClientRect().width
    @canvas.height = @canvas.parentElement.getBoundingClientRect().height
    initialX= 400
    initialX= 320 if @simpleMenu
    @buttons["playButton"].location.x = @buttons["backButton"].location.x + 80
    @buttons["selectInputGear"].location.x = Math.max(@canvas.width - initialX, @buttons["backButton"].location.x + 80)
    @buttons["selectOutputGear"].location.x = @buttons["selectInputGear"].location.x + 80
    @buttons["showFormulas"].location.x = @buttons["selectOutputGear"].location.x + 80
    @buttons["helpButton"].location.x = @buttons["showFormulas"].location.x + 80

    if not @simpleMenu
      @buttons["showObjectives"].location.x = @buttons["showFormulas"].location.x + 80
      @buttons["tryVerify"].location.x =  Math.max(@buttons["backButton"].location.x ,@canvas.width - 181)
      @buttons["tryVerify"].location.y = @canvas.height - 80
      @buttons["helpButton"].location.x = @buttons["showObjectives"].location.x + 80

#    console.log (@canvas.height)
#    @buttons["clearButton"].location.x = Math.max(@canvas.width - 260, @buttons["playButton"].location.x + 80)
#    @buttons["cloudButton"].location.x = @buttons["clearButton"].location.x + 80
#    @buttons["helpButton"].location.x = @buttons["cloudButton"].location.x + 80


# -- usage demo --
  loadDemoMovements: ->
    @demoMovements = [
      from: @getButtonCenter("helpButton")
      to: new Point(400, 200)
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 100
      duration: 1500
    ,
      to: new Point(600, 200)
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 40
      duration: 1000
    ,
      to: new Point(600, 240)
      type: MovementType.STRAIGHT
      duration: 500
    ,
      to: new Point(400, 300)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      to: new Point(200, 180)
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 90
      duration: 1000
    ,
      to: new Point(200, 260)
      type: MovementType.STRAIGHT
      duration: 500
    ,
      to: new Point(280, 260)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      to: new Point(650, 220)
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.CIRCLE
      radius: 80
      duration: 1000
    ,
      to: new Point(380, 150)
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      atStart: MovementAction.PEN_DOWN
      type: MovementType.LEFT_HALF_CIRCLE
      radius: 140
      duration: 1500
      pause: 0
    ,
      to: new Point(700, 400)
      type: MovementType.STRAIGHT
      duration: 1000
      pause: 0
    ,
      type: MovementType.RIGHT_HALF_CIRCLE
      radius: 110
      duration: 1000
      pause: 0
    ,
      to: new Point(380, 150)
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      to: new Point(285, 180)
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      to: new Point(250, 190)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    , # press play button
      to: @getButtonCenter("playButton")
      atEnd: MovementAction.PEN_TAP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      to: new Point(525, 250)
      type: MovementType.STRAIGHT
      duration: 3000
    ,
      to: new Point(625, 150)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      to: new Point(120, 250)
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      to: new Point(750, 300)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ,
      to: new Point(525, 200)
      type: MovementType.STRAIGHT
      duration: 1000
    ,
      to: new Point(300, 400)
      atStart: MovementAction.PEN_DOWN
      atEnd: MovementAction.PEN_UP
      type: MovementType.STRAIGHT
      duration: 1500
    ]

  getButtonCenter: (buttonName) ->
    button = @buttons[buttonName]
    buttonCorner = new Point(button.location.x, button.location.y)
    buttonCorner.plus(new Point(0.5 * button.width + button.padding, 0.5 * button.height + button.padding))

  updateDemo: (delta) ->
    # check if resting or if last movement completed
    if @restTimer > 0
      @restTimer = Math.max(@restTimer - delta, 0)
      return
    else if @currentDemoMovement is @demoMovements.length
      @stopDemo()
      return

    # advance movement
    movement = @demoMovements[@currentDemoMovement]
    if @movementCompletion is 0
      movement.from ?= @pointerLocation
      movement.pause ?= 500
      @pointerLocation = movement.from.clone()
      if movement.atStart is MovementAction.PEN_DOWN
        @handlePenDown(@pointerLocation.x, @pointerLocation.y)
    if @movementCompletion < 1
      @movementCompletion = Math.min(1, @movementCompletion + delta / movement.duration)
      @updatePointerLocation(movement, @movementCompletion)
      @handlePenMove(@pointerLocation.x, @pointerLocation.y)
    if @movementCompletion is 1
      if movement.atEnd is MovementAction.PEN_TAP
        @handlePenDown(@pointerLocation.x, @pointerLocation.y)
        @handlePenUp()
      else if movement.atEnd is MovementAction.PEN_UP
        @handlePenUp()
      @restTimer = movement.pause
      @movementCompletion = 0
      @currentDemoMovement++

  updatePointerLocation: (movement, movementCompletion) ->
    if movement.type is MovementType.STRAIGHT
      delta = movement.to.minus(movement.from)
      @pointerLocation = movement.from.plus(delta.times(movementCompletion))
    else if movement.type is MovementType.CIRCLE
      center = new Point(movement.from.x , movement.from.y + movement.radius)
      @pointerLocation = center.plus(Point.polar(Math.PI - (movementCompletion - 0.25) * 2 * Math.PI, movement.radius))
    else if movement.type is MovementType.LEFT_HALF_CIRCLE
      center = new Point(movement.from.x , movement.from.y + movement.radius)
      angle = 1.5 * Math.PI - movementCompletion * Math.PI
      @pointerLocation = center.plus(Point.polar(angle, movement.radius))
    else if movement.type is MovementType.RIGHT_HALF_CIRCLE
      center = new Point(movement.from.x , movement.from.y - movement.radius)
      angle = 0.5 * Math.PI - movementCompletion * Math.PI
      @pointerLocation = center.plus(Point.polar(angle, movement.radius))

  playDemo: ->
    @loadDemoMovements() # load these on each play in case canvas size changed
    @boardBackup = @board.clone()
    @board.clear()
    @currentDemoMovement = 0
    @movementCompletion = 0
    @isDemoPlaying = true
    @displayMessage("click anywhere to stop the demo")

  stopDemo: ->
    @isDemoPlaying = false
    @restTimer = 0
    @stroke = []
    @selectedGear = null
    @selectedIcon = "gearIcon"
    @board.restoreAfterDemo(@boardBackup)
    @clearMessage()

  boardUploaded: (event) ->
    #parent.location.hash = event.target.responseText.trim()
    @displayMessage("Board saved. Share it by copying the text in your address bar.", "black", 4000)

  uploadBoard: ->
    boardJSON = JSON.stringify(@game)
    Util.sendPostRequest(boardJSON, "upload_board.php", ((event) => @boardUploaded(event)))

  addTeeth:(gear)->
    @board.removeGear gear
    gear.numberOfTeeth = gear.numberOfTeeth+1
    gear = Gear.fromObject gear
    @selectedGear = gear
    if @board.addGear(gear) and !(gear.numberOfTeeth of @gearImages)
      @addGearImage gear


  removeTeeth: (gear)->
    if gear.numberOfTeeth>6
      @board.removeGear gear
      gear.numberOfTeeth = gear.numberOfTeeth-1
      gear = Gear.fromObject gear
      @selectedGear = gear
      if @board.addGear(gear) and !(gear.numberOfTeeth of @gearImages)
        @addGearImage gear

  setRPM: (rpm)->
    @selectedGear.momentum = rpm*2*Math.PI/60
    #@selectedGear.rpm=rpm

  rpmUp:(gear)->
    gear.momentum += @rpmToMomentum 1
    #@currentAction = Action.SETTING_MOMENTUM
    #@selectedGearMomentum=gear.momentum
    #@handlePenUp()

  rpmDown:(gear)->
    gear.momentum -= @rpmToMomentum 1
    #@currentAction = Action.SETTING_MOMENTUM
    #@selectedGearMomentum=gear.momentum
    #@handlePenUp()
    #if gear.momentum is 0

  momentumToRPM:(momentum)->
    momentum*60/(2*Math.PI)

  rpmToMomentum:(rpm)->
    rpm*(2*Math.PI)/60


  selectInputGear:()->
    #@inputGear=@selectedGear
    @board.setInputGear @selectedGear

  selectOutputGear:()->
    #@outputGear=@selectedGear
    @board.setOutputGear @selectedGear

  showFormulasModal: () ->
    $('#formulasModal').modal 'toggle'

  showObjectivesModal: () ->
    $('#objectivesModal').modal 'toggle'

  showSubmitAnswerModal: () ->
    $('#submitAnswerModal').modal 'toggle'

  showBackConfirmationModal: () ->
    $('#backConfirmationModal').modal 'toggle'

  loadGameMenus:(game)->
    #objectives modal
    $('#objectivesModal .modal-title').html game.modals?.objectives?.header
    $('#objectivesModal .modal-body').html game.modals?.objectives?.body
    $('#objectivesModal').modal('toggle') if game.modals?.objectives?.body

    $('#somethingWentWrong .modal-title').html game.modals?.validationError?.header
    $('#somethingWentWrong .modal-body').html game.modals?.validationError?.body

    $('#validationsPassed .modal-title').html game.modals?.validationPassed?.header
    $('#validationsPassed .modal-body').html game.modals?.validationPassed?.body

    $('#backConfirmationModal .modal-title').html game.modals?.backToMenu?.header
    $('#backConfirmationModal .modal-body').html game.modals?.backToMenu?.body
    $('#backConfirmationModal .btn-danger').html game.modals?.backToMenu?.performAction if(game.modals?.backToMenu?.performAction)

    #validate modal
    $('#submitAnswerModal .modal-title').html game.modals?.objectives?.header
    $('#submitAnswerModal .form-horizontal').append game.modals?.validate?.body
    for id, input of game.inputs
      $('#submitAnswerModal .form-horizontal').append @createField input


  createField: (input) ->
    ret=""
    ret="""<div class="col-sm-12">
      <p class="form-control-static">#{input.properties.objective}</p>
      </div><br/>""" if input.properties?.objective?
    ret+="""
      <label for='#{input.id}'  class="col-sm-3 control-label">#{input.properties?.beforeInputText}</label>
      """ if input.properties?.beforeInputText?
    
    if input.inputType is "radio"
      ret += """<div class="col-sm-12" >"""
      for option in input.properties?.options
        ret += """
<div class="radio">
          <label><input type="radio" name="#{input.id}" value="#{option}" class="radio" />#{option}</label>
</div>
          """
      ret += """</div>"""
    else
      ret += """
        <div class="col-sm-7">
        <input id='#{input.id}' type="text" class="form-control" placeholder="Text input"/>
        </div>"""

    ret +="""
      <label for='#{input.id}' class="col-sm-1 control-label">#{input.properties?.afterInputText}</label>
    <div class="col-sm-1"/>
      """ if input.properties?.afterInputText?

    ret="""  <div class="form-group">#{ret}</div> """
    ret

  verify: ->
    @game.inputs[input.id].actualValue = input.value for input in $('#inputs .form-control')
    @game.inputs[input.name].actualValue = input.value for input in $('#inputs .radio:checked')
    passed=@game.validate()
    currTime = new Date().getTime()
    elapsedTime = currTime - @initTime
    #@initTime = new Date().getTime()
    result= new ValidationResult(@game.level,@game.key,elapsedTime/1000,passed)
    
    Util.sendPostRequest(JSON.stringify(result), "/verify")
    if passed
      $('#validationsPassed').modal('toggle')
    else
      $('#somethingWentWrong').modal('toggle')


  MENU_BUTTONS = [
    ["addTeethButton", "zup.png", [-125,-120]]
    ["removeTeethButton", "zdown.png", [125,-120]]
    ["rpmUpButton", "momentumUp.png", [-125,-40]]
    ["rpmDownButton", "momentumDown.png", [125,-40]]
#    ["drawMenuButton", "hand.png"]
  ] 

  HIDDEN_MENU_BUTTONS= [
    ["drawMenuButton", "menu.png"]
  ]
  removeMenu:->
    for [name, file] in MENU_BUTTONS
      delete @buttons[name]

  removePlusButton:->
    delete @buttons["drawMenuButton"]

  drawPlusButton:(gear) ->
    #console.log gear
    {x, y} = gear.location
    radius=gear.pitchRadius
    for [name, file], i in HIDDEN_MENU_BUTTONS
      button = new Image()
      button.name = name
      button.padding = 3
      button.src = "img/" + file
      button.location = new Point(x+radius, y-radius)
      @buttons[name] = button


  loadMenuButtons:(location, width, height) ->
    {x, y} = location
    for [name, file, [xx,yy]], i in MENU_BUTTONS
      button = new Image()
      button.name = name
      button.padding = 3
      button.src = "img/" + file
      xxx= if i%%2 then x-width/2+6 else x+width/2-button.width-11 #6 de padding
      bWith= (2*button.padding)+button.width/2
      yyy= (6-bWith + y - height )+((2*bWith)*Math.floor(i/2))
      #console.log yyy
      button.location = new Point(xxx, yyy)

      @buttons[name] = button
    #console.log(button.src + x)


  drawMenu:(ctx, gear)->
    @removePlusButton()
    {x, y} = gear.location
    width = 250
    height = 217 #161
    radius = 10

    ctx.save()
    ctx.translate(x-width/2, y-20-height)
    ctx.beginPath()
#    ctx.moveTo(0, -10)
#    #ctx.lineTo(-20, -30)
#    #ctx.moveTo(-20, -30)
#    #ctx.moveTo(-20, -30)
#    ctx.quadraticCurveTo(-40, -40,-width/2, -40)
#    ctx.moveTo(-width/2, -40)
#    ctx.quadraticCurveTo(-width, -40,-width, -40-height/2)
   # ctx.moveTo(-40, -20)
    #ctx.lineTo(120, 20)
    #ctx.moveTo(120, 20)
    #ctx.lineTo(-40, 10)
    ctx.moveTo(radius, 0)
    ctx.lineTo(width - radius, 0)
    ctx.quadraticCurveTo(width, 0, width, radius)
    ctx.lineTo(width, height - radius)
    ctx.quadraticCurveTo(width, height, width - radius, height)
    ctx.lineTo(radius, height)
    ctx.quadraticCurveTo(0, height, 0, height - radius);
    ctx.lineTo(0, radius)
    ctx.quadraticCurveTo(0, 0, radius, 0);

    ctx.lineWidth = 3
    ctx.fillStyle="white"
    ctx.fill()

    ctx.fillStyle = "black"
    ctx.font = "bold 16px Arial"
    ctx.fillText("Z="+gear.numberOfTeeth, 100, 40)
    ctx.fillText("M="+Math.round(gear.momentum*100)/100 , 100, 120)
    myY=160
    ctx.fillText("-----------------" , 80, myY)
    myY+=20
    ctx.fillText("r="+gear.pitchRadius , 100, myY)
    myY+=20
    ctx.fillText("n="+Math.round(gear.rpm*100)/100 , 100, myY)


    #ctx.fillText("r="+gear.pitchRadius, 10, 60)
    #ctx.fillText("Vtan="+Math.round(gear.pitchRadius*@rpmToMomentum(gear.rpm)), 10, 80)
    ctx.strokeStyle = "black"
    ctx.stroke()
    ctx.restore()
    @loadMenuButtons gear.location, width ,height-20
#
#drawButton: (ctx, button) ->
#  {x, y} = button.location
#  padding = button.padding
#  ctx.save()
#  ctx.translate(x, y)
#  ctx.beginPath()
#
#  # draw a round rectangle
#  radius = 10
#  width = button.width + 2 * padding
#  height = button.height + 2 * padding
#  ctx.moveTo(radius, 0)
#  ctx.lineTo(width - radius, 0)
#  ctx.quadraticCurveTo(width, 0, width, radius)
#  ctx.lineTo(width, height - radius)
#  ctx.quadraticCurveTo(width, height, width - radius, height)
#  ctx.lineTo(radius, height)
#  ctx.quadraticCurveTo(0, height, 0, height - radius);
#  ctx.lineTo(0, radius)
#  ctx.quadraticCurveTo(0, 0, radius, 0);
#
#  if button.name is @selectedButton
#    ctx.fillStyle = "rgba(50, 150, 255, 0.8)"
#  else
#    ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
#  ctx.fill()
#  ctx.lineWidth = 1
#  ctx.strokeStyle = "black"
#  ctx.stroke()
#  ctx.drawImage(button, padding, padding)
#  ctx.restore()

  window.gearsketch.GearSketch = GearSketch