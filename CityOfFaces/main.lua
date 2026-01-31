-- Love2D Mask Mechanic Game
-- "The Escape from Veritas"
-- A game about seeing through lies.

-- Load modules
local levels = require("levels")
local Particles = require("particles")

-- The "Arco" Style Palette
local colors = {
  background_mask_on  = {0.96, 0.90, 0.80},
  player_mask_on      = {0.82, 0.22, 0.22},
  walls_mask_on       = {0.20, 0.16, 0.20},
  background_mask_off = {0.10, 0.08, 0.14},
  player_mask_off     = {0.00, 0.80, 0.80},
  walls_mask_off      = {0.15, 0.12, 0.25},
  floor_mask_on       = {1.0, 1.0, 1.0},
  floor_mask_off      = {0.2, 0.2, 0.5},
  hiding_spot         = {0.08, 0.06, 0.12},
  goal                = {0.95, 0.75, 0.20},
  guard               = {0.90, 0.30, 0.40},
  guard_alert         = {1.00, 0.20, 0.20},
  warden              = {0.3, 0.1, 0.4},
  lantern_glow        = {1.0, 0.9, 0.4},
  fragment            = {1.0, 0.85, 0.3},
  key                 = {0.9, 0.8, 0.2},
  ui_background       = {0.08, 0.06, 0.10, 0.95},
  ui_text_win         = {0.95, 0.85, 0.50},
  ui_text_lose        = {0.90, 0.25, 0.25},
  ui_text_level       = {0.70, 0.65, 0.55},
  ui_text_story       = {0.90, 0.88, 0.82},
  ui_text_dim         = {0.50, 0.48, 0.42},
  trail_color         = {0.8, 0.15, 0.15},
  detection_bar       = {1.0, 0.6, 0.2},
  sanity_bar_bg       = {0.15, 0.12, 0.18},
  mask_shadow         = {0.3, 0.1, 0.5},
  mask_swift          = {0.2, 0.8, 0.3},
  mask_oracle         = {0.9, 0.7, 0.2}
}

-- Window settings
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local cameraX, cameraY = 0, 0
local tileSize = 32

-- Screen shake
local shakeDuration = 0
local shakeIntensity = 3

-- Level state
local currentLevelIndex = 1
local mapMaskOn, mapMaskOff = nil, nil

-- Game states
local STATE_STORY = "story"
local STATE_PLAYING = "playing"
local STATE_COMPLETE = "complete"
local STATE_GAMEOVER = "gameover"
local STATE_INSANE = "insane"
local STATE_FINALE = "finale"
local STATE_FRAGMENT = "fragment"  -- Showing fragment text
local gameState = STATE_STORY

-- Story/Fragment display
local currentStory = {}
local storyTimer, storyLinesShown = 0, 0
local currentFragmentText = ""
local fragmentDisplayTimer = 0

-- Finale sequence
local finaleTimer, finalePhase, finaleFade = 0, 0, 0

-- Sanity system
local sanity = 0
local SANITY_MAX = 100
local SANITY_INCREASE_RATE = 15
local SANITY_DECREASE_RATE = 25
local sanityGameOverReason = ""

-- Shader
local glitchShader, shaderTime, gameCanvas = nil, 0, nil

-- Images
local playerImg, guardImg, floorImg = nil, nil, nil
local playerScale, guardScale, floorScale = 1, 1, 1

-- Particle system
local particleSystem = nil

-- Player trail
local playerTrail = {}
local TRAIL_MAX_LENGTH = 8
local trailTimer = 0

--------------------------------------------------------------------------------
-- MASK SYSTEM
--------------------------------------------------------------------------------
local MASK_CRACKED = 1  -- Default - see truth
local MASK_SHADOW = 2   -- Invisibility
local MASK_SWIFT = 3    -- Speed boost
local MASK_ORACLE = 4   -- See guard paths

local masks = {
  [MASK_CRACKED] = { name = "Cracked", color = {0.7, 0.7, 0.7}, duration = 0, cooldown = 0, unlocked = true },
  [MASK_SHADOW] = { name = "Shadow", color = colors.mask_shadow, duration = 3, cooldown = 10, unlocked = false },
  [MASK_SWIFT] = { name = "Swift", color = colors.mask_swift, duration = 5, cooldown = 8, unlocked = false },
  [MASK_ORACLE] = { name = "Oracle", color = colors.mask_oracle, duration = 4, cooldown = 12, unlocked = false }
}

local currentMask = MASK_CRACKED
local maskActiveTimer = 0      -- Time remaining on active power
local maskCooldownTimers = {0, 0, 0, 0}  -- Cooldown for each mask
local isMaskPowerActive = false

--------------------------------------------------------------------------------
-- PLAYER
--------------------------------------------------------------------------------
local player = {
  x = 0, y = 0,
  size = 32,
  baseSpeed = 200,
  speed = 200,
  rotation = 0,
  targetRotation = 0,
  isHidden = false,    -- In hiding spot
  isInvisible = false  -- Shadow mask active
}

local isMaskOn = true
local wasMaskOn = true

--------------------------------------------------------------------------------
-- GUARD / WARDEN
--------------------------------------------------------------------------------
local GUARD_PATROL = "patrol"
local GUARD_CHASE = "chase"
local GUARD_SUSPICIOUS = "suspicious"

local guard = {
  x = 0, y = 0,
  radius = 14,
  speed = 150,
  chaseSpeed = 150,
  patrolSpeed = 80,
  active = false,
  state = GUARD_PATROL,
  detectionRange = 300,
  catchRange = 45,
  path = {},
  pathIndex = 1,
  pathTimer = 0,
  pathRecalcTime = 0.5,
  startX = 0, startY = 0,
  dirX = 1, dirY = 0,
  rotation = 0,
  -- Detection meter (0-100)
  suspicion = 0,
  suspicionRate = 40,      -- How fast suspicion builds
  suspicionDecayRate = 20  -- How fast it decays
}

