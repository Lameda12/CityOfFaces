-- Love2D Mask Mechanic Game
-- "The Escape from Veritas"
-- A game about seeing through lies.

-- Load level data from external file
local levels = require("levels")

-- The "Arco" Style Palette
local colors = {
  background_mask_on  = {0.96, 0.90, 0.80}, -- Sand / Paper (Light) - The Lie
  player_mask_on      = {0.82, 0.22, 0.22}, -- Vibrant Red
  walls_mask_on       = {0.20, 0.16, 0.20}, -- Dark Ink

  background_mask_off = {0.10, 0.08, 0.14}, -- Deep Night (Dark) - The Truth
  player_mask_off     = {0.00, 0.80, 0.80}, -- Neon Cyan (Ghostly)
  walls_mask_off      = {0.15, 0.12, 0.25}, -- Shadow Purple

  goal                = {0.95, 0.75, 0.20}, -- Sunset Gold
  guard               = {0.90, 0.30, 0.40}, -- Crimson
  guard_alert         = {1.00, 0.20, 0.20}, -- Bright red when chasing
  ui_background       = {0.08, 0.06, 0.10, 0.95}, -- Midnight (with alpha)
  ui_text_win         = {0.95, 0.85, 0.50}, -- Golden text
  ui_text_lose        = {0.90, 0.25, 0.25}, -- Red text
  ui_text_level       = {0.70, 0.65, 0.55}, -- Muted gold for level name
  ui_text_story       = {0.90, 0.88, 0.82}, -- Story text
  ui_text_dim         = {0.50, 0.48, 0.42}, -- Dimmed text
  finale_white        = {1, 1, 1}           -- Pure white for ending
}

-- Window and camera settings
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local cameraX, cameraY = 0, 0

-- Screen shake
local shakeDuration = 0
local shakeIntensity = 3

local tileSize = 32

-- Level state
local currentLevelIndex = 1
local mapMaskOn = nil
local mapMaskOff = nil

-- Game states
local STATE_STORY = "story"       -- Showing story text
local STATE_PLAYING = "playing"   -- Normal gameplay
local STATE_COMPLETE = "complete" -- Level complete, showing message
local STATE_GAMEOVER = "gameover" -- Player caught
local STATE_FINALE = "finale"     -- Final ending sequence
local gameState = STATE_STORY

-- Story display
local currentStory = {}
local storyTimer = 0
local storyLinesShown = 0

-- Finale sequence
local finaleTimer = 0
local finalePhase = 0  -- 0: fade out, 1: text, 2: complete
local finaleFade = 0

local player = {
  x = 0,
  y = 0,
  size = 32,
  speed = 200
}

local isMaskOn = true
local wasMaskOn = true  -- Track previous state for shake trigger

-- Guard AI states
local GUARD_PATROL = "patrol"   -- Patrolling / returning to start
local GUARD_CHASE = "chase"     -- Chasing the player

local guard = {
  x = 0,
  y = 0,
  radius = 14,
  speed = 150,            -- Slower than player (200) so they can escape
  chaseSpeed = 150,       -- Speed when chasing
  patrolSpeed = 80,       -- Speed when patrolling
  active = false,
  
  -- AI state
  state = GUARD_PATROL,
  detectionRange = 300,   -- How far guard can "see" player
  catchRange = 45,        -- How close to catch player
  
  -- Pathfinding
  path = {},              -- List of {x, y} waypoints
  pathIndex = 1,          -- Current waypoint index
  pathTimer = 0,          -- Timer for path recalculation
  pathRecalcTime = 0.5,   -- Recalculate path every 0.5 seconds
  
  -- Start position (for returning when player hides)
  startX = 0,
  startY = 0,
  
  -- Direction for eye rendering
  dirX = 1,
  dirY = 0
}

local goal = {
  x = 0,
  y = 0,
  size = 32
}

-- Current level info
local currentLevelName = ""
local currentEpisode = 1
local currentEnding = nil
local isFinalLevel = false

--------------------------------------------------------------------------------
-- A* PATHFINDING
-- The guard lives in the "Truth" world (mapMaskOff)
--------------------------------------------------------------------------------

