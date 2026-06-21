-- src/core/bestiary.lua
-- BESTIAIRE : codex PERSISTANT des créatures RENCONTRÉES (vues en boutique / au combat). Miroir exact de
-- grimoire.lua mais pour les unités (méta-progression cross-run « la connaissance »). Le MODE DEV full-unlock
-- révèle tout au read-time (isSeen -> true) sans toucher le disque. IO hors SIM (love.filesystem, pcall,
-- dégrade gracieusement) -> tenu hors de src/combat. cf. [[the-pit-relics]], src/core/grimoire.lua.

local Dev = require("src.core.dev")

local Bestiary = { seen = {}, file = "bestiary.txt", loaded = false }

local function canIO()
  return love and love.filesystem and love.filesystem.read and love.filesystem.write
end

function Bestiary.load()
  Bestiary.seen = {}
  if canIO() then
    local ok, data = pcall(love.filesystem.read, Bestiary.file)
    if ok and type(data) == "string" then
      for id in data:gmatch("[^\r\n]+") do Bestiary.seen[id] = true end
    end
  end
  Bestiary.loaded = true
end

function Bestiary.save()
  if not canIO() then return end
  local lines = {}
  for id in pairs(Bestiary.seen) do lines[#lines + 1] = id end
  table.sort(lines) -- fichier déterministe / diff-able
  pcall(love.filesystem.write, Bestiary.file, table.concat(lines, "\n"))
end

function Bestiary.isSeen(id)
  if Dev.fullUnlock() then return true end -- MODE DEV : tout révélé (read-time ; ne pollue pas Bestiary.seen)
  if not Bestiary.loaded then Bestiary.load() end
  return Bestiary.seen[id] == true
end

-- Marque une créature comme rencontrée (+ persiste). Renvoie true si NOUVELLEMENT vue (-> 1 seule écriture).
function Bestiary.mark(id)
  if not id then return false end
  if not Bestiary.loaded then Bestiary.load() end
  if not Bestiary.seen[id] then
    Bestiary.seen[id] = true
    Bestiary.save()
    return true
  end
  return false
end

function Bestiary.count()
  if not Bestiary.loaded then Bestiary.load() end
  local n = 0
  for _ in pairs(Bestiary.seen) do n = n + 1 end
  return n
end

function Bestiary.wipe()
  Bestiary.seen = {}
  Bestiary.loaded = true
  if canIO() then pcall(love.filesystem.write, Bestiary.file, "") end
end

return Bestiary
