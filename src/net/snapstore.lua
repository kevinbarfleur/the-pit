-- src/net/snapstore.lua
-- STORE de snapshots (pilier #3) : persiste un pool local de builds figés et en SERT un comme adversaire,
-- filtré par (version, tier de progression). COLD-START résolu : si aucun snapshot ne matche, on retombe
-- sur une équipe IA (Encounters) -> il y a TOUJOURS un adversaire jouable. Aucun netcode temps réel.
--
-- IO (love.filesystem, repli MÉMOIRE en test) -> ce module N'EST PAS de la SIM (tenu hors src/combat).
-- Un « vrai » backend (serveur) remplacerait load/save/serve sans toucher au reste (même contrat).

local Snapshot = require("src.net.snapshot")

local Store = { pool = {}, file = "snapshots.txt", loaded = false }

local function canIO() return love and love.filesystem and love.filesystem.read and love.filesystem.write end

-- Charge le pool depuis le disque (une ligne = un snapshot encodé). Idempotent.
function Store.load()
  Store.pool = {}
  if canIO() then
    local ok, data = pcall(love.filesystem.read, Store.file)
    if ok and type(data) == "string" then
      for line in data:gmatch("[^\r\n]+") do
        local s = Snapshot.decode(line)
        if s then Store.pool[#Store.pool + 1] = s end
      end
    end
  end
  Store.loaded = true
end

-- Ajoute un snapshot au pool (+ append disque si IO). Le build du joueur devient un « ghost » servable.
function Store.save(snap)
  if not Store.loaded then Store.load() end
  Store.pool[#Store.pool + 1] = snap
  if canIO() then
    local ok, data = pcall(love.filesystem.read, Store.file)
    local existing = (ok and type(data) == "string") and data or ""
    pcall(love.filesystem.write, Store.file, existing .. Snapshot.encode(snap) .. "\n")
  end
end

-- Sert un snapshot pour (version, tier) : MÊME version + tier <= demandé (un adversaire de progression
-- <= la nôtre). rng (seedé) pioche parmi les candidats -> sélection rejouable. nil si aucun candidat.
function Store.serve(version, tier, rng)
  if not Store.loaded then Store.load() end
  local cand = {}
  for _, s in ipairs(Store.pool) do
    if tostring(s.version) == tostring(version) and (s.tier or 0) <= tier then cand[#cand + 1] = s end
  end
  if #cand == 0 then return nil end
  return cand[rng and rng:random(1, #cand) or #cand]
end

-- COLD-START : un adversaire jouable GARANTI. Renvoie (compo côté `side`, meta) : un snapshot servi si
-- dispo, sinon la compo IA fournie par l'appelant (Encounter seedé). C'est le takeaway architectural #1.
function Store.serveComp(version, tier, side, rng, aiComp)
  local snap = Store.serve(version, tier, rng)
  if snap then return Snapshot.toComp(snap, side), { source = "snapshot", tier = snap.tier } end
  return aiComp, { source = "ai_seed" }
end

function Store.count() if not Store.loaded then Store.load() end return #Store.pool end

function Store.wipe()
  Store.pool = {}; Store.loaded = true
  if canIO() then pcall(love.filesystem.write, Store.file, "") end
end

return Store
