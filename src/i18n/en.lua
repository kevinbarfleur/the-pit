-- src/i18n/en.lua
-- Locale ANGLAISE (langue par défaut & fallback). Table PLATE clé -> chaîne. Tout le texte affiché du
-- jeu vit ici. Ajouter une langue = copier ce fichier en `src/i18n/<code>.lua` et traduire les valeurs
-- (garder les clés et les marqueurs {name} ; ils sont réordonnables). Chaînes en ASCII (police LÖVE).
--
-- Conventions de clés : ui.* (chrome/HUD/boutons), scene.* (titres), result.*, runover.*, type.*,
-- shape.<sigil>.{label,archetype}, encounter.<key>.name, unit.<id>.{name,passive_name,passive_desc}.

return {
  -- meta
  ["ui.empty"] = "",

  -- chrome / HUD
  ["ui.title"] = "THE PIT",
  ["ui.quit"] = "[esc] quit",
  ["ui.fps"] = "FPS {n}",
  ["scene.build"] = "build",
  ["scene.combat"] = "combat",
  ["scene.runover"] = "run over",
  ["ui.hint_build"] = "[click-drag] buy/place  -  REROLL/LEVEL  -  [s] sigil  -  FIGHT",
  ["ui.hint_combat"] = "auto-battle in progress...",
  ["ui.hint_combat_end"] = "[click] back to build   [r] replay",
  ["ui.hint_runover"] = "[click] new run   -   [r] new run",

  -- build / shop
  ["ui.fight"] = "FIGHT",
  ["ui.reroll"] = "REROLL {n}g",
  ["ui.level_up"] = "LEVEL {n}g",
  ["ui.level_max"] = "MAX LEVEL",
  ["ui.cost"] = "{n}g",
  ["ui.hud"] = "GOLD {gold}    LIVES {lives}/{maxlives}    WINS {wins}/{target}    ROUND {round}    LEVEL {level} ({slots}/{maxslots} slots)",
  ["ui.win_streak"] = "WIN STREAK x{n}",
  ["ui.loss_streak"] = "LOSS STREAK x{n}",
  ["ui.placed_count"] = "{placed} placed  -  {active}/9 slots",
  ["ui.sigil_header"] = "{label}  -  {archetype}",

  -- tooltip
  ["ui.unit_header"] = "{name}  ({type})",
  ["ui.unit_stats"] = "HP {hp}    DMG {dmg}    CD {cd}",

  -- combat
  ["ui.vs"] = "vs  {name}",
  ["result.victory"] = "VICTORY",
  ["result.defeat"] = "DEFEAT",

  -- run over
  ["runover.win"] = "ASCENSION",
  ["runover.lose"] = "THE PIT KEEPS YOU",
  ["runover.stats"] = "{wins} wins  -  {losses} losses  -  {rounds} rounds  -  level {level}",

  -- unit types (clé mécanique -> libellé affiché)
  ["type.flesh"] = "Flesh",
  ["type.order"] = "Order",
  ["type.bone"] = "Bone",
  ["type.arcane"] = "Arcane",
  ["type.abyss"] = "Abyss",

  -- sigils (formes de plateau)
  ["shape.carre.label"] = "Novice's Square",
  ["shape.carre.archetype"] = "versatile",
  ["shape.croix.label"] = "Cross Sigil",
  ["shape.croix.archetype"] = "mono-carry",
  ["shape.anneau.label"] = "Ring Sigil",
  ["shape.anneau.archetype"] = "chain",
  ["shape.diamant.label"] = "Diamond Sigil",
  ["shape.diamant.archetype"] = "go-wide",
  ["shape.ligne.label"] = "Conduit Sigil",
  ["shape.ligne.archetype"] = "conduit",

  -- encounters (IA de seed)
  ["encounter.fallen_patrol.name"] = "FALLEN PATROL",
  ["encounter.drowned_choir.name"] = "DROWNED CHOIR",
  ["encounter.brood.name"] = "BROOD",

  -- units : nom + passif (nom & description). Mécanique = src/data/units.lua (effects).
  ["unit.marauder.name"] = "MARAUDER",
  ["unit.marauder.passive_name"] = "Brutality",
  ["unit.marauder.passive_desc"] = "+8 damage on its first strike of the fight.",
  ["unit.templar.name"] = "TEMPLAR",
  ["unit.templar.passive_name"] = "Bulwark",
  ["unit.templar.passive_desc"] = "Combat start: +14 shield to adjacent neighbors.",
  ["unit.skeleton.name"] = "SKELETON",
  ["unit.skeleton.passive_name"] = "Broken Bones",
  ["unit.skeleton.passive_desc"] = "Returns 3 damage to each attacker that strikes it.",
  ["unit.bandit.name"] = "BANDIT",
  ["unit.bandit.passive_name"] = "Nimble",
  ["unit.bandit.passive_desc"] = "Fast cadence (short cooldown). No notable passive.",
  ["unit.witch.name"] = "WITCH",
  ["unit.witch.passive_name"] = "Venom",
  ["unit.witch.passive_desc"] = "Its strikes poison: 2 dmg/s for 3s.",
  ["unit.demon.name"] = "DEMON",
  ["unit.demon.passive_name"] = "Leech",
  ["unit.demon.passive_desc"] = "Heals for 50% of damage dealt.",

  -- units à effets (familles de statuts)
  ["unit.spore_tick.name"] = "SPORE TICK",
  ["unit.spore_tick.passive_name"] = "Infestation",
  ["unit.spore_tick.passive_desc"] = "Fast strikes stack poison: 1 dmg/s for 3s each. Poison ignores shields.",
  ["unit.corruptor.name"] = "CORRUPTOR",
  ["unit.corruptor.passive_name"] = "Defilement",
  ["unit.corruptor.passive_desc"] = "Poison stacks that also weaken the target's output (-6% per stack).",
  ["unit.emberling.name"] = "EMBERLING",
  ["unit.emberling.passive_name"] = "Kindling",
  ["unit.emberling.passive_desc"] = "Strikes burn (6 dmg/s) but the flame decays. Burn licks shields.",
  ["unit.razorkin.name"] = "RAZORKIN",
  ["unit.razorkin.passive_name"] = "Hemorrhage",
  ["unit.razorkin.passive_desc"] = "Strikes bleed (2 dmg/s) and slow the target's attack by 20%.",
  ["unit.rot_hound.name"] = "ROT HOUND",
  ["unit.rot_hound.passive_name"] = "Necrosis",
  ["unit.rot_hound.passive_desc"] = "Rot that swells while maintained and gnaws away max HP.",
  ["unit.stormcaller.name"] = "STORMCALLER",
  ["unit.stormcaller.passive_name"] = "Conduction",
  ["unit.stormcaller.passive_desc"] = "Stacks shock: the target takes +7% damage per shock stack.",
  ["unit.plague_doctor.name"] = "PLAGUE DOCTOR",
  ["unit.plague_doctor.passive_name"] = "Ward",
  ["unit.plague_doctor.passive_desc"] = "Regenerates 3 HP/s at combat start — outlasts damage over time.",

  -- wave 1 : T1 enablers (burn / bleed / poison / rot)
  ["unit.cinder_cur.name"] = "CINDER CUR",
  ["unit.cinder_cur.passive_name"] = "Ember Coat",
  ["unit.cinder_cur.passive_desc"] = "Fast strikes burn (4 dmg/s) and keep rekindling. Burn licks shields.",
  ["unit.pyre_tender.name"] = "PYRE TENDER",
  ["unit.pyre_tender.passive_name"] = "Bonfire",
  ["unit.pyre_tender.passive_desc"] = "Slow, heavy strikes ignite a fierce burn (10 dmg/s) that decays.",
  ["unit.ash_moth.name"] = "ASH MOTH",
  ["unit.ash_moth.passive_name"] = "Cinders",
  ["unit.ash_moth.passive_desc"] = "Cheap strikes burn (7 dmg/s) but the flame fades fast.",
  ["unit.gash_fiend.name"] = "GASH FIEND",
  ["unit.gash_fiend.passive_name"] = "Deep Cut",
  ["unit.gash_fiend.passive_desc"] = "Strikes bleed (3 dmg/s) and slow the target's attack by 20%.",
  ["unit.hookjaw.name"] = "HOOKJAW",
  ["unit.hookjaw.passive_name"] = "Hamstring",
  ["unit.hookjaw.passive_desc"] = "Light bleed (1 dmg/s) but a heavy 30% attack slow — pure tempo control.",
  ["unit.leech_thorn.name"] = "LEECH THORN",
  ["unit.leech_thorn.passive_name"] = "Barbed",
  ["unit.leech_thorn.passive_desc"] = "Strikes bleed (2 dmg/s) and returns 3 damage to attackers.",
  ["unit.bile_spitter.name"] = "BILE SPITTER",
  ["unit.bile_spitter.passive_name"] = "Acrid",
  ["unit.bile_spitter.passive_desc"] = "Poison stacks (2 dmg/s) that also weaken the target's output by 10% each.",
  ["unit.rot_grub.name"] = "ROT GRUB",
  ["unit.rot_grub.passive_name"] = "Lingering Venom",
  ["unit.rot_grub.passive_desc"] = "Long-lasting poison stacks (2 dmg/s for 5s). Poison ignores shields.",
  ["unit.carrion_pecker.name"] = "CARRION PECKER",
  ["unit.carrion_pecker.passive_name"] = "Quick Rot",
  ["unit.carrion_pecker.passive_desc"] = "Fast strikes swell rot quickly, but it caps low (6 dmg/s).",
  ["unit.maggot_king.name"] = "MAGGOT KING",
  ["unit.maggot_king.passive_name"] = "Teeming",
  ["unit.maggot_king.passive_desc"] = "Slow to start, but rot swells high (up to 12 dmg/s) over a long fight.",
  ["unit.necro_leech.name"] = "NECRO LEECH",
  ["unit.necro_leech.passive_name"] = "Atrophy",
  ["unit.necro_leech.passive_desc"] = "Rot that gnaws away a heavy share of max HP (35% of rot damage).",
}
