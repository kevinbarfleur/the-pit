-- src/scenes/combat.lua
-- Phase de COMBAT : on rejoue automatiquement la bataille entre l'équipe du joueur (gauche,
-- construite dans la phase build) et une équipe adverse (droite, IA de seed). Spectateur :
-- aucune entrée pendant le combat. À la fin -> bandeau VICTOIRE/DEFAITE puis retour au build.
--
-- Sépare SIM et RENDER : `arena` (src/combat) résout la bataille (déterministe, seedée) et émet
-- des événements ; `renderer` (src/render) les consomme pour l'animation. La scène orchestre.
--
-- ── UI = kit PROPRE (.dc.html / design-system), aligné sur src/scenes/build.lua ──────────────────────
-- La scène n'utilise plus Forge (kit legacy) : la chrome (titre/hint/« vs »), le verdict (Banner) et les
-- boutons de fin (Button : CHRONICLE secondary / CONTINUE primary+yeux) viennent du kit propre. Le JUICE
-- (survol/press) passe par Feel (RENDER pur, headless-safe). Le texte est en rôles de police Theme via Draw
-- (Cinzel gravé pour titres/noms, Space Mono pour valeurs/hints, Spectral pour la prose) -> net à toute réso.
--
-- Interface scène : update / drawWorld / drawBack / drawOverlay(view) / keypressed / mousepressed / mousemoved.

local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local Chronicle = require("src.render.chronicle")
local Bus = require("src.core.bus")
local Ambient = require("src.fx.ambient")
local Biome = require("src.fx.biome")    -- décor de biome parallaxe (refonte Combat Frame, phase 4) — EN PAUSE
local NightmareBG = require("src.fx.nightmare_bg") -- fond cauchemardesque shader (remplace le biome, retour user)

-- Bascule de fond de combat : le BIOME parallaxe est mis EN PAUSE (retour user « pas satisfait ») au profit
-- d'un FOND UNI sombre + shader cauchemardesque (distorsion onirique / double vision / yeux). Remettre à true
-- pour réactiver le biome (le code est conservé intact des deux côtés).
local USE_BIOME = false
local Theme = require("src.ui.theme")
local Draw = require("src.ui.draw")
local Button = require("src.ui.button")  -- boutons propres (CHRONICLE secondary / CONTINUE primary)
local Feel = require("src.ui.feel")      -- JUICE : survol (glow/lift) + press (squash/flash)
local Panel = require("src.ui.panel")    -- surfaces propres (résumé post-combat : ruban, cartes)
local Overlay = require("src.ui.overlay") -- CHORÉGRAPHIE d'entrée unifiée (voile qui monte + groupe en back-ease)
local Units = require("src.data.units")  -- type d'unité (pip de portrait) + noms
local UnitResolver = require("src.core.unit_resolver")
local MiniRig = require("src.render.minirig") -- frimousse de créature (portraits MVP / 1re perte du résumé)
local Keywords = require("src.ui.keywords") -- icônes/couleurs d'afflictions dans le bilan par monstre
local MonsterCard = require("src.render.monstercard")
local CardGlossary = require("src.ui.card_glossary")
local InfluencePanel = require("src.ui.influence_panel")
local Run = require("src.run.state")     -- WIN_TARGET (descente) pour le ruban de stats
local Pacing = require("src.run.pacing") -- pacing live centralise (hp/cooldown/fatigue + affichage CD)
local SFX = require("src.audio.sfx")     -- SON (Oniric grave) : verdict VICTOIRE/DEFAITE — RENDER pur, no-op headless
local T = require("src.core.i18n").t

local Combat = {}
Combat.__index = Combat

-- Post-mortem "pourquoi" (1.3) : ordre FIXE des causes de mort = tie-break déterministe pour la
-- cause dominante (jamais `pairs`). Les afflictions priment sur la frappe à égalité (thème + clarté).
local CAUSE_ORDER = { "poison", "rot", "bleed", "burn", "shock", "reflect", "attack" }

-- Boutons de fin (espace DESIGN) : CHRONICLE (secondary) + CONTINUE (primary, CTA). Largeurs/hauteurs propres.
local BTN_W, BTN_H, BTN_GAP = 176, 44, 18

-- Hit-test d'un rect (espace design). Tolère un curseur hors-écran (mx<0) et un rect absent.
local function inBtn(mx, my, r)
  return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end

local function ctrlHeld()
  return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lctrl", "rctrl")
end