-- Convert pixel coordinates to grid coordinates
local function pixelToGrid(px, py)
  return math.floor(px / tileSize) + 1, math.floor(py / tileSize) + 1
end

-- Convert grid coordinates to pixel coordinates (center of tile)
local function gridToPixel(gx, gy)
  return (gx - 1) * tileSize + tileSize / 2, (gy - 1) * tileSize + tileSize / 2
end

-- Check if a grid cell is walkable
local function isWalkable(map, gx, gy)
  if not map then return false end
  if gx < 1 or gy < 1 then return false end
  if gy > #map then return false end
  if gx > #map[gy] then return false end
  return map[gy][gx] == 0
end

-- Heuristic: Manhattan distance
local function heuristic(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end

-- Create a unique key for a grid position
local function posKey(x, y)
  return x .. "," .. y
end

-- A* pathfinding algorithm
-- Returns a list of {x, y} pixel coordinates, or empty table if no path
local function findPath(startX, startY, goalX, goalY, map)
  -- Convert to grid coordinates
  local startGX, startGY = pixelToGrid(startX, startY)
  local goalGX, goalGY = pixelToGrid(goalX, goalY)
  
  -- If start or goal is not walkable, return empty path
  if not isWalkable(map, startGX, startGY) then
    -- Try to find nearest walkable cell to start
    startGX, startGY = startGX, startGY  -- Keep as is, guard might be in wall temporarily
  end
  if not isWalkable(map, goalGX, goalGY) then
    return {}
  end
  
  -- If already at goal, return empty path
  if startGX == goalGX and startGY == goalGY then
    return {}
  end
  
  -- Open set: nodes to evaluate (priority queue using table)
  -- Each entry: {gx, gy, f, g}
  local openSet = {}
  local openSetMap = {}  -- For quick lookup
  
  -- Closed set: nodes already evaluated
  local closedSet = {}
  
  -- Parent map for path reconstruction
  local cameFrom = {}
  
  -- G scores (cost from start to node)
  local gScore = {}
  gScore[posKey(startGX, startGY)] = 0
  
  -- F scores (g + heuristic)
  local fScore = {}
  local startF = heuristic(startGX, startGY, goalGX, goalGY)
  fScore[posKey(startGX, startGY)] = startF
  
  -- Add start node
  table.insert(openSet, {gx = startGX, gy = startGY, f = startF})
  openSetMap[posKey(startGX, startGY)] = true
  
  -- Neighbor offsets (4-directional)
  local neighbors = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  
  -- Maximum iterations to prevent infinite loops
  local maxIterations = 1000
  local iterations = 0
  
  while #openSet > 0 and iterations < maxIterations do
    iterations = iterations + 1
    
    -- Find node with lowest F score
    local lowestIdx = 1
    for i = 2, #openSet do
      if openSet[i].f < openSet[lowestIdx].f then
        lowestIdx = i
      end
    end
    
    local current = openSet[lowestIdx]
    local currentKey = posKey(current.gx, current.gy)
    
    -- Goal reached?
    if current.gx == goalGX and current.gy == goalGY then
      -- Reconstruct path
      local path = {}
      local key = currentKey
      while cameFrom[key] do
        local gx, gy = key:match("(%d+),(%d+)")
        gx, gy = tonumber(gx), tonumber(gy)
        local px, py = gridToPixel(gx, gy)
        table.insert(path, 1, {x = px, y = py})
        key = cameFrom[key]
      end
      return path
    end
    
    -- Move current from open to closed set
    table.remove(openSet, lowestIdx)
    openSetMap[currentKey] = nil
    closedSet[currentKey] = true
    
    -- Check neighbors
    for _, offset in ipairs(neighbors) do
      local nx, ny = current.gx + offset[1], current.gy + offset[2]
      local neighborKey = posKey(nx, ny)
      
      -- Skip if not walkable or already evaluated
      if isWalkable(map, nx, ny) and not closedSet[neighborKey] then
        local tentativeG = gScore[currentKey] + 1
        
        local neighborG = gScore[neighborKey]
        if not neighborG or tentativeG < neighborG then
          -- This path is better
          cameFrom[neighborKey] = currentKey
          gScore[neighborKey] = tentativeG
          local f = tentativeG + heuristic(nx, ny, goalGX, goalGY)
          fScore[neighborKey] = f
          
          if not openSetMap[neighborKey] then
            table.insert(openSet, {gx = nx, gy = ny, f = f})
            openSetMap[neighborKey] = true
          end
        end
      end
    end
  end
  
  -- No path found
  return {}
end

--------------------------------------------------------------------------------
-- GAME LOGIC
--------------------------------------------------------------------------------

-- Get the currently active map based on mask state
local function getActiveMap()
  if isMaskOn then
    return mapMaskOn
  end
  return mapMaskOff
end

-- Simple AABB (Axis-Aligned Bounding Box) collision test
local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and
    bx < ax + aw and
    ay < by + bh and
    by < ay + ah
end

-- Check if a position collides with walls in the active map
local function isCollidingWithMap(x, y)
  local map = getActiveMap()
  if not map then return true end

  local left = math.floor(x / tileSize) + 1
  local right = math.floor((x + player.size - 1) / tileSize) + 1
  local top = math.floor(y / tileSize) + 1
  local bottom = math.floor((y + player.size - 1) / tileSize) + 1

  for row = top, bottom do
    for col = left, right do
      local rowData = map[row]
      local cell = rowData and rowData[col] or 1

      if cell == 1 then
        local wallX = (col - 1) * tileSize
        local wallY = (row - 1) * tileSize
        if aabb(x, y, player.size, player.size, wallX, wallY, tileSize, tileSize) then
          return true
        end
      end
    end
  end

  return false
end

-- Trigger screen shake
local function triggerShake(duration, intensity)
  shakeDuration = duration or 0.15
  shakeIntensity = intensity or 3
end

-- Calculate distance between two points
local function distance(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

-- Update guard AI
local function updateGuardAI(dt)
  if not guard.active then return end
  
  local playerCenterX = player.x + player.size / 2
  local playerCenterY = player.y + player.size / 2
  local distToPlayer = distance(guard.x, guard.y, playerCenterX, playerCenterY)
  
  -- Determine guard state based on mask and distance
  if not isMaskOn and distToPlayer < guard.detectionRange then
    -- Player revealed and in range: CHASE!
    guard.state = GUARD_CHASE
    guard.speed = guard.chaseSpeed
    
    -- Update path timer
    guard.pathTimer = guard.pathTimer + dt
    
    -- Recalculate path periodically or if we don't have one
    if guard.pathTimer >= guard.pathRecalcTime or #guard.path == 0 then
      guard.pathTimer = 0
      -- Path uses mapMaskOff (guard sees the Truth)
      guard.path = findPath(guard.x, guard.y, playerCenterX, playerCenterY, mapMaskOff)
      guard.pathIndex = 1
    end
  else
    -- Player hidden (mask on) or out of range: PATROL back to start
    if guard.state == GUARD_CHASE then
      -- Just lost sight, recalculate path to start
      guard.path = findPath(guard.x, guard.y, guard.startX, guard.startY, mapMaskOff)
      guard.pathIndex = 1
      guard.pathTimer = 0
    end
    guard.state = GUARD_PATROL
    guard.speed = guard.patrolSpeed
  end
  
  -- Move along path
  if #guard.path > 0 and guard.pathIndex <= #guard.path then
    local target = guard.path[guard.pathIndex]
    local dx = target.x - guard.x
    local dy = target.y - guard.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0 then
      -- Normalize and move
      local moveX = (dx / dist) * guard.speed * dt
      local moveY = (dy / dist) * guard.speed * dt
      
      -- Update direction for eye rendering
      if math.abs(dx) > math.abs(dy) then
        guard.dirX = dx > 0 and 1 or -1
        guard.dirY = 0
      else
        guard.dirX = 0
        guard.dirY = dy > 0 and 1 or -1
      end
      
      -- Move (but don't overshoot)
      if dist > guard.speed * dt then
        guard.x = guard.x + moveX
        guard.y = guard.y + moveY
      else
        guard.x = target.x
        guard.y = target.y
        guard.pathIndex = guard.pathIndex + 1
      end
    end
  elseif guard.state == GUARD_PATROL then
    -- At start position, slowly wander or stay still
    -- For simplicity, just stay still when at start
  end
  
  -- Check for catch condition
  if not isMaskOn and distToPlayer <= guard.catchRange then
    gameState = STATE_GAMEOVER
    triggerShake(0.3, 6)
  end
end

-- Load a specific level by index
local function loadLevel(levelIndex)
  local levelData = levels[levelIndex]
  if not levelData then
    -- No more levels - shouldn't happen, finale handles ending
    gameState = STATE_FINALE
    return
  end

  -- Load map data
  mapMaskOn = levelData.mapMaskOn
  mapMaskOff = levelData.mapMaskOff
  currentLevelName = levelData.name or ("Level " .. levelIndex)
  currentEpisode = levelData.episode or 1
  currentEnding = levelData.ending
  isFinalLevel = levelData.isFinalLevel or false

  -- Set player start position
  player.x = levelData.playerStart.x
  player.y = levelData.playerStart.y

  -- Set goal position
  goal.x = levelData.goalPos.x
  goal.y = levelData.goalPos.y

  -- Set guard data (if exists)
  if levelData.guard then
    local guardData = levelData.guard
    -- Start position (center of patrol area)
    local startX = (guardData.minX + guardData.maxX) / 2
    guard.startX = startX
    guard.startY = guardData.y
    guard.x = startX
    guard.y = guardData.y
    
    -- Speeds
    guard.chaseSpeed = guardData.speed or 150
    guard.patrolSpeed = (guardData.speed or 150) * 0.6  -- Patrol is slower
    guard.speed = guard.patrolSpeed
    
    -- Reset AI state
    guard.state = GUARD_PATROL
    guard.path = {}
    guard.pathIndex = 1
    guard.pathTimer = 0
    guard.dirX = 1
    guard.dirY = 0
    guard.active = true
  else
    guard.active = false
  end

  -- Set story text
  if levelData.story then
    currentStory = levelData.story
    storyLinesShown = 0
    storyTimer = 0
    gameState = STATE_STORY
  else
    gameState = STATE_PLAYING
  end

  -- Reset mask state
  isMaskOn = true
  wasMaskOn = true
end

-- Advance to the next level
local function nextLevel()
  currentLevelIndex = currentLevelIndex + 1
  loadLevel(currentLevelIndex)
  triggerShake(0.2, 5)
end

-- Start the finale sequence
local function startFinale()
  gameState = STATE_FINALE
  finaleTimer = 0
  finalePhase = 0
  finaleFade = 0
end

function love.load()
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {resizable = false})
  love.window.setTitle("The Escape from Veritas")

  -- Start at Level 1
  currentLevelIndex = 1
  loadLevel(currentLevelIndex)
end

function love.update(dt)
  -- Handle story state
  if gameState == STATE_STORY then
    storyTimer = storyTimer + dt
    -- Reveal lines gradually
    local targetLines = math.floor(storyTimer / 0.8) + 1
    if targetLines > storyLinesShown then
      storyLinesShown = math.min(targetLines, #currentStory)
    end
    return
  end

  -- Handle finale state
  if gameState == STATE_FINALE then
    finaleTimer = finaleTimer + dt
    
    if finalePhase == 0 then
      -- Fade to white
      finaleFade = math.min(finaleTimer / 2, 1)
      if finaleTimer > 2.5 then
        finalePhase = 1
        finaleTimer = 0
      end
    elseif finalePhase == 1 then
      -- Show final text
      if finaleTimer > 4 then
        finalePhase = 2
      end
    end
    return
  end

  -- Space bar held down = mask off
  isMaskOn = not love.keyboard.isDown("space")

  -- Trigger shake when mask state changes
  if isMaskOn ~= wasMaskOn then
    triggerShake(0.12, 4)
    wasMaskOn = isMaskOn
  end

  -- Update screen shake timer
  if shakeDuration > 0 then
    shakeDuration = shakeDuration - dt
  end

  -- Stop updates if game ended or level complete
  if gameState ~= STATE_PLAYING then
    return
  end

  local dx, dy = 0, 0
  if love.keyboard.isDown("left") then
    dx = dx - 1
  end
  if love.keyboard.isDown("right") then
    dx = dx + 1
  end
  if love.keyboard.isDown("up") then
    dy = dy - 1
  end
  if love.keyboard.isDown("down") then
    dy = dy + 1
  end

  -- Normalize to keep speed consistent diagonally
  local length = math.sqrt(dx * dx + dy * dy)
  if length > 0 then
    dx = dx / length
    dy = dy / length
  end

  local nextX = player.x + dx * player.speed * dt
  local nextY = player.y + dy * player.speed * dt

  -- Move on each axis separately for smoother collision handling
  if not isCollidingWithMap(nextX, player.y) then
    player.x = nextX
  end
  if not isCollidingWithMap(player.x, nextY) then
    player.y = nextY
  end

  -- Update camera to follow player
  cameraX = player.x + player.size / 2 - WINDOW_WIDTH / 2
  cameraY = player.y + player.size / 2 - WINDOW_HEIGHT / 2

  -- Update guard AI
  updateGuardAI(dt)

  -- Win condition: player touches the goal
  if aabb(player.x, player.y, player.size, player.size, goal.x, goal.y, goal.size, goal.size) then
    if isFinalLevel then
      startFinale()
    else
      gameState = STATE_COMPLETE
    end
  end
end

function love.keypressed(key)
  if gameState == STATE_STORY then
    -- Any key skips/continues story
    if key == "return" or key == "space" then
      if storyLinesShown >= #currentStory then
        gameState = STATE_PLAYING
      else
        storyLinesShown = #currentStory  -- Show all lines
      end
    end
  elseif gameState == STATE_COMPLETE then
    if key == "return" or key == "space" then
      nextLevel()
    end
  elseif gameState == STATE_GAMEOVER then
    if key == "r" then
      loadLevel(currentLevelIndex)
    end
  elseif gameState == STATE_FINALE and finalePhase == 2 then
    if key == "r" then
      -- Restart from beginning
      currentLevelIndex = 1
      finalePhase = 0
      finaleFade = 0
      loadLevel(currentLevelIndex)
    end
  end
end

function love.draw()
  -- Finale: fade to white
  if gameState == STATE_FINALE then
    -- Background fades to white
    local bg = {}
    for i = 1, 3 do
      bg[i] = colors.background_mask_off[i] + (1 - colors.background_mask_off[i]) * finaleFade
    end
    love.graphics.setBackgroundColor(bg)

    if finalePhase >= 1 then
      -- Pure white background
      love.graphics.setBackgroundColor(1, 1, 1)
      
      -- Fade in the final text
      local textAlpha = math.min(finaleTimer / 1.5, 1)
      love.graphics.setColor(0.1, 0.1, 0.1, textAlpha)
      
      love.graphics.printf("I am free.", 0, WINDOW_HEIGHT / 2 - 40, WINDOW_WIDTH, "center")
      
      if finalePhase == 2 then
        love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
        love.graphics.printf("THE END", 0, WINDOW_HEIGHT / 2 + 20, WINDOW_WIDTH, "center")
        love.graphics.printf("Press R to Play Again", 0, WINDOW_HEIGHT / 2 + 60, WINDOW_WIDTH, "center")
      end
    else
      -- Still fading, draw world dimly
      drawWorld()
    end
    return
  end

  -- Normal background
  if isMaskOn then
    love.graphics.setBackgroundColor(colors.background_mask_on)
  else
    love.graphics.setBackgroundColor(colors.background_mask_off)
  end

  -- Draw the game world
  drawWorld()

  -- UI: Episode and Level name (top-left)
  love.graphics.setColor(colors.ui_text_dim)
  love.graphics.print("Episode " .. currentEpisode, 10, 10)
  love.graphics.setColor(colors.ui_text_level)
  love.graphics.print(currentLevelName, 10, 28)
  
  -- Debug: Show guard state (can remove later)
  if guard.active then
    love.graphics.setColor(colors.ui_text_dim)
    local stateText = guard.state == GUARD_CHASE and "ALERT!" or "Patrolling"
    love.graphics.print("Guard: " .. stateText, 10, 46)
  end

  -- Story overlay
  if gameState == STATE_STORY then
    -- Dim overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    -- Story box
    local boxY = WINDOW_HEIGHT / 2 - 100
    local boxHeight = 200
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", 50, boxY, WINDOW_WIDTH - 100, boxHeight)

    -- Story text
    love.graphics.setColor(colors.ui_text_story)
    local lineY = boxY + 20
    for i = 1, storyLinesShown do
      if currentStory[i] then
        love.graphics.printf(currentStory[i], 70, lineY, WINDOW_WIDTH - 140, "left")
        lineY = lineY + 24
      end
    end

    -- Continue prompt
    if storyLinesShown >= #currentStory then
      love.graphics.setColor(colors.ui_text_dim)
      love.graphics.printf("Press ENTER to continue...", 0, boxY + boxHeight - 35, WINDOW_WIDTH, "center")
    end
  end

  -- Level complete overlay
  if gameState == STATE_COMPLETE then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    local boxY = WINDOW_HEIGHT / 2 - 60
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 200, boxY, 400, 120)

    love.graphics.setColor(colors.ui_text_win)
    love.graphics.printf("LEVEL COMPLETE", 0, boxY + 20, WINDOW_WIDTH, "center")

    -- Show ending text if any
    if currentEnding and currentEnding ~= "FINALE" then
      love.graphics.setColor(colors.ui_text_story)
      love.graphics.printf(currentEnding, WINDOW_WIDTH / 2 - 180, boxY + 50, 360, "center")
    end

    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press ENTER to Continue", 0, boxY + 90, WINDOW_WIDTH, "center")
  end

  -- Game over overlay
  if gameState == STATE_GAMEOVER then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 150, WINDOW_HEIGHT / 2 - 50, 300, 100)

    love.graphics.setColor(colors.ui_text_lose)
    love.graphics.printf("CAUGHT", 0, WINDOW_HEIGHT / 2 - 35, WINDOW_WIDTH, "center")

    love.graphics.setColor(colors.ui_text_story)
    love.graphics.printf("They saw your true face.", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")

    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press R to Retry", 0, WINDOW_HEIGHT / 2 + 30, WINDOW_WIDTH, "center")
  end
end

-- Separate function to draw the game world
function drawWorld()
  love.graphics.push()

  -- Screen shake offset
  local shakeX, shakeY = 0, 0
  if shakeDuration > 0 then
    shakeX = love.math.random(-shakeIntensity, shakeIntensity)
    shakeY = love.math.random(-shakeIntensity, shakeIntensity)
  end

  love.graphics.translate(-cameraX + shakeX, -cameraY + shakeY)

  local map = getActiveMap()

  -- Draw walls
  if isMaskOn then
    love.graphics.setColor(colors.walls_mask_on)
  else
    love.graphics.setColor(colors.walls_mask_off)
  end

  if map then
    for row = 1, #map do
      for col = 1, #map[row] do
        if map[row][col] == 1 then
          local x = (col - 1) * tileSize
          local y = (row - 1) * tileSize
          love.graphics.rectangle("fill", x + 1, y + 1, tileSize - 2, tileSize - 2)
        end
      end
    end
  end

  -- Draw goal (Sunset Gold)
  love.graphics.setColor(colors.goal)
  love.graphics.rectangle("fill", goal.x + 1, goal.y + 1, goal.size - 2, goal.size - 2)

  -- Draw player
  if isMaskOn then
    love.graphics.setColor(colors.player_mask_on)
  else
    love.graphics.setColor(colors.player_mask_off)
  end
  love.graphics.rectangle("fill", player.x + 1, player.y + 1, player.size - 2, player.size - 2)

  -- Draw guard (if active)
  if guard.active then
    -- Color changes when chasing
    if guard.state == GUARD_CHASE then
      love.graphics.setColor(colors.guard_alert)
    else
      love.graphics.setColor(colors.guard)
    end
    love.graphics.circle("fill", guard.x, guard.y, guard.radius)
    
    -- Draw a small "eye" to indicate direction
    love.graphics.setColor(1, 1, 1)
    local eyeOffsetX = guard.dirX * 5
    local eyeOffsetY = guard.dirY * 5
    love.graphics.circle("fill", guard.x + eyeOffsetX, guard.y + eyeOffsetY - 2, 3)
    
    -- Draw alert indicator when chasing
    if guard.state == GUARD_CHASE then
      love.graphics.setColor(1, 0.3, 0.3)
      love.graphics.print("!", guard.x - 3, guard.y - guard.radius - 18)
    end
  end

  love.graphics.pop()
end
