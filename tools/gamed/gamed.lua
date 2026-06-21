-- tools/gamed/gamed.lua
-- DAEMON DE JEU headless (Pilier C) : un REPL ligne->JSON qui expose l'API d'actions du rundriver à un
-- processus parent (le serveur MCP Python). UNE instance = UNE session de partie (isolation process,
-- parallélisme trivial pour les swarms d'agents).
--
-- PROTOCOLE : l'ENTRÉE est une ligne « commande arg1 arg2 » (parse trivial, pas de JSON à décoder) ;
-- la RÉPONSE est une ligne JSON. Chaque action renvoie aussi l'état mis à jour (peu de round-trips).
-- ⚠️ RENDER-tainted (charge le rundriver -> Build). Tourne sous luajit + tests/mock_love (comme sim.lua).
--   Lancement : luajit tools/gamed/gamed.lua   (puis lignes de commande sur stdin)

package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Rundriver = require("src.lab.rundriver")
local Policies = require("src.lab.policies")
local Units = require("src.data.units")
local json = require("tools.gamed.json")

local drv = nil

local function reply(t) io.write(json.encode(t)); io.write("\n"); io.flush() end
local function st() return drv and drv:state() or nil end

-- Fiche MÉCANIQUE d'une unité (l'agent raisonne sur les chiffres, pas sur les libellés i18n).
local function unitInfo(id)
  local u = Units[id]
  if not u then return { error = "unknown_unit", id = id } end
  local ops = {}
  for _, e in ipairs(u.effects or {}) do ops[#ops + 1] = e.op end
  return {
    id = id, type = u.type, archetype = Policies.archetypeOf(id), cost = u.cost or 3,
    hp = u.hp, dmg = u.dmg, cd = u.cd, aggro = u.aggro or 0, taunt = u.taunt and true or false,
    effects = ops,
  }
end

local handlers = {}

function handlers.new(a)
  local opts = {}
  if a[2] then opts.sigil = a[2] end
  if a[3] then opts.relicsKnown = (a[3] == "1" or a[3] == "true") end
  drv = Rundriver.new(tonumber(a[1]) or 0, opts)
  return drv:state()
end

function handlers.state() return st() or { error = "no_game" } end

function handlers.buy(a)
  if not drv then return { error = "no_game" } end
  local r = drv:buy(tonumber(a[1]), a[2] and tonumber(a[2]) or nil)
  return { ok = r and true or false, bought = (type(r) == "string") and r or nil, state = st() }
end

function handlers.sell(a)
  if not drv then return { error = "no_game" } end
  return { ok = drv:sell(tonumber(a[1])) and true or false, state = st() }
end

function handlers.reroll()
  if not drv then return { error = "no_game" } end
  return { ok = drv:reroll() and true or false, state = st() }
end

-- Grant d'emplacement timé (remplace l'ancien `level`). accept_grant [cell] : +1 slot, ouvert sur la case
-- `cell` (ou la meilleure case centrale par défaut) ; decline_grant : refuse pour de l'or (jeu « tall »).
function handlers.accept_grant(a)
  if not drv then return { error = "no_game" } end
  local cell = a[1] and tonumber(a[1]) or nil
  return { ok = drv:acceptSlotGrant(cell) and true or false, state = st() }
end

function handlers.decline_grant()
  if not drv then return { error = "no_game" } end
  return { ok = drv:declineSlotGrant() and true or false, state = st() }
end

function handlers.move(a)
  if not drv then return { error = "no_game" } end
  return { ok = drv:move(tonumber(a[1]), tonumber(a[2])) and true or false, state = st() }
end

function handlers.reshape(a)
  if not drv then return { error = "no_game" } end
  return { ok = drv:reshape(a[1]) and true or false, state = st() }
end

function handlers.fight()
  if not drv then return { error = "no_game" } end
  local fr = drv:fight()
  fr.state = st()
  return fr
end

function handlers.pickrelic(a)
  if not drv then return { error = "no_game" } end
  local id = drv:pickRelic(tonumber(a[1]))
  return { picked = id or false, state = st() }
end

function handlers.describe(a) return unitInfo(a[1]) end

function handlers.pool()
  local out = {}
  for _, id in ipairs(Units.pool or Units.order) do out[#out + 1] = unitInfo(id) end
  return { units = out }
end

function handlers.ping() return { ok = true, daemon = "the-pit/gamed" } end

-- ── Boucle : lit stdin ligne par ligne (bloquant), dispatch, répond en JSON. EOF/quit -> sortie. ──
for line in io.lines() do
  local parts = {}
  for w in line:gmatch("%S+") do parts[#parts + 1] = w end
  local cmd = parts[1]
  if cmd == "quit" or cmd == "exit" then break end
  if cmd then
    table.remove(parts, 1)
    local h = handlers[cmd]
    if h then
      local ok, res = pcall(h, parts)
      reply(ok and res or { error = "exception", detail = tostring(res), cmd = cmd })
    else
      reply({ error = "unknown_command", cmd = cmd })
    end
  end
end
