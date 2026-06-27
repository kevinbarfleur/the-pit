-- src/data/abominations.lua
-- Catalogue des boss PvE/endgame issus de docs/generation/generateur-abominations.html.
-- DATA pure : aucune dependance love.*, aucune logique de rendu. Le rendu procedural
-- reste pour l'instant dans le generateur HTML ; cette table donne au lab une version
-- mecanique simulable : un boss de scoring + trois generaux tuables qui bloquent le focus.

local Abominations = {}

local function E(trigger, op, params)
  return { trigger = trigger, op = op, params = params or {} }
end

local function boss(id, hp, dmg, cd, effects, extra)
  extra = extra or {}
  extra.id = "abom_" .. id .. "_boss"
  extra.role = "boss"
  extra.hp = hp
  extra.dmg = dmg
  extra.cd = cd
  extra.aggro = extra.aggro or 25
  extra.effects = effects
  return extra
end

local function general(id, hp, dmg, cd, effects, extra)
  extra = extra or {}
  extra.id = "abom_" .. id
  extra.role = "general"
  extra.hp = hp
  extra.dmg = dmg
  extra.cd = cd
  extra.aggro = extra.aggro or 35
  extra.effects = effects
  return extra
end

Abominations.list = {
  {
    key = "leviathan",
    name = "Leviathan des Abysses",
    theme = "flesh",
    accent = "#9a5a8e",
    intent = "attrition poison/rot avec corps qui se soigne pendant que les tentacules occupent le front",
    boss = boss("leviathan", 1800, 8, 96, {
      E("on_hit", "poison", { dps = 2, dur = 180, weaken = 0.04 }),
      E("on_hit", "lifesteal", { frac = 0.25 }),
    }, { dmgReduce = 0.08 }),
    generals = {
      general("lev_spawn", 120, 4, 50, { E("on_death", "summon", { token = "spiderling" }) }),
      general("lev_carapace", 175, 3, 78, { E("on_attacked", "thorns", { value = 3 }) }, { taunt = true, dmgReduce = 0.10, shield = 10 }),
      general("lev_floater", 115, 4, 62, { E("on_hit", "rot", { base = 1, growth = 1, dur = 180, capDps = 7, maxHpFrac = 0.08 }) }),
    },
  },
  {
    key = "regard",
    name = "Le Regard",
    theme = "eye",
    accent = "#ff4a4a",
    intent = "marque les cibles puis les ouvre aux explosions de choc",
    boss = boss("regard", 1700, 9, 76, {
      E("on_hit", "shock", { add = 2, volt = 5, cap = 8, dur = 210 }),
      E("on_hit", "grant_vuln", { value = 0.12, dur = 150 }),
    }),
    generals = {
      general("eye_watcher", 140, 4, 64, { E("combat_start", "grant_team", { markEnemiesVuln = 0.10 }) }, { aggro = 20 }),
      general("eye_tear", 120, 7, 52, { E("on_hit", "grant_vuln", { value = 0.18, dur = 120 }) }),
      general("eye_crawler", 165, 5, 48, { E("on_hit", "shock", { add = 1, cap = 6, dur = 150 }) }, { haste = 0.08 }),
    },
  },
  {
    key = "ossuaire",
    name = "Le Roi-Os",
    theme = "bone",
    accent = "#cfd0c0",
    intent = "mur defensif qui teste le sustain et les counters anti-tank",
    boss = boss("ossuary", 2300, 7, 96, {
      E("on_attacked", "thorns", { value = 5 }),
      E("combat_start", "regen", { value = 2 }),
    }, { dmgReduce = 0.18, shield = 40 }),
    generals = {
      general("bone_reaper", 150, 9, 78, { E("on_attack", "execute", { threshold = 0.30, bonus = 0.60 }) }),
      general("bone_crawler", 180, 5, 58, { E("on_attacked", "thorns", { value = 4 }) }, { dmgReduce = 0.10 }),
      general("bone_guard", 260, 4, 84, {}, { taunt = true, dmgReduce = 0.24, shield = 35 }),
    },
  },
  {
    key = "kraken",
    name = "Souverain des Profondeurs",
    theme = "sea",
    accent = "#5af0e0",
    intent = "controle par slow et arcs de choc, faible contre burst rapide des generaux",
    boss = boss("kraken", 1750, 7, 84, {
      E("on_hit", "shock", { add = 1, volt = 5, cap = 7, dur = 180, chain = 1 }),
      E("on_hit", "bleed", { dps = 1, dur = 180, slowPct = 0.08 }),
    }),
    generals = {
      general("krak_strangler", 140, 3, 56, { E("on_hit", "bleed", { dps = 1, dur = 180, slowPct = 0.16 }) }),
      general("krak_swimmer", 115, 5, 48, { E("on_hit", "shock", { add = 1, cap = 5, dur = 150 }) }, { haste = 0.06 }),
      general("krak_angler", 130, 5, 68, { E("on_hit", "grant_vuln", { value = 0.12, dur = 120 }) }),
    },
  },
  {
    key = "idole",
    name = "L'Idole Profanee",
    theme = "sacred",
    accent = "#fff0a0",
    intent = "boucliers et invulnerabilite courte, punis par strip shield et scaling long",
    boss = boss("idol", 2100, 8, 90, {
      E("combat_start", "grant_team", { invulnT = 90 }),
      E("combat_start", "regen", { value = 2 }),
    }, { shield = 60, dmgReduce = 0.12 }),
    generals = {
      general("idol_knight", 240, 5, 82, {}, { taunt = true, shield = 45, dmgReduce = 0.18 }),
      general("idol_seraph", 130, 6, 58, { E("combat_start", "grant_team", { markEnemiesVuln = 0.08 }) }, { haste = 0.10 }),
      general("idol_reliquary", 190, 3, 100, { E("combat_start", "regen", { value = 3 }) }, { shield = 30 }),
    },
  },
  {
    key = "ruche",
    name = "La Reine-Mere",
    theme = "hive",
    accent = "#9aff3a",
    intent = "adds et poison, bon test pour les builds cleave/spread",
    boss = boss("broodmother", 1750, 6, 90, {
      E("on_hit", "poison", { dps = 1, dur = 150, spread = { dps = 1, dur = 90 } }),
      E("combat_start", "grant_team", { poisonDurBonus = 30 }),
    }),
    generals = {
      general("hive_soldier", 145, 4, 54, { E("on_death", "summon", { token = "spiderling" }) }, { taunt = true }),
      general("hive_winged", 105, 4, 46, { E("on_hit", "poison", { dps = 1, dur = 120 }) }, { haste = 0.08 }),
      general("hive_burrower", 135, 4, 68, { E("on_death", "summon", { token = "grubling" }) }, { dmgReduce = 0.08 }),
    },
  },
  {
    key = "brasier",
    name = "Le Seigneur du Brasier",
    theme = "burn",
    accent = "#ff6a1a",
    intent = "front-load de burn puis propagation, demande de tuer vite ou de survivre au feu",
    boss = boss("emberlord", 1700, 9, 86, {
      E("on_hit", "burn", { dps = 5, dur = 150, decayPct = 0.20 }),
    }),
    generals = {
      general("cinder_hound", 115, 5, 56, { E("on_hit", "burn", { dps = 3, dur = 150 }) }, { haste = 0.06 }),
      general("ash_wraith", 105, 4, 66, { E("on_death", "spread_burn_on_death", { frac = 0.55, minDps = 3, dur = 100 }) }),
      general("magma_brute", 180, 6, 92, { E("on_attacked", "thorns", { value = 2 }) }, { taunt = true, dmgReduce = 0.08 }),
    },
  },
  {
    key = "floraison",
    name = "La Floraison",
    theme = "mycelium",
    accent = "#5affc8",
    intent = "hybride poison/rot qui recompense les builds capables de gerer plusieurs afflictions",
    boss = boss("mycelium", 1950, 7, 82, {
      E("on_hit", "poison", { dps = 2, dur = 210, weaken = 0.08 }),
      E("on_hit", "rot", { base = 1, growth = 1, dur = 240, capDps = 10, maxHpFrac = 0.12 }),
    }, { dmgReduce = 0.08 }),
    generals = {
      general("spore_walker", 145, 4, 54, { E("on_hit", "poison", { dps = 2, dur = 180 }) }),
      general("cap_beast", 215, 5, 76, { E("combat_start", "regen", { value = 2 }) }, { taunt = true }),
      general("rot_crawler", 150, 5, 58, { E("on_hit", "rot", { base = 1, growth = 1, dur = 210, capDps = 8, maxHpFrac = 0.10 }) }),
    },
  },
  {
    key = "devoreur",
    name = "Le Devoreur",
    theme = "void",
    accent = "#c04aff",
    intent = "menace de removal et execute, bon juge de survie post-victoire",
    boss = boss("devourer", 2000, 9, 88, {
      E("on_attack", "percent_hp_strike", { frac = 0.08, cap = 12 }),
      E("on_attack", "execute", { threshold = 0.28, bonus = 0.50 }),
    }, { strikeHighestHp = true }),
    generals = {
      general("gnasher", 135, 8, 56, { E("on_attack", "execute", { threshold = 0.30, bonus = 0.50 }) }),
      general("grasper", 170, 5, 66, { E("on_hit", "grant_vuln", { value = 0.18, dur = 150 }) }, { taunt = true }),
      general("void_mote", 120, 5, 46, { E("on_hit", "shock", { add = 1, volt = 5, cap = 6, dur = 180 }) }, { haste = 0.10 }),
    },
  },
  {
    key = "vermine",
    name = "Le Grand Ver",
    theme = "worm",
    accent = "#ff5a7a",
    intent = "anti-tank long, mord les PV max et force un vrai DPS soutenu",
    boss = boss("greatworm", 2400, 8, 100, {
      E("on_attack", "percent_hp_strike", { frac = 0.10, cap = 12 }),
      E("on_hit", "rot", { base = 2, growth = 1, dur = 240, capDps = 12, maxHpFrac = 0.18 }),
    }, { dmgReduce = 0.10, strikeHighestHp = true }),
    generals = {
      general("lamprey", 135, 5, 48, { E("on_hit", "lifesteal", { frac = 0.30 }) }, { haste = 0.08 }),
      general("grub", 190, 4, 64, { E("on_death", "summon", { token = "grubling" }) }, { taunt = true }),
      general("burrow_tick", 155, 5, 58, { E("on_hit", "rot", { base = 1, growth = 1, dur = 210, capDps = 8, maxHpFrac = 0.10 }) }),
    },
  },
}

Abominations.order = {}
Abominations.byKey = {}
for _, a in ipairs(Abominations.list) do
  Abominations.order[#Abominations.order + 1] = a.key
  Abominations.byKey[a.key] = a
end

return Abominations