-- The Warden (boss)
local warden = {
  x = 0, y = 0,
  radius = 20,
  speed = 180,
  active = false,
  detectionRange = 400,
  catchRange = 50,
  canSeeInShadows = true,
  canSeeThroughShadowMask = true,
  path = {},
  pathIndex = 1,
  pathTimer = 0,
  rotation = 0,
  state = GUARD_PATROL
}

local goal = { x = 0, y = 0, size = 32 }

--------------------------------------------------------------------------------
-- COLLECTIBLES
--------------------------------------------------------------------------------
local fragments = {}           -- Memory fragments in current level
local collectedFragments = 0   -- Total collected across all levels
local totalFragments = 0       -- Total in game

local keys = {}                -- Keys in boss level
local collectedKeys = 0
local keysRequired = 0

local maskPickups = {}         -- Mask pickups in current level

--------------------------------------------------------------------------------
-- LEVEL INFO
--------------------------------------------------------------------------------
local currentLevelName = ""
local currentEpisode = 1
local currentEnding = nil
local isFinalLevel = false
local isBossLevel = false

--------------------------------------------------------------------------------
-- PATHFINDING (A*)
--------------------------------------------------------------------------------
local function pixelToGrid(px, py)
  return math.floor(px / tileSize) + 1, math.floor(py / tileSize) + 1
end

local function gridToPixel(gx, gy)
  return (gx - 1) * tileSize + tileSize / 2, (gy - 1) * tileSize + tileSize / 2
end

local function isWalkable(map, gx, gy)
  if not map then return false end
  if gx < 1 or gy < 1 then return false end
  if gy > #map then return false end
  if gx > #map[gy] then return false end
  return map[gy][gx] ~= 1  -- 0 or 2 (hiding spot) is walkable
end

local function posKey(x, y)
  return x .. "," .. y
end

