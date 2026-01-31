-- Particle System for "The Escape from Veritas"
-- Handles dust motes, torch flames, footstep trails, fragment glows, and sanity particles

local Particles = {}

--------------------------------------------------------------------------------
-- PARTICLE CLASS
--------------------------------------------------------------------------------

local Particle = {}
Particle.__index = Particle

function Particle.new(x, y, config)
  local self = setmetatable({}, Particle)
  self.x = x
  self.y = y
  self.vx = config.vx or 0
  self.vy = config.vy or 0
  self.life = config.life or 1
  self.maxLife = self.life
  self.size = config.size or 4
  self.sizeDecay = config.sizeDecay or 0
  self.color = config.color or {1, 1, 1, 1}
  self.fadeOut = config.fadeOut ~= false
  self.gravity = config.gravity or 0
  self.friction = config.friction or 1
  self.rotation = config.rotation or 0
  self.rotationSpeed = config.rotationSpeed or 0
  self.shape = config.shape or "circle"  -- "circle", "square", "spark"
  return self
end

function Particle:update(dt)
  self.life = self.life - dt
  
  -- Apply gravity
  self.vy = self.vy + self.gravity * dt
  
  -- Apply friction
  self.vx = self.vx * self.friction
  self.vy = self.vy * self.friction
  
  -- Move
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  
  -- Rotate
  self.rotation = self.rotation + self.rotationSpeed * dt
  
  -- Shrink
  if self.sizeDecay > 0 then
    self.size = math.max(0, self.size - self.sizeDecay * dt)
  end
  
  return self.life > 0 and self.size > 0
end

function Particle:draw()
  local alpha = self.color[4] or 1
  if self.fadeOut then
    alpha = alpha * (self.life / self.maxLife)
  end
  
  love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
  
  if self.shape == "circle" then
    love.graphics.circle("fill", self.x, self.y, self.size)
  elseif self.shape == "square" then
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    love.graphics.rectangle("fill", -self.size/2, -self.size/2, self.size, self.size)
    love.graphics.pop()
  elseif self.shape == "spark" then
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    love.graphics.rectangle("fill", -self.size/2, -1, self.size, 2)
    love.graphics.pop()
  end
end

--------------------------------------------------------------------------------
-- EMITTER CLASS
--------------------------------------------------------------------------------

local Emitter = {}
Emitter.__index = Emitter

function Emitter.new(x, y, config)
  local self = setmetatable({}, Emitter)
  self.x = x
  self.y = y
  self.particles = {}
  self.config = config or {}
  self.emitTimer = 0
  self.emitRate = config.emitRate or 0.1  -- Seconds between emissions
  self.particlesPerEmit = config.particlesPerEmit or 1
  self.active = true
  self.followTarget = nil
  return self
end

function Emitter:setPosition(x, y)
  self.x = x
  self.y = y
end

function Emitter:follow(target)
  self.followTarget = target
end

function Emitter:emit(count)
  count = count or self.particlesPerEmit
  for i = 1, count do
    local config = self:generateParticleConfig()
    local offsetX = (math.random() - 0.5) * (self.config.spawnRadius or 0)
    local offsetY = (math.random() - 0.5) * (self.config.spawnRadius or 0)
    local p = Particle.new(self.x + offsetX, self.y + offsetY, config)
    table.insert(self.particles, p)
  end
end

