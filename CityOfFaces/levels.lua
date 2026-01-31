-- Level Data for "The Escape from Veritas"
-- Each level contains: mapMaskOn, mapMaskOff, playerStart, goalPos, guard, story
-- NEW: fragments, hidingSpots, maskPickups, keys, warden

local tileSize = 32

-- Tile types:
-- 0 = Empty/Floor
-- 1 = Wall
-- 2 = Hiding Spot (shadow area)

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

-- Helper to add hiding spot (shadow area)
local function addHidingSpot(map, row, col)
  if map[row] then map[row][col] = 2 end
end

-- Helper to add rectangular hiding area
local function addHidingArea(map, rowStart, rowEnd, colStart, colEnd)
  for row = rowStart, rowEnd do
    for col = colStart, colEnd do
      if map[row] and map[row][col] == 0 then
        map[row][col] = 2
      end
    end
  end
end

--------------------------------------------------------------------------------
-- STORY FRAGMENTS (Lore pieces)
--------------------------------------------------------------------------------
local storyFragments = {
  -- Episode 1
  "The masks were given to protect us... or so we were told.",
  "In Veritas, no one remembers their own face.",
  "The Warden was the first to wear the mask. He never took it off.",
  
  -- Episode 2
  "They say looking at the Truth drives you mad.",
  "The festivals are lies. Behind the confetti, surveillance.",
  "Some masks crack. When they do, people disappear.",
  
  -- Episode 3
  "The Warden sees all faces. Even your true one.",
  "There was a time before the masks. No one remembers it.",
  "Freedom lies beyond the walls. If you can reach them.",
  
  -- Episode 4 (Boss)
  "The Warden is not human. Not anymore.",
  "His lantern reveals what the masks hide.",
  "Only three keys can open the final gate.",
  
  -- Secret/Bonus
  "You were the one who created the masks.",
  "The Truth was always inside you.",
  "To be free, you must see yourself."
}

--------------------------------------------------------------------------------
-- EPISODE 1: THE CRACK IN THE MASK (Tutorial)
--------------------------------------------------------------------------------
local function createEpisode1()
  local mapOn = createEmptyMap(18, 12)
  local mapOff = createEmptyMap(18, 12)

  -- MASK ON (The Lie): Prison cell looks solid, door is locked
  addVerticalWall(mapOn, 4, 2, 10)
  addHorizontalWall(mapOn, 6, 4, 8)
  setCell(mapOn, 6, 6, 1)
  setCell(mapOn, 6, 7, 1)
  addVerticalWall(mapOn, 10, 2, 11)
  setCell(mapOn, 6, 10, 1)

  -- MASK OFF (The Truth): You see the crack, the door is broken
  addVerticalWall(mapOff, 4, 2, 4)
  addVerticalWall(mapOff, 4, 7, 10)
  addHorizontalWall(mapOff, 6, 4, 5)
  clearCell(mapOff, 6, 6)
  clearCell(mapOff, 6, 7)
  addVerticalWall(mapOff, 10, 2, 11)
  clearCell(mapOff, 6, 10)

  -- Add hiding spots (dark corners in cell)
  addHidingSpot(mapOn, 9, 2)
  addHidingSpot(mapOn, 9, 3)
  addHidingSpot(mapOff, 9, 2)
  addHidingSpot(mapOff, 9, 3)

  return {
    name = "The Crack in the Mask",
    episode = 1,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 2, y = tileSize * 3 },
    goalPos = { x = tileSize * 15, y = tileSize * 5 },
    guard = nil,  -- No guard in tutorial
    
    -- Memory fragments (collectibles)
    fragments = {
      { x = tileSize * 2.5, y = tileSize * 8.5, text = storyFragments[1] },
      { x = tileSize * 7.5, y = tileSize * 3.5, text = storyFragments[2] },
      { x = tileSize * 13.5, y = tileSize * 8.5, text = storyFragments[3] }
    },
    
    story = {
      "You wake in darkness.",
      "Your mask... it's cracked.",
      "Through the crack, you see things others cannot.",
      "",
      "Hold SPACE to see the Truth.",
      "Find your way out.",
      "",
      "Collect the glowing fragments to learn the truth."
    },
    ending = "You step outside. A Guard patrols the street ahead..."
  }
