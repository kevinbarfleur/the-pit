-- src/core/grimoire.lua
-- Le GRIMOIRE : codex PERSISTANT cross-run (méta-progression « la connaissance »). Enregistre les
-- reliques IDENTIFIÉES au niveau COMPTE (pas par run) : une fois qu'on a déduit le vrai effet d'une
-- relique cryptique, il devient lore lisible de façon PERMANENTE (pilier #2, anti-brute-force façon
-- Obra Dinn). cf. CLAUDE.md §2.
--
-- Persistance via love.filesystem (vérifié, LÖVE 11.5 : read/write dans le dossier de sauvegarde) si
-- disponible ; sinon repli MÉMOIRE (tests headless / mock). Dégrade gracieusement (pcall) — jamais de
-- crash si l'IO échoue. Ce module N'EST PAS de la SIM (il fait de l'IO) : tenu hors de src/combat.

local Grimoire = { known = {}, file = "grimoire.txt", loaded = false }

local function canIO()
  return love and love.filesystem and love.filesystem.read and love.filesystem.write
end

-- Charge le codex depuis le disque (une ligne = un id de relique connue). Idempotent.
function Grimoire.load()
  Grimoire.known = {}
  if canIO() then
    local ok, data = pcall(love.filesystem.read, Grimoire.file)
    if ok and type(data) == "string" then
      for id in data:gmatch("[^\r\n]+") do Grimoire.known[id] = true end
    end
  end
  Grimoire.loaded = true
end

-- Écrit le codex (ids triés -> fichier déterministe/diff-able). Silencieux si pas d'IO.
function Grimoire.save()
  if not canIO() then return end
  local lines = {}
  for id in pairs(Grimoire.known) do lines[#lines + 1] = id end
  table.sort(lines)
  pcall(love.filesystem.write, Grimoire.file, table.concat(lines, "\n"))
end

function Grimoire.isKnown(id)
  if not Grimoire.loaded then Grimoire.load() end
  return Grimoire.known[id] == true
end

-- Apprend une relique (l'inscrit au Grimoire + persiste). Renvoie true si NOUVELLEMENT apprise.
function Grimoire.learn(id)
  if not Grimoire.loaded then Grimoire.load() end
  if not Grimoire.known[id] then
    Grimoire.known[id] = true
    Grimoire.save()
    return true
  end
  return false
end

function Grimoire.count()
  if not Grimoire.loaded then Grimoire.load() end
  local n = 0
  for _ in pairs(Grimoire.known) do n = n + 1 end
  return n
end

-- Réinitialise (tests) : vide la mémoire ET le disque.
function Grimoire.wipe()
  Grimoire.known = {}
  Grimoire.loaded = true
  if canIO() then pcall(love.filesystem.write, Grimoire.file, "") end
end

return Grimoire
