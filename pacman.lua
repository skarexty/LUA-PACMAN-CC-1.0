-- pacman.lua for CC: Tweaked / ComputerCraft
-- Usage: place on a Computer, `pastebin get <id> pacman.lua` or copy-file, then run `lua pacman.lua`
-- Controls: Arrow keys to move (or WASD). Press Q to quit. 
-- Features: simple map, pellets, power-pellets, ghosts with basic AI, score and lives.

local term = term
local os = os
local math = math
local textutils = textutils

-- CONFIG
local TICK_DELAY = 0.12 -- seconds per game tick
local START_LIVES = 3
local POWER_DURATION = 30 -- ticks while ghosts are vulnerable

-- KEY MAP (ComputerCraft keys API key codes)
local keys = keys
local keymap = {
  [keys.left]  = {-1,0},
  [keys.right] = {1,0},
  [keys.up]    = {0,-1},
  [keys.down]  = {0,1},
  -- WASD fallback
  [string.byte('a')] = {-1,0},
  [string.byte('d')] = {1,0},
  [string.byte('w')] = {0,-1},
  [string.byte('s')] = {0,1}
}

-- MAP: use a small map for terminals ~ 28x16
local rawMap = {
  "############################",
  "#............##............#",
  "#.####.#####.##.#####.####.#",
  "#o#  #.#   #.##.#   #.#  #o#",
  "#.####.#####.##.#####.####.#",
  "#..........................#",
  "#.####.##.########.##.####.#",
  "#......##....##....##......#",
  "######.##### ## #####.######",
  "     #.##### ## #####.#     ",
  "     #.##          ##.#     ",
  "######.## ######## ##.######",
  "#............##............#",
  "#.####.#####.##.#####.####.#",
  "#o..#................#..o# #",
  "############################"
}

-- parse map
local width = #rawMap[1]
local height = #rawMap
local map = {}
for y=1,height do
  map[y] = {}
  for x=1,width do
    local ch = rawMap[y]:sub(x,x)
    map[y][x] = ch
  end
end

-- helper
local function inBounds(x,y)
  return x>=1 and x<=width and y>=1 and y<=height
end

local function isWalkable(ch)
  return ch ~= '#'
end

-- find free place for pacman
local function findEmpty()
  for y=1,height do
    for x=1,width do
      if map[y][x] == '.' or map[y][x] == ' ' or map[y][x] == 'o' then
        return x,y
      end
    end
  end
  return 2,2
end

-- Entities
local pac = {x=2,y=2,dx=1,dy=0,lives=START_LIVES,score=0}
local ghosts = {}

local function addGhost(x,y)
  table.insert(ghosts, {x=x,y=y,dx=0,dy=0,mode='chase',frightened=0})
end

-- place pacman and ghosts
pac.x, pac.y = findEmpty()
addGhost(15,8)
addGhost(16,8)
addGhost(15,9)
addGhost(16,9)

-- draw
local function draw()
  term.clear()
  term.setCursorPos(1,1)
  for y=1,height do
    for x=1,width do
      local ch = map[y][x]
      local drawch = ch
      if pac.x==x and pac.y==y then drawch = 'C' end
      for _,g in pairs(ghosts) do
        if g.x==x and g.y==y then
          if g.frightened>0 then drawch = 'g' else drawch = 'G' end
        end
      end
      io.write(drawch)
    end
    io.write('\n')
  end
  io.write('\nScore: '..pac.score.."  Lives: "..pac.lives.."  (Q quits)\n")
end

-- Movement check
local function canMove(x,y)
  if not inBounds(x,y) then return false end
  return isWalkable(map[y][x])
end

-- Eat pellet
local function tryEat(x,y)
  local ch = map[y][x]
  if ch == '.' then
    pac.score = pac.score + 10
    map[y][x] = ' '
  elseif ch == 'o' then
    pac.score = pac.score + 50
    map[y][x] = ' '
    for _,g in ipairs(ghosts) do
      g.frightened = POWER_DURATION
    end
  end
end

-- Simple ghost AI: random valid direction, prefer chase if not frightened
local function ghostStep(g)
  if g.frightened>0 then
    g.frightened = g.frightened - 1
  end
  local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
  local choices = {}
  for _,d in ipairs(dirs) do
    local nx,ny = g.x + d[1], g.y + d[2]
    if canMove(nx,ny) then
      table.insert(choices, d)
    end
  end
  if #choices == 0 then return end
  local function scoreDir(d)
    local nx,ny = g.x + d[1], g.y + d[2]
    local dist = math.abs(nx - pac.x) + math.abs(ny - pac.y)
    if g.frightened>0 then return dist end
    return -dist
  end
  table.sort(choices, function(a,b) return scoreDir(a) < scoreDir(b) end)
  if math.random() < 0.6 then
    local pick = choices[1]
    g.dx, g.dy = pick[1], pick[2]
  else
    local pick = choices[math.random(1,#choices)]
    g.dx, g.dy = pick[1], pick[2]
  end
  local nx,ny = g.x + g.dx, g.y + g.dy
  if canMove(nx,ny) then
    g.x, g.y = nx, ny
  end
end

-- check collisions
local function checkCollisions()
  for _,g in ipairs(ghosts) do
    if g.x == pac.x and g.y == pac.y then
      if g.frightened>0 then
        pac.score = pac.score + 200
        g.x, g.y = 15,8
        g.frightened = 0
      else
        pac.lives = pac.lives - 1
        pac.x, pac.y = findEmpty()
        pac.dx, pac.dy = 0,0
        for _,h in ipairs(ghosts) do h.x,h.y = 15,8 end
        os.sleep(1)
      end
    end
  end
end

-- count pellets
local function pelletsRemaining()
  local cnt=0
  for y=1,height do for x=1,width do if map[y][x]=='.' or map[y][x]=='o' then cnt=cnt+1 end end end
  return cnt
end

-- Input handling
local inputDir = {dx=0,dy=0}

local function handleKey(key)
  if key == keys.q or key == string.byte('q') then
    error('quit')
  end
  local d = keymap[key]
  if d then
    inputDir.dx, inputDir.dy = d[1], d[2]
  end
end

-- Main loop
math.randomseed(os.time())

local function gameLoop()
  while true do
    local t0 = os.clock()
    if inputDir.dx ~= 0 or inputDir.dy ~= 0 then
      local nx,ny = pac.x + inputDir.dx, pac.y + inputDir.dy
      if canMove(nx,ny) then
        pac.x, pac.y = nx, ny
        pac.dx, pac.dy = inputDir.dx, inputDir.dy
        tryEat(pac.x, pac.y)
      end
    end
    for _,g in ipairs(ghosts) do ghostStep(g) end
    checkCollisions()
    draw()
    if pelletsRemaining() == 0 then
      print('\nYou win! Score: '..pac.score)
      break
    end
    if pac.lives <= 0 then
      print('\nGame Over! Score: '..pac.score)
      break
    end
    local elapsed = os.clock() - t0
    local wait = TICK_DELAY - elapsed
    if wait < 0 then wait = 0 end
    local timer = os.startTimer(wait)
    while true do
      local e, p1 = os.pullEvent()
      if e == 'timer' and p1 == timer then break end
      if e == 'key' then handleKey(p1) end
    end
  end
end

-- entry
local ok, err = pcall(function() draw(); gameLoop() end)
if not ok then
  if tostring(err) ~= 'quit' then
    print('Fehler: '..tostring(err))
  end
end
print('Spiel beendet.')
