# Creature Identity Map — spec de la Phase B (renommer vers le visuel)

> **Décision créateur (2026-06-24)** : les sprites procéduraux sont **canon** (« godlike, on n'y
> touche plus »). On **adapte nom + lore + effets** pour matcher le visuel. Ce doc = la spec de
> travail. Données `RENDERS-AS` **calculées en exécutant le vrai générateur** (`creaturegen.lua`
> FNV-1a + hash nombre-d'or), pas devinées.

## Protocole par unité (ordre strict)
1. **PIN** — pour toute unité à famille **dérivée** (sans `family=` aujourd'hui), écrire
   `family = "<famille actuelle>"` dans `src/data/units.lua`. Verrouille le sprite (sinon changer
   les effets déplace le sprite via `deriveFamily`). **Golden-neutre** (la `family` est lue par le
   générateur, jamais par la SIM). Vérifier golden inchangé + screenshot d'un échantillon.
2. **RENOMME + RELORE** — nouveau nom + flavor collant au sprite, dans `src/i18n/en.lua`
   (`unit.<id>.name` / `.lore`). **Golden-neutre.** Garder l'`id` mécanique inchangé.
3. **RÉ-ADAPTE EFFETS** — re-thématiser l'effet vers le visuel **en gardant la famille mécanique/
   le rôle** quand possible (préserve l'équilibre + les synergies de type M4). **Sim-gated** :
   `luajit tools/sim.lua N` après chaque batch + golden rebaseline + entrée GOLDEN-LOG.

## Comment le sprite est choisi (pour PIN correctement)
`CreatureGen.cached{id,type,effects,rank,family}` → si `family=` présent : **bypass** ; sinon
`deriveFamily(type, effects, id)` = (pole du `type`) ∩ (lean de l'affliction du 1er effet), puis
`hashId("fam."..id)`. Archetype = `hashId("arch."..id)`, palette = `hashId("palette."..id)`,
seed per-arch = `hashId(id)`. **41 familles, 93 archetypes.** Tant que l'`id` ne change pas,
archetype+palette+seed sont stables ; **pin `family=` à la famille listée ci-dessous** suffit à
geler le sprite exact.

`TYPE → POLE de familles` : arcane→{cauchemar,oeil,cristal,golem,spore,plante,cocon,chimere} ·
abyss→{demon,cephalo,abyssal,kraken,gelatine,hydre,meduse,ombre,culte,aile} ·
bone→{mortvivant,spectre,crane,pendu,wendigo,larve,annelide} ·
flesh→{bete,canide,bandit,rongeur,colosse,reptile,echassier,crustace,arachnide} ·
order→{templier,inquisiteur,seraphin,griffon,automate,insecte,essaim}.

## Collisions d'archetype (plusieurs unités → même silhouette ; à arbitrer au réveil)
- **heron** : pyre_tender, ash_moth, gash_fiend
- **cocoon** : witch, miasma_acolyte, plague_bearer, venom_censer
- **marionette** : maggot_king, decay_tender, patient_worm
- **throne** (roue d'yeux ardente) : templar, shieldbearer, ward_weaver
- **revenant** : skeleton, gravewarden, husk
- **possessed** : ash_maw, plague_pyre · **anglerfish** : demon, static_swarm, arc_warden
- **shade** : necro_leech, marrow_drinker · **reef** : acid_maw, ink_horror
- **eyecluster** : stormcaller, thunderhead, dynamo_priest

> Pour les collisions, mitiger par **palette/seed** (déjà distincts) ; ne PAS réassigner la famille
> (= toucher au visuel). Si une collision reste laide, la **lister au réveil** pour décision créateur.

## Table par unité (83) — `id | nom actuel | rk | type | effet | RENDERS-AS | mismatch`
`*` = `family=` déjà forcé (sprite déjà verrouillé, pas de PIN à ajouter).

| id | nom | rk | type | effet | RENDERS-AS (famille/archetype — look) | mismatch |
|---|---|---|---|---|---|---|
| marauder | MARAUDER | 1 | flesh | +8 first strike | crustace/**crab** — carapace large, pinces, yeux pédonculés | SEVERE |
| templar | TEMPLAR | 3 | order | shield aura | seraphin/**throne** — roue d'yeux ardente (Ophanim) | SEVERE |
| skeleton | SKELETON | 1 | bone | thorns 3 | mortvivant/**revenant** — cadavre voûté pourrissant | MILD |
| bandit | BANDIT | 1 | flesh | none | crustace/**mantisshrimp** — plaques, pinces-marteau | SEVERE |
| witch | WITCH | 2 | arcane | poison 2/180 | cocon/**cocoon** — sac d'œufs fibreux, fente lumineuse | SEVERE |
| demon | DEMON | 1 | abyss | lifesteal 0.4 | abyssal/**anglerfish** — mâchoire abyssale + leurre | SEVERE |
| spore_tick | SPORE TICK | 1 | arcane | poison stacks | spore/**myconid** — colonie de champignons | none |
| corruptor | CORRUPTOR | 3 | abyss | poison+weaken | kraken/**kraken** — léviathan à tentacules+bec | MILD |
| emberling | EMBERLING | 2 | abyss | burn 6 | demon/**serpent** — naga démoniaque cornu | MILD |
| razorkin | RAZORKIN | 2 | flesh | bleed+slow | bete/**direcat** — grand félin à crocs | MILD |
| rot_hound | ROT HOUND | 2 | bone | rot | larve/**grub** — asticot en C bouffi | SEVERE |
| stormcaller | STORMCALLER | 2 | arcane | shock stacks | oeil/**eyecluster** — amas d'yeux flottant | SEVERE |
| plague_doctor | PLAGUE DOCTOR | 3 | order | regen 3 | essaim/**hive** — nuée d'insectes | SEVERE |
| cinder_cur | CINDER CUR | 2 | abyss | burn rekindle | culte/**hierophant** — prêtre robé cornu | SEVERE |
| pyre_tender | PYRE TENDER | 2 | flesh | burn 10 | echassier/**heron** — échassier décharné à bec-dague | SEVERE |
| ash_moth | ASH MOTH | 1 | flesh | burn fades | echassier/**heron** — échassier (collision heron) | SEVERE |
| gash_fiend | GASH FIEND | 2 | flesh | bleed+slow | echassier/**heron** — échassier (collision heron) | SEVERE |
| hookjaw | HOOKJAW | 2 | flesh | heavy slow bleed | bete/**behemoth** — quadrupède cornu massif | MILD |
| leech_thorn | LEECH THORN | 3 | bone | bleed+thorns | wendigo/**wendigo** — humanoïde décharné à crâne de cerf | SEVERE |
| bile_spitter | BILE SPITTER | 3 | arcane | poison+weaken | plante/**maweed** — gueule-fleur sur tige | MILD |
| rot_grub | ROT GRUB | 2 | abyss | poison long | hydre/**hydra** — corps à 4 cous-serpents | SEVERE |
| carrion_pecker | CARRION PECKER | 1 | flesh | rot fast | colosse/**cyclops** — brute borgne massive | SEVERE |
| maggot_king | MAGGOT KING | 3 | bone | rot high cap | pendu/**marionette** — pantin de bois à fils | SEVERE |
| necro_leech | NECRO LEECH | 3 | abyss | rot heavy | ombre/**shade** — silhouette noire encapuchonnée | MILD |
| soot_acolyte | SOOT ACOLYTE | 3 | arcane | aura +burn dps | chimere/**chimera** — amalgame à 3 têtes | SEVERE |
| clot_mender | CLOT MENDER | 3 | bone | aura grant bleed | wendigo/**wendigo** — décharné à bois | SEVERE |
| miasma_acolyte | MIASMA ACOLYTE | 3 | arcane | aura +poison dps | cocon/**cocoon** — sac d'œufs (collision cocoon) | SEVERE |
| decay_tender | DECAY TENDER | 3 | bone | aura +rot growth | pendu/**marionette** — pantin (collision marionette) | SEVERE |
| bellows_priest | BELLOWS PRIEST | 3 | abyss | burn slow-decay | culte/**cultist** — cultiste robé encapuchonné | none |
| wildfire_hound | WILDFIRE HOUND | 4 | abyss | burn+spread-death | demon/**fiend** — démon dressé cornu | MILD |
| kiln_warden | KILN WARDEN | 4 | flesh | burn extend | colosse/**ogre** — brute top-lourde | MILD |
| bloodletter | BLOODLETTER | 4 | flesh | bleed rupture x2 | echassier/**strider** — échassier à pattes-échasses | SEVERE |
| tendon_render | TENDON RENDER | 4 | bone | bleed slow scales | wendigo/**wendigo** — décharné à bois | MILD |
| vein_splitter | VEIN SPLITTER | 3 | flesh | deep bleed | bandit/**cutthroat** — voyou à dagues | none |
| plague_bearer | PLAGUE BEARER | 4 | arcane | poison contagion | cocon/**cocoon** — sac d'œufs (collision cocoon) | SEVERE |
| acid_maw | ACID MAW | 3 | abyss | poison eats shield | cephalo/**reef** — bulbe-anémone à gueule + tentacules | none |
| patient_worm | PATIENT WORM | 4 | bone | rot ramp | pendu/**marionette** — pantin (collision marionette) | SEVERE |
| hollow_gut | HOLLOW GUT | 4 | abyss | rot heals self | gelatine/**blobmonster** — blob à yeux internes | MILD |
| blight_spreader | BLIGHT SPREADER | 4 | bone | rot+spread-death | pendu/**hanged** — pendu à la corde | SEVERE |
| ash_maw | ASH-MAW | 5 | abyss | team burn no-decay | culte/**possessed** — robé à tentacule+œil | MILD |
| plague_pyre | PLAGUE-PYRE | 5 | abyss | burn→poison death | culte/**possessed** — robé tentaculaire (collision) | MILD |
| slow_bleed | THE SLOW BLEED | 5 | bone | team slow+bleed | wendigo/**wendigo** — décharné à bois | MILD |
| marrow_drinker | MARROW DRINKER | 5 | abyss | bleed→rot convert | ombre/**shade** — silhouette noire (collision shade) | MILD |
| festering | THE FESTERING | 5 | arcane | team poison no-cap | cauchemar/**fleshcrawler** — mille-pattes de chair | none |
| venom_censer | VENOM CENSER | 5 | arcane | poison→ignite | cocon/**cocoon** — sac d'œufs (collision cocoon) | SEVERE |
| pit_maw | THE PIT-MAW | 5 | bone | team rot creep | larve/**grub** — asticot géant en C | MILD |
| wither_bloom | WITHER BLOOM | 5 | abyss | rot+slow+weaken | ombre/**voidmaw** — disque de vide plein d'yeux | MILD |
| gravewarden | GRAVEWARDEN | 4 | bone | taunt+thorns | mortvivant/**revenant** — cadavre voûté (collision) | none |
| live_wire | LIVE WIRE | 1 | arcane | shock fast | oeil/**eyeswarm** — constellation d'yeux | SEVERE |
| thunderhead | THUNDERHEAD | 2 | arcane | shock dense | oeil/**eyecluster** — amas d'yeux (collision) | MILD |
| static_swarm | STATIC SWARM | 2 | abyss | shock long | abyssal/**anglerfish** — poisson abyssal (collision) | SEVERE |
| galvanizer | GALVANIZER | 4 | flesh | first-strike+shock | rongeur/**ratking** — nœud de 6 rats | SEVERE |
| stormlord | STORMLORD | 3 | arcane | shock marks | cristal/**crystalcluster** — géode hérissée | MILD |
| dynamo_priest | DYNAMO PRIEST | 4 | arcane | shock transfer | oeil/**eyecluster** — amas d'yeux (collision) | SEVERE |
| arc_warden | ARC WARDEN | 4 | abyss | shock chain | abyssal/**anglerfish** — poisson abyssal (collision) | SEVERE |
| storm_anchor | STORM ANCHOR | 3 | arcane | shock persist | cristal/**shardwalker** — biped cristallin | MILD |
| shieldbearer | SHIELDBEARER | 2 | order | shield aura | seraphin/**throne** — roue d'yeux (collision throne) | SEVERE |
| aegis_warden | AEGIS WARDEN | 4 | bone | shield+thorns+taunt | mortvivant/**skeletonquad** — quadrupède osseux | SEVERE |
| oath_keeper | OATH KEEPER | 4 | order | big shield aura | templier/**paladin** — chevalier à halo+épée | none |
| bulwark_acolyte | BULWARK ACOLYTE | 3 | arcane | shield aura | golem/**golem** — golem de pierre runique | MILD |
| ward_weaver | WARD WEAVER | 4 | order | periodic shield | seraphin/**throne** — roue d'yeux (collision throne) | SEVERE |
| barrier_savant | BARRIER SAVANT | 4 | order | aura +shield/cdr | templier/**paladin** — chevalier à halo (collision) | MILD |
| mirror_ward | MIRROR WARD | 4 | order | aura reflect | seraphin/**seraph** — ange à halo multi-ailes | MILD |
| surge_warden | SURGE WARDEN | 4 | order | aura overcharge | griffon/**hippogriff** — quadrupède ailé à bec | SEVERE |
| siege_breaker | SIEGE BREAKER | 3 | flesh | strip shield+dmg | canide/**wolf** — loup quadrupède | MILD |
| chitin_drone | CHITIN DRONE | 2 | order | poison | insecte*/**insectoid** — insecte segmenté mandibulé | none |
| bore_worm | BORE WORM | 2 | bone | rot | annelide*/**leech** — ver annelé à gueule-anneau | none |
| wailing_shade | WAILING SHADE | 2 | bone | bleed+slow | spectre*/**wraith** — fantôme qui s'efface | none |
| pyre_herald | PYRE HERALD | 2 | abyss | burn | culte*/**cultist** — cultiste robé | none |
| byakhee | BYAKHEE | 2 | abyss | bleed+slow | aile*/**harpy** — voltigeur à ailes de plumes | MILD |
| zeal_inquisitor | ZEAL INQUISITOR | 2 | order | burn | inquisiteur*/**inquisitor** — mitre+halo+fléau | none |
| coil_viper | COIL VIPER | 2 | flesh | poison | reptile*/**coilserpent** — serpent lové | none |
| web_recluse | WEB RECLUSE | 2 | flesh | poison | arachnide*/**spider** — araignée 8 pattes | none |
| siphon_jelly | SIPHON JELLY | 2 | abyss | shock | meduse*/**jelly** — méduse à filaments | none |
| skull_colossus | SKULL COLOSSUS | 5 | bone | burn 4 | crane*/**skullking** — crâne colossal incandescent | none |
| rust_sentinel | RUST SENTINEL | 4 | order | shock | automate*/**reliquary** — automate-reliquaire à cœur | none |
| runestone_golem | RUNESTONE GOLEM | 4 | arcane | shield aura | golem*/**golem** — golem runique | none |
| ink_horror | INK HORROR | 2 | abyss | poison | cephalo*/**reef** — anémone à tentacules (collision reef) | none |
| deep_kraken | DEEP KRAKEN | 5 | abyss | poison | kraken*/**kraken** — léviathan (collision kraken) | none |
| husk | HUSK | 1 | bone | none | mortvivant*/**revenant** — cadavre voûté (collision) | none |
| gnaw_rat | GNAW-RAT | 1 | flesh | micro bleed | rongeur*/**ratgiant** — rat géant voûté | none |
| footman | FOOTMAN | 1 | order | none | automate*/**automaton** — robot riveté à cœur | MILD |
| mire_thing | MIRE THING | 1 | abyss | none | gelatine*/**blobmonster** — blob à yeux (collision) | none |

**Bilan** : ~32 SEVERE, ~23 MILD, ~28 none. Les `none`/`*` = les 30 unités à `family=` forcé (vague
v7 + plancher rang-1) + quelques tirages chanceux (festering, vein_splitter, acid_maw, bellows_priest,
oath_keeper). Les SEVERE = unités à famille **dérivée** (6 vanilla + vagues DoT + ladder choc + bloc
shield/ward) où la famille vient d'un hash type+affliction sans rapport au nom.

**Régénérer la table** : `luajit /tmp/pit_render_map.lua` depuis la racine (recalcule RENDERS-AS) —
ou mieux, via le harnais PNG (voir NIGHT-PLAN) pour **voir** réellement chaque sprite.
