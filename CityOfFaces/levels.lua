-- Level Data for "The Escape from Veritas"
-- Each level contains: mapMaskOn, mapMaskOff, playerStart, goalPos, guard, story

local tileSize = 32

-- Helper to generate an empty map with border walls
local function createEmptyMap(width, height)
  local map = {}
  for row = 1, height do
    map[row] = {}
    for col = 1, width do
      if row == 1 or row == height or col == 1 or col == width then
        map[row][col] = 1
      else
        map[row][col] = 0
      end
    end
  end
  return map
end

-- Helper to add a horizontal wall
local function addHorizontalWall(map, row, colStart, colEnd)
  for col = colStart, colEnd do
    if map[row] then map[row][col] = 1 end
  end
end

-- Helper to add a vertical wall
local function addVerticalWall(map, col, rowStart, rowEnd)
  for row = rowStart, rowEnd do
    if map[row] then map[row][col] = 1 end
  end
end

-- Helper to clear a cell
local function clearCell(map, row, col)
  if map[row] then map[row][col] = 0 end
end

-- Helper to set a cell
local function setCell(map, row, col, value)
  if map[row] then map[row][col] = value end
end

--------------------------------------------------------------------------------
-- EPISODE 1: THE CRACK IN THE MASK (Tutorial)
-- Story: You wake up in your cell. Your mask is broken. You see a hole in the 
-- wall that others can't see.
-- Goal: Teach the player the mechanics safely. No enemies.
--------------------------------------------------------------------------------
local function createEpisode1()
  local mapOn = createEmptyMap(18, 12)
  local mapOff = createEmptyMap(18, 12)

  -- MASK ON (The Lie): Prison cell looks solid, door is locked
  -- Your cell walls
  addVerticalWall(mapOn, 4, 2, 10)
  addHorizontalWall(mapOn, 6, 4, 8)
  -- The "locked door" - solid wall
  setCell(mapOn, 6, 6, 1)
  setCell(mapOn, 6, 7, 1)
  -- Corridor walls
  addVerticalWall(mapOn, 10, 2, 11)
  -- Exit door appears locked
  setCell(mapOn, 6, 10, 1)

  -- MASK OFF (The Truth): You see the crack, the door is broken
  -- Cell walls have a crack/hole
  addVerticalWall(mapOff, 4, 2, 4)  -- Gap at rows 5-6
  addVerticalWall(mapOff, 4, 7, 10)
  addHorizontalWall(mapOff, 6, 4, 5) -- Partial wall
  -- The "door" is actually broken - open!
  clearCell(mapOff, 6, 6)
  clearCell(mapOff, 6, 7)
  -- Corridor - same
  addVerticalWall(mapOff, 10, 2, 11)
  -- Exit is open in truth
  clearCell(mapOff, 6, 10)

  return {
    name = "The Crack in the Mask",
    episode = 1,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 3 },
    goalPos = { x = tileSize * 15, y = tileSize * 5 },
    -- No guard in tutorial (or very far away, inactive)
    guard = nil,
    -- Story text shown at level start
    story = {
      "You wake in darkness.",
      "Your mask... it's cracked.",
      "Through the crack, you see things others cannot.",
      "",
      "Hold SPACE to see the Truth.",
      "Find your way out."
    },
    -- Ending text
    ending = "You step outside. A Guard patrols the street ahead..."
  }
end