end

--------------------------------------------------------------------------------
-- EPISODE 2: THE STREETS OF SILENCE (Challenge)
--------------------------------------------------------------------------------
local function createEpisode2_Part1()
  local mapOn = createEmptyMap(22, 16)
  local mapOff = createEmptyMap(22, 16)

  -- MASK ON (The Lie): Beautiful festival streets
  addHorizontalWall(mapOn, 4, 2, 8)
  addVerticalWall(mapOn, 8, 4, 8)
  addHorizontalWall(mapOn, 8, 4, 8)
  addHorizontalWall(mapOn, 10, 10, 16)
  addVerticalWall(mapOn, 16, 10, 14)
  
  -- Add hiding spots (alcoves)
  addHidingArea(mapOn, 2, 3, 9, 11)
  addHidingArea(mapOn, 13, 14, 2, 4)

  -- MASK OFF (The Truth): Surveillance nightmare
  addHorizontalWall(mapOff, 4, 2, 6)
  addVerticalWall(mapOff, 6, 4, 10)
  addVerticalWall(mapOff, 10, 8, 14)
  addVerticalWall(mapOff, 14, 8, 14)
  addHorizontalWall(mapOff, 12, 2, 9)
  
  -- Same hiding spots
  addHidingArea(mapOff, 2, 3, 9, 11)
  addHidingArea(mapOff, 13, 14, 2, 4)

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
    
    fragments = {
      { x = tileSize * 10.5, y = tileSize * 2.5, text = storyFragments[4] },
      { x = tileSize * 3.5, y = tileSize * 13.5, text = storyFragments[5] },
      { x = tileSize * 17.5, y = tileSize * 10.5, text = storyFragments[6] }
    },
    
    -- Shadow Mask pickup (become invisible)
    maskPickups = {
      { x = tileSize * 12, y = tileSize * 13, maskType = "shadow" }
    },
    
    story = {
      "The city streets.",
      "In the Lie, festivals and joy.",
      "In the Truth, cameras everywhere.",
      "",
      "The Guards see your true face.",
      "Keep your mask ON near them.",
      "",
      "Press 1-4 to switch masks.",
      "Find the Shadow Mask to become invisible!"
    },
    ending = nil
  }
end

local function createEpisode2_Part2()
  local mapOn = createEmptyMap(25, 18)
  local mapOff = createEmptyMap(25, 18)

  -- MASK ON: Maze of festival decorations
  addVerticalWall(mapOn, 5, 2, 14)
  clearCell(mapOn, 8, 5)
  addVerticalWall(mapOn, 10, 4, 16)
  clearCell(mapOn, 12, 10)
  addVerticalWall(mapOn, 15, 2, 12)
  addHorizontalWall(mapOn, 10, 15, 22)
  addVerticalWall(mapOn, 20, 10, 16)
  clearCell(mapOn, 14, 20)
  
  -- Hiding spots
  addHidingArea(mapOn, 2, 4, 2, 4)
  addHidingArea(mapOn, 14, 16, 6, 8)

  -- MASK OFF: Surveillance grid
  addVerticalWall(mapOff, 5, 5, 16)
  clearCell(mapOff, 10, 5)
  addVerticalWall(mapOff, 10, 2, 12)
  clearCell(mapOff, 6, 10)
  addVerticalWall(mapOff, 15, 6, 16)
  clearCell(mapOff, 10, 15)
  addHorizontalWall(mapOff, 6, 15, 22)
  addVerticalWall(mapOff, 20, 2, 12)
  clearCell(mapOff, 10, 20)
  
  addHidingArea(mapOff, 2, 4, 2, 4)
  addHidingArea(mapOff, 14, 16, 6, 8)

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
    
    fragments = {
      { x = tileSize * 3.5, y = tileSize * 3.5, text = storyFragments[7] },
      { x = tileSize * 15.5, y = tileSize * 15.5, text = storyFragments[8] },
      { x = tileSize * 21.5, y = tileSize * 5.5, text = storyFragments[9] }
    },
    
    -- Swift Mask pickup (speed boost)
    maskPickups = {
      { x = tileSize * 8, y = tileSize * 14, maskType = "swift" }
    },
    
    story = {
      "The sewers lie ahead.",
      "One final stretch through the streets.",
      "",
      "Toggle wisely. The Guard is close.",
      "Use hiding spots (dark areas) to stay safe!"
    },
    ending = "You descend into darkness. The Truth grows unstable here..."
  }