function Emitter:generateParticleConfig()
  local cfg = self.config
  
  -- Random velocity within range
  local speed = cfg.speed or 50
  local speedVar = cfg.speedVariance or 0
  local actualSpeed = speed + (math.random() - 0.5) * speedVar * 2
  
  local angle = cfg.angle or 0
  local angleVar = cfg.angleVariance or math.pi * 2
  local actualAngle = angle + (math.random() - 0.5) * angleVar * 2
  
  local vx = math.cos(actualAngle) * actualSpeed
  local vy = math.sin(actualAngle) * actualSpeed
  
  -- Random life within range
  local life = cfg.life or 1
  local lifeVar = cfg.lifeVariance or 0
  local actualLife = life + (math.random() - 0.5) * lifeVar * 2
  
  -- Random size within range
  local size = cfg.size or 4
  local sizeVar = cfg.sizeVariance or 0
  local actualSize = size + (math.random() - 0.5) * sizeVar * 2
  
  -- Color with optional variation
  local color = cfg.color or {1, 1, 1, 1}
  local colorVar = cfg.colorVariance or 0
  local actualColor = {
    math.max(0, math.min(1, color[1] + (math.random() - 0.5) * colorVar)),
    math.max(0, math.min(1, color[2] + (math.random() - 0.5) * colorVar)),
    math.max(0, math.min(1, color[3] + (math.random() - 0.5) * colorVar)),
    color[4] or 1
  }
  
  return {
    vx = vx,
    vy = vy,
    life = actualLife,
    size = actualSize,
    sizeDecay = cfg.sizeDecay or 0,
    color = actualColor,
    fadeOut = cfg.fadeOut ~= false,
    gravity = cfg.gravity or 0,
    friction = cfg.friction or 1,
    rotation = math.random() * math.pi * 2,
    rotationSpeed = (cfg.rotationSpeed or 0) + (math.random() - 0.5) * (cfg.rotationSpeedVariance or 0),
    shape = cfg.shape or "circle"
  }
end

function Emitter:update(dt)
  -- Follow target if set
  if self.followTarget then
    self.x = self.followTarget.x
    self.y = self.followTarget.y
  end
  
  -- Emit new particles
  if self.active and self.emitRate > 0 then
    self.emitTimer = self.emitTimer + dt
    while self.emitTimer >= self.emitRate do
      self.emitTimer = self.emitTimer - self.emitRate
      self:emit()
    end
  end
  
  -- Update existing particles
  for i = #self.particles, 1, -1 do
    if not self.particles[i]:update(dt) then
      table.remove(self.particles, i)
    end
  end
end

function Emitter:draw()
  for _, p in ipairs(self.particles) do
    p:draw()
  end
end

function Emitter:clear()
  self.particles = {}
end

--------------------------------------------------------------------------------
-- PARTICLE SYSTEM (Manager)
--------------------------------------------------------------------------------

local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

function ParticleSystem.new()
  local self = setmetatable({}, ParticleSystem)
  self.emitters = {}
  self.oneShots = {}  -- One-time particle bursts
  return self
end

function ParticleSystem:addEmitter(name, emitter)
  self.emitters[name] = emitter
  return emitter
end

function ParticleSystem:removeEmitter(name)
  self.emitters[name] = nil
end

function ParticleSystem:getEmitter(name)
  return self.emitters[name]
end

-- One-shot burst of particles at a position
function ParticleSystem:burst(x, y, config, count)
  local emitter = Emitter.new(x, y, config)
  emitter.active = false
  emitter:emit(count or 10)
  table.insert(self.oneShots, emitter)
end

function ParticleSystem:update(dt)
  -- Update named emitters
  for _, emitter in pairs(self.emitters) do
    emitter:update(dt)
  end
  
  -- Update one-shot bursts
  for i = #self.oneShots, 1, -1 do
    self.oneShots[i]:update(dt)
    if #self.oneShots[i].particles == 0 then
      table.remove(self.oneShots, i)
    end
  end
end

function ParticleSystem:draw()
  for _, emitter in pairs(self.emitters) do
    emitter:draw()
  end
  
  for _, oneShot in ipairs(self.oneShots) do
    oneShot:draw()
  end
end

function ParticleSystem:clear()
  for _, emitter in pairs(self.emitters) do
    emitter:clear()
  end
  self.oneShots = {}
end

--------------------------------------------------------------------------------
-- PRESET CONFIGURATIONS
--------------------------------------------------------------------------------