--------------------------------------------------------------------------------
-- EPISODE 2: THE STREETS OF SILENCE (Challenge)
-- Story: The city streets. The "Lie" is beautiful. The "Truth" is surveillance.
-- Goal: Avoid the Guards.
--------------------------------------------------------------------------------
local function createEpisode2_Part1()
  local mapOn = createEmptyMap(22, 16)
  local mapOff = createEmptyMap(22, 16)

  -- MASK ON (The Lie): Beautiful festival streets, clear paths
  -- Building blocks
  addHorizontalWall(mapOn, 4, 2, 8)
  addVerticalWall(mapOn, 8, 4, 8)
  addHorizontalWall(mapOn, 8, 4, 8)
  -- Festival booth (blocks path in lie)
  addHorizontalWall(mapOn, 10, 10, 16)
  addVerticalWall(mapOn, 16, 10, 14)
  -- Crowd area - safe passage in the lie
  -- (open space around row 12)

  -- MASK OFF (The Truth): Surveillance nightmare, different paths
  -- Surveillance towers block different areas
  addHorizontalWall(mapOff, 4, 2, 6)
  addVerticalWall(mapOff, 6, 4, 10)
  -- The festival booth is just scaffolding - you can pass through
  addVerticalWall(mapOff, 10, 8, 14)
  addVerticalWall(mapOff, 14, 8, 14)
  -- But camera sightlines block the "safe" crowd area
  addHorizontalWall(mapOff, 12, 2, 9)

  return {
    name = "The Streets of Silence",
    episode = 2,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 7 },
    goalPos = { x = tileSize * 19, y = tileSize * 13 },
    guard = {
      y = tileSize * 6 + tileSize / 2,
      minX = tileSize * 8,
      maxX = tileSize * 18,
      speed = 90
    },
    story = {
      "The city streets.",
      "In the Lie, festivals and joy.",
      "In the Truth, cameras everywhere.",
      "",
      "The Guards see your true face.",
      "Keep your mask ON near them."
    },
    ending = nil  -- Continues to next part
  }
end

local function createEpisode2_Part2()
  local mapOn = createEmptyMap(25, 18)
  local mapOff = createEmptyMap(25, 18)

  -- MASK ON: Maze of festival decorations
  addVerticalWall(mapOn, 5, 2, 14)
  clearCell(mapOn, 8, 5)  -- Gap
  addVerticalWall(mapOn, 10, 4, 16)
  clearCell(mapOn, 12, 10)  -- Gap
  addVerticalWall(mapOn, 15, 2, 12)
  addHorizontalWall(mapOn, 10, 15, 22)
  addVerticalWall(mapOn, 20, 10, 16)
  clearCell(mapOn, 14, 20)  -- Gap

  -- MASK OFF: Surveillance grid - different gaps
  addVerticalWall(mapOff, 5, 5, 16)
  clearCell(mapOff, 10, 5)  -- Different gap
  addVerticalWall(mapOff, 10, 2, 12)
  clearCell(mapOff, 6, 10)  -- Different gap
  addVerticalWall(mapOff, 15, 6, 16)
  clearCell(mapOff, 10, 15)  -- Gap
  addHorizontalWall(mapOff, 6, 15, 22)
  addVerticalWall(mapOff, 20, 2, 12)
  clearCell(mapOff, 10, 20)  -- Gap

  return {
    name = "The Sewer Entrance",
    episode = 2,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 2 },
    goalPos = { x = tileSize * 22, y = tileSize * 15 },
    guard = {
      y = tileSize * 9 + tileSize / 2,
      minX = tileSize * 6,
      maxX = tileSize * 14,
      speed = 110
    },
    story = {
      "The sewers lie ahead.",
      "One final stretch through the streets.",
      "",
      "Toggle wisely. The Guard is close."
    },
    ending = "You descend into darkness. The Truth grows unstable here..."
  }
end