end

--------------------------------------------------------------------------------
-- EPISODE 3: THE DEEP TRUTH (The Gauntlet)
--------------------------------------------------------------------------------
local function createEpisode3_Part1()
  local mapOn = createEmptyMap(20, 15)
  local mapOff = createEmptyMap(20, 15)

  -- MASK ON: Sewer tunnels
  addVerticalWall(mapOn, 6, 2, 12)
  clearCell(mapOn, 7, 6)
  addHorizontalWall(mapOn, 8, 6, 14)
  addVerticalWall(mapOn, 14, 8, 13)
  
  addHidingArea(mapOn, 2, 4, 2, 4)
  addHidingArea(mapOn, 11, 13, 15, 17)

  -- MASK OFF: Reality shifts
  addVerticalWall(mapOff, 6, 5, 13)
  clearCell(mapOff, 10, 6)
  addHorizontalWall(mapOff, 5, 6, 14)
  addVerticalWall(mapOff, 14, 2, 8)
  clearCell(mapOff, 5, 14)
  
  addHidingArea(mapOff, 2, 4, 2, 4)
  addHidingArea(mapOff, 11, 13, 15, 17)

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
    
    fragments = {
      { x = tileSize * 3.5, y = tileSize * 3.5, text = storyFragments[10] },
      { x = tileSize * 12.5, y = tileSize * 3.5, text = storyFragments[11] },
      { x = tileSize * 16.5, y = tileSize * 12.5, text = storyFragments[12] }
    },
    
    -- Oracle Mask pickup (see guard paths)
    maskPickups = {
      { x = tileSize * 10, y = tileSize * 11, maskType = "oracle" }
    },
    
    story = {
      "The sewers twist and shift.",
      "Reality is unstable here.",
      "",
      "Walls MOVE when you see the Truth.",
      "Time your switches carefully.",
      "",
      "The Oracle Mask reveals enemy paths!"
    },
    ending = nil
  }
end

local function createEpisode3_Part2()
  local mapOn = createEmptyMap(30, 12)
  local mapOff = createEmptyMap(30, 12)

  -- THE FINAL CORRIDOR
  addVerticalWall(mapOn, 6, 2, 8)
  clearCell(mapOn, 5, 6)
  addVerticalWall(mapOn, 10, 4, 10)
  clearCell(mapOn, 7, 10)
  addVerticalWall(mapOn, 14, 2, 8)
  clearCell(mapOn, 5, 14)
  addVerticalWall(mapOn, 18, 4, 10)
  clearCell(mapOn, 7, 18)
  addVerticalWall(mapOn, 22, 2, 8)
  clearCell(mapOn, 5, 22)
  
  addHidingArea(mapOn, 9, 10, 2, 4)

  -- MASK OFF: Barriers in OPPOSITE positions
  addVerticalWall(mapOff, 6, 4, 10)
  clearCell(mapOff, 7, 6)
  addVerticalWall(mapOff, 10, 2, 8)
  clearCell(mapOff, 5, 10)
  addVerticalWall(mapOff, 14, 4, 10)
  clearCell(mapOff, 7, 14)
  addVerticalWall(mapOff, 18, 2, 8)
  clearCell(mapOff, 5, 18)
  addVerticalWall(mapOff, 22, 4, 10)
  clearCell(mapOff, 7, 22)
  
  addHidingArea(mapOff, 9, 10, 2, 4)

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
      speed = 160
    },
    
    fragments = {
      { x = tileSize * 8.5, y = tileSize * 3.5, text = storyFragments[13] },
      { x = tileSize * 16.5, y = tileSize * 9.5, text = storyFragments[14] },
      { x = tileSize * 24.5, y = tileSize * 3.5, text = storyFragments[15] }
    },
    
    story = {
      "The exit is ahead.",
      "One final run.",
      "",
      "Switch between worlds to phase through.",
      "Don't stop moving."
    },
    ending = nil  -- Continues to boss
  }
