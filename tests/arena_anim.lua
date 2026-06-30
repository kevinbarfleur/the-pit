-- tests/arena_anim.lua
-- B.1b — Câblage de l'ÉTAT D'ANIM critter dans la couche RENDER (src/render/arena_draw.lua). On NE teste PAS le
-- rendu (Critter.drawAt no-op sous le mock : pas de SpriteBatch) mais la MACHINE À ÉTATS render-local : commutation
-- par les évènements du bus (attack/hit/death), priorité death > hurt > atk, latch de la mort, et retour à idle au
-- terme des durées. Cette logique a une vraie sémantique de feedback (un mort n'attaque plus, un coup interrompt
-- l'attaque) -> elle mérite une garde de non-régression. Headless-safe. Lancement : luajit tests/arena_anim.lua
package.path = "./?.lua;" .. package.path
love = require("tests.mock_love")

local Palette = require("src.core.palette")
local Arena = require("src.combat.arena")
local ArenaDraw = require("src.render.arena_draw")
local Critter = require("src.render.critter")

local function spec(id, x)
  local Units = require("src.data.units")
  local u = Units[id]
  return { id = id, hp = u.hp, dmg = u.dmg, cd = u.cd, effects = u.effects, shield = 0, x = x, y = 96, facing = 1 }
end

local DUR = ArenaDraw.CR_DUR

local ok, err = pcall(function()
  -- Deux unités GÉNÉRÉES (tout le roster l'est ; Critter.has=true) qui se font face.
  assert(Critter.has("witch") and Critter.has("marauder"), "pré-requis : unités générées (Critter.has)")
  local arena = Arena.new({ left = { spec("witch", 150) }, right = { spec("marauder", 170) }, autoReset = false, seed = 7 })
  local rd = ArenaDraw.new(arena, Palette)
  local A, B = arena.units[1], arena.units[2]

  -- état initial : aucune entrée (idle implicite -> setAnim crée à la demande).
  assert(rd.anim[A] == nil, "anim vierge avant tout évènement")

  -- 1) attack -> atk
  arena.bus:emit("attack", A)
  assert(rd.anim[A] and rd.anim[A].state == "atk", "attack -> atk (état=" .. tostring(rd.anim[A] and rd.anim[A].state) .. ")")
  assert(rd.anim[A].age == 0, "atk fraîchement armé (age=0)")

  -- 2) hit pendant l'atk -> hurt (le coup reçu PRIME sur l'attaque ; priorité 2 > 1)
  arena.bus:emit("hit", B, A) -- (attaquant B, cible A)
  assert(rd.anim[A].state == "hurt", "hit interrompt atk -> hurt (état=" .. rd.anim[A].state .. ")")

  -- 3) attack pendant un hurt FRAIS -> IGNORÉ (le hurt poursuit, pas de ré-armement atk)
  arena.bus:emit("attack", A)
  assert(rd.anim[A].state == "hurt", "atk n'écrase PAS un hurt frais (état=" .. rd.anim[A].state .. ")")

  -- 4) le hurt arrive à terme -> retour idle (update avance l'âge)
  for _ = 1, DUR.hurt do rd:update(1.0, 1) end
  assert(rd.anim[A].state == "idle", "hurt résorbé -> idle (état=" .. rd.anim[A].state .. ")")

  -- 5) re-attack après résorption -> atk de nouveau
  arena.bus:emit("attack", A)
  assert(rd.anim[A].state == "atk", "attack post-idle -> atk")

  -- 6) death -> death (priorité absolue, écrase l'atk)
  A.alive = false
  arena.bus:emit("death", A)
  assert(rd.anim[A].state == "death", "death écrase atk -> death")

  -- 7) LATCH : aucun évènement ne relance une unité morte (ni hit, ni attack)
  arena.bus:emit("hit", B, A)
  assert(rd.anim[A].state == "death", "hit après mort : reste death (latch)")
  arena.bus:emit("attack", A)
  assert(rd.anim[A].state == "death", "attack après mort : reste death (latch)")

  -- 8) la mort NE retombe JAMAIS en idle, même au-delà de DEATH_DUR (figée à son âge ; ph plafonnée à 1 dans draw)
  for _ = 1, DUR.death + 30 do rd:update(1.0, 1) end
  assert(rd.anim[A].state == "death", "death ne retombe pas en idle (latch après DEATH_DUR)")
  local deadAge = rd.dead[A]
  assert(deadAge and deadAge > 0, "dead fade age avance")

  -- 8b) spawned/summon preserve : le vrai callback bus ne doit PAS relancer le fade des cadavres.
  arena.bus:emit("spawned", arena.units)
  assert(rd.anim[A] and rd.anim[A].state == "death", "spawned preserve garde le latch death")
  assert(rd.dead[A] == deadAge, "spawned preserve garde l'âge du fade de mort")

  -- 9) rebuild() purge l'état d'anim (nouveau combat -> table vierge)
  rd:rebuild()
  assert(next(rd.anim) == nil, "rebuild purge self.anim")

  print("  arena_anim : attack->atk / hit interrompt atk / atk n'écrase pas hurt / retour idle / death latch OK")
end)

if ok then
  print("=> ARENA_ANIM OK.")
else
  print("=> ARENA_ANIM FAIL : " .. tostring(err))
  os.exit(1)
end