--------------------------------------------------------------------------------
-- EPISODE 3: THE DEEP TRUTH (The Gauntlet)
-- Story: The final stretch. The Truth is unstable. Glitch effects.
-- Goal: Survive the hardest puzzles. Moving walls.
--------------------------------------------------------------------------------
local function createEpisode3_Part1()
  local mapOn = createEmptyMap(20, 15)
  local mapOff = createEmptyMap(20, 15)

  -- MASK ON: Sewer tunnels
  addVerticalWall(mapOn, 6, 2, 12)
  clearCell(mapOn, 7, 6)
  addHorizontalWall(mapOn, 8, 6, 14)
  addVerticalWall(mapOn, 14, 8, 13)

  -- MASK OFF: Reality shifts - walls MOVE
  -- Completely different configuration
  addVerticalWall(mapOff, 6, 5, 13)
  clearCell(mapOff, 10, 6)
  addHorizontalWall(mapOff, 5, 6, 14)
  addVerticalWall(mapOff, 14, 2, 8)
  clearCell(mapOff, 5, 14)

  return {
    name = "The Deep Truth",
    episode = 3,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 3 },
    goalPos = { x = tileSize * 17, y = tileSize * 12 },
    guard = {
      y = tileSize * 10 + tileSize / 2,
      minX = tileSize * 7,
      maxX = tileSize * 13,
      speed = 130
    },
    -- Moving walls data (walls that shift when toggling)
    movingWalls = {
      { onPos = {row = 6, col = 10}, offPos = {row = 10, col = 10} },
      { onPos = {row = 6, col = 11}, offPos = {row = 10, col = 11} }
    },
    story = {
      "The sewers twist and shift.",
      "Reality is unstable here.",
      "",
      "Walls MOVE when you see the Truth.",
      "Time your switches carefully."
    },
    ending = nil
  }
end

local function createEpisode3_Finale()
  local mapOn = createEmptyMap(30, 12)
  local mapOff = createEmptyMap(30, 12)

  -- THE FINAL CORRIDOR - Must switch rapidly while moving
  
  -- MASK ON: Series of barriers
  addVerticalWall(mapOn, 6, 2, 8)
  clearCell(mapOn, 5, 6)   -- Bottom gap
  addVerticalWall(mapOn, 10, 4, 10)
  clearCell(mapOn, 7, 10)  -- Middle gap
  addVerticalWall(mapOn, 14, 2, 8)
  clearCell(mapOn, 5, 14)  -- Bottom gap
  addVerticalWall(mapOn, 18, 4, 10)
  clearCell(mapOn, 7, 18)  -- Middle gap
  addVerticalWall(mapOn, 22, 2, 8)
  clearCell(mapOn, 5, 22)  -- Bottom gap

  -- MASK OFF: Barriers in OPPOSITE positions
  addVerticalWall(mapOff, 6, 4, 10)
  clearCell(mapOff, 7, 6)   -- Middle gap (opposite)
  addVerticalWall(mapOff, 10, 2, 8)
  clearCell(mapOff, 5, 10)  -- Bottom gap (opposite)
  addVerticalWall(mapOff, 14, 4, 10)
  clearCell(mapOff, 7, 14)  -- Middle gap (opposite)
  addVerticalWall(mapOff, 18, 2, 8)
  clearCell(mapOff, 5, 18)  -- Bottom gap (opposite)
  addVerticalWall(mapOff, 22, 4, 10)
  clearCell(mapOff, 7, 22)  -- Middle gap (opposite)

  return {
    name = "The Final Run",
    episode = 3,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 6 },
    goalPos = { x = tileSize * 27, y = tileSize * 6 },
    guard = {
      y = tileSize * 9 + tileSize / 2,
      minX = tileSize * 4,
      maxX = tileSize * 24,
      speed = 160  -- Fast!
    },
    story = {
      "The exit is ahead.",
      "One final run.",
      "",
      "Switch between worlds to phase through.",
      "Don't stop moving."
    },
    ending = "FINALE",  -- Special flag for ending sequence
    isFinalLevel = true
  }
end

--------------------------------------------------------------------------------
-- Export all levels in order
--------------------------------------------------------------------------------
return {
  -- Episode 1: Tutorial
  createEpisode1(),
  
  -- Episode 2: The Streets
  createEpisode2_Part1(),
  createEpisode2_Part2(),
  
  -- Episode 3: The Gauntlet
  createEpisode3_Part1(),
  createEpisode3_Finale()
}
