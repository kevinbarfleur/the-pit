-- src/i18n/en_ext.lua
-- EXTENSION de la locale EN — clés ajoutées HORS de en.lua (édité en parallèle par un autre chantier)
-- pour éviter tout conflit d'édition concurrent. Fusionné dans la locale "en" par src/core/i18n.lua
-- (fusion ADDITIVE : ne remplace jamais une clé existante de en.lua). À REFONDRE dans en.lua plus tard.
--
-- Contenu : chaînes des nouvelles unités CHOC (ladder) & BOUCLIER (cf. src/data/units.lua).

return {
  -- ── CHOC (ladder) ──
  ["unit.live_wire.name"]         = "LIVE WIRE",
  ["unit.live_wire.passive_name"] = "Spasm",
  ["unit.live_wire.passive_desc"] = "Quick jolts stack shock: the target takes +5% damage per stack (up to 5).",

  ["unit.thunderhead.name"]         = "THUNDERHEAD",
  ["unit.thunderhead.passive_name"] = "Stormbreak",
  ["unit.thunderhead.passive_desc"] = "Slow, heavy blows stack shock: +12% damage per stack (up to 6).",

  ["unit.static_swarm.name"]         = "STATIC SWARM",
  ["unit.static_swarm.passive_name"] = "Gathering Charge",
  ["unit.static_swarm.passive_desc"] = "Builds lasting shock: +6% damage per stack, piling as high as 12.",

  ["unit.galvanizer.name"]         = "GALVANIZER",
  ["unit.galvanizer.passive_name"] = "Live Current",
  ["unit.galvanizer.passive_desc"] = "+6 damage on its first strike. Each blow stacks 2 shock (+8% per stack, up to 8) - then feasts on it.",

  ["unit.stormlord.name"]         = "STORMLORD",
  ["unit.stormlord.passive_name"] = "Overload",
  ["unit.stormlord.passive_desc"] = "Each strike stacks 2 shock (+10% per stack, up to 16): marks a prey for the whole pack.",

  -- ── BOUCLIER ──
  ["unit.shieldbearer.name"]         = "SHIELDBEARER",
  ["unit.shieldbearer.passive_name"] = "Huddle",
  ["unit.shieldbearer.passive_desc"] = "Combat start: +6 shield to adjacent neighbors. Draws blows onto itself.",

  ["unit.aegis_warden.name"]         = "AEGIS WARDEN",
  ["unit.aegis_warden.passive_name"] = "Bone Aegis",
  ["unit.aegis_warden.passive_desc"] = "Taunt: forces the enemy front to strike it. +10 shield to neighbors; returns 4 damage to attackers.",

  ["unit.oath_keeper.name"]         = "OATH KEEPER",
  ["unit.oath_keeper.passive_name"] = "Warding Oath",
  ["unit.oath_keeper.passive_desc"] = "Combat start: +18 shield to adjacent neighbors.",

  ["unit.bulwark_acolyte.name"]         = "BULWARK ACOLYTE",
  ["unit.bulwark_acolyte.passive_name"] = "Shared Faith",
  ["unit.bulwark_acolyte.passive_desc"] = "Combat start: +8 shield to every adjacent neighbor.",

  -- ── Proving Ground : nouvel archétype + filtre + compos & scénarios choc/bouclier ──
  ["pg.archetype.shield"] = "Shield",
  ["pg.filter.all"]       = "All",

  ["comp.shock_storm_carre.note"] = "Pile shock on a durable target, then a heavy hitter punishes the amplified prey.",
  ["comp.bulwark_carre.note"]     = "Overlapping shield auras blanket the board; the taunt wall soaks while carries hide behind.",

  ["scenario.shock_vs_tank.label"]      = "Conduction",
  ["scenario.shock_vs_tank.note"]       = "Shock stacks climb on a wall that survives long enough to feel every amplified blow.",
  ["scenario.shock_vs_bruiser.label"]   = "Overload",
  ["scenario.shock_vs_bruiser.note"]    = "An amplified burst race: whoever marks the prey first wins the exchange.",
  ["scenario.bulwark_vs_bruiser.label"] = "Bulwark",
  ["scenario.bulwark_vs_bruiser.note"]  = "Stacked shields absorb a fast bruiser rush - watch the cyan wards drain blow by blow.",
}
