-- src/render/chronicle.lua
-- LA CHRONIQUE — modèle du journal de combat (couche RENDER). On ÉCOUTE le bus SIM (lecture seule,
-- comme arena_draw) ; on ne modifie JAMAIS la sim -> golden-safe. On construit une liste d'ENTRÉES
-- lisibles, ordonnée par tick.
--
-- Principe clé (afflictions) : un TICK de DoT n'est PAS une entrée. Une affliction = une "ligne
-- VIVANTE" (1 instance par source+cible+famille) ouverte à la pose ; les ticks de DoT (events
-- `damage` de cause = famille) ALIMENTENT son total cumulé, ils ne créent jamais de ligne. Cf.
-- docs/research/combat-chronicle-spec.md §4.6.
--
-- Le modèle ne connaît PAS les couleurs (pas de love.*) : `segments()` renvoie des fragments porteurs
-- d'un rôle + d'une équipe ; le RENDU (P1c) mappe équipe -> couleur (or = joueur "left", sang = "right").

local T = require("src.core.i18n").t

local Chronicle = {}
Chronicle.__index = Chronicle

-- Familles qui TICKENT dans le temps (leurs events `damage` s'agrègent dans la ligne vivante).
-- Le CHOC en est exclu : il ne tick pas, il se DÉCHARGE en un coup (cause="shock" = entrée "strike").
local DOT_TICK = { poison = true, burn = true, bleed = true, rot = true }

-- Causes de `damage` qui sont des COUPS discrets (≠ ticks de DoT) -> entrée "strike".
local STRIKE_CAUSE = { attack = true, shock = true, thorns = true, reflect = true }

local function teamOf(u) return u and u.team end
local function idOf(u) return u and u.id end

function Chronicle.new(arena)
  local self = setmetatable({
    arena = arena,
    entries = {}, -- liste ORDONNÉE (par tick d'insertion) : { tick, kind, actor*, target*, family, ... }
    live = {},    -- instances vivantes d'affliction : clé(source,cible,famille) -> entrée (agrégation)
    _lastStrike = nil, -- dernier COUP inséré { source, tick } : sert à TAGGER sa conséquence immédiate (indentation causale)
  }, Chronicle)
  if arena and arena.bus then self:_subscribe(arena.bus) end
  return self
end

-- Modèle DÉTACHÉ : relit une chronique ARCHIVÉE (entries sérialisées d'un round passé) avec les mêmes
-- méthodes de lecture (segments/value/timeStr/visible), SANS abonnement au bus. Sert au sélecteur de round.
function Chronicle.fromEntries(entries)
  return setmetatable({ entries = entries or {}, live = {} }, Chronicle)
end

function Chronicle:_key(source, target, family)
  return tostring(source) .. "#" .. tostring(target) .. "#" .. family
end

function Chronicle:_add(e)
  e.tick = self.arena.t or 0
  self.entries[#self.entries + 1] = e
  e._idx = #self.entries -- rang d'insertion (sert à choisir la cause d'affliction la plus récente à la mort)
  return e
end

-- 1A — heuristique d'indentation causale : vrai si le DERNIER coup inséré vient de `source` AU MÊME tick
-- que l'instant courant (arena.t). Une affliction/propagation posée juste après un coup du même acteur,
-- au même tick, EST la conséquence de ce coup (le coup applique le DoT) -> on l'indente sous sa cause.
function Chronicle:_causedBy(source)
  local ls = self._lastStrike
  return (ls and source and ls.source == source and ls.tick == (self.arena.t or 0)) or nil
end

function Chronicle:_subscribe(bus)
  -- POSE d'affliction : ouvre (ou rafraîchit) une ligne vivante. Une réapplication ne crée PAS de ligne.
  bus:on("affliction_applied", function(e)
    local key = self:_key(e.source, e.target, e.family)
    local inst = self.live[key]
    if inst and inst.open then
      inst.dps, inst.dur, inst.stacks = e.dps, e.dur, e.stacks -- refresh silencieux
      inst.refreshed = (inst.refreshed or 0) + 1
    else
      inst = self:_add({
        kind = "affliction", family = e.family,
        actorId = idOf(e.source), actorTeam = teamOf(e.source),
        targetId = idOf(e.target), targetTeam = teamOf(e.target),
        dps = e.dps, dur = e.dur, stacks = e.stacks, total = 0, open = true,
        caused = self:_causedBy(e.source), -- indentée si elle suit un coup du même acteur au même tick (1A)
      })
      self.live[key] = inst
    end
  end)

  -- DÉGÂT : soit un TICK de DoT (s'agrège dans la ligne vivante), soit un COUP discret (entrée "strike").
  bus:on("damage", function(r)
    local cause = r.cause or "attack"
    local amount = r.hp or r.raw or 0
    if DOT_TICK[cause] and r.source then
      local inst = self.live[self:_key(r.source, r.target, cause)]
      if inst then inst.total = inst.total + amount end -- agrège ; pas de nouvelle entrée
    elseif STRIKE_CAUSE[cause] then
      self:_add({
        kind = "strike", cause = cause,
        actorId = idOf(r.source), actorTeam = teamOf(r.source),
        targetId = idOf(r.target), targetTeam = teamOf(r.target),
        amount = amount, absorbed = r.absorbed,
      })
      -- mémorise ce coup (source + tick) -> une affliction/propagation du MÊME acteur, AU MÊME tick, juste
      -- après, est sa CONSÉQUENCE directe (le coup applique le DoT) -> on l'indentera sous sa cause (1A).
      self._lastStrike = { source = r.source, tick = self.arena.t or 0 }
    end
  end)

  -- PROPAGATION / contagion : l'affliction saute à un voisin.
  bus:on("spread", function(e)
    self:_add({
      kind = "spread", family = e.family,
      actorId = idOf(e.from), actorTeam = teamOf(e.from),
      targetId = idOf(e.to), targetTeam = teamOf(e.to),
      amount = e.magnitude,
      caused = self:_causedBy(e.from), -- propagation déclenchée par un coup du même acteur au même tick (1A)
    })
  end)

  -- BOUCLIER (cast périodique) -> catégorie "soins/boucliers".
  bus:on("shield_cast", function(e)
    self:_add({
      kind = "shield",
      actorId = idOf(e.caster), actorTeam = teamOf(e.caster),
      amount = e.value,
    })
  end)

  -- MORT : entrée + on FERME les lignes vivantes d'affliction sur le défunt (elles ne tickeront plus). On
  -- repère AUSSI la dernière affliction encore active (la plus « avancée » dans entries) comme cause probable
  -- -> suffixe « par <icône famille> » sur le bloc MORT (lecture du POURQUOI au coup d'œil).
  bus:on("death", function(u)
    local entry = self:_add({ kind = "death", targetId = idOf(u), targetTeam = teamOf(u), actorTeam = teamOf(u) })
    local bestIdx, causeFamily = -1, nil
    for _, inst in pairs(self.live) do -- RENDER : pairs toléré (on ne modifie qu'un flag, l'ordre des entrées ne change pas)
      if inst.targetId == idOf(u) and inst.targetTeam == teamOf(u) then
        inst.open = false; inst.killed = true
        if (inst._idx or 0) > bestIdx then bestIdx = inst._idx or 0; causeFamily = inst.family end
      end
    end
    entry.causeFamily = causeFamily -- nil si la mort vient d'un coup (pas d'icône de cause)
  end)
end

-- Temps lisible : ticks -> secondes (60 ticks/s, cf. love.run TICK=1/60).
function Chronicle:timeStr(e) return string.format("%.1fs", (e.tick or 0) / 60) end

-- Fragments de texte porteurs d'un RÔLE et d'une ÉQUIPE (le rendu mappe équipe -> couleur). Le modèle
-- reste sans couleur (pas de dépendance love/Theme) -> testable en headless.
function Chronicle:segments(e)
  local function nm(id) return id and T("unit." .. id .. ".name") or "?" end
  local s = {}
  local function push(text, team, role) s[#s + 1] = { text = text, team = team, role = role } end
  if e.kind == "strike" then
    local verb = (e.cause == "shock" and "chronicle.v.discharge")
      or (e.cause == "thorns" and "chronicle.v.thorns")
      or (e.cause == "reflect" and "chronicle.v.reflect")
      or "chronicle.v.strike"
    push(nm(e.actorId), e.actorTeam, "actor")
    push(" " .. T(verb) .. " ", nil, "op")
    push(nm(e.targetId), e.targetTeam, "target")
  elseif e.kind == "affliction" then
    push(nm(e.actorId), e.actorTeam, "actor")
    push(" " .. T("chronicle.v.afflict") .. " ", nil, "op")
    push(nm(e.targetId), e.targetTeam, "target")
    push(" " .. T("kw." .. e.family .. ".name"), nil, "family")
  elseif e.kind == "spread" then
    push(nm(e.actorId), e.actorTeam, "actor")
    push(" " .. T("chronicle.v.spread") .. " ", nil, "op")
    push(nm(e.targetId), e.targetTeam, "target")
    push(" " .. T("kw." .. e.family .. ".name"), nil, "family")
  elseif e.kind == "shield" then
    push(nm(e.actorId), e.actorTeam, "actor")
    push(" " .. T("chronicle.v.shield"), nil, "op")
  elseif e.kind == "death" then
    push(nm(e.targetId), e.targetTeam, "target")
    push(" " .. T("chronicle.v.fall"), nil, "op")
  end
  return s
end

-- Valeur affichée à droite (montant / DPS / charge). Le total cumulé d'une affliction vit dans `e.total`.
function Chronicle:value(e)
  if e.kind == "strike" or e.kind == "spread" or e.kind == "shield" then
    return e.amount and tostring(e.amount) or nil
  elseif e.kind == "affliction" then
    if e.dps and e.dps > 0 then return e.dps .. "/s" end
    if e.stacks then return "x" .. e.stacks end
  end
  return nil
end

-- Liste filtrée pour l'affichage. `kinds` = set de catégories visibles (nil = tout) ; `team` = "left" |
-- "right" | nil (tout) appliqué à l'ACTEUR de l'entrée (qui a initié l'action).
function Chronicle:visible(kinds, team)
  local out = {}
  for _, e in ipairs(self.entries) do
    local okKind = (not kinds) or kinds[e.kind]
    local okTeam = (not team) or (e.actorTeam == team)
    if okKind and okTeam then out[#out + 1] = e end
  end
  return out
end

return Chronicle