Particles.presets = {
  -- Floating dust motes
  dust = {
    emitRate = 0.3,
    particlesPerEmit = 1,
    spawnRadius = 400,
    speed = 15,
    speedVariance = 10,
    angle = -math.pi/2,  -- Upward
    angleVariance = math.pi/4,
    life = 4,
    lifeVariance = 2,
    size = 2,
    sizeVariance = 1,
    color = {0.8, 0.8, 0.7, 0.4},
    colorVariance = 0.1,
    fadeOut = true,
    gravity = -5,
    friction = 0.99,
    shape = "circle"
  },
  
  -- Torch flame particles
  flame = {
    emitRate = 0.03,
    particlesPerEmit = 2,
    spawnRadius = 4,
    speed = 40,
    speedVariance = 20,
    angle = -math.pi/2,  -- Upward
    angleVariance = math.pi/6,
    life = 0.5,
    lifeVariance = 0.2,
    size = 6,
    sizeVariance = 2,
    sizeDecay = 8,
    color = {1, 0.7, 0.2, 0.9},
    colorVariance = 0.2,
    fadeOut = true,
    gravity = -100,
    friction = 0.95,
    shape = "circle"
  },
  
  -- Player footstep trail
  footstep = {
    emitRate = 0.1,
    particlesPerEmit = 1,
    spawnRadius = 2,
    speed = 5,
    speedVariance = 3,
    angle = math.pi/2,  -- Downward
    angleVariance = math.pi/4,
    life = 0.8,
    lifeVariance = 0.2,
    size = 4,
    sizeVariance = 1,
    sizeDecay = 3,
    color = {0.5, 0.4, 0.3, 0.5},
    fadeOut = true,
    gravity = 0,
    friction = 0.9,
    shape = "circle"
  },
  
  -- Memory fragment glow
  fragmentGlow = {
    emitRate = 0.08,
    particlesPerEmit = 1,
    spawnRadius = 8,
    speed = 20,
    speedVariance = 15,
    angle = 0,
    angleVariance = math.pi,
    life = 1.2,
    lifeVariance = 0.4,
    size = 4,
    sizeVariance = 2,
    sizeDecay = 2,
    color = {0.9, 0.8, 0.3, 0.7},
    colorVariance = 0.15,
    fadeOut = true,
    gravity = -30,
    friction = 0.97,
    shape = "circle"
  },
  
  -- Sanity distortion particles
  sanity = {
    emitRate = 0.05,
    particlesPerEmit = 2,
    spawnRadius = 300,
    speed = 30,
    speedVariance = 20,
    angle = 0,
    angleVariance = math.pi,
    life = 1.5,
    lifeVariance = 0.5,
    size = 3,
    sizeVariance = 2,
    color = {0.8, 0.2, 0.6, 0.6},
    colorVariance = 0.2,
    fadeOut = true,
    gravity = 0,
    friction = 0.98,
    shape = "spark",
    rotationSpeed = 3,
    rotationSpeedVariance = 2
  },
  
  -- Collect burst (when picking up items)
  collectBurst = {
    speed = 80,
    speedVariance = 40,
    angle = 0,
    angleVariance = math.pi,
    life = 0.6,
    lifeVariance = 0.2,
    size = 5,
    sizeVariance = 2,
    sizeDecay = 6,
    color = {1, 0.9, 0.4, 1},
    fadeOut = true,
    gravity = 50,
    friction = 0.95,
    shape = "square",
    rotationSpeed = 5,
    rotationSpeedVariance = 3
  },
  
  -- Detection alert particles
  alert = {
    speed = 60,
    speedVariance = 30,
    angle = -math.pi/2,
    angleVariance = math.pi/3,
    life = 0.4,
    lifeVariance = 0.1,
    size = 4,
    sizeVariance = 2,
    color = {1, 0.3, 0.3, 0.9},
    fadeOut = true,
    gravity = -50,
    friction = 0.9,
    shape = "spark",
    rotationSpeed = 8
  },
  
  -- Lantern glow particles
  lantern = {
    emitRate = 0.1,
    particlesPerEmit = 1,
    spawnRadius = 6,
    speed = 15,
    speedVariance = 10,
    angle = -math.pi/2,
    angleVariance = math.pi/3,
    life = 0.8,
    lifeVariance = 0.3,
    size = 3,
    sizeVariance = 1,
    color = {1, 0.9, 0.5, 0.5},
    fadeOut = true,
    gravity = -20,
    friction = 0.95,
    shape = "circle"
  }
}

-- Export
Particles.Particle = Particle
Particles.Emitter = Emitter
Particles.ParticleSystem = ParticleSystem

return Particles
