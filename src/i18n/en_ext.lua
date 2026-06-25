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

  -- ── Tags de filtre thématiques (facette transversale du Proving Ground) ──
  ["pg.tag.spread"] = "Spread",
  ["pg.tag.cross"]  = "Cross",
  ["pg.tag.tempo"]  = "Control",
  ["pg.tag.vfx"]    = "Showcase",
  ["pg.tag.mirror"] = "Mirror",

  -- ── Équipes « joueur » : notes de composition ──
  ["comp.spread_showcase.note"]        = "Four plagues braided into one ring - every hit, every death seeds the next throat; watch the contagion crawl the wall.",
  ["comp.poison_amp_croix.note"]       = "One carrier crowned at the cross's heart, drowned in amplifiers - uncapped venom that no flesh outlasts.",
  ["comp.burn_conduit_ligne.note"]     = "A trench of fire that refuses to die down - every spark is kept, extended, fanned, until the whole front is ash.",
  ["comp.bleed_lock_anneau.note"]      = "They never get to swing - slowed to a crawl and bled for every twitch, the enemy dies of its own stillness.",
  ["comp.rot_patient_carre.note"]      = "Outlast, then outlive - the maggots feast slow and certain while their flesh simply runs out beneath them.",
  ["comp.cross_venom_pyre.note"]       = "Venom curdles into flame, flame rots back into venom - a wound that feeds on its own infection.",
  ["comp.shock_nuke_croix.note"]       = "All current funneled to one throat - the storm marks its prey, then every coil empties at once.",
  ["comp.fortress_thorns_carre.note"]  = "A wall that bites back - every blow spent on the bulwark is paid in the striker's own blood.",
  ["comp.swarm_wide_diamant.note"]     = "No champion, only the mob - a dozen small fires lit at once, each fed a little, all of it lethal together.",

  -- ── Équipes « joueur » : labels + notes de scénarios ──
  ["scenario.transmission.label"]     = "Four Plagues",
  ["scenario.transmission.note"]      = "All four spread carriers against a clustered brawler line - poison leaps on every hit, while fire and rot vault from each fresh corpse to its neighbors.",
  ["scenario.amp_vs_wall.label"]      = "Acid & Iron",
  ["scenario.amp_vs_wall.note"]       = "Uncapped amplified venom tests whether a thorn-fortress can outlast a poison that ignores every stack limit.",
  ["scenario.conduit_vs_swarm.label"] = "Trench Fire",
  ["scenario.conduit_vs_swarm.note"]  = "A single perpetual line of flame against a wide mob of cheap sparks - focused permanence vs scattered breadth.",
  ["scenario.lockdown.label"]         = "Stillness",
  ["scenario.lockdown.note"]          = "Pure tempo denial vs a burst nuke - can the storm discharge before it is slowed into silence?",
  ["scenario.inevitable.label"]       = "Slow Rot",
  ["scenario.inevitable.note"]        = "Patient rot that wins late vs a fire that wins now - a race between an early blaze and inevitable decay.",
  ["scenario.infection_loop.label"]   = "Curdled",
  ["scenario.infection_loop.note"]    = "Poison detonating into fire and fire seeding poison, looping across a clustered wall - cross-family spread on display.",
  ["scenario.nuke_vs_fortress.label"] = "Coil & Bulwark",
  ["scenario.nuke_vs_fortress.note"]  = "A focused condenser burst hammered into a reflecting taunt-wall - does the thorn wall punish the discharge?",
  ["scenario.plague_mirror.label"]    = "Two Throats",
  ["scenario.plague_mirror.note"]     = "Amplified mono-carry venom against the four-plague ring - two poison philosophies, same end.",
  ["scenario.attrition_clash.label"]  = "Rot & Ruin",
  ["scenario.attrition_clash.note"]   = "Two cross-family attrition engines grind into each other - whichever loop sustains longest collapses the other.",
  ["scenario.swarm_vs_lock.label"]    = "Mob & Chains",
  ["scenario.swarm_vs_lock.note"]     = "A wide cheap mob throws bodies into a tempo-lock - does breadth beat the slow, or drown in its own blood?",

  -- ── Boucliers périodiques (caster + renforts + counter) ──
  ["unit.ward_weaver.name"]            = "WARD WEAVER",
  ["unit.ward_weaver.passive_name"]    = "Recurring Ward",
  ["unit.ward_weaver.passive_desc"]    = "Every 4s, casts a 20 shield onto adjacent allies - again and again, not just once.",
  ["unit.barrier_savant.name"]         = "BARRIER SAVANT",
  ["unit.barrier_savant.passive_name"] = "Honed Wards",
  ["unit.barrier_savant.passive_desc"] = "Strengthens an adjacent ward-caster: +50% shield value and casts 25% faster.",
  ["unit.mirror_ward.name"]            = "MIRROR WARD",
  ["unit.mirror_ward.passive_name"]    = "Spite Glass",
  ["unit.mirror_ward.passive_desc"]    = "An adjacent ward-caster's shields reflect 40% of absorbed damage and reach one ring further.",
  ["unit.surge_warden.name"]           = "SURGE WARDEN",
  ["unit.surge_warden.passive_name"]   = "Overcharge",
  ["unit.surge_warden.passive_desc"]   = "An adjacent ward-caster's unspent shields pile up (to 2x) instead of refreshing; +50% value.",
  ["unit.siege_breaker.name"]          = "SIEGE BREAKER",
  ["unit.siege_breaker.passive_name"]  = "Sunder",
  ["unit.siege_breaker.passive_desc"]  = "Each strike dissolves half the target's shield - made to crack walls.",

  -- ── Compos & duels boucliers périodiques ──
  ["comp.ward_fortress_carre.note"] = "A wall that rebuilds itself - wards re-cast every few seconds, biting back and swelling beyond breaking.",
  ["comp.siege_carre.note"]         = "Hammers built to break walls - every blow sunders the shield before the flesh.",
  ["scenario.ward_wall.label"]      = "Living Wall",
  ["scenario.ward_wall.note"]       = "Periodic wards re-dress the front over and over, reflecting blows - watch the cyan pulses and the spite-sparks on the attacker.",
  ["scenario.breach.label"]         = "Breach",
  ["scenario.breach.note"]          = "The same-batch counter: sunder-strikes dissolve the periodic wards faster than they can re-cast.",

  -- ── Modificateurs rares du choc ──
  ["unit.dynamo_priest.name"]         = "DYNAMO PRIEST",
  ["unit.dynamo_priest.passive_name"] = "Conduction",
  ["unit.dynamo_priest.passive_desc"] = "When a charge discharges, half its stacks leap to a neighbor - the shock spreads instead of ending.",
  ["unit.arc_warden.name"]            = "ARC WARDEN",
  ["unit.arc_warden.passive_name"]    = "Forked Bolt",
  ["unit.arc_warden.passive_desc"]    = "Discharges arc to 2 nearby foes for 60% of the burst - a charge that cleans a line.",
  ["unit.storm_anchor.name"]          = "STORM ANCHOR",
  ["unit.storm_anchor.passive_name"]  = "Held Charge",
  ["unit.storm_anchor.passive_desc"]  = "The charge never fully empties - half the stacks remain after each discharge, a relentless current.",

  -- ── Compo & duel modificateurs de choc ──
  ["comp.shock_arc_carre.note"]     = "A storm that forks and lingers - charges chain across the line, leap to neighbors, and never fully discharge.",
  ["scenario.arc_storm.label"]      = "Forked Storm",
  ["scenario.arc_storm.note"]       = "Rare shock modifiers on show: discharges chain to nearby foes, charges leap to neighbors, and never fully drain.",

  -- ── Run-over (CTA forge de relance) : libellé court du bouton-œil « descendre à nouveau » ──
  ["runover.descend"] = "DESCEND AGAIN",

  -- ── Barre du bas du BUILD (kit forge) : labels SANS le coût (le coût va dans le diamant du bouton éco) ──
  ["ui.reroll_label"] = "REROLL",
  ["ui.refuse_label"] = "REFUSE",
  ["ui.lives_orb"]    = "LIVES {n}/{max}", -- compteur au-dessus de l'orbe de vie
  ["ui.merge_to_lvl"] = "LVL {n}", -- badge brillant boutique : niveau ATTEINT si l'achat déclenche une fusion (duplicatas)

  -- ── Fiche monstre TCG (carte au survol, src/scenes/build.lua) : rôles (tank/carry/bruiser) + tags ──
  -- Le rôle est DÉRIVÉ d'aggro/taunt (taunt OU aggro>=30 -> TANK ; aggro<=7 -> CARRY ; sinon BRUISER).
  ["kw.role.tank"]    = "TANK",
  ["kw.role.carry"]   = "CARRY",
  ["kw.role.bruiser"] = "BRUISER",
  ["kw.chimera"]      = "CHIMERA", -- corps composite (bodyplan composé) ; tag pur
  ["card.rank"]       = "RANK {n}/5",

  -- ── Mots-clés d'AFFLICTION (chips icône+nom : registre src/ui/keywords.lua, consommés par carte/codex/reliques) ──
  ["kw.poison.name"]  = "POISON",
  ["kw.poison.blurb"] = "Stacking venom - damage over time that also weakens the victim's blows.",
  ["kw.bleed.name"]   = "BLEED",
  ["kw.bleed.blurb"]  = "Open wounds - light damage over time that slows the victim's attacks.",
  ["kw.burn.name"]    = "BURN",
  ["kw.burn.blurb"]   = "Searing fire - heavy damage that fades as the flames die down.",
  ["kw.rot.name"]     = "ROT",
  ["kw.rot.blurb"]    = "Necrosis - damage over time that eats away the victim's maximum life.",
  ["kw.shock.name"]   = "SHOCK",
  ["kw.shock.blurb"]  = "Charge - stacks pile up, then discharge to amplify the next hit.",

  -- ── Étiquettes de stats FRAMELESS de la fiche monstre (src/scenes/build.lua:drawCardStats) ──
  ["ui.stat_hp"]  = "HP",
  ["ui.stat_dmg"] = "DMG",
  ["ui.stat_cd"]  = "CD",

  -- ── COMMANDANT (C4, UI ui-artisan) — piédestal hors-graphe + portée VISIBLE au survol (spec §4.2). ──
  -- L'étiquette de portée résolue depuis le `target` du commandBonus : qui l'aura touche, en clair.
  ["ui.command_word"]   = "COMMANDS",        -- préfixe de l'étiquette de portée (survol du piédestal)
  ["ui.command_pack"]   = "the whole pack",  -- target=team  (toute la meute pulse)
  ["ui.command_front"]  = "the vanguard",    -- target=role:front (la seule unité avant)
  ["ui.command_back"]   = "the rear-guard",  -- target=role:back
  ["ui.command_center"] = "the heart",       -- target=role:center
  ["ui.command_tier"]   = "tier-{n} beasts", -- target=tier:N (le Roi des Rats : rang 1)
  ["ui.command_level"]  = "level-{n} beasts", -- target=level:N (l'Aïeul : non-fusionnées)
  ["ui.command_none_short"] = "none in range", -- aura qui ne touche aucune unité posée (portée vide)
  ["ui.pedestal_label"] = "WARLORD",         -- libellé gravé du socle (au-dessus du piédestal)
  ["ui.pedestal_cadence"] = "SLOW CADENCE",  -- légende de la barre de cadence lente (sous le piédestal)
  ["ui.commander_tag"] = "COMMANDER",        -- repère de combat AU-DESSUS du chef qui supervise (sans barre de vie)

  -- ── W1 — AXE TYPE-IDENTITÉ (plan big-update §AXE 2) : 5 mono-type amps + 1 rainbow payoff + 3 reliques.
  -- Convention de valeur = celle du roster (atkInc/dmgReduce/haste en % car increased ; regen/dmg/hp en plat).
  ["unit.flesh_warband.name"]         = "FLESH WARBAND",
  ["unit.flesh_warband.passive_name"] = "Pack Fury",
  ["unit.flesh_warband.passive_desc"] = "Combat start: every Flesh ally strikes for +10% more - the warband bleeds together.",

  ["unit.bone_choir.name"]         = "BONE CHOIR",
  ["unit.bone_choir.passive_name"] = "Ossuary",
  ["unit.bone_choir.passive_desc"] = "Combat start: every Bone ally takes 8% less attack damage - bone on bone, nothing passes.",

  ["unit.arcane_seer.name"]         = "ARCANE SEER",
  ["unit.arcane_seer.passive_name"] = "Quickened Mind",
  ["unit.arcane_seer.passive_desc"] = "Combat start: every Arcane ally attacks 8% faster - the frequency of foreknowledge.",

  ["unit.abyss_maw.name"]         = "ABYSS MAW",
  ["unit.abyss_maw.passive_name"] = "Tidal Venom",
  ["unit.abyss_maw.passive_desc"] = "Combat start: every Abyss ally's poison bites 15% deeper - the venom of the deep obeys.",

  ["unit.order_marshal.name"]         = "ORDER MARSHAL",
  ["unit.order_marshal.passive_name"] = "Standing Order",
  ["unit.order_marshal.passive_desc"] = "Combat start: every Order ally regenerates 2 HP/s - the empire mends its own ranks.",

  ["unit.prism_horror.name"]         = "PRISM HORROR",
  ["unit.prism_horror.passive_name"] = "Foreign Flesh",
  ["unit.prism_horror.passive_desc"] = "Combat start: gains +2 damage and +4 HP for each distinct type on your board - every alien flesh feeds it.",

  -- reliques type-identité (mono-type gating + rainbow team payoff)
  ["relic.pack_blood.name"]   = "PACK BLOOD",
  ["relic.pack_blood.effect"] = "Your Flesh beasts strike for +8% more.",
  ["relic.pack_blood.flavor"] = "One scent, one hunger; the meat-things move as a single starving thing.",

  ["relic.bile_orb.name"]   = "BILE ORB",
  ["relic.bile_orb.effect"] = "Your Abyss beasts' poison bites 12% deeper.",
  ["relic.bile_orb.flavor"] = "A globe of standing black water; everything drowned in it learns to drown others.",

  ["relic.prismatic_wraith.name"]   = "PRISMATIC WRAITH",
  ["relic.prismatic_wraith.effect"] = "Each beast gains +3 damage and +5 HP per distinct type on your board.",
  ["relic.prismatic_wraith.flavor"] = "It wears every nature at once, and none of them fit; the seams are where it cuts.",

  -- COMMANDANT (« At command » sur la fiche) des 6 unités W1 (clés requises par tests/commanders.lua + i18n).
  ["unit.flesh_warband.command_name"]   = "THE PACK CROWNED",
  ["unit.flesh_warband.command_desc"]   = "Its foremost killer strikes for +12% more.",
  ["unit.flesh_warband.command_flavor"] = "Lashed together hide to hide, the warband finds one throat to feed, and feeds it first.",
  ["unit.bone_choir.command_name"]   = "THE WALLED CHOIR",
  ["unit.bone_choir.command_desc"]   = "The whole pit takes 6% less.",
  ["unit.bone_choir.command_flavor"] = "A scaffold of singing bone; under its dirge the whole pit hardens to a single ossuary.",
  ["unit.arcane_seer.command_name"]   = "THE OPENED EYE",
  ["unit.arcane_seer.command_desc"]   = "The whole pit strikes 6% faster.",
  ["unit.arcane_seer.command_flavor"] = "It saw the blow before the arm rose; on its foreknowledge the whole pit moves the quicker.",
  ["unit.abyss_maw.command_name"]   = "THE DROWNING TIDE",
  ["unit.abyss_maw.command_desc"]   = "The pit's venom bites 18% deeper.",
  ["unit.abyss_maw.command_flavor"] = "A maw that opens onto black water; under it, every venom in the pit drinks the deeper.",
  ["unit.order_marshal.command_name"]   = "THE STANDING ORDER",
  ["unit.order_marshal.command_desc"]   = "The whole pit mends 2 HP each second.",
  ["unit.order_marshal.command_flavor"] = "It does not bleed so much as repair; under its order the whole pit closes its own wounds.",
  ["unit.prism_horror.command_name"]   = "THE SHATTERED LIGHT",
  ["unit.prism_horror.command_desc"]   = "The unit at the heart strikes for +12% more.",
  ["unit.prism_horror.command_flavor"] = "Every nature refracts through it onto the one it crowns at the center; the heart of the pit cuts brightest.",
}