end

--------------------------------------------------------------------------------
-- EPISODE 4: THE WARDEN (Boss Fight)
--------------------------------------------------------------------------------
local function createBossLevel()
  local mapOn = createEmptyMap(30, 25)
  local mapOff = createEmptyMap(30, 25)

  -- Large arena with pillars
  -- Central pillars
  for _, pos in ipairs({{8,8}, {8,17}, {22,8}, {22,17}}) do
    for dr = -1, 1 do
      for dc = -1, 1 do
        setCell(mapOn, pos[1]+dr, pos[2]+dc, 1)
        setCell(mapOff, pos[1]+dr, pos[2]+dc, 1)
      end
    end
  end
  
  -- Interior walls - different in each world
  -- MASK ON
  addHorizontalWall(mapOn, 5, 10, 20)
  addHorizontalWall(mapOn, 20, 10, 20)
  addVerticalWall(mapOn, 15, 8, 12)
  addVerticalWall(mapOn, 15, 13, 17)
  clearCell(mapOn, 5, 15)
  clearCell(mapOn, 20, 15)
  
  -- MASK OFF - different gaps
  addHorizontalWall(mapOff, 5, 8, 12)
  addHorizontalWall(mapOff, 5, 18, 22)
  addHorizontalWall(mapOff, 20, 8, 12)
  addHorizontalWall(mapOff, 20, 18, 22)
  addVerticalWall(mapOff, 12, 8, 17)
  addVerticalWall(mapOff, 18, 8, 17)
  clearCell(mapOff, 12, 12)
  clearCell(mapOff, 12, 18)
  
  -- Hiding spots in corners
  addHidingArea(mapOn, 2, 4, 2, 4)
  addHidingArea(mapOn, 2, 4, 25, 28)
  addHidingArea(mapOn, 21, 23, 2, 4)
  addHidingArea(mapOn, 21, 23, 25, 28)
  
  addHidingArea(mapOff, 2, 4, 2, 4)
  addHidingArea(mapOff, 2, 4, 25, 28)
  addHidingArea(mapOff, 21, 23, 2, 4)
  addHidingArea(mapOff, 21, 23, 25, 28)
  
  -- Exit gate (locked until 3 keys collected)
  addHorizontalWall(mapOn, 23, 14, 16)
  addHorizontalWall(mapOff, 23, 14, 16)

  return {
    name = "The Warden",
    episode = 4,
    mapMaskOn = mapOn,
    mapMaskOff = mapOff,
    playerStart = { x = tileSize * 15, y = tileSize * 2 },
    goalPos = { x = tileSize * 15, y = tileSize * 23 },  -- Behind the gate
    guard = nil,  -- Regular guard disabled
    
    -- THE WARDEN - Boss enemy
    warden = {
      x = tileSize * 15,
      y = tileSize * 12,
      speed = 180,
      detectionRange = 400,
      catchRange = 50,
      canSeeInShadows = true,  -- Lantern reveals hidden players
      canSeeThroughShadowMask = true
    },
    
    -- Keys required to open the exit
    keys = {
      { x = tileSize * 3, y = tileSize * 12 },
      { x = tileSize * 27, y = tileSize * 12 },
      { x = tileSize * 15, y = tileSize * 18 }
    },
    keysRequired = 3,
    
    fragments = {
      { x = tileSize * 5.5, y = tileSize * 5.5, text = "You were the one who created the masks." },
      { x = tileSize * 24.5, y = tileSize * 5.5, text = "The Truth was always inside you." },
      { x = tileSize * 15.5, y = tileSize * 10.5, text = "To be free, you must see yourself." }
    },
    
    story = {
      "THE WARDEN",
      "",
      "He sees all faces. Even your true one.",
      "His lantern reveals what the masks hide.",
      "",
      "Collect the THREE KEYS to open the gate.",
      "The Shadow Mask will not hide you from him.",
      "Only the Oracle Mask shows his path.",
      "",
      "Run. Hide. Survive."
    },
    
    ending = "FINALE",
    isFinalLevel = true,
    isBossLevel = true
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
  createEpisode3_Part2(),
  
  -- Episode 4: Boss Fight
  createBossLevel()
}