-- Choix de BIOME déterministe par combat : le seed du combat -> une clé stable parmi les 4 décors (replays
-- identiques, snapshot async cohérent). v1 = rotation seedée ; mapping THÉMATIQUE (par type d'adversaire
-- dominant) à venir. Robuste si Biome.KEYS manque.
local function biomeFor(payload)
  local keys = Biome.KEYS or { "abysses" }
  return keys[1 + ((payload.seed or 11) % #keys)]
end

local function unitName(id) return (Units[id] and T("unit." .. id .. ".name")) or id end

local function arenaOptions(payload)
  local p = payload or {}
  local opts = Pacing.arenaOptions(p.pacingProfile)
  opts.left = p.left
  opts.right = p.right
  opts.autoReset = false
  opts.seed = p.seed
  return opts
end

function Combat.new(palette, vw, vh, host, payload)
  payload = payload or {}
  local opts = arenaOptions(payload)
  local earlyMurmurs = {}
  local earlyBus = Bus.new()
  local earlyFn = earlyBus:on("murmur", function(e) earlyMurmurs[#earlyMurmurs + 1] = e end)
  opts.bus = earlyBus
  local arena = Arena.new(opts)
  earlyBus:off("murmur", earlyFn)
  local self = setmetatable({
    vw = vw, vh = vh, t = 0, host = host, palette = palette, payload = payload,
    daChrome = true, -- chrome DA portée par la scène (pas de HUD générique : cf. main.lua drawHud)
    nativeWorld = true, -- arène rendue en RÉSOLUTION NATIVE (sprites primgen 64px nets, pas via le canvas 320)
    titleKey = "scene.combat",
    hintKey = "ui.hint_combat",
    enemyKey = payload.enemyKey,
    pacingId = Pacing.id(payload.pacingProfile),
    ambient = Ambient.new(payload.seed or 11), -- atmosphère "combat" (repli ultime)
    biome = USE_BIOME and Biome.new(biomeFor(payload), payload.seed or 11) or nil, -- décor de biome (EN PAUSE)
    nightmareBg = (not USE_BIOME) and NightmareBG.new(payload.seed or 11) or nil, -- fond cauchemardesque shader
    arena = arena,
    renderer = ArenaDraw.new(arena, palette),
    paused = false, -- PAUSE spectateur (Espace) : gèle entièrement le combat (analyse / screenshots)
    speed = 1, skipping = false, -- VITESSE spectateur (refonte Combat Frame) : 1×/2× ; SKIP = avance jusqu'à la fin
    mx = -1, my = -1, -- curseur (espace design) : survol des boutons de fin + gaze des yeux du CTA
  }, Combat)
  self:_track() -- écoute le bus SIM (lecture seule) pour le post-mortem "pourquoi" (1.3)
  for _, e in ipairs(earlyMurmurs) do self:_recordMurmur(e) end
  return self
end

function Combat:restart()
  -- Même seed -> bataille rejouée À L'IDENTIQUE (c'est déjà un replay déterministe).
  self.arena = Arena.new(arenaOptions(self.payload))
  self.renderer = ArenaDraw.new(self.arena, self.palette)
  self._verdictPlayed = nil -- SON : un REPLAY rejoue son verdict (le bilan se ré-affiche)
  self._sumAnim = nil       -- ENTRÉE : un REPLAY rejoue la chorégraphie d'apparition du bilan
  self:_track()
end

function Combat:_recordMurmur(e)
  if not (e and e.source and e.key) then return end
  local rows = self.murmursByUnit and self.murmursByUnit[e.source]
  if not rows then
    rows = {}
    self.murmursByUnit = self.murmursByUnit or {}
    self.murmursByUnit[e.source] = rows
  end
  local x = unitName(e.source.id)
  local y = e.partner and unitName(e.partner.id) or ""
  rows[#rows + 1] = {
    key = e.key,
    text = T("whisper." .. e.key .. ".cryptic", { x = x, y = y }),
    tick = self.arena and self.arena.t or 0,
  }
end

-- 1.3 — Attribution causale : on ÉCOUTE le bus SIM (lecture seule, comme le renderer ; aucun effet sur
-- la sim -> golden inchangé). "damage" mémorise le dernier coup reçu par chaque unité ; "death" fige
-- l'attribution (qui a fauché qui, par quelle cause, à quel tick).
function Combat:_track()
  self.killLog = {} -- ordre de tick : { victim, killer, cause, tick }
  self.lastHit = {} -- [victime] = { source, cause } : dernier coup encaissé
  self.murmursByUnit = {} -- [unit] = lignes cryptiques deja declenchees (cachees partout ailleurs)
  self.summary = nil -- résumé "pourquoi", mémoïsé en fin de combat
  self.full = nil    -- résumé COMPLET (écran post-combat), mémoïsé en fin de combat
  -- Stats agrégées pour le résumé post-combat (refonte « Combat Screen » Frame 4). RENDER pur (lecture du
  -- bus, comme le reste de _track -> golden-safe). amt = PV RÉELLEMENT perdus (`r.hp`).
  self.dmgByCause = {}   -- [cause] = dégâts infligés par TON équipe (source.team == left)
  self.dealtByUnit = {}  -- [unité] = dégâts infligés (-> MVP)
  self.soakedByUnit = {} -- [unité] = dégâts encaissés par tes unités (-> MVP tank)
  self.unitDealt = {}    -- [unité] = dégâts infligés, deux équipes
  self.unitTaken = {}    -- [unité] = dégâts encaissés, deux équipes
  self.unitKills = {}    -- [unité] = kills confirmés, deux équipes
  self.unitAfflictions = {} -- [unité][family] = poses/propagations d'affliction
  self.unitDeathTime = {} -- [unité] = seconde de mort
  self.dealtTotal, self.takenTotal = 0, 0
  local function bump(map, unit, amount)
    if unit and amount and amount > 0 then map[unit] = (map[unit] or 0) + amount end
  end
  local function bumpAff(unit, family)
    if not (unit and family) then return end
    local t = self.unitAfflictions[unit]
    if not t then t = {}; self.unitAfflictions[unit] = t end
    t[family] = (t[family] or 0) + 1
  end
  local arena = self.arena
  arena.bus:on("damage", function(r)
    if r.target then self.lastHit[r.target] = { source = r.source, cause = r.cause or "attack" } end
    local amt = r.hp or 0
    if amt > 0 then
      local src, tgt, cause = r.source, r.target, r.cause or "attack"
      bump(self.unitDealt, src, amt)
      bump(self.unitTaken, tgt, amt)
      if src and src.team == "left" then
        self.dmgByCause[cause] = (self.dmgByCause[cause] or 0) + amt
        self.dealtByUnit[src] = (self.dealtByUnit[src] or 0) + amt
        self.dealtTotal = self.dealtTotal + amt
      end
      if tgt and tgt.team == "left" then
        self.soakedByUnit[tgt] = (self.soakedByUnit[tgt] or 0) + amt
        self.takenTotal = self.takenTotal + amt
      end
    end
  end)
  arena.bus:on("affliction_applied", function(e) bumpAff(e.source, e.family) end)
  arena.bus:on("spread", function(e) bumpAff(e.from, e.family) end)
  arena.bus:on("murmur", function(e) self:_recordMurmur(e) end)
  arena.bus:on("death", function(u)
    local h = self.lastHit[u]
    self.unitDeathTime[u] = (arena.t or 0) / 60
    if h and h.source then self.unitKills[h.source] = (self.unitKills[h.source] or 0) + 1 end
    self.killLog[#self.killLog + 1] =
      { victim = u, killer = h and h.source, cause = (h and h.cause) or "attack", tick = arena.t }
  end)
  self.chron = Chronicle.new(arena) -- modèle du JOURNAL — écoute le bus (golden-safe) ; affiché par l'overlay [c]
end

-- Résumé du combat (mémoïsé) : cause DOMINANTE + PREMIÈRE perte du joueur. En victoire on lit ce que
-- TON équipe a infligé (morts ennemies "right"), en défaite ce qui T'a fauché (morts joueur "left").
function Combat:_computeSummary()
  local foe = self.arena.win and "right" or "left"
  local count, firstLoss = {}, nil
  for _, k in ipairs(self.killLog) do
    if k.victim.team == foe then count[k.cause] = (count[k.cause] or 0) + 1 end
    if k.victim.team == "left" and not firstLoss then firstLoss = k.victim end
  end
  local topCause, topN = nil, 0
  for _, cause in ipairs(CAUSE_ORDER) do -- ordre fixe = tie-break déterministe
    if (count[cause] or 0) > topN then topCause, topN = cause, count[cause] end
  end
  return { win = self.arena.win, cause = topCause, n = topN, firstLoss = firstLoss }
end

-- Un PAS de simulation+rendu (frameDt fixe). Le déroulé reste DÉTERMINISTE (arena.t incrémenté de frameDt) :
-- 2× = 2 pas/frame, SKIP = beaucoup de pas/frame -> même bataille, juste rejouée plus vite (spectateur).
function Combat:_step(frameDt)
  self.t = self.t + frameDt
  self.ambient:update(frameDt)
  self.arena:update(frameDt, self.t) -- SIM (émet des événements)
  self.renderer:update(frameDt, self.t) -- RENDER (consomme + anime)
end

function Combat:update(frameDt)
  Feel.update(frameDt) -- JUICE (remplace Forge.uiTick) : avance survol/press des boutons de fin (RENDER pur)
  Feel.hover("combat.spd1", inBtn(self.mx, self.my, self._btnSpd1))
  Feel.hover("combat.spd2", inBtn(self.mx, self.my, self._btnSpd2))
  Feel.hover("combat.skip", inBtn(self.mx, self.my, self._btnSkip))
  Feel.hover("combat.pause", inBtn(self.mx, self.my, self._btnPause))
  if self.paused then return end -- combat GELÉ (sim + anims) -> reprise identique via Espace
  -- Fond animé : avancé UNE FOIS/frame (temps réel), JAMAIS multiplié par les pas de SKIP/2× (le décor ne doit
  -- pas s'accélérer). frameDt en unités-frame@60 -> /60 = secondes. Biome (en pause) OU fond cauchemardesque.
  if self.biome then self.biome:update(frameDt / 60) end
  if self.nightmareBg then self.nightmareBg:update(frameDt / 60) end
  -- VITESSE : hors conclusion, 1×/2× pas par frame (SKIP -> beaucoup, borné anti-gel). Une fois CONCLU, on
  -- continue à avancer UN pas/frame (overAge + anims de mort -> l'écran de fin apparaît, comportement d'avant).
  local steps = self.arena.over and 1 or (self.skipping and 240 or (self.speed or 1))
  for _ = 1, steps do
    self:_step(frameDt)
    if self.arena.over then break end
  end
  -- SON (RENDER pur) : accents de famille + coup lourd + mort, agrégés à 1/frame par le renderer. Hors du loop
  -- -> jamais multiplié par SKIP/2×. No-op headless ; ne touche pas la SIM.
  self.renderer:flushAudio()
  if self.arena.over then self.skipping = false end
  if self.arena.over then
    self.hintKey = "ui.hint_combat_end"
    -- ENTRÉE CHORÉGRAPHIÉE du bilan (cohérence avec les autres overlays) : le `_sumAnim` 0→1 monte une fois
    -- que l'écran de fin s'affiche (overAge >= 20, comme drawOverlay) -> le voile MONTE + le groupe entre en
    -- back-ease subtil au lieu de « poper ». frameDt @60 -> /60 = secondes (approche framerate-correcte).
    if self.arena.overAge >= 20 then
      self._sumAnim = Overlay.advance(self._sumAnim, frameDt / 60)
    end
    -- survol des deux boutons de fin (glow/lift lissés) — n'a d'effet visible qu'une fois l'écran affiché.
    Feel.hover("combat.chron", inBtn(self.mx, self.my, self._btnChron))
    Feel.hover("combat.cont", inBtn(self.mx, self.my, self._btnCont))
    Feel.hover("combat.replay", inBtn(self.mx, self.my, self._btnReplay))
  end
end

-- La souris arrive en espace VIRTUEL (main.lua:toVirtual) ; les rects de fin + le gaze des yeux sont en
-- espace DESIGN -> on convertit ×4 ICI (comme relicpick/runover). self.mx/self.my sont donc en DESIGN.
function Combat:mousemoved(vx, vy) self.mx, self.my = vx * 4, vy * 4 end

function Combat:wheelmoved(_, dy)
  if self.arena.over and self.arena.overAge >= 20 then return end
  if self.forceNetworkInspect or ctrlHeld() then return end
  local u = self:unitAt(self.mx, self.my)
  if not u then return end
  self.influenceScroll = self.influenceScroll or {}
  self.influenceScroll[u] = math.max(0, (self.influenceScroll[u] or 0) - (dy or 0) * 36)
  return true
end

function Combat:unitAt(mx, my)
  local vx, vy = (mx or self.mx) / 4, (my or self.my) / 4
  local best, bestD
  for _, u in ipairs(self.arena.units or {}) do
    if u.alive then
      local rx, top, bottom = u.isCommander and 18 or 17, u.isCommander and 34 or 38, 8
      if vx >= u.x - rx and vx <= u.x + rx and vy >= u.y - top and vy <= u.y + bottom then
        local d = (vx - u.x) * (vx - u.x) + (vy - (u.y - 16)) * (vy - (u.y - 16))
        if not bestD or d < bestD then best, bestD = u, d end
      end
    end
  end
  return best
end

local function pct(v)
  return (v >= 0 and "+" or "") .. tostring(math.floor(v * 100 + 0.5)) .. "%"
end

local function addRow(rows, kind, value, source, detail, badge)
  rows[#rows + 1] = {
    kind = kind,
    value = value,
    valueText = InfluencePanel.formatValue(kind, value),
    source = source,
    detail = detail,
    badge = badge,
  }
end

local function bonusFirstValue(u)
  for _, e in ipairs(u.effects or {}) do
    if e.trigger == "on_attack" and e.op == "bonus_first" then
      return (e.params and e.params.value) or 0
    end
  end
  return nil
end

function Combat:combatInfluenceData(u)
  local state, mods, affl, expired, murmurs = {}, {}, {}, {}, {}
  addRow(state, "state", tostring(math.max(0, math.floor(u.hp or 0))) .. "/" .. tostring(math.floor(u.maxHp or 0)),
    T("ui.influence_current_hp"), nil, nil)
  if (u.shield or 0) > 0 then
    addRow(state, "shield", "+" .. tostring(math.floor(u.shield or 0)), T("ui.influence_source_shield"), nil, nil)
  end
  if not u.isCommander and not self.arena.over then
    addRow(state, "state", string.format("%.1fs", math.max(0, (u.atkTimer or 0) / 60)),
      T("ui.influence_next_attack"), nil, nil)
  end
  if u.target and u.target.alive then
    addRow(state, "state", T("unit." .. u.target.id .. ".name"), T("ui.influence_target"), nil, nil)
  end

  local bf = bonusFirstValue(u)
  if bf and bf > 0 then
    if u.firstHit then
      addRow(mods, "empower", "+" .. tostring(bf), T("ui.influence_first_attack"), nil, T("ui.influence_first_badge"))
    else
      addRow(expired, "empower", "+" .. tostring(bf), T("ui.influence_first_attack"), T("ui.influence_used"), T("ui.influence_first_badge"))
    end
  end
  if (u.haste or 0) > 0 then addRow(mods, "haste", pct(u.haste), T("ui.influence_source_haste"), nil, nil) end
  if (u.atkSlow or 0) > 0 then addRow(mods, "slow", "-" .. tostring(math.floor(u.atkSlow * 100 + 0.5)) .. "%", T("ui.influence_source_bleed_slow"), nil, nil) end
  if (u.atkInc or 0) > 0 then addRow(mods, "empower", pct(u.atkInc), T("ui.influence_source_attack_damage"), nil, nil) end
  if (u.dmgReduce or 0) > 0 then addRow(mods, "guard", "-" .. tostring(math.floor(u.dmgReduce * 100 + 0.5)) .. "%", T("ui.influence_source_damage_taken"), nil, nil) end
  if (u.multicast or 0) > 0 then addRow(mods, "multicast", "+" .. tostring(math.floor(u.multicast)), T("ui.influence_source_extra_strike"), nil, nil) end
  if (u.regen or 0) > 0 then addRow(mods, "regen", "+" .. tostring(u.regen) .. " HP/s", T("ui.influence_source_regen"), nil, nil) end
  local life = (u.lifestealAura or 0) + (u.lifestealBonus or 0)
  if life > 0 then addRow(mods, "heal", pct(life), T("ui.influence_source_lifesteal"), nil, nil) end
  for _, k in ipairs({ "poison", "burn", "bleed", "rot" }) do
    local v = u[k .. "Inc"] or 0
    if v > 0 then addRow(mods, k, pct(v), T("ui.influence_damage_source", { name = Keywords.tagName(k) }), nil, nil) end
  end

  local dots = u.dots or {}
  local poisonStacks = dots.poison or {}
  local poisonDps = 0
  for _, st in ipairs(poisonStacks) do poisonDps = poisonDps + (st.dps or 0) end
  if poisonDps > 0 then
    addRow(affl, "poison", tostring(poisonDps) .. " dps", T("ui.influence_stacks", { n = #poisonStacks }), nil, nil)
  end
  for _, k in ipairs({ "burn", "bleed", "rot" }) do
    local d = dots[k]
    if d then
      local val = tostring(d.dps or d.base or 0) .. " dps"
      local rem = d.remaining and T("ui.influence_seconds_left", { s = string.format("%.1f", math.max(0, d.remaining / 60)) }) or nil
      addRow(affl, k, val, rem, (k == "bleed" and (u.atkSlow or 0) > 0) and T("ui.influence_slows_attacks") or nil, nil)
    end
  end
  if dots.shock and (dots.shock.stacks or 0) > 0 then
    addRow(affl, "shock", T("ui.influence_stacks", { n = dots.shock.stacks }), nil, nil, nil)
  end

  for _, m in ipairs(self.murmursByUnit[u] or {}) do
    murmurs[#murmurs + 1] = {
      kind = "whisper",
      valueText = T("ui.influence_murmur_value"),
      source = T("ui.influence_murmur_source"),
      detail = m.text,
      badge = T("ui.influence_murmur_badge"),
    }
  end

  return {
    title = T("ui.influence_title"),
    subtitle = T("unit." .. u.id .. ".name"),
    sections = {
      { title = T("ui.influence_current_state"), rows = state },
      { title = T("ui.influence_active_mods"), rows = mods },
      { title = T("ui.influence_active_dots"), rows = affl },
      { title = T("ui.influence_expired"), rows = expired },
      { title = T("ui.influence_murmur_title"), rows = murmurs },
    },
  }
end

function Combat:combatCardUnit(u)
  local level = (u.spec and u.spec.level) or 1
  local data = UnitResolver.unitForLevel(u.id, level)
  data.hp = tostring(math.max(0, math.floor(u.hp or 0))) .. "/" .. tostring(math.floor(u.maxHp or 0))
  data.dmg = math.floor(u.dmg or data.dmg or 0)
  data.cd = u.cd or data.cd
  data.effects = u.effects or data.effects
  data.level = level
  return data, level
end

function Combat:drawCombatTooltip(view)
  if self.arena.over and self.arena.overAge >= 20 then return end
  if self.forceNetworkInspect or ctrlHeld() then return end
  local u = self:unitAt(self.mx, self.my)
  if not u then return end
  local unit, level = self:combatCardUnit(u)
  Draw.begin(view)
  local box = MonsterCard.draw(view, self.palette, u.id, self.mx, self.my, self.t / 60,
    { keywordHint = true, networkHint = true, unit = unit, level = level })
  self.influenceScroll = self.influenceScroll or {}
  local sidecar = box and InfluencePanel.draw(view, box, self:combatInfluenceData(u),
    { scroll = self.influenceScroll[u] or 0 })
  if sidecar then self.influenceScroll[u] = sidecar.scroll or 0 end
  local showKeywords = love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown("lshift", "rshift")
  if box and showKeywords then
    CardGlossary.drawMonster(view, InfluencePanel.union(box, sidecar), u.id, self.t / 60,
      { showKeywords = true, scroll = self.tagGlossaryScroll or 0, unit = unit })
  end
  Draw.finish()
end

function Combat:_unitBySlot(team, slot)
  for _, u in ipairs(self.arena.units or {}) do
    if u.team == team and u.slot == slot and u.alive then return u end
  end
  return nil
end

function Combat:combatInfluenceLinksFor(focus)
  local links, seen = {}, {}
  local function add(a, b, kind)
    if not (a and b and a.alive and b.alive) then return end
    if a == b then return end
    local key = tostring(a) .. ">" .. tostring(b) .. ":" .. tostring(kind or "empower")
    if seen[key] then return end
    seen[key] = true
    links[#links + 1] = { a = a, b = b, kind = kind or "empower" }
  end
  local function sourceLinks(src)
    if not (src and src.alive) then return end
    if src.target and src.target.alive then add(src, src.target, "empower") end
    if src.shieldCaster and src.shieldCaster.targets then
      for _, t in ipairs(src.shieldCaster.targets) do add(src, t, "shield") end
    end
    if src.focusWith then
      add(self:_unitBySlot(src.team, src.focusWith), src, "empower")
    end
  end

  if focus then
    sourceLinks(focus)
    for _, src in ipairs(self.arena.units or {}) do
      if src ~= focus and src.alive then
        if src.target == focus then add(src, focus, "empower") end
        if src.shieldCaster and src.shieldCaster.targets then
          for _, t in ipairs(src.shieldCaster.targets) do
            if t == focus then add(src, focus, "shield") end
          end
        end
        if src.focusWith and self:_unitBySlot(src.team, src.focusWith) == focus then
          add(focus, src, "empower")
        end
      end
    end
  else
    for _, src in ipairs(self.arena.units or {}) do sourceLinks(src) end
  end
  return links
end

function Combat:drawCombatInfluenceLinks(view)
  if not (self.forceNetworkInspect or ctrlHeld()) then return end
  local u = self:unitAt(self.mx, self.my)
  local allMode = not u
  local links = self:combatInfluenceLinksFor(u)
  if #links == 0 then return end
  Draw.begin(view)
  for _, lk in ipairs(links) do
    local col = Theme.c[lk.kind] or Theme.c.gold
    local ax, ay = lk.a.x * 4, (lk.a.y - 16) * 4
    local bx, by = lk.b.x * 4, (lk.b.y - 16) * 4
    if love.graphics.setBlendMode then
      love.graphics.setBlendMode("add")
      Draw.setColor({ col[1], col[2], col[3], allMode and 0.09 or 0.18 })
      love.graphics.setLineWidth(allMode and 6 or 8)
      love.graphics.line(ax, ay, bx, by)
      love.graphics.setBlendMode("alpha")
    end
    Draw.setColor({ col[1], col[2], col[3], allMode and 0.44 or 0.82 })
    love.graphics.setLineWidth(allMode and 2 or 2.5)
    love.graphics.line(ax, ay, bx, by)
  end
  love.graphics.setLineWidth(1)
  Draw.reset()
  Draw.finish()
end

-- Décor de BIOME parallaxe (refonte Combat Frame) derrière les combattants pixel, + SCRIMS qui le poussent
-- en arrière et gardent les sprites lisibles sur TOUT biome. Repli sur l'atmosphère "combat" si pas de biome.
function Combat:drawBack(view)
  Draw.begin(view)
  if self.nightmareBg then
    -- FOND CAUCHEMARDESQUE : un seul shader peint tout (base unie sombre + distorsion onirique / double vision
    -- / yeux). Pas de scrims : la base est déjà sombre et le shader porte sa propre vignette/respiration.
    self.nightmareBg:draw(0, 0, Draw.W, Draw.H)
  elseif self.biome then
    local W, H = Draw.W, Draw.H
    self.biome:draw(0, 0, W, H) -- les 6 calques (filtre linéaire = profondeur de champ douce) + particules
    if love.graphics then
      local s1, s2, s3 = 6 / 255, 4 / 255, 10 / 255 -- encre de fond (assombrissement)
      Draw.setColor({ s1, s2, s3, 0.48 }); love.graphics.rectangle("fill", 0, 0, W, H) -- 1) assombri plat
      Panel.vgrad(0, 0, W, H * 0.22, { s1, s2, s3, 0.6 }, { s1, s2, s3, 0 })             -- 2) fondu HAUT
      Panel.vgrad(0, H * 0.6, W, H * 0.4, { s1, s2, s3, 0 }, { 4 / 255, 2 / 255, 7 / 255, 0.82 }) -- bas
      Draw.setColor({ 0, 0, 0, 0.10 })                                                  -- 3) scanlines (2px/4px)
      for y = 0, H - 1, 4 do love.graphics.rectangle("fill", 0, y, W, 2) end
      Draw.reset()
    end
  else
    self.ambient:draw("combat")
  end
  Draw.finish()
end

function Combat:drawWorld()
  self.renderer:draw(false)
end

-- Vivants/total par équipe (gauche = joueur, droite = ghost). Lecture seule de la SIM.
function Combat:_counts()
  local la, lt, ra, rt = 0, 0, 0, 0
  for _, u in ipairs(self.arena.units) do
    if u.team == "left" then lt = lt + 1; if u.alive then la = la + 1 end
    else rt = rt + 1; if u.alive then ra = ra + 1 end end
  end
  return la, lt, ra, rt
end

-- Petite goutte de sang (pip d'hôte) centrée en (cx,cy) : pleine = unité vivante, sourde = tombée.
local function teardrop(cx, cy, on, col)
  local C = Theme.c
  Draw.setColor(on and (col or C.blood) or C.stone700)
  if love.graphics then
    love.graphics.polygon("fill", cx, cy - 5, cx - 3.5, cy + 1.5, cx + 3.5, cy + 1.5)
    love.graphics.circle("fill", cx, cy + 1.5, 3.5)
  end
  Draw.reset()
end

-- Jauge de FATIGUE (centre, sous le « vs ») : progression vers l'enrage (t / FATIGUE_START) ; ENRAGE s'allume
-- au plafond (au-delà, l'usure globale frappe tout le monde -> tout combat conclut). Lecture seule.
function Combat:_drawFatigue()
  local c = Theme.c
  local ft = self.arena.fatigue
  local start = (ft and ft.start) or self.arena.FATIGUE_START or 1020
  local pct = math.max(0, math.min(1, (self.arena.t or 0) / start))
  local enraged = pct >= 1
  local f = Theme.label(8)
  local barW = 200
  local total = f:getWidth(T("ui.fatigue")) + 8 + barW + 8 + f:getWidth(T("ui.enrage"))
  local x, y = math.floor(Draw.W / 2 - total / 2), 52
  Draw.text(T("ui.fatigue"), x, y - 4, c.ink4, f)
  local bx = x + f:getWidth(T("ui.fatigue")) + 8
  Draw.rect(bx, y - 2, barW, 5, { 0x0a / 255, 0x08 / 255, 0x10 / 255, 1 }, c.iron, 1)
  local fillW = math.floor((barW - 2) * pct)
  if fillW > 0 then Draw.rect(bx + 1, y - 1, fillW, 3, enraged and c.bloodL or c.blood) end
  Draw.text(T("ui.enrage"), bx + barW + 8, y - 4, enraged and c.bloodL or c.ink5, f)
end

-- HUD haut (refonte « Combat Frame ») : [ YOUR HOST · pips · count ] · [ ROUND·GHOST / vs NOM ] · [ count ·
-- pips · NOM ]. Pips = un par unité (plein = vivant). PROPRE (Cinzel pour le nom, Space Mono pour le reste).
function Combat:_drawCombatHud()
  local c = Theme.c
  local la, lt, ra, rt = self:_counts()
  local labF, valF = Theme.label(9), Theme.value(13)
  local midY = 22
  -- GAUCHE : YOUR HOST + pips + count.
  Draw.text(T("ui.your_host"), 22, midY - 5, c.ink4, labF)
  local px = 22 + labF:getWidth(T("ui.your_host")) + 12
  local nl = math.min(9, lt)
  for i = 1, nl do teardrop(px + (i - 1) * 9 + 4, midY, i <= la, c.blood) end
  Draw.text(tostring(la), px + nl * 9 + 8, midY - valF:getHeight() / 2, c.ink2, valF)
  -- CENTRE : ROUND·GHOST + vs NOM.
  local run = self.host.run
  Draw.textC(run and T("ui.round_ghost", { n = run.round }) or T("ui.exhibition_ghost"), Draw.W / 2, 8, c.ink4, Theme.label(8))
  local name = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  local vf, nf = Theme.bodyItalic(13), Theme.subhead(16)
  local vw, nw = vf:getWidth("vs "), nf:getWidth(name)
  local cx = math.floor(Draw.W / 2 - (vw + nw) / 2)
  Draw.text("vs ", cx, 24, c.ink3, vf)
  Draw.text(name, cx + vw, 22, c.ink, nf)
  -- DROITE : count + pips + NOM (petit), aligné à droite.
  local rx = Draw.W - 64
  Draw.textR(name, rx, midY - 5, c.ink4, labF)
  local nr = math.min(9, rt)
  local pstart = rx - labF:getWidth(name) - 12 - nr * 9
  for i = 1, nr do teardrop(pstart + (i - 1) * 9 + 4, midY, i <= ra, { 0.48, 0.54, 0.42, 1 }) end
  Draw.textR(tostring(ra), pstart - 6, midY - valF:getHeight() / 2, c.ink2, valF)
  self:_drawFatigue()
end

-- Contrôles bas (refonte « Combat Frame ») : « auto-battle in progress · the Pit decides » à gauche ;
-- segments de VITESSE [ 1× | 2× | SKIP ] + « [c] chronicle » à droite. Les rects de vitesse sont posés ICI
-- (hit-test de mousepressed PENDANT le combat). Visible seulement tant que le combat n'est pas conclu.
function Combat:_drawControls()
  local c = Theme.c
  local f = Theme.label(9)
  local y = Draw.H - 17
  Draw.rect(0, Draw.H - 34, Draw.W, 1, { c.brassS[1], c.brassS[2], c.brassS[3], 0.1 })
  -- gauche : statut.
  Draw.text(T("ui.auto_battle"), 18, y - 5, c.ink4, f)
  local aw = f:getWidth(T("ui.auto_battle"))
  Draw.text("  ·  " .. T("ui.pit_decides"), 18 + aw, y - 5, c.ink5, f)
  -- droite : [c] chronicle (extrême droite) + segments de vitesse à sa gauche.
  local hint = T("ui.chronicle_hint")
  Draw.textR(hint, Draw.W - 18, y - 5, c.ink4, f)
  local segs = {
    { id = "pause", label = self.paused and T("ui.resume") or T("ui.pause"), on = self.paused },
    { id = "spd1", label = "1×", on = (self.speed == 1) and not self.skipping },
    { id = "spd2", label = "2×", on = (self.speed == 2) and not self.skipping },
    { id = "skip", label = T("ui.speed_skip"), on = self.skipping },
  }
  local totalW = 0
  for _, s in ipairs(segs) do s.w = f:getWidth(s.label) + 24; totalW = totalW + s.w end
  local sx = Draw.W - 18 - f:getWidth(hint) - 16 - totalW
  for _, s in ipairs(segs) do
    local r = { x = sx, y = y - 11, w = s.w, h = 22 }
    local hot = inBtn(self.mx, self.my, r)
    Draw.rect(sx, r.y, s.w, 22, s.on and { 0x7a / 255, 0x1d / 255, 0x16 / 255, 1 } or { 0x10 / 255, 0x0d / 255, 0x16 / 255, 1 }, c.iron, 1)
    Draw.textC(s.label, sx + s.w / 2, y - 5, s.on and c.ctaText or (hot and c.ink2 or c.ink3), f)
    if s.id == "pause" then self._btnPause = r
    elseif s.id == "spd1" then self._btnSpd1 = r
    elseif s.id == "spd2" then self._btnSpd2 = r
    else self._btnSkip = r end
    sx = sx + s.w
  end
end

-- ── Écran de RÉSUMÉ post-combat (refonte « Combat Screen » Frame 4) ──────────────────────────────────
-- Remplace la modale de verdict par un écran COMPLET : header (verdict Jacquard + flavor) + ruban de stats
-- (durée/survivants/tués/vies/descente) + DAMAGE BY CAUSE (barres) + THE LEDGER (MVP + 1re perte) + actions
-- (CLAIM THE SPOILS / [c] CHRONICLE / [r] REPLAY). RENDER pur (lit les stats agrégées de _track). ──

-- Libellé court + couleur d'une cause de dégâts (attack -> BLADE ; afflictions -> nom en caps + teinte).
local function causeLabel(cause) return (cause == "attack") and T("ui.cause_blade") or cause:upper() end
local function causeColor(cause)
  local c = Theme.c
  if cause == "attack" or cause == "reflect" or cause == "thorns" then return c.bloodL end
  return c[cause] or c.ink2
end
-- Tuile de portrait (MVP / 1re perte) : socle laiton hachuré + VRAIE frimousse de la créature (MiniRig,
-- centrée/clippée, déterministe par id) + petit pip de type en coin. `fallen` voile la tuile (1re perte =
-- tombée). RENDER pur, headless-safe (MiniRig retombe sur une boîte de repli sous mock LÖVE).
local function portraitTile(view, x, y, sz, id, border, fallen)
  local c = Theme.c
  Panel.vgrad(x, y, sz, sz, { 0x2a / 255, 0x1f / 255, 0x10 / 255, 1 }, { 0x1d / 255, 0x15 / 255, 0x09 / 255, 1 })
  local U = Units[id]
  if U and MiniRig and MiniRig.draw then
    MiniRig.draw(view, id, nil, x + 3, y + 3, sz - 6, sz - 6, 1)
  end
  if fallen then Draw.rect(x, y, sz, sz, { 0x05 / 255, 0x03 / 255, 0x06 / 255, 0.5 }) end -- voile de mort
  Draw.rect(x, y, sz, sz, nil, border or c.iron, 1)
  -- pip de type (coin haut-gauche) : lecture rapide de la famille même quand la silhouette est sombre.
  local tcol = (U and Theme.type(U.type).color) or c.bone
  if love and love.graphics then
    love.graphics.push(); love.graphics.translate(x + 9, y + 9); love.graphics.rotate(0.785)
    Draw.setColor(tcol); love.graphics.rectangle("fill", -3, -3, 6, 6); love.graphics.pop(); Draw.reset()
  end
end

local function compactName(str, font, maxW)
  if not (font and str) or font:getWidth(str) <= maxW then return str end
  local ell = "..."
  local out = str
  while #out > 1 and font:getWidth(out .. ell) > maxW do out = out:sub(1, #out - 1) end
  return out .. ell
end

local function afflictionList(map)
  local out = {}
  if map then
    for _, key in ipairs(Keywords.order) do
      if map[key] and map[key] > 0 then out[#out + 1] = { key = key, count = map[key] } end
    end
  end
  return out
end

-- Résumé COMPLET (mémoïsé) : stats + dégâts par cause (triés) + MVP + 1re perte. Déterministe (ipairs ;
-- pairs seulement pour des sommes commutatives).
function Combat:_fullSummary()
  local arena = self.arena
  local la, lt, ra, rt = self:_counts()
  local causes = {}
  for cause, v in pairs(self.dmgByCause) do causes[#causes + 1] = { cause = cause, value = v } end
  table.sort(causes, function(a, b) if a.value == b.value then return a.cause < b.cause end return a.value > b.value end)
  local mvp, mvpScore
  for _, u in ipairs(arena.units) do
    if u.team == "left" then
      local sc = (self.dealtByUnit[u] or 0) + (self.soakedByUnit[u] or 0)
      if not mvpScore or sc > mvpScore then mvp, mvpScore = u, sc end
    end
  end
  local firstLoss
  for _, k in ipairs(self.killLog) do
    if k.victim.team == "left" then firstLoss = { id = k.victim.id, time = (k.tick or 0) / 60 }; break end
  end
  local firstLossUnit = nil
  for _, k in ipairs(self.killLog) do
    if k.victim.team == "left" then firstLossUnit = k.victim; break end
  end
  local function roster(team)
    local rows = {}
    for _, u in ipairs(arena.units) do
      if u.team == team and not u.isCommander then
        rows[#rows + 1] = {
          unit = u, id = u.id, alive = u.alive,
          deathTime = self.unitDeathTime[u],
          dealt = self.unitDealt[u] or 0,
          taken = self.unitTaken[u] or 0,
          kills = self.unitKills[u] or 0,
          afflictions = afflictionList(self.unitAfflictions[u]),
          mvp = (u == mvp),
          firstLoss = (u == firstLossUnit),
        }
      end
    end
    return rows
  end
  local run = self.host.run
  return {
    win = arena.win, duration = (arena.t or 0) / 60,
    survN = la, survT = lt, slainN = rt - ra, slainT = rt,
    livesDelta = run and (arena.win and 0 or -1) or nil,
    descN = run and math.min(Run.WIN_TARGET, run.wins + (arena.win and 1 or 0)) or nil, descT = Run.WIN_TARGET,
    causes = causes, dealt = self.dealtTotal, taken = self.takenTotal,
    mvp = mvp and { id = mvp.id, dealt = self.dealtByUnit[mvp] or 0, soaked = self.soakedByUnit[mvp] or 0 } or nil,
    firstLoss = firstLoss,
    leftRows = roster("left"),
    rightRows = roster("right"),
  }
end

local function drawAfflictions(x, y, list, maxW)
  local c = Theme.c
  local f = Theme.label(8)
  if not list or #list == 0 then
    Draw.text(T("ui.no_afflictions"), x, y, c.ink5, f)
    return
  end
  local cx, used = x, 0
  for i, a in ipairs(list) do
    if i > 3 then
      Draw.text("+" .. tostring(#list - 3), cx + 2, y, c.ink4, f)
      return
    end
    local kw = Keywords.get(a.key)
    local col = (kw and kw.color) or c.ink3
    local ic = Keywords.icon(a.key)
    local iw = 10
    if used + iw > maxW then return end
    if ic and love and love.graphics then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(ic.image, math.floor(cx), math.floor(y + 1), 0, 1, 1)
    else
      Draw.rect(cx, y + 2, 7, 7, col)
    end
    cx = cx + 10; used = used + 10
    if a.count and a.count > 1 then
      local txt = "x" .. tostring(a.count)
      local tw = f:getWidth(txt)
      if used + tw > maxW then return end
      Draw.text(txt, cx, y, col, f)
      cx = cx + tw + 5; used = used + tw + 5
    else
      cx = cx + 5; used = used + 5
    end
  end
end

local function drawCauseStrip(s, x, y, w, h)
  local c = Theme.c
  Panel.vgrad(x, y, w, h, { 0x10 / 255, 0x0c / 255, 0x15 / 255, 0.96 }, { 0x09 / 255, 0x07 / 255, 0x0e / 255, 0.96 })
  Draw.rect(x, y, w, h, nil, c.iron, 1)
  Draw.text(T("ui.dmg_by_cause"), x + 12, y + 11, c.ink3, Theme.label(9))
  local causeX = x + 174
  local maxV = (s.causes[1] and s.causes[1].value) or 1
  for i = 1, math.min(3, #s.causes) do
    local cz = s.causes[i]
    local col = causeColor(cz.cause)
    local bx = causeX + (i - 1) * 178
    Draw.text(causeLabel(cz.cause), bx, y + 8, col, Theme.label(8))
    Draw.rect(bx, y + 23, 112, 6, { 0x05 / 255, 0x04 / 255, 0x08 / 255, 1 }, c.iron, 1)
    local fw = math.floor(110 * (cz.value / maxV))
    if fw > 0 then Draw.rect(bx + 1, y + 24, fw, 4, col) end
    Draw.textR(tostring(cz.value), bx + 150, y + 7, c.ink, Theme.value(12))
  end
  local f = Theme.label(9)
  local dt = T("ui.dealt") .. " " .. tostring(s.dealt) .. "  /  " .. T("ui.taken") .. " " .. tostring(s.taken)
  Draw.textR(dt, x + w - 12, y + 12, c.ink4, f)
end

local function drawRosterPanel(view, x, y, w, h, title, rows, accent)
  local c = Theme.c
  Panel.vgrad(x, y, w, h, { 0x12 / 255, 0x0e / 255, 0x16 / 255, 0.96 }, { 0x08 / 255, 0x06 / 255, 0x0d / 255, 0.96 })
  Draw.rect(x, y, w, h, nil, accent or c.iron, 1)
  local hf, cf = Theme.label(11), Theme.label(8)
  Draw.text(title, x + 12, y + 10, c.ink, hf)
  local colKills = x + w - 24
  local colTaken = x + w - 76
  local colDealt = x + w - 130
  local affX = x + w - 250
  Draw.textR(T("ui.col_dealt"), colDealt, y + 13, c.ink4, cf)
  Draw.textR(T("ui.col_taken"), colTaken, y + 13, c.ink4, cf)
  Draw.textR(T("ui.col_kills"), colKills, y + 13, c.ink4, cf)
  Draw.text(T("ui.col_affl"), affX, y + 13, c.ink4, cf)
  Draw.rect(x + 10, y + 31, w - 20, 1, c.iron)

  local n = math.max(1, #rows)
  local avail = h - 40
  local rowH = math.min(46, math.floor(avail / n))
  if rowH < 28 then rowH = math.max(22, math.floor(avail / n)) end
  local py = y + 38
  for i, r in ipairs(rows) do
    if py + rowH > y + h - 4 then break end
    local fill = (i % 2 == 1) and { 0x0b / 255, 0x08 / 255, 0x10 / 255, 0.72 } or { 0x11 / 255, 0x0d / 255, 0x15 / 255, 0.72 }
    Draw.rect(x + 8, py, w - 16, rowH - 2, fill, (r.mvp and c.brass) or (r.firstLoss and c.bloodD) or nil, 1)
    local p = math.max(16, math.min(32, rowH - 8))
    portraitTile(view, x + 13, py + math.floor((rowH - p) / 2), p, r.id, r.alive and c.iron or c.bloodD, not r.alive)
    local nameX = x + 20 + p
    local nameW = math.max(80, affX - nameX - 12)
    local nf = Theme.subhead(rowH < 32 and 10 or 11)
    Draw.text(compactName(unitName(r.id), nf, nameW), nameX, py + 5, r.alive and c.ink or c.ink3, nf)
    local status
    local sc = c.ink5
    if r.alive then
      status, sc = T("ui.status_alive"), c.regen
    else
      status, sc = T("ui.status_fell", { time = string.format("%.1f", r.deathTime or 0) }), c.bloodL
    end
    if r.mvp then status = T("ui.mvp") .. " · " .. status end
    if r.firstLoss then status = T("ui.first_to_fall_short") .. " · " .. status end
    Draw.text(compactName(status, cf, nameW), nameX, py + rowH - 16, sc, cf)
    drawAfflictions(affX, py + math.floor(rowH / 2) - 5, r.afflictions, 104)
    Draw.textR(tostring(r.dealt), colDealt, py + math.floor(rowH / 2) - 8, c.ink, Theme.value(12))
    Draw.textR(tostring(r.taken), colTaken, py + math.floor(rowH / 2) - 8, r.taken > 0 and c.bloodL or c.ink4, Theme.value(12))
    Draw.textR(tostring(r.kills), colKills, py + math.floor(rowH / 2) - 8, r.kills > 0 and c.gold or c.ink4, Theme.value(12))
    py = py + rowH
  end
end

function Combat:_drawSummary(view)
  Draw.begin(view)
  local c = Theme.c
  if not self.full then self.full = self:_fullSummary() end
  if not self.summary then self.summary = self:_computeSummary() end
  local s, why = self.full, self.summary
  local W, H, won = Draw.W, Draw.H, self.full.win

  -- SON (verdict) : UNE fois, au 1er affichage du bilan. VICTOIRE -> pad maj7 grave et rêveur (success) ;
  -- DEFAITE -> la chute, grave et longue (defeat). RENDER pur (no-op headless) ; ne touche pas la SIM.
  if not self._verdictPlayed then
    self._verdictPlayed = true
    SFX.play(won and "success" or "defeat")
  end

  -- (0) FOND = le MÊME fond que le combat (cauchemardesque champ + yeux, ou biome si réactivé), plein écran
  -- et VIVANT -> cohérence avec l'arène (retour user : plus de halos/cercles d'ambiance hétéroclites). Il
  -- recouvre l'arène finie ; un voile sombre par-dessus garde le ruban/cartes de bilan parfaitement lisibles.
  -- verdictT = secondes écoulées depuis l'apparition du bilan (overAge >= 20) -> pilote la VICTOIRE (montée de
  -- lumière + fermeture progressive des yeux). Défaite : yeux ouverts/tremblants/sanglants (cf. nightmare_bg).
  local vT = math.max(0, ((self.arena.overAge or 20) - 20) / 60)
  local verdict = won and "win" or "loss"
  local vopts = { verdict = verdict, verdictT = vT }
  -- (0a) CHAMP du fond (assombrissable) — cauchemardesque (champ + brillance de victoire) ou biome si réactivé.
  if self.nightmareBg then self.nightmareBg:drawField(0, 0, W, H, vopts)
  elseif self.biome then self.biome:draw(0, 0, W, H)
  else Panel.vgrad(0, 0, W, H, { 0x10 / 255, 0x0c / 255, 0x16 / 255, 1 }, { 0x05 / 255, 0x03 / 255, 0x08 / 255, 1 }) end
  -- (0b) VOILE de lisibilité : un peu plus CLAIR en VICTOIRE (laisse respirer la lumière) sans nuire au texte.
  -- ENTRÉE CHORÉGRAPHIÉE (anim 0→1, avancé dans Combat:update) : le voile MONTE avec l'entrée (·anim) comme
  -- pour les autres overlays -> il ne « pope » plus, il se POSE. À anim=1 -> exactement l'alpha d'avant.
  local anim = self._sumAnim or 1
  Draw.setColor({ 0x05 / 255, 0x03 / 255, 0x09 / 255, (won and 0.40 or 0.52) * anim })
  love.graphics.rectangle("fill", 0, 0, W, H)
  Draw.reset()
  -- (0c) YEUX par-dessus le voile (PROMINENTS) : défaite = plusieurs ouverts/tremblants/sanglants ; victoire = se ferment.
  if self.nightmareBg then self.nightmareBg:drawEyes(0, 0, W, H, vopts) end

  -- (0d) ENROBAGE du GROUPE de contenu : scale SUBTIL autour du centre écran (range 0,025 -> entrée discrète,
  -- PAS un rétrécissement de petite modale ; c'est un écran plein). Le fond cauchemardesque/voile/yeux restent
  -- HORS de l'enrobage (ils vivent, ils ne « zooment » pas). À anim=1 -> transform identité (pose = rendu d'avant).
  Overlay.pushContent(W / 2, H / 2, anim, 0.025)

  -- (1) HEADER : kicker + verdict (Jacquard, casse de titre) + flavor. PAS de cercle/halo derrière le mot
  -- (retour user : « j'aime pas le cercle ») -> le verdict tient seul sur le fond cauchemardesque + voile.
  Draw.textC(T(won and "ui.summary_kicker_win" or "ui.summary_kicker_loss"), W / 2, 36, c.ink3, Theme.label(10))
  Draw.textC(T(won and "ui.verdict_win" or "ui.verdict_loss"), W / 2, 54, won and c.gold or c.bloodL, Theme.display(56))
  local foe = T("encounter." .. (self.enemyKey or "unknown") .. ".name")
  local causeWord = (why and why.cause) and (why.cause == "attack" and "blades" or why.cause) or "attrition"
  Draw.textC(T(won and "ui.summary_flavor_win" or "ui.summary_flavor_loss", { cause = causeWord, foe = foe }),
    W / 2, 128, c.ink2, Theme.bodyItalic(15))

  -- (2) RUBAN DE STATS centré.
  local rf, vf = Theme.label(8), Theme.value(20)
  local cells = {
    { lab = T("ui.stat_duration"), val = string.format("%.1f", s.duration), suf = "s", vc = c.ink },
    { lab = T("ui.stat_survivors"), val = tostring(s.survN), suf = "/" .. s.survT, vc = c.ink },
    { lab = T("ui.stat_slain"), val = tostring(s.slainN), suf = "/" .. s.slainT, vc = c.ink },
  }
  if s.livesDelta ~= nil then cells[#cells + 1] = { lab = T("ui.stat_lives"), val = (s.livesDelta >= 0 and "±" or "−") .. math.abs(s.livesDelta), vc = (s.livesDelta >= 0) and c.regen or c.bloodL } end
  if s.descN ~= nil then cells[#cells + 1] = { lab = T("ui.stat_descent"), val = tostring(s.descN), suf = "/" .. s.descT, vc = c.gold } end
  local cellW, ribbonW = {}, 0
  for i, cell in ipairs(cells) do
    local valW = vf:getWidth(cell.val) + (cell.suf and rf:getWidth(cell.suf) or 0)
    local w = math.max(rf:getWidth(cell.lab), valW) + 52
    cellW[i] = w; ribbonW = ribbonW + w
  end
  ribbonW = ribbonW + (#cells - 1)
  local rx, ry, rh = math.floor(W / 2 - ribbonW / 2), 166, 54
  Panel.vgrad(rx, ry, ribbonW, rh, c.stone800, c.stone900)
  Draw.rect(rx, ry, ribbonW, rh, nil, c.iron, 1)
  local cxp = rx
  for i, cell in ipairs(cells) do
    local w = cellW[i]
    Draw.textC(cell.lab, cxp + w / 2, ry + 11, c.ink4, rf)
    local vw, sw = vf:getWidth(cell.val), (cell.suf and rf:getWidth(cell.suf) or 0)
    local vx = math.floor(cxp + w / 2 - (vw + sw) / 2)
    Draw.text(cell.val, vx, ry + 24, cell.vc, vf)
    if cell.suf then Draw.text(cell.suf, vx + vw, ry + 32, c.ink3, rf) end
    cxp = cxp + w
    if i < #cells then Draw.rect(cxp, ry + 8, 1, rh - 16, c.iron); cxp = cxp + 1 end
  end

  -- (3) POST-MORTEM LISIBLE : causes compactes, puis deux rosters symétriques avec stats par monstre.
  drawCauseStrip(s, 180, 232, 920, 38)
  local rosterTop, rosterH = 282, 312
  drawRosterPanel(view, 56, rosterTop, 568, rosterH, T("ui.roster_host"), s.leftRows or {}, c.gold)
  drawRosterPanel(view, 656, rosterTop, 568, rosterH, T("ui.roster_foe"), s.rightRows or {}, c.bloodD)

  -- ACTIONS : CTA principal en bas-centre, secondaires dessous. Les yeux du bouton primary sont conservés.
  local bw, bh = 520, 44
  local bx, byb = math.floor(W / 2 - bw / 2), 614
  self._btnCont = { x = bx, y = byb, w = bw, h = bh }
  Button.draw(bx, byb, bw, bh, "primary", T("ui.claim_spoils"),
    { hover = inBtn(self.mx, self.my, self._btnCont), feel = Feel.state("combat.cont"), id = "combat.cont",
      mouse = { mx = self.mx, my = self.my }, t = self.t / 60 })
  local by2, bh2, gap = byb + bh + 10, 36, 12
  local halfW = math.floor((bw - gap) / 2)
  self._btnChron = { x = bx, y = by2, w = halfW, h = bh2 }
  self._btnReplay = { x = bx + halfW + gap, y = by2, w = bw - halfW - gap, h = bh2 }
  Button.draw(self._btnChron.x, by2, halfW, bh2, "secondary", T("ui.chronicle_btn"),
    { hover = inBtn(self.mx, self.my, self._btnChron), feel = Feel.state("combat.chron"), id = "combat.chron" })
  Button.draw(self._btnReplay.x, by2, self._btnReplay.w, bh2, "secondary", T("ui.replay_btn"),
    { hover = inBtn(self.mx, self.my, self._btnReplay), feel = Feel.state("combat.replay"), id = "combat.replay" })

  -- (fin de l'enrobage du groupe) + FADE-UP : un wash sombre PAR-DESSUS le contenu, alpha = (1-anim)·force,
  -- qui s'efface à mesure que l'entrée se pose -> le bilan « remonte du noir » (le fade qui appaire la
  -- chorégraphie aux autres overlays + au son success/defeat). À anim=1 -> wash transparent (rendu d'avant).
  Overlay.popContent()
  if anim < 1 then
    Draw.setColor({ 0x05 / 255, 0x03 / 255, 0x09 / 255, (1 - anim) * 0.55 })
    love.graphics.rectangle("fill", 0, 0, W, H)
    Draw.reset()
  end
  Draw.finish()
end

function Combat:drawOverlay(view)
  Draw.begin(view)
  self:_drawCombatHud()                                  -- HUD haut (hôtes/round/vs/fatigue)
  if not self.arena.over then self:_drawControls() end   -- contrôles bas (vitesse + chronicle) pendant le combat
  Draw.finish()

  if not (self.arena.over and self.arena.overAge >= 20) then self:drawCombatInfluenceLinks(view) end
  self.renderer:drawOverlay(view) -- noms d'unités + nombres flottants (gère sa propre transform)
  self:drawCombatTooltip(view)

  -- Verdict + post-mortem + boutons (1.3 / 2A) : l'attribution causale est la précondition du ranked/rétention.
  -- On attend overAge >= 20 (laisse l'anim de mort se poser) avant d'afficher l'écran de fin.
  if self.arena.over and self.arena.overAge >= 20 then
    self:_drawSummary(view)
  end

  -- Indicateur de PAUSE : glyphe ❚❚ DESSINÉ (pas de texte -> aucune dépendance i18n), haut-centre, hors
  -- de la zone des grilles -> screenshot lisible. Le combat figé est déjà un retour clair en soi.
  if self.paused then
    Draw.begin(view)
    local c = Theme.c
    local bx, by = Draw.W / 2 - 5, 56
    Draw.setColor(c.ink, 0.92)
    if love and love.graphics then
      love.graphics.rectangle("fill", bx, by, 4, 14)
      love.graphics.rectangle("fill", bx + 7, by, 4, 14)
    end
    Draw.reset()
    Draw.finish()
  end
end

function Combat:keypressed(key)
  if key == "space" then self.paused = not self.paused; return end -- PAUSE / reprise (spectateur)
  if key == "r" then self:restart() end
end

function Combat:mousepressed(vx, vy, button)
  if button ~= 1 then return end
  self.mx, self.my = vx * 4, vy * 4 -- virtuel -> DESIGN (les rects sont en espace design)
  -- VITESSE (pendant le combat) : 1× / 2× / SKIP. Pas d'autre entrée tant que ce n'est pas conclu.
  if not self.arena.over then
    if inBtn(self.mx, self.my, self._btnPause) then Feel.press("combat.pause"); self.paused = not self.paused; return end
    if inBtn(self.mx, self.my, self._btnSpd1) then Feel.press("combat.spd1"); self.speed, self.skipping = 1, false; return end
    if inBtn(self.mx, self.my, self._btnSpd2) then Feel.press("combat.spd2"); self.speed, self.skipping = 2, false; return end
    if inBtn(self.mx, self.my, self._btnSkip) then Feel.press("combat.skip"); self.skipping = true; return end
    return
  end
  -- 2A — plus de clic-n'importe-où : on hit-teste UNIQUEMENT les deux boutons de l'écran de fin.
  -- Feedback de press IMMÉDIAT (Feel.press sans action -> squash/flash) PUIS action TOUT DE SUITE : le test
  -- headless asserte openChronicle/finishCombat juste après le clic -> on n'utilise PAS l'action différée.
  if inBtn(self.mx, self.my, self._btnReplay) then
    Feel.press("combat.replay", function() self:restart() end); return -- rejoue la MÊME bataille (seed identique)
  end
  if inBtn(self.mx, self.my, self._btnChron) then
    -- ⭐ ACTION DIFFÉRÉE (Feel, bible §4) : press visible AVANT l'ouverture (~160 ms) -> on SENT le clic.
    -- Le test mûrit l'action via Combat:update (-> Feel.update) avant d'asserter openChronicle.
    Feel.press("combat.chron", function()
      if self.host.openChronicle then self.host.openChronicle() end -- overlay chronique (no-op hors run)
    end)
    return
  end
  if inBtn(self.mx, self.my, self._btnCont) then
    -- ⭐ DIFFÉRÉE : press visible AVANT le changement de scène. EXHIBITION (banc d'essai) : payload.onFinish
    -- prend la main (retour Proving Ground, sans toucher la méta de run) ; sinon host ; fallback goto build.
    Feel.press("combat.cont", function()
      if self.payload.onFinish then self.payload.onFinish(self.arena.win, self.arena)
      elseif self.host.finishCombat then self.host.finishCombat(self.arena.win)
      else self.host.goto("build") end
    end, { delay = Feel.CTA_DELAY })
    return
  end
end

return Combat