local function heuristic(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end

local function findPath(startX, startY, goalX, goalY, map)
  local startGX, startGY = pixelToGrid(startX, startY)
  local goalGX, goalGY = pixelToGrid(goalX, goalY)
  
  if not isWalkable(map, goalGX, goalGY) then return {} end
  if startGX == goalGX and startGY == goalGY then return {} end
  
  local openSet, openSetMap, closedSet = {}, {}, {}
  local cameFrom, gScore, fScore = {}, {}, {}
  
  gScore[posKey(startGX, startGY)] = 0
  local startF = heuristic(startGX, startGY, goalGX, goalGY)
  fScore[posKey(startGX, startGY)] = startF
  
  table.insert(openSet, {gx = startGX, gy = startGY, f = startF})
  openSetMap[posKey(startGX, startGY)] = true
  
  local neighbors = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  local iterations = 0
  
  while #openSet > 0 and iterations < 1000 do
    iterations = iterations + 1
    
    local lowestIdx = 1
    for i = 2, #openSet do
      if openSet[i].f < openSet[lowestIdx].f then lowestIdx = i end
    end
    
    local current = openSet[lowestIdx]
    local currentKey = posKey(current.gx, current.gy)
    
    if current.gx == goalGX and current.gy == goalGY then
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
    
    table.remove(openSet, lowestIdx)
    openSetMap[currentKey] = nil
    closedSet[currentKey] = true
    
    for _, offset in ipairs(neighbors) do
      local nx, ny = current.gx + offset[1], current.gy + offset[2]
      local neighborKey = posKey(nx, ny)
      
      if isWalkable(map, nx, ny) and not closedSet[neighborKey] then
        local tentativeG = gScore[currentKey] + 1
        local neighborG = gScore[neighborKey]
        
        if not neighborG or tentativeG < neighborG then
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
  
  return {}
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function getActiveMap()
  return isMaskOn and mapMaskOn or mapMaskOff
end

local function aabb(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

local function distance(x1, y1, x2, y2)
  return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

local function lerpAngle(a, b, t)
  local diff = b - a
  while diff > math.pi do diff = diff - 2 * math.pi end
  while diff < -math.pi do diff = diff + 2 * math.pi end
  return a + diff * t
end

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

local function isInHidingSpot(x, y)
  local map = getActiveMap()
  if not map then return false end
  
  local centerX = x + player.size / 2
  local centerY = y + player.size / 2
  local col = math.floor(centerX / tileSize) + 1
  local row = math.floor(centerY / tileSize) + 1
  
  if map[row] and map[row][col] == 2 then
    return true
  end
  return false
end

local function triggerShake(duration, intensity)
  shakeDuration = duration or 0.15
  shakeIntensity = intensity or 3
end

--------------------------------------------------------------------------------
-- MASK SYSTEM FUNCTIONS
--------------------------------------------------------------------------------
local function activateMaskPower(maskType)
  if maskType == MASK_CRACKED then return end
  if not masks[maskType].unlocked then return end
  if maskCooldownTimers[maskType] > 0 then return end
  if isMaskPowerActive then return end
  
  currentMask = maskType
  maskActiveTimer = masks[maskType].duration
  isMaskPowerActive = true
  
  -- Apply power effects
  if maskType == MASK_SHADOW then
    player.isInvisible = true
  elseif maskType == MASK_SWIFT then
    player.speed = player.baseSpeed * 2
  end
  
  triggerShake(0.1, 2)
  particleSystem:burst(player.x + player.size/2, player.y + player.size/2, 
    Particles.presets.collectBurst, 8)
end

local function deactivateMaskPower()
  if not isMaskPowerActive then return end
  
  -- Start cooldown
  maskCooldownTimers[currentMask] = masks[currentMask].cooldown
  
  -- Remove effects
  player.isInvisible = false
  player.speed = player.baseSpeed
  
  isMaskPowerActive = false
  currentMask = MASK_CRACKED
end

local function updateMaskSystem(dt)
  -- Update cooldowns
  for i = 1, 4 do
    if maskCooldownTimers[i] > 0 then
      maskCooldownTimers[i] = math.max(0, maskCooldownTimers[i] - dt)
    end
  end
  
  -- Update active power timer
  if isMaskPowerActive then
    maskActiveTimer = maskActiveTimer - dt
    if maskActiveTimer <= 0 then
      deactivateMaskPower()
    end
  end
end

--------------------------------------------------------------------------------
-- GUARD AI
--------------------------------------------------------------------------------
local function canGuardSeePlayer(g)
  local playerCenterX = player.x + player.size / 2
  local playerCenterY = player.y + player.size / 2
  local dist = distance(g.x, g.y, playerCenterX, playerCenterY)
  
  if dist > g.detectionRange then return false end
  
  -- Player is wearing mask (in Lie world)
  if isMaskOn then return false end
  
  -- Player is invisible (shadow mask)
  if player.isInvisible and not g.canSeeThroughShadowMask then
    return false
  end
  
  -- Player is in hiding spot
  if player.isHidden and not g.canSeeInShadows then
    return false
  end
  
  return true
end

local function updateGuardAI(dt)
  if not guard.active then return end
  
  local playerCenterX = player.x + player.size / 2
  local playerCenterY = player.y + player.size / 2
  local distToPlayer = distance(guard.x, guard.y, playerCenterX, playerCenterY)
  local canSee = canGuardSeePlayer(guard)
  
  -- Update suspicion meter
  if canSee then
    guard.suspicion = math.min(100, guard.suspicion + guard.suspicionRate * dt)
    if guard.suspicion >= 100 then
      guard.state = GUARD_CHASE
      guard.speed = guard.chaseSpeed
    elseif guard.suspicion > 30 then
      guard.state = GUARD_SUSPICIOUS
    end
  else
    guard.suspicion = math.max(0, guard.suspicion - guard.suspicionDecayRate * dt)
    if guard.suspicion < 30 and guard.state == GUARD_SUSPICIOUS then
      guard.state = GUARD_PATROL
      guard.speed = guard.patrolSpeed
    end
  end
  
  -- Chase behavior
  if guard.state == GUARD_CHASE then
    guard.pathTimer = guard.pathTimer + dt
    if guard.pathTimer >= guard.pathRecalcTime or #guard.path == 0 then
      guard.pathTimer = 0
      guard.path = findPath(guard.x, guard.y, playerCenterX, playerCenterY, mapMaskOff)
      guard.pathIndex = 1
    end
    
    -- If lost sight for too long, return to patrol
    if not canSee then
      guard.suspicion = math.max(0, guard.suspicion - guard.suspicionDecayRate * dt * 2)
      if guard.suspicion <= 0 then
        guard.state = GUARD_PATROL
        guard.speed = guard.patrolSpeed
        guard.path = findPath(guard.x, guard.y, guard.startX, guard.startY, mapMaskOff)
        guard.pathIndex = 1
      end
    end
  elseif guard.state == GUARD_PATROL and #guard.path == 0 then
    -- At patrol point, could wander
  end
  
  -- Move along path
  if #guard.path > 0 and guard.pathIndex <= #guard.path then
    local target = guard.path[guard.pathIndex]
    local dx = target.x - guard.x
    local dy = target.y - guard.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
      local moveX = (dx / dist) * guard.speed * dt
      local moveY = (dy / dist) * guard.speed * dt
      
      guard.rotation = math.atan2(dy, dx)
      guard.dirX = dx > 0 and 1 or -1
      guard.dirY = dy > 0 and 1 or -1
      
      if dist > guard.speed * dt then
        guard.x = guard.x + moveX
        guard.y = guard.y + moveY
      else
        guard.x = target.x
        guard.y = target.y
        guard.pathIndex = guard.pathIndex + 1
      end
    end
  end
  
  -- Catch player
  if canSee and distToPlayer <= guard.catchRange then
    gameState = STATE_GAMEOVER
    sanityGameOverReason = "The guard saw your true face."
    triggerShake(0.3, 6)
  end
end

local function updateWardenAI(dt)
  if not warden.active then return end
  
  local playerCenterX = player.x + player.size / 2
  local playerCenterY = player.y + player.size / 2
  local distToPlayer = distance(warden.x, warden.y, playerCenterX, playerCenterY)
  local canSee = canGuardSeePlayer(warden)
  
  -- Warden always chases when sees player
  if canSee then
    warden.state = GUARD_CHASE
    warden.pathTimer = warden.pathTimer + dt
    if warden.pathTimer >= 0.3 or #warden.path == 0 then
      warden.pathTimer = 0
      warden.path = findPath(warden.x, warden.y, playerCenterX, playerCenterY, mapMaskOff)
      warden.pathIndex = 1
    end
  else
    -- Patrol around map
    if #warden.path == 0 or warden.pathIndex > #warden.path then
      local targetX = math.random(3, 27) * tileSize
      local targetY = math.random(3, 22) * tileSize
      warden.path = findPath(warden.x, warden.y, targetX, targetY, mapMaskOff)
      warden.pathIndex = 1
    end
  end
  
  -- Move
  if #warden.path > 0 and warden.pathIndex <= #warden.path then
    local target = warden.path[warden.pathIndex]
    local dx = target.x - warden.x
    local dy = target.y - warden.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
      warden.rotation = math.atan2(dy, dx)
      local speed = canSee and warden.speed or (warden.speed * 0.6)
      
      if dist > speed * dt then
        warden.x = warden.x + (dx / dist) * speed * dt
        warden.y = warden.y + (dy / dist) * speed * dt
      else
        warden.x = target.x
        warden.y = target.y
        warden.pathIndex = warden.pathIndex + 1
      end
    end
  end
  
  -- Catch
  if canSee and distToPlayer <= warden.catchRange then
    gameState = STATE_GAMEOVER
    sanityGameOverReason = "The Warden caught you."
    triggerShake(0.5, 8)
  end
end

--------------------------------------------------------------------------------
-- SANITY & TRAIL
--------------------------------------------------------------------------------
local function updateSanity(dt)
  if isMaskOn then
    sanity = math.max(0, sanity - SANITY_DECREASE_RATE * dt)
  else
    sanity = math.min(SANITY_MAX, sanity + SANITY_INCREASE_RATE * dt)
    if sanity >= SANITY_MAX then
      sanityGameOverReason = "The Truth consumed your mind."
      gameState = STATE_INSANE
      triggerShake(0.5, 8)
    end
  end
end

local function updatePlayerTrail(dt)
  trailTimer = trailTimer + dt
  if trailTimer >= 0.03 then
    trailTimer = 0
    table.insert(playerTrail, 1, {
      x = player.x + player.size / 2,
      y = player.y + player.size / 2,
      alpha = 1.0
    })
    while #playerTrail > TRAIL_MAX_LENGTH do
      table.remove(playerTrail)
    end
  end
  for i, point in ipairs(playerTrail) do
    point.alpha = 1.0 - (i / TRAIL_MAX_LENGTH)
  end
end

--------------------------------------------------------------------------------
-- COLLECTIBLES
--------------------------------------------------------------------------------
local function checkCollectibles()
  local px, py = player.x + player.size/2, player.y + player.size/2
  
  -- Fragments
  for i = #fragments, 1, -1 do
    local f = fragments[i]
    if distance(px, py, f.x, f.y) < 24 then
      collectedFragments = collectedFragments + 1
      currentFragmentText = f.text
      gameState = STATE_FRAGMENT
      fragmentDisplayTimer = 0
      particleSystem:burst(f.x, f.y, Particles.presets.collectBurst, 15)
      triggerShake(0.1, 2)
      table.remove(fragments, i)
    end
  end
  
  -- Keys
  for i = #keys, 1, -1 do
    local k = keys[i]
    if distance(px, py, k.x, k.y) < 24 then
      collectedKeys = collectedKeys + 1
      particleSystem:burst(k.x, k.y, Particles.presets.collectBurst, 20)
      triggerShake(0.15, 3)
      table.remove(keys, i)
    end
  end
  
  -- Mask pickups
  for i = #maskPickups, 1, -1 do
    local m = maskPickups[i]
    if distance(px, py, m.x, m.y) < 24 then
      if m.maskType == "shadow" then
        masks[MASK_SHADOW].unlocked = true
      elseif m.maskType == "swift" then
        masks[MASK_SWIFT].unlocked = true
      elseif m.maskType == "oracle" then
        masks[MASK_ORACLE].unlocked = true
      end
      particleSystem:burst(m.x, m.y, Particles.presets.collectBurst, 25)
      triggerShake(0.2, 4)
      table.remove(maskPickups, i)
    end
  end
end

--------------------------------------------------------------------------------
-- LEVEL LOADING
--------------------------------------------------------------------------------
local function loadLevel(levelIndex)
  local levelData = levels[levelIndex]
  if not levelData then
    gameState = STATE_FINALE
    return
  end
  
  mapMaskOn = levelData.mapMaskOn
  mapMaskOff = levelData.mapMaskOff
  currentLevelName = levelData.name or ("Level " .. levelIndex)
  currentEpisode = levelData.episode or 1
  currentEnding = levelData.ending
  isFinalLevel = levelData.isFinalLevel or false
  isBossLevel = levelData.isBossLevel or false
  
  player.x = levelData.playerStart.x
  player.y = levelData.playerStart.y
  player.rotation = 0
  player.speed = player.baseSpeed
  player.isHidden = false
  player.isInvisible = false
  
  goal.x = levelData.goalPos.x
  goal.y = levelData.goalPos.y
  
  -- Regular guard
  if levelData.guard then
    local g = levelData.guard
    local startX = (g.minX + g.maxX) / 2
    guard.startX = startX
    guard.startY = g.y
    guard.x = startX
    guard.y = g.y
    guard.chaseSpeed = g.speed or 150
    guard.patrolSpeed = (g.speed or 150) * 0.6
    guard.speed = guard.patrolSpeed
    guard.state = GUARD_PATROL
    guard.path = {}
    guard.pathIndex = 1
    guard.suspicion = 0
    guard.rotation = 0
    guard.active = true
  else
    guard.active = false
  end
  
  -- Warden (boss)
  if levelData.warden then
    local w = levelData.warden
    warden.x = w.x
    warden.y = w.y
    warden.speed = w.speed or 180
    warden.detectionRange = w.detectionRange or 400
    warden.catchRange = w.catchRange or 50
    warden.canSeeInShadows = w.canSeeInShadows or false
    warden.canSeeThroughShadowMask = w.canSeeThroughShadowMask or false
    warden.path = {}
    warden.pathIndex = 1
    warden.state = GUARD_PATROL
    warden.active = true
  else
    warden.active = false
  end
  
  -- Collectibles
  fragments = {}
  if levelData.fragments then
    for _, f in ipairs(levelData.fragments) do
      table.insert(fragments, {x = f.x, y = f.y, text = f.text})
    end
  end
  
  keys = {}
  collectedKeys = 0
  keysRequired = levelData.keysRequired or 0
  if levelData.keys then
    for _, k in ipairs(levelData.keys) do
      table.insert(keys, {x = k.x, y = k.y})
    end
  end
  
  maskPickups = {}
  if levelData.maskPickups then
    for _, m in ipairs(levelData.maskPickups) do
      table.insert(maskPickups, {x = m.x, y = m.y, maskType = m.maskType})
    end
  end
  
  -- Story
  if levelData.story then
    currentStory = levelData.story
    storyLinesShown = 0
    storyTimer = 0
    gameState = STATE_STORY
  else
    gameState = STATE_PLAYING
  end
  
  -- Reset state
  isMaskOn = true
  wasMaskOn = true
  sanity = 0
  playerTrail = {}
  currentMask = MASK_CRACKED
  isMaskPowerActive = false
  maskActiveTimer = 0
  
  -- Clear particles
  if particleSystem then
    particleSystem:clear()
  end
end

local function nextLevel()
  currentLevelIndex = currentLevelIndex + 1
  loadLevel(currentLevelIndex)
  triggerShake(0.2, 5)
end

local function startFinale()
  gameState = STATE_FINALE
  finaleTimer = 0
  finalePhase = 0
  finaleFade = 0
end

--------------------------------------------------------------------------------
-- LOVE CALLBACKS
--------------------------------------------------------------------------------
function love.load()
  love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, {resizable = false})
  love.window.setTitle("The Escape from Veritas")
  
  gameCanvas = love.graphics.newCanvas(WINDOW_WIDTH, WINDOW_HEIGHT)
  
  local shaderCode = love.filesystem.read("shaders/glitch.glsl")
  if shaderCode then
    glitchShader = love.graphics.newShader(shaderCode)
  end
  
  -- Load images
  local success
  success, playerImg = pcall(love.graphics.newImage, "assets/player.png")
  if not success then playerImg = nil end
  success, guardImg = pcall(love.graphics.newImage, "assets/guard.png")
  if not success then guardImg = nil end
  success, floorImg = pcall(love.graphics.newImage, "assets/floor.png")
  if not success then floorImg = nil end
  
  if playerImg then playerScale = tileSize / playerImg:getWidth() end
  if guardImg then guardScale = tileSize / guardImg:getWidth() end
  if floorImg then floorScale = tileSize / floorImg:getWidth() end
  
  -- Initialize particle system
  particleSystem = Particles.ParticleSystem.new()
  
  -- Add ambient dust emitter
  local dustEmitter = Particles.Emitter.new(WINDOW_WIDTH/2, WINDOW_HEIGHT/2, Particles.presets.dust)
  particleSystem:addEmitter("dust", dustEmitter)
  
  -- Count total fragments
  for _, level in ipairs(levels) do
    if level.fragments then
      totalFragments = totalFragments + #level.fragments
    end
  end
  
  currentLevelIndex = 1
  loadLevel(currentLevelIndex)
end

function love.update(dt)
  shaderTime = shaderTime + dt
  
  -- Update dust position to follow camera
  local dustEmitter = particleSystem:getEmitter("dust")
  if dustEmitter then
    dustEmitter:setPosition(cameraX + WINDOW_WIDTH/2, cameraY + WINDOW_HEIGHT/2)
  end
  
  particleSystem:update(dt)
  
  -- Story state
  if gameState == STATE_STORY then
    storyTimer = storyTimer + dt
    local targetLines = math.floor(storyTimer / 0.6) + 1
    if targetLines > storyLinesShown then
      storyLinesShown = math.min(targetLines, #currentStory)
    end
    return
  end
  
  -- Fragment display
  if gameState == STATE_FRAGMENT then
    fragmentDisplayTimer = fragmentDisplayTimer + dt
    if fragmentDisplayTimer > 3 then
      gameState = STATE_PLAYING
    end
    return
  end
  
  -- Finale
  if gameState == STATE_FINALE then
    finaleTimer = finaleTimer + dt
    if finalePhase == 0 then
      finaleFade = math.min(finaleTimer / 2, 1)
      if finaleTimer > 2.5 then
        finalePhase = 1
        finaleTimer = 0
      end
    elseif finalePhase == 1 then
      if finaleTimer > 4 then
        finalePhase = 2
      end
    end
    return
  end
  
  -- Not playing
  if gameState ~= STATE_PLAYING then return end
  
  -- Mask toggle (SPACE for truth, but powers use number keys)
  isMaskOn = not love.keyboard.isDown("space")
  
  if isMaskOn ~= wasMaskOn then
    triggerShake(0.12, 4)
    wasMaskOn = isMaskOn
  end
  
  if shakeDuration > 0 then
    shakeDuration = shakeDuration - dt
  end
  
  -- Update systems
  updateSanity(dt)
  updateMaskSystem(dt)
  updatePlayerTrail(dt)
  
  -- Check if in hiding spot
  player.isHidden = isInHidingSpot(player.x, player.y)
  
  -- Movement
  local dx, dy = 0, 0
  if love.keyboard.isDown("left") or love.keyboard.isDown("a") then dx = dx - 1 end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dx = dx + 1 end
  if love.keyboard.isDown("up") or love.keyboard.isDown("w") then dy = dy - 1 end
  if love.keyboard.isDown("down") or love.keyboard.isDown("s") then dy = dy + 1 end
  
  local length = math.sqrt(dx*dx + dy*dy)
  if length > 0 then
    dx, dy = dx / length, dy / length
    player.targetRotation = math.atan2(dy, dx)
  end
  
  player.rotation = lerpAngle(player.rotation, player.targetRotation, dt * 10)
  
  local nextX = player.x + dx * player.speed * dt
  local nextY = player.y + dy * player.speed * dt
  
  if not isCollidingWithMap(nextX, player.y) then player.x = nextX end
  if not isCollidingWithMap(player.x, nextY) then player.y = nextY end
  
  -- Camera
  cameraX = player.x + player.size/2 - WINDOW_WIDTH/2
  cameraY = player.y + player.size/2 - WINDOW_HEIGHT/2
  
  -- AI
  updateGuardAI(dt)
  updateWardenAI(dt)
  
  -- Collectibles
  checkCollectibles()
  
  -- Win condition
  local canExit = true
  if isBossLevel and collectedKeys < keysRequired then
    canExit = false
  end
  
  if canExit and aabb(player.x, player.y, player.size, player.size, goal.x, goal.y, goal.size, goal.size) then
    if isFinalLevel then
      startFinale()
    else
      gameState = STATE_COMPLETE
    end
  end
end

function love.keypressed(key)
  -- Mask powers (1-4)
  if gameState == STATE_PLAYING then
    if key == "1" then currentMask = MASK_CRACKED
    elseif key == "2" then activateMaskPower(MASK_SHADOW)
    elseif key == "3" then activateMaskPower(MASK_SWIFT)
    elseif key == "4" then activateMaskPower(MASK_ORACLE)
    end
  end
  
  if gameState == STATE_STORY then
    if key == "return" or key == "space" then
      if storyLinesShown >= #currentStory then
        gameState = STATE_PLAYING
      else
        storyLinesShown = #currentStory
      end
    end
  elseif gameState == STATE_FRAGMENT then
    if key == "return" or key == "space" then
      gameState = STATE_PLAYING
    end
  elseif gameState == STATE_COMPLETE then
    if key == "return" or key == "space" then
      nextLevel()
    end
  elseif gameState == STATE_GAMEOVER or gameState == STATE_INSANE then
    if key == "r" then
      loadLevel(currentLevelIndex)
    end
  elseif gameState == STATE_FINALE and finalePhase == 2 then
    if key == "r" then
      currentLevelIndex = 1
      finalePhase = 0
      finaleFade = 0
      collectedFragments = 0
      masks[MASK_SHADOW].unlocked = false
      masks[MASK_SWIFT].unlocked = false
      masks[MASK_ORACLE].unlocked = false
      loadLevel(currentLevelIndex)
    end
  end
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------
function love.draw()
  local shaderIntensity = sanity / SANITY_MAX
  local useShader = glitchShader and shaderIntensity > 0.05 and gameState == STATE_PLAYING
  
  if useShader then
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear()
  end
  
  -- Finale
  if gameState == STATE_FINALE then
    local bg = {}
    for i = 1, 3 do
      bg[i] = colors.background_mask_off[i] + (1 - colors.background_mask_off[i]) * finaleFade
    end
    love.graphics.setBackgroundColor(bg)
    
    if finalePhase >= 1 then
      love.graphics.setBackgroundColor(1, 1, 1)
      local textAlpha = math.min(finaleTimer / 1.5, 1)
      love.graphics.setColor(0.1, 0.1, 0.1, textAlpha)
      love.graphics.printf("I am free.", 0, WINDOW_HEIGHT/2 - 40, WINDOW_WIDTH, "center")
      
      if finalePhase == 2 then
        love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
        love.graphics.printf("THE END", 0, WINDOW_HEIGHT/2 + 20, WINDOW_WIDTH, "center")
        
        -- Show fragment count
        if collectedFragments >= totalFragments then
          love.graphics.setColor(1, 0.85, 0.3)
          love.graphics.printf("TRUE ENDING - All memories recovered", 0, WINDOW_HEIGHT/2 + 50, WINDOW_WIDTH, "center")
        end
        
        love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
        love.graphics.printf("Press R to Play Again", 0, WINDOW_HEIGHT/2 + 80, WINDOW_WIDTH, "center")
      end
    else
      drawWorld()
    end
    
    if useShader then love.graphics.setCanvas() end
    return
  end
  
  -- Background
  if isMaskOn then
    love.graphics.setBackgroundColor(colors.background_mask_on)
  else
    love.graphics.setBackgroundColor(colors.background_mask_off)
  end
  
  drawWorld()
  
  if useShader then
    love.graphics.setCanvas()
    glitchShader:send("intensity", shaderIntensity)
    glitchShader:send("time", shaderTime)
    love.graphics.setShader(glitchShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(gameCanvas, 0, 0)
    love.graphics.setShader()
  end
  
  drawUI()
end

function drawWorld()
  love.graphics.push()
  
  local shakeX, shakeY = 0, 0
  if shakeDuration > 0 then
    shakeX = love.math.random(-shakeIntensity, shakeIntensity)
    shakeY = love.math.random(-shakeIntensity, shakeIntensity)
  end
  
  love.graphics.translate(-cameraX + shakeX, -cameraY + shakeY)
  
  local map = getActiveMap()
  
  -- Floor
  if isMaskOn then
    love.graphics.setColor(colors.floor_mask_on)
  else
    love.graphics.setColor(colors.floor_mask_off)
  end
  
  if map then
    for row = 1, #map do
      for col = 1, #map[row] do
        local x = (col - 1) * tileSize
        local y = (row - 1) * tileSize
        local cell = map[row][col]
        
        if cell == 2 then
          -- Hiding spot
          love.graphics.setColor(colors.hiding_spot)
          love.graphics.rectangle("fill", x, y, tileSize, tileSize)
        elseif cell == 0 then
          if floorImg then
            if isMaskOn then
              love.graphics.setColor(colors.floor_mask_on)
            else
              love.graphics.setColor(colors.floor_mask_off)
            end
            love.graphics.draw(floorImg, x, y, 0, floorScale, floorScale)
          end
        end
      end
    end
  end
  
  -- Walls
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
  
  -- Collectibles
  -- Fragments
  for _, f in ipairs(fragments) do
    local pulse = 0.7 + 0.3 * math.sin(shaderTime * 3)
    love.graphics.setColor(colors.fragment[1], colors.fragment[2], colors.fragment[3], pulse)
    love.graphics.circle("fill", f.x, f.y, 10)
    love.graphics.setColor(1, 1, 1, pulse * 0.5)
    love.graphics.circle("fill", f.x, f.y, 5)
  end
  
  -- Keys
  for _, k in ipairs(keys) do
    local pulse = 0.8 + 0.2 * math.sin(shaderTime * 4)
    love.graphics.setColor(colors.key[1], colors.key[2], colors.key[3], pulse)
    love.graphics.rectangle("fill", k.x - 6, k.y - 10, 12, 20)
    love.graphics.circle("fill", k.x, k.y - 6, 6)
  end
  
  -- Mask pickups
  for _, m in ipairs(maskPickups) do
    local c
    if m.maskType == "shadow" then c = colors.mask_shadow
    elseif m.maskType == "swift" then c = colors.mask_swift
    elseif m.maskType == "oracle" then c = colors.mask_oracle
    else c = {1, 1, 1}
    end
    local pulse = 0.7 + 0.3 * math.sin(shaderTime * 2.5)
    love.graphics.setColor(c[1], c[2], c[3], pulse)
    love.graphics.circle("fill", m.x, m.y, 14)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", m.x, m.y, 14)
  end
  
  -- Goal
  if not isBossLevel or collectedKeys >= keysRequired then
    love.graphics.setColor(colors.goal)
  else
    love.graphics.setColor(0.5, 0.4, 0.2, 0.5)
  end
  love.graphics.rectangle("fill", goal.x + 1, goal.y + 1, goal.size - 2, goal.size - 2)
  
  -- Player trail
  for i, point in ipairs(playerTrail) do
    local trailAlpha = point.alpha * 0.5
    local trailSize = 5 - (i * 0.4)
    if trailSize > 0 then
      if isMaskOn then
        love.graphics.setColor(colors.trail_color[1], colors.trail_color[2], colors.trail_color[3], trailAlpha)
      else
        love.graphics.setColor(0, 0.7, 0.7, trailAlpha)
      end
      love.graphics.circle("fill", point.x, point.y, trailSize)
    end
  end
  
  -- Player
  local centerX = player.x + player.size / 2
  local centerY = player.y + player.size / 2
  
  if player.isInvisible then
    love.graphics.setColor(1, 1, 1, 0.3)
  elseif isMaskOn then
    love.graphics.setColor(1, 1, 1)
  else
    love.graphics.setColor(0, 0.9, 0.9)
  end
  
  if playerImg then
    local originX = playerImg:getWidth() / 2
    local originY = playerImg:getHeight() / 2
    love.graphics.draw(playerImg, centerX, centerY, player.rotation, playerScale, playerScale, originX, originY)
  else
    love.graphics.rectangle("fill", player.x + 1, player.y + 1, player.size - 2, player.size - 2)
  end
  
  -- Guard
  if guard.active then
    if guard.state == GUARD_CHASE then
      love.graphics.setColor(colors.guard_alert)
    elseif guard.state == GUARD_SUSPICIOUS then
      love.graphics.setColor(1, 0.6, 0.3)
    else
      love.graphics.setColor(colors.guard)
    end
    
    if guardImg then
      local originX = guardImg:getWidth() / 2
      local originY = guardImg:getHeight() / 2
      love.graphics.draw(guardImg, guard.x, guard.y, guard.rotation, guardScale, guardScale, originX, originY)
    else
      love.graphics.circle("fill", guard.x, guard.y, guard.radius)
    end
    
    -- Lantern glow
    local prevMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(colors.lantern_glow[1], colors.lantern_glow[2], colors.lantern_glow[3], 0.3)
    love.graphics.circle("fill", guard.x + guard.dirX * 8, guard.y, 18)
    love.graphics.setBlendMode(prevMode)
    
    -- Oracle mask: show path
    if isMaskPowerActive and currentMask == MASK_ORACLE and #guard.path > 0 then
      love.graphics.setColor(1, 0.5, 0.2, 0.4)
      for i, p in ipairs(guard.path) do
        love.graphics.circle("fill", p.x, p.y, 4)
      end
    end
  end
  
  -- Warden
  if warden.active then
    love.graphics.setColor(colors.warden)
    if guardImg then
      local scale = guardScale * 1.5
      local originX = guardImg:getWidth() / 2
      local originY = guardImg:getHeight() / 2
      love.graphics.draw(guardImg, warden.x, warden.y, warden.rotation, scale, scale, originX, originY)
    else
      love.graphics.circle("fill", warden.x, warden.y, warden.radius)
    end
    
    -- Large lantern glow
    local prevMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 0.8, 0.3, 0.4)
    love.graphics.circle("fill", warden.x, warden.y, 60)
    love.graphics.setColor(1, 0.9, 0.5, 0.6)
    love.graphics.circle("fill", warden.x, warden.y, 30)
    love.graphics.setBlendMode(prevMode)
    
    -- Oracle mask: show warden path
    if isMaskPowerActive and currentMask == MASK_ORACLE and #warden.path > 0 then
      love.graphics.setColor(0.8, 0.2, 0.5, 0.5)
      for i, p in ipairs(warden.path) do
        love.graphics.circle("fill", p.x, p.y, 5)
      end
    end
  end
  
  -- Particles
  particleSystem:draw()
  
  love.graphics.pop()
end

function drawUI()
  -- Top left: Level info
  love.graphics.setColor(colors.ui_text_dim)
  love.graphics.print("Episode " .. currentEpisode, 10, 10)
  love.graphics.setColor(colors.ui_text_level)
  love.graphics.print(currentLevelName, 10, 28)
  
  -- Fragments counter
  love.graphics.setColor(colors.fragment)
  love.graphics.print("Memories: " .. collectedFragments .. "/" .. totalFragments, 10, 50)
  
  -- Keys (boss level)
  if isBossLevel then
    love.graphics.setColor(colors.key)
    love.graphics.print("Keys: " .. collectedKeys .. "/" .. keysRequired, 10, 68)
  end
  
  -- Right side: Mask slots
  local slotX = WINDOW_WIDTH - 180
  local slotY = 10
  local slotSize = 36
  
  for i = 1, 4 do
    local m = masks[i]
    local isActive = (i == currentMask and isMaskPowerActive)
    local isUnlocked = m.unlocked
    local onCooldown = maskCooldownTimers[i] > 0
    
    -- Slot background
    if isActive then
      love.graphics.setColor(m.color[1], m.color[2], m.color[3], 0.8)
    elseif isUnlocked then
      love.graphics.setColor(m.color[1] * 0.5, m.color[2] * 0.5, m.color[3] * 0.5, 0.6)
    else
      love.graphics.setColor(0.2, 0.2, 0.2, 0.4)
    end
    love.graphics.rectangle("fill", slotX + (i-1) * (slotSize + 4), slotY, slotSize, slotSize)
    
    -- Border
    if i == currentMask then
      love.graphics.setColor(1, 1, 1, 0.9)
    else
      love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    end
    love.graphics.rectangle("line", slotX + (i-1) * (slotSize + 4), slotY, slotSize, slotSize)
    
    -- Number
    love.graphics.setColor(1, 1, 1, isUnlocked and 1 or 0.3)
    love.graphics.print(tostring(i), slotX + (i-1) * (slotSize + 4) + 13, slotY + 10)
    
    -- Cooldown overlay
    if onCooldown then
      local cooldownRatio = maskCooldownTimers[i] / m.cooldown
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", slotX + (i-1) * (slotSize + 4), slotY, slotSize, slotSize * cooldownRatio)
    end
  end
  
  -- Active power timer
  if isMaskPowerActive then
    love.graphics.setColor(masks[currentMask].color)
    local barWidth = 160
    local ratio = maskActiveTimer / masks[currentMask].duration
    love.graphics.rectangle("fill", slotX, slotY + slotSize + 4, barWidth * ratio, 6)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", slotX, slotY + slotSize + 4, barWidth, 6)
  end
  
  -- Sanity bar
  local barWidth = 120
  local barHeight = 10
  local barX = WINDOW_WIDTH - barWidth - 10
  local barY = slotY + slotSize + 20
  
  love.graphics.setColor(colors.sanity_bar_bg)
  love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
  
  local r = 0.8 + (sanity / SANITY_MAX) * 0.2
  local g = 0.2 - (sanity / SANITY_MAX) * 0.2
  local b = 0.6 - (sanity / SANITY_MAX) * 0.4
  love.graphics.setColor(r, g, b)
  love.graphics.rectangle("fill", barX, barY, (sanity / SANITY_MAX) * barWidth, barHeight)
  
  love.graphics.setColor(colors.ui_text_dim)
  love.graphics.print("SANITY", barX, barY + barHeight + 2)
  
  -- Detection meter (if guard sees player)
  if guard.active and guard.suspicion > 0 then
    local detX = WINDOW_WIDTH / 2 - 75
    local detY = 10
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", detX, detY, 150, 16)
    love.graphics.setColor(colors.detection_bar)
    love.graphics.rectangle("fill", detX, detY, (guard.suspicion / 100) * 150, 16)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("DETECTION", detX, detY + 1, 150, "center")
  end
  
  -- States overlays
  if gameState == STATE_STORY then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    local boxY = WINDOW_HEIGHT / 2 - 120
    local boxHeight = 240
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", 50, boxY, WINDOW_WIDTH - 100, boxHeight)
    
    love.graphics.setColor(colors.ui_text_story)
    local lineY = boxY + 20
    for i = 1, storyLinesShown do
      if currentStory[i] then
        love.graphics.printf(currentStory[i], 70, lineY, WINDOW_WIDTH - 140, "left")
        lineY = lineY + 22
      end
    end
    
    if storyLinesShown >= #currentStory then
      love.graphics.setColor(colors.ui_text_dim)
      love.graphics.printf("Press ENTER to continue...", 0, boxY + boxHeight - 30, WINDOW_WIDTH, "center")
    end
  end
  
  if gameState == STATE_FRAGMENT then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    love.graphics.setColor(colors.fragment)
    love.graphics.printf("MEMORY RECOVERED", 0, WINDOW_HEIGHT / 2 - 60, WINDOW_WIDTH, "center")
    
    love.graphics.setColor(colors.ui_text_story)
    love.graphics.printf('"' .. currentFragmentText .. '"', 100, WINDOW_HEIGHT / 2 - 20, WINDOW_WIDTH - 200, "center")
    
    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press ENTER to continue...", 0, WINDOW_HEIGHT / 2 + 50, WINDOW_WIDTH, "center")
  end
  
  if gameState == STATE_COMPLETE then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    local boxY = WINDOW_HEIGHT / 2 - 60
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 200, boxY, 400, 120)
    
    love.graphics.setColor(colors.ui_text_win)
    love.graphics.printf("LEVEL COMPLETE", 0, boxY + 15, WINDOW_WIDTH, "center")
    
    if currentEnding and currentEnding ~= "FINALE" then
      love.graphics.setColor(colors.ui_text_story)
      love.graphics.printf(currentEnding, WINDOW_WIDTH / 2 - 180, boxY + 45, 360, "center")
    end
    
    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press ENTER to Continue", 0, boxY + 90, WINDOW_WIDTH, "center")
  end
  
  if gameState == STATE_GAMEOVER then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 160, WINDOW_HEIGHT / 2 - 55, 320, 110)
    
    love.graphics.setColor(colors.ui_text_lose)
    love.graphics.printf("CAUGHT", 0, WINDOW_HEIGHT / 2 - 40, WINDOW_WIDTH, "center")
    
    love.graphics.setColor(colors.ui_text_story)
    love.graphics.printf(sanityGameOverReason, WINDOW_WIDTH / 2 - 140, WINDOW_HEIGHT / 2 - 5, 280, "center")
    
    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press R to Retry", 0, WINDOW_HEIGHT / 2 + 35, WINDOW_WIDTH, "center")
  end
  
  if gameState == STATE_INSANE then
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    love.graphics.setColor(colors.ui_background)
    love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 180, WINDOW_HEIGHT / 2 - 60, 360, 120)
    
    love.graphics.setColor(0.8, 0.2, 0.6)
    love.graphics.printf("MIND SHATTERED", 0, WINDOW_HEIGHT / 2 - 45, WINDOW_WIDTH, "center")
    
    love.graphics.setColor(colors.ui_text_story)
    love.graphics.printf(sanityGameOverReason, WINDOW_WIDTH / 2 - 160, WINDOW_HEIGHT / 2 - 10, 320, "center")
    
    love.graphics.setColor(colors.ui_text_dim)
    love.graphics.printf("Press R to Retry", 0, WINDOW_HEIGHT / 2 + 40, WINDOW_WIDTH, "center")
  end
end
