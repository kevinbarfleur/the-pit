# The Pit — Plan de contenu des effets (refonte unités, step 9)

> **Statut** : PLAN DE CONTENU autoritaire pour le re-mapping des effets du roster (~83 unités).
> Document de DESIGN — **aucun code Lua ici**. Il guide l'implémentation par vagues de
> `src/data/units.lua` (spec §8.2 step 9) et la passe i18n des passifs.
>
> **Sources réconciliées** (lues ligne-à-ligne, 2026-06-24) :
> - `docs/base-game/creature-identity-map.md` — **la vérité VISUELLE** (RENDERS-AS = canon, on n'y touche plus).
> - `docs/base-game/creature-renames.md` — noms + lore canon.
> - `docs/research/effects-overhaul-spec.md` — §2 vocabulaire agnostique, §3 familles=thèmes, §4 tiers, §9.3 cible d'archétypes.
> - `src/data/units.lua` — stats/effets/rangs ACTUELS (source mécanique).
> - **Moteur vérifié** : `src/effects/ops.lua` (tous les new-ops agnostiques **déjà câblés + gated**),
>   `src/scenes/build.lua` (handler `aura_stat` K1 **câblé** : `haste/atkInc/dmgReduce/regen/multicast/
>   lifesteal/statInc` × `neighbors/role:front|back|center/team/tier:N/level:N`).
>
> **Principe directeur (spec §3)** : *les enablers s'empilent → 1-2 carries massacrent*. Chaque thème
> = **2-3 enablers** (DoT/base) · **1 amplificateur agnostique** (empower/vuln/hâte/multicast) ·
> **1-2 carries amplifiables** · **1 support/contre**.
>
> **Contraintes gravées** (spec §2.0, §4, sigils gelés) : sigils GELÉS → tension de placement ancrée
> sur le **CARRÉ 3×3** (centre 4 voisins / bord 3 / coin 2) + axe front/back du ciblage. Aucun design
> dépendant d'une forme de sigil. `MULTICAST_MAX=3`, empower ≤+150 %, vuln ≤+50 %. Tous chiffres =
> **PLACEHOLDERS** (à tuner via `tools/sim.lua`). Bas tier faible / haut tier fort.

---

## 0. Note méthodo — re-thématisation visuel → mécanique

La spec §3 a écrit sa table de familles sur des **ids mécaniques** et des familles **inventées**
(« Burn/Forge », « Bleed/Bêtes »…) qui ne correspondent **PAS** aux vraies familles visuelles du
générateur. Critique du journal §11 (M4) : il faut **réconcilier** avec les RENDERS-AS canon.

**Décision de ce plan** : on regroupe les unités en **9 thèmes mécaniques** dont le **liant est
visuel ET mécanique** (pas la `family` du générateur, qui est un détail de sprite). Le visuel impose
le *flavor* et le *rôle plausible* ; la mécanique préserve l'équilibre (familles DoT existantes +
ladder de tiers). Exemple canonique de la consigne : un AMAS D'YEUX (`stormcaller`) reste **choc +
marque** (visuel = orage d'yeux ⇒ shock/vuln) ; un SAC D'ŒUFS couveur (`witch`) reste **poison +
contagion** (visuel = couvain ⇒ poison) ; une ANGLERFISH à leurre (`demon`/`static_swarm`/`arc_warden`)
gagne **lifesteal + aggro/taunt** (le leurre *attire*).

**Garde-fou équilibre** : on **garde la famille DoT mécanique** de chaque unité quand elle en a une
(`U.dotFamily` reste valide — c'est le « type » des synergies de draft) ; on ne déplace que le
**verbe agnostique greffé** (empower/vuln/multicast/hâte/execute/cleave/heal_on_kill/grant) vers l'unité dont
le visuel le justifie. Donc les 5 familles DoT (burn/bleed/poison/rot/shock) **survivent intactes** ;
ce plan **ajoute** la couche agnostique manquante (spec §1.3) en la posant sur les bons visuels.

---

## 1. Réconciliation FAMILLES = THÈMES (9 thèmes, visuel + méca + rôle de synergie)

Chaque thème respecte le squelette spec §3 : enablers · 1 amplificateur agnostique · carry(s) · support/contre.
La colonne « liant visuel » justifie le regroupement par RENDERS-AS canon (pas par `family` générateur).

### T1 — LE BÛCHER (Burn / robés-prêtres & bûchers ardents)
**Liant visuel** : robés cornus, hiérophantes, échassiers-bûcherons, crânes incandescents, démons de lave.
**Identité méca** : brûlure (burst décroissant) ; l'amplificateur natif = **hâte-aura** (forger plus vite = rallumer).
- **Enablers** : `pyre_herald` (CULTE/cultiste robé), `zeal_inquisitor` (mitre+halo+fléau), `ash_moth` (échassier maigre, feu éphémère), `cinder_cur` (refresh cadence).
- **Amplificateur agnostique** : `bellows_priest` (cultiste robé = le *soufflet*) → **hâte-aura** `haste` team/neighbors (spec §3 « Hâte-aura sur bellows_priest »).
- **2e accès empower (v2)** : `zeal_inquisitor` (mitre+halo+fléau, rk 2 = prêtre-guerrier qui exhorte) → `aura_stat atkInc 0.12 neighbors`. Donne un point d'accès empower **early** (rang distinct de maggot_king rk 3).
- **Carry amplifiable** : `pyre_tender` (échassier-bûcheron, gros front-load), `skull_colossus` (crâne colossal ardent = carry HP+burn + **heal-on-kill v2**).
- **Support/contre** : `cinder_cur` (re-allumage) ; purge anti-feu réservée à un support cross-thème (`plague_doctor`).
- **HAUT** : `ash_maw` (robé tentaculaire = *les braises éternelles*, `grant_team burnNoDecay`).

### T2 — LES BÊTES SAIGNANTES (Bleed / fauves & échassiers à lames)
**Liant visuel** : félins à crocs, béhémoths cornus, échassiers à bec-rasoir, loups, harpies.
**Identité méca** : saignement cumulatif + slow ; l'amplificateur natif = **multicast-aura** (la bête qui frappe en rafale — l'exemple-fondateur de l'user).
- **Enablers** : `razorkin` (direcat à crocs), `gash_fiend` (héron bec-rasoir), `byakhee` (harpie en piqué), `gnaw_rat` (micro-bleed, plancher).
- **Amplificateur agnostique** : `hookjaw` (GORE-BULL béhémoth = le maître de tempo) → **multicast-aura** sur le carry adjacent (`multicast` role/neighbors) **OU** hâte ; cf. §5 Q-multicast-host.
- **Carry amplifiable** : `bloodletter` (DAGGERBEAK, rupture ×2), `vein_splitter` (cutthroat à dagues, bleed profond).
- **Support/contre** : `tendon_render` (slow scale aux PV manquants = contrôle).
- **HAUT** : `slow_bleed` (THE GAUNT VERDICT, wendigo = `grant_team slowEnemies`).

### T3 — LE COUVAIN (Poison / sacs d'œufs, plantes-gueules, serpents)
**Liant visuel** : cocons/sacs d'œufs fibreux, gueule-fleur sur tige, serpents lovés, araignées, anémones.
**Identité méca** : stacks de poison + weaken ; l'amplificateur natif = **vuln-on-hit** (marque la proie, tout passe ×).
- **Enablers** : `spore_tick` (myconid, empile vite), `coil_viper` (cobra), `web_recluse` (araignée), `chitin_drone` (insecte de ruche), `rot_grub` (hydre, longue durée), `ink_horror` (anémone-encre).
- **Amplificateur agnostique** : `corruptor` (KRAKEN, DROWNED BEAK = la marque) → **vuln-on-hit** `grant_vuln` (spec §3 « Vuln-on-hit sur corruptor »).
- **Carry amplifiable** : `witch` (BROODING SAC, apex glass-cannon dmg 13), `deep_kraken` (léviathan, dmg 12).
- **Support/contre** : `bile_spitter` (maweed, weaken pur) ; `acid_maw` (anémone, ronge le bouclier = contre-armure).
- **HAUT** : `festering` (mille-pattes de chair = `grant_team poisonNoCap`).

### T4 — LA POURRITURE (Rot / charognes, asticots, pantins, pendus)
**Liant visuel** : asticots en C, pantins de bois à fils, pendus, ombres encapuchonnées, cyclopes charognards.
**Identité méca** : rot qui enfle + ampute PVmax (attrition) ; amplificateur natif = **empower-aura** (le roi qui **ordonne aux frappeurs** — pas qui amplifie le rot ; cf. Q-empower-host).
- **Enablers** : `carrion_pecker` (cyclope charognard, cadence, **heal-on-kill v2**), `bore_worm` (ver-foreur), `rot_hound` (asticot, amputation), `decay_tender` (pantin, aura +growth existante).
- **Amplificateur agnostique** : `maggot_king` (THE STRUNG TYRANT, pantin-roi) → **empower-aura** `atkInc` neighbors. ⚠ **boost le dégât d'ATTAQUE des voisins-frappeurs, PAS le rot** — à placer au centre, entouré de carries d'attaque (bloodletter, pyre_tender, thunderhead), pas d'autres rot-poseurs.
- **Carry amplifiable** : `necro_leech` (ombre, amputation lourde), `patient_worm` (pantin, ramp passif).
- **Support/contre** : `hollow_gut` (blob, l'amputation le nourrit = sustain) ; `gravewarden` (cadavre voûté = tank/taunt du thème).
- **HAUT** : `pit_maw` (asticot géant = `grant_team rotEnemies`), `marrow_drinker` (ombre, `convert bleed→rot` = pivot croisé).

### T5 — LE CHŒUR D'ORAGE (Shock / amas d'yeux, géodes, anglerfish-leurres)
**Liant visuel** : amas/essaims/constellations d'yeux, géodes cristallines, automates à cœur, anglerfish abyssaux.
**Identité méca** : condensateur de choc (charge → décharge) ; le choc EST l'ampli natif (spec §3) ; on greffe **vuln/empower** au sommet.
- **Enablers** : `live_wire` (constellation d'yeux, cadence), `static_swarm` (anglerfish, patient), `siphon_jelly` (méduse), `storm_anchor` (cristal, persist).
- **Amplificateur agnostique** : `stormcaller` (STORMGLINT SHOAL, amas d'yeux = *là où il regarde, la foudre tombe*) → **vuln-on-hit** `grant_vuln` (le visuel « marque par le regard » = la marque) ; `stormlord` (géode) garde son volt+marque-de-choc.
- **Carry amplifiable** : `thunderhead` (amas d'yeux, charge dense burst), `galvanizer` (nœud de 6 rats, bruiser autonome first-strike+choc).
- **Support/contre** : `arc_warden` (anglerfish, chain = nettoyage de ligne), `dynamo_priest` (amas d'yeux, transfer), `rust_sentinel` (automate, choc+armure).
- **HAUT** : (différé — ladder choc non étendu, cf. §6) ; relique **Langue Fourchue** (`grant_team shockChain`) tient le rôle finisher.

### T6 — LA VIGILE DORÉE (Order / roues d'yeux, séraphins, golems, automates)
**Liant visuel** : roues d'yeux ardentes (Ophanim/throne), anges multi-ailes, golems runiques, automates rivetés, chevaliers à halo.
**Identité méca** : boucliers / tank / taunt (famille SUPPORT assumée, pas de carry égoïste — spec §3) ; amplificateur natif = **armure-aura + focus** ; counter de board = strip-shield.
- **Enablers (mur)** : `shieldbearer` (PALE OPHAN, aura cheap), `bulwark_acolyte` (golem, large), `runestone_golem` (golem, tank-support), `footman` (automate, plancher).
- **Amplificateur agnostique** : `templar` (THE GILDED VIGIL, roue d'yeux) → **armure-aura** `dmgReduce` neighbors (spec §3 « Armure-aura + focus-fire sur templar ») ; `barrier_savant` (chevalier, +valeur/cdr aux casters).
- **Carry amplifiable** : (assumé sans carry égoïste) ; `oath_keeper` (paladin halo+épée) sert de pilier offensif-défensif ; `rust_sentinel` mute vers T5 (choc) — laisser ici comme bruiser-tank order.
- **Support/contre** : `siege_breaker` (WALLBITER, loup = strip-shield) ; `ward_weaver`/`mirror_ward`/`surge_warden` (renforts de bouclier périodique) ; `aegis_warden` (stag osseux, tank+taunt).
- **HAUT** : `oath_keeper` (grosse aura) ; relique de bris-siège (commandant Bannière du Bris-Siège).

### T7 — LE LEURRE ABYSSAL (Lifesteal / sangsues, anglerfish, ombres, krakens)
**Liant visuel** : anglerfish à leurre, démons à fanal, ombres encapuchonnées, krakens, gélatines.
**Identité méca** : vol de vie + **attirer le focus** (le leurre *attire* — spec consigne) ; rôle = bruiser auto-suffisant + aggro/taunt douce.
- **Enablers/bruisers** : `demon` (LANTERN-GULLET anglerfish, lifesteal — le fanal qui attire ⇒ **+aggro**), `mire_thing` (blob, plancher).
- **Amplificateur agnostique** : `wither_bloom` (voidmaw, disque d'yeux = `rot+slow+weaken` croisé, l'usure totale) — sert de débuffeur de zone.
- **Carry amplifiable** : `corruptor`/`deep_kraken` partagés avec T3 (poison) ; `hollow_gut` (blob, sustain rot).
- **Support/contre** : `necro_leech` (ombre) ; `plague_doctor` (VIOLET SWARM, nuée = regen + **purge** anti-DoT = le contre du méta DoT).
- **HAUT** : `plague_pyre` (robé tentaculaire = croisé feu→poison à la mort).

### T8 — LES ROUAGES (Constructs / golems, automates, crânes, colosses — robustes)
**Liant visuel** : golems de pierre, automates-reliquaires, crânes colossaux, brutes top-lourdes, cyclopes.
**Identité méca** : stat-sticks robustes + **synergie-famille-à-l'achat** (spec §3) ; carry empower-payoff.
- **Enablers/stat-sticks** : `footman` (automate, plancher), `husk` (cadavre, plancher), `mire_thing` (blob, plancher), `bandit` (mantisshrimp, plancher hors-la-loi).
- **Amplificateur agnostique** : **synergie-famille-à-l'achat** (F-RunState, effet LOCAL v1) sur les constructs ; commandant **Le Roi des Rats** (tier:1 +stats) anticipé pour le payoff.
- **Carry amplifiable** : `runestone_golem` (golem, carry empower), `skull_colossus` (crâne colossal, carry HP+burn), `rust_sentinel` (automate).
- **Support/contre** : `kiln_warden` (ogre, burn extend = robustesse) ; `siege_breaker` (anti-bouclier).
- **HAUT** : (différé) ; payoff via reliques BAS « stats plates » empilées (spec §5.2).

### T9 — LES CRUSTACÉS / HORS-LA-LOI (Burst d'ouverture / crabes, mantes, bandits)
**Liant visuel** : crabes à pinces (marauder), mantisshrimp à pinces-marteau, voyous à dagues.
**Identité méca** : burst d'ouverture (`bonus_first`) ; amplificateur natif = **exécution** (déterministe — la pince qui achève le blessé, v2 remplace le crit RNG).
- **Enablers** : `bandit` (SUMP CLEAVER mantisshrimp, plancher hors-la-loi), `vein_splitter` (cutthroat — partagé T2).
- **Amplificateur agnostique** : `galvanizer` (déjà first-strike) → reste T5 choc ; l'**exécution** se pose sur `marauder` (`on_attack execute`, état pur, zéro RNG).
- **Carry amplifiable** : `marauder` (TIDEWRACK PINCER, crabe = burst carry first-strike + **execute** + armure de carapace).
- **Support/contre (v2)** : `siege_breaker` (loup, **cleave** = déchire la ligne en travers, seul hôte cleave v1) ouvre les murs = enabler de burst de zone.
- **HAUT** : (différé) ; relique Couronne d'Échos (multicast role:front) couronne le crabe carry.

**Le levier de tension de placement (spec §3)** : un carry (`witch` couvain / `thunderhead` orage /
`marauder` crabe) **veut** la portée de SON amplificateur (vuln de `corruptor` / vuln de `stormcaller`
/ execute + multicast) ET le bon nœud du carré (centre = 4 voisins). Construire le board = empiler le
plus d'enablers sur 1-2 carries au bon nœud. **C'est le dilemme visé.**

---

## 2. TABLE PAR UNITÉ (les ~83)

> Colonnes : `id | nom canon | rk | rôle | tier | NOUVEL effet (descripteur dans le vocabulaire dispo) | thème | accroche lore (visuel + nom)`.
> **rôle** = carry / tank / bruiser / support / enabler. **tier** = BAS (« hanté ») / MOYEN / HAUT.
> Descripteur = `{trigger, op, params, target}` en langage du moteur (ops.lua + aura_stat). « + » = effet conservé.
> `[CONSERVE]` = on garde l'effet actuel (déjà bon visuel+rôle). `[GREFFE]` = on ajoute la couche agnostique.

### 2.a — Les 6 vanille (sprites historiques + renommés)

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| marauder | TIDEWRACK PINCER | 1 | carry | MOYEN | `on_attack bonus_first {8}` [CONSERVE] + **`on_attack execute {threshold=0.25, bonus=0.60}`** [GREFFE v2 : la pince achève — déterministe, remplace le crit RNG] | T9 Crustacés | Crabe à pinces ; sa pince broie le blessé comme une coquille vide, et achève qui chancelle. |
| templar | THE GILDED VIGIL | 3 | support | MOYEN | **`combat_start aura_stat {stat=dmgReduce, value=0.12, target=neighbors}`** (remplace shield_aura → armure-aura) | T6 Vigile | Roue d'yeux dorés ; son regard tournoyant détourne les coups de ceux qu'elle veille. |
| skeleton | THE GREEN HUSK | 1 | enabler | BAS | `on_attacked thorns {3}` [CONSERVE] | T4 Pourriture | Cadavre gonflé d'eau qui rend coup pour coup, os contre os. |
| bandit | SUMP CLEAVER | 1 | enabler | BAS | stat-stick (vide) [CONSERVE] — plancher hors-la-loi | T9 Crustacés | Pince-marteau qui a fendu un heaume et mangé l'intérieur. |
| witch | THE BROODING SAC | 2 | carry | MOYEN | `on_hit poison {dps=2, dur=180}` [CONSERVE] — apex glass-cannon (dmg 13) | T3 Couvain | Sac d'œufs tiède ; là où sa lueur suinte, l'air tourne au poison. |
| demon | LANTERN-GULLET | 1 | bruiser | BAS | `on_hit lifesteal {0.4}` [CONSERVE] + **`aggro 25`** [GREFFE : le fanal attire] | T7 Leurre | Anglerfish ; sa petite lueur verte est une invitation, et la gueule attend dans le noir. |

### 2.b — Familles de statuts v0 (les 7 fondateurs)

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| spore_tick | SPORE TICK | 1 | enabler | BAS | `on_hit poison {dps=1, dur=180}` [CONSERVE] — empile vite | T3 Couvain | Colonie de champignons qui essaime ses spores au moindre contact. |
| corruptor | THE DROWNED BEAK | 3 | enabler | MOYEN | `on_hit poison {dps=2, dur=180, weaken=0.06}` [CONSERVE] + **`on_hit grant_vuln {value=0.15, dur=2}`** [GREFFE : la marque] | T3 Couvain | Léviathan vineux ; sa morsure rend la plaie trop fétide pour qu'on se défende. |
| emberling | EMBERLING | 2 | enabler | BAS-MOY | `on_hit burn {dps=6, dur=150}` [CONSERVE] | T1 Bûcher | Naga démoniaque cornu qui crache une braise qui lèche l'armure. |
| razorkin | RAZORKIN | 2 | enabler | BAS-MOY | `on_hit bleed {dps=2, dur=240, slowPct=0.20}` [CONSERVE] | T2 Bêtes | Grand félin à crocs ; une griffade ouvre et ralentit. |
| rot_hound | CRYPT-MAGGOT | 2 | enabler | MOYEN | `on_hit rot {base=1, growth=1, capDps=10, maxHpFrac=0.15}` [CONSERVE] | T4 Pourriture | Asticot lové en C, d'autant plus gras que le cadavre tient longtemps. |
| stormcaller | STORMGLINT SHOAL | 2 | enabler→ampli | MOYEN | `on_hit shock {add=1, cap=6}` [CONSERVE] + **`on_hit grant_vuln {value=0.12, dur=1.5}`** [GREFFE : là où il regarde, la foudre tombe] | T5 Orage | Amas d'yeux bleus dans son orage privé ; son regard appelle l'éclair. |
| plague_doctor | THE VIOLET SWARM | 3 | support | MOYEN | `combat_start regen {3}` [CONSERVE] + **`on_low_hp purge {scope=BORNÉE}`** [GREFFE v2 : contre anti-DoT *qui incline, pas efface* — retire -4 stacks OU 1 seule famille, jamais reset total ; déclenché à <50 % PV] | T7 Leurre | Nuée couronnée d'ailes ; quand on l'acule, elle recoud à la hâte une partie de ses plaies. |

### 2.c — Vague 1 : T1 enablers DoT (burn/bleed/poison/rot)

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| cinder_cur | THE EMBER HIEROPHANT | 2 | enabler | BAS-MOY | `on_hit burn {dps=4, dur=120, refresh=true}` [CONSERVE] | T1 Bûcher | Prêtre robé cornu, quatre charbons pour yeux ; sa bénédiction est une braise qui se rallume. |
| pyre_tender | THE KINDLING-STORK | 2 | carry | MOYEN | `on_hit burn {dps=10, dur=180}` [CONSERVE] — carry front-load | T1 Bûcher | Échassier décharné qui pose un feu profond et patient dans les tombés. |
| ash_moth | THE PALE WADER | 1 | enabler | BAS | `on_hit burn {dps=7, dur=120, decayPct=0.45}` [CONSERVE] — éphémère cheap | T1 Bûcher | Affamé des berges brûlées ; la flammèche qu'il allume meurt presque aussitôt. |
| gash_fiend | THE GREY SLITTER | 2 | enabler | BAS-MOY | `on_hit bleed {dps=3, dur=240, slowPct=0.20}` [CONSERVE] | T2 Bêtes | Bec en rasoir crochu ; un passage t'ouvre jusqu'à l'os. |
| hookjaw | THE GORE-BULL | 2 | bruiser→ampli | MOYEN | `on_hit bleed {dps=1, dur=300, slowPct=0.30}` [CONSERVE] + **`combat_start aura_stat {stat=multicast, value=1, target=role:front}`** [GREFFE : la bête en rafale — l'exemple-fondateur] | T2 Bêtes | Montagne de muscle et de corne ; elle te marche dessus et donne le rythme du carnage. |
| leech_thorn | THE ANTLERED FAMINE | 3 | enabler | MOYEN | `on_hit bleed {dps=2, slowPct=0.10}` + `on_attacked thorns {3}` [CONSERVE] | T2 Bêtes | Affamé à crâne de cerf qui porte en barbelure chaque plaie qu'il inflige. |
| bile_spitter | THE BILE SPITTER | 3 | support | MOYEN | `on_hit poison {dps=2, dur=180, weaken=0.10}` [CONSERVE] — weaken pur | T3 Couvain | Gueule-fleur sur tige qui crache une bile qui amollit la chair. |
| rot_grub | THE FOUR-MAWED CREEPER | 2 | enabler | BAS-MOY | `on_hit poison {dps=2, dur=300}` [CONSERVE] — longue durée | T3 Couvain | Quatre cous, quatre têtes, un venin si patient qu'il oublie de s'arrêter. |
| carrion_pecker | THE LONE-EYED GORGER | 1 | enabler | BAS-MOY | `on_hit rot {…, capDps=6, maxHpFrac=0.10}` [CONSERVE] + **`on_kill heal_on_kill {value=4}`** [GREFFE v2 : le charognard se repaît du cadavre] | T4 Pourriture | Une orbite pâle, aucun esprit derrière ; il dévore la carcasse qu'il a faite et s'en repaît. |
| maggot_king | THE STRUNG TYRANT | 3 | ampli | MOYEN-HAUT | `on_hit rot {…}` [CONSERVE] + **`combat_start aura_stat {stat=atkInc, value=0.20, target=neighbors}`** [GREFFE : empower-aura le roi qui ordonne] | T4 Pourriture | Pantin tyran pendu à des fils invisibles ; sa pourriture s'aggrave tant que joue la pièce. |
| necro_leech | THE HUSHED MOURNER | 3 | carry | MOYEN | `on_hit rot {…, maxHpFrac=0.35}` [CONSERVE] — amputation lourde | T4 Pourriture | Petit deuil noir des halles mortes ; ce qu'il touche, simplement, pourrit. |

### 2.d — Vague 2 : auras d'adjacence DoT (semeurs build-résolus)

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| soot_acolyte | THE THREE-HEADED PYRE | 3 | support | MOYEN | `combat_start aura_burn_dps {inc=0.5, target=neighbors}` [CONSERVE] | T1 Bûcher | Trois crânes partagent une fournaise, assez proches pour attiser le feu d'un voisin. |
| clot_mender | ANTLER WRAITH | 3 | support | MOYEN | `combat_start aura_grant_bleed {dps=1, slowPct=0.10, target=neighbors}` [CONSERVE] | T2 Bêtes | Il raboule l'air de ses bois d'os, et chaque plaie qu'il ouvre continue de pleurer. |
| miasma_acolyte | THE BILE SAC | 3 | support | MOYEN | `combat_start aura_poison_dps {inc=0.5, target=neighbors}` [CONSERVE] | T3 Couvain | Œuf vert gonflé qui vente sa pourriture par une couture qui suinte. |
| decay_tender | THE STRUNG SAINT | 3 | support | MOYEN | `combat_start aura_rot_growth {bonus=1, target=neighbors}` [CONSERVE] | T4 Pourriture | Pendu à sa propre croix, le pantin saint se jette sur toi par fils pourris. |

### 2.e — Vague 3 : T2 twists DoT

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| bellows_priest | BELLOWS PRIEST | 3 | ampli | MOYEN | `on_hit burn {dps=6, dur=180, decayPct=0.15}` [CONSERVE] + **`combat_start aura_stat {stat=haste, value=0.12, target=neighbors}`** [GREFFE : le soufflet — hâte-aura] | T1 Bûcher | Cultiste robé qui souffle sur les braises ; à côté de lui, les feux s'attisent et frappent plus vite. |
| wildfire_hound | THE WILDFIRE FIEND | 4 | enabler | MOYEN-HAUT | `on_hit burn {dps=5}` + `on_death spread_burn_on_death {…}` [CONSERVE] | T1 Bûcher | Démon corné ceint de lave ; là où sa proie brûle et tombe, le feu prend la suivante. |
| kiln_warden | KILN WARDEN | 4 | bruiser | MOYEN | `on_hit burn {dps=5, mode=extend_if_weaker}` [CONSERVE] | T8 Rouages | Brute top-lourde de four ; le surplus de chaleur prolonge au lieu de se perdre. |
| bloodletter | DAGGERBEAK | 4 | carry | MOYEN-HAUT | `on_hit bleed {dps=2, aggravateMult=2.0}` [CONSERVE] — carry rupture ×2 | T2 Bêtes | Échassier à pattes-échasses qui lance la moelle d'un bec aiguisé comme une lame. |
| tendon_render | THE SINEW-STAG | 4 | support | MOYEN | `on_hit bleed {dps=2, slowScalesMissingHp=true}` [CONSERVE] — contrôle | T2 Bêtes | Affamé à bois ; plus tu saignes, plus tu boites. |
| vein_splitter | VEIN SPLITTER | 3 | carry | MOYEN | `on_hit bleed {dps=4, dur=180, slowPct=0.15}` [CONSERVE] — bleed profond | T2 Bêtes / T9 | Voyou à dagues qui fait deux entailles d'un seul passage. |
| plague_bearer | THE WEEPING CHRYSALIS | 4 | enabler | MOYEN-HAUT | `on_hit poison {…, spread={dps=1, dur=120}}` [CONSERVE] — contagion | T3 Couvain | Cocon pourpre meurtri qui éclate et disperse la contagion sur tout ce qu'il touche. |
| acid_maw | ACID MAW | 3 | support | MOYEN | `on_hit poison {…, shieldEat=0.30}` [CONSERVE] — anti-bouclier | T3 Couvain | Anémone à gueule ; son venin dissout l'armure par couches. |
| patient_worm | THE HOLLOW MARIONETTE | 4 | carry | MOYEN-HAUT | `on_hit rot {…, passiveRamp=1}` [CONSERVE] — ramp passif | T4 Pourriture | Bien après que les fils auraient dû pourrir, le pantin de bois tressaille encore et attend. |
| hollow_gut | HOLLOW GUT | 4 | bruiser | MOYEN | `on_hit rot {…, amputateHealsMe=0.5}` [CONSERVE] — sustain | T4 / T7 | Blob aux yeux internes ; chaque plafond de vie qu'il ronge, il le boit. |
| blight_spreader | THE GALLOWS-HUNG | 4 | enabler | MOYEN-HAUT | `on_hit rot {…}` + `on_death spread_rot {…}` [CONSERVE] | T4 Pourriture | Pendu à une corde qui ne s'effiloche jamais ; la pourriture tombe avec lui. |

### 2.f — Vague 4 : T3 transforms / croisés (HAUT — réécrivent une règle)

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| ash_maw | THE VIOLET PYRE | 5 | carry | HAUT | `on_hit burn {…}` + `combat_start grant_team {burnNoDecay}` [CONSERVE] | T1 Bûcher | Robé sombre couronné d'yeux froids ; tant qu'il se tient là, tes feux ne s'éteignent jamais. |
| plague_pyre | THE VIOLET CONTAGION | 5 | enabler | HAUT | `on_hit burn {…}` + `on_death spread_burn_on_death {…, alsoPoison}` [CONSERVE] | T1 / T7 | Même robe sombre, mais quand son feu saute du mourant il sème un mal dans le vivant. |
| slow_bleed | THE GAUNT VERDICT | 5 | support | HAUT | `on_hit bleed {…}` + `combat_start grant_team {slowEnemies=0.12}` [CONSERVE] | T2 Bêtes | Juge à bois d'os et côtes nues ; au premier regard, tout le champ commence à céder. |
| marrow_drinker | THE COLD COMMUNION | 5 | carry | HAUT | `on_hit convert_to_rot {…}` [CONSERVE] — pivot croisé bleed→rot | T4 Pourriture | Deuil noir, un sigil au creux de la main ; il boit ton sang et ne rend que la pourriture. |
| festering | THE FESTERING | 5 | carry | HAUT | `on_hit poison {…}` + `combat_start grant_team {poisonNoCap, poisonDurBonus=60}` [CONSERVE] | T3 Couvain | Mille-pattes de chair ; sous lui le venin oublie sa limite et le temps. |
| venom_censer | THE EMBER-SAC | 5 | carry | HAUT | `on_hit poison {…, igniteAt=5, igniteBurst}` [CONSERVE] — détonation croisée | T3 / T1 | Sac d'œufs cendreux qui couve un charbon ; à cinq doses, la coque éclate en flammes. |
| pit_maw | THE PIT'S FIRSTBORN | 5 | support | HAUT | `on_hit rot {…}` + `combat_start grant_team {rotEnemies}` [CONSERVE] | T4 Pourriture | Asticot devenu vaste dans le noir, lové sur sa faim ; sa pourriture rampe sur tout ce qui s'approche. |
| wither_bloom | THE WITHERING GAZE | 5 | support | HAUT | `on_hit rot {…}` + `on_hit bleed {0 dps, slow}` + `on_hit poison {0 dps, weaken}` [CONSERVE] | T7 Leurre | Roue d'yeux rouges dans un trou du monde ; sous son regard tu ralentis, t'affaiblis, pourris. |

### 2.g — Tank, ladder choc, boucliers

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| gravewarden | GRAVEWARDEN | 4 | tank | MOYEN | `on_attacked thorns {4}` + `aggro 40, taunt=true` [CONSERVE] | T4 Pourriture | Cadavre voûté qui se dresse en sentinelle et défie le coup. |
| live_wire | SPAWN OF EYES | 1 | enabler | BAS | `on_hit shock {add=1, cap=5}` [CONSERVE] — cadence | T5 Orage | Humble grappe d'yeux rouges qui frémissent d'un seul mouvement et piquent où ils fixent. |
| thunderhead | THE RED CONGREGATION | 2 | carry | MOYEN | `on_hit shock {add=1, volt=6, cap=4}` [CONSERVE] — burst dense | T5 Orage | Nœud d'yeux rouges qui s'éveille en un tonnerre bas ; où ils te fixent, l'air craque. |
| static_swarm | LANTERN-GORGE | 2 | enabler | BAS-MOY | `on_hit shock {add=1, cap=8, dur=240}` [CONSERVE] — patient | T5 / T7 | Là où nulle lumière ne devrait porter, son leurre brille et ses mâchoires attendent. |
| galvanizer | THE KNOTTED SIX | 4 | bruiser | MOYEN-HAUT | `on_attack bonus_first {6}` + `on_hit shock {add=2, cap=6}` [CONSERVE] | T5 / T9 | Six rats fondus queue à queue, six yeux d'or, une couronne grouillante. |
| stormlord | THE STORMSPIRE | 3 | ampli | MOYEN | `on_hit shock {add=2, volt=4, cap=8}` [CONSERVE] — marque de choc | T5 Orage | Géode de verre violet qui bourdonne avant de mordre ; marque une proie et chaque coup pèse plus lourd. |
| dynamo_priest | THE BLUE CONGREGATION | 4 | support | MOYEN-HAUT | `on_hit shock {…, transfer=0.5}` [CONSERVE] | T5 Orage | Forme ailée sombre percée d'yeux bleus froids qui s'ouvrent d'un coup. |
| arc_warden | THE COLD LURE | 4 | support | MOYEN-HAUT | `on_hit shock {…, chain=2}` [CONSERVE] — nettoyage de ligne | T5 / T7 | Son fanal dérive devant comme un ami ; les mâchoires enchaînées suivent dans le noir. |
| storm_anchor | STORM ANCHOR | 3 | enabler | MOYEN | `on_hit shock {…, persist=0.5}` [CONSERVE] | T5 Orage | Biped cristallin qui retient la moitié de sa charge pour une pression continue. |
| shieldbearer | PALE OPHAN | 2 | support | BAS-MOY | `combat_start shield_aura {6, target=neighbors}` [CONSERVE] | T6 Vigile | Roue d'yeux froids sur ailes grises ; son regard détourne les coups. |
| aegis_warden | THE PALE STAG | 4 | tank | MOYEN-HAUT | `shield_aura {10}` + `thorns {4}` + `aggro 40, taunt` [CONSERVE] | T6 Vigile | Charpente d'os blanchis qui se dresse, bois levé, et provoque le coup. |
| oath_keeper | OATH KEEPER | 4 | support | MOYEN-HAUT | `combat_start shield_aura {18, target=neighbors}` [CONSERVE] — pilier | T6 Vigile | Chevalier à halo et épée ; sa grande garde tient la ligne. |
| bulwark_acolyte | WARDSTONE SENTINEL | 3 | support | MOYEN | `combat_start shield_aura {8, target=neighbors}` [CONSERVE] | T6 / T8 | Dalle de pierre runique grise qui s'éveille d'une froide lueur bleue et veille sur les siens. |
| ward_weaver | THE GILDED THRONE | 4 | support | MOYEN-HAUT | `combat_start shield_caster {value=20, cd=240, target=neighbors}` [CONSERVE] | T6 Vigile | Sur des ailes d'or battu trône un œil au bord rouge qui répare ce que la guerre a brisé. |
| barrier_savant | BARRIER SAVANT | 4 | support | MOYEN-HAUT | `combat_start aura_shield {valueInc=0.5, cdr=0.25, target=neighbors}` [CONSERVE] | T6 Vigile | Chevalier à halo qui renforce et accélère le tisseur de garde à ses côtés. |
| mirror_ward | MIRROR WARD | 4 | support | MOYEN-HAUT | `combat_start aura_shield {reflect=0.4, radius=true, target=neighbors}` [CONSERVE] | T6 Vigile | Ange à halo multi-ailes ; ce que le bouclier absorbe mord l'attaquant. |
| surge_warden | THE BEAKED COURSER | 4 | support | MOYEN-HAUT | `combat_start aura_shield {overcharge=true, valueInc=0.5, target=neighbors}` [CONSERVE] | T6 Vigile | Quadrupède ailé à bec et regard croisé qui fait s'accumuler les boucliers non consommés. |
| siege_breaker | WALLBITER | 3 | bruiser | MOYEN-HAUT | `on_hit strip_shield {0.5}` [CONSERVE] + **`on_hit cleave {frac=0.5}`** [GREFFE v2 : le SEUL hôte cleave v1 — déchire en travers la ligne, profondeur 1] | T6 / T9 | Loup gris maigre dressé à trouver la couture du mur et la déchirer d'un coup qui mord les flancs. |

### 2.h — Roster v7 (familles visuelles peuplées) + plancher rang-1

| id | nom canon | rk | rôle | tier | NOUVEL effet | thème | accroche lore |
|---|---|---|---|---|---|---|---|
| chitin_drone | CHITIN DRONE | 2 | enabler | BAS-MOY | `on_hit poison {dps=2, dur=160}` [CONSERVE] | T3 Couvain | Insecte segmenté mandibulé qui inocule le venin de ruche. |
| bore_worm | BORE WORM | 2 | enabler | BAS-MOY | `on_hit rot {base=1, growth=1, dur=210, capDps=8}` [CONSERVE] | T4 Pourriture | Ver annelé à gueule-anneau qui fore et digère. |
| wailing_shade | WAILING SHADE | 2 | enabler | BAS-MOY | `on_hit bleed {dps=2, dur=200, slowPct=0.15}` [CONSERVE] | T2 Bêtes | Fantôme qui s'efface, lacérant d'un froid coupant. |
| pyre_herald | PYRE HERALD | 2 | enabler | BAS-MOY | `on_hit burn {dps=6, dur=170}` [CONSERVE] | T1 Bûcher | Cultiste robé qui porte un bûcher noir au bout de ses doigts. |
| byakhee | BYAKHEE | 2 | enabler | BAS-MOY | `on_hit bleed {dps=3, dur=180, slowPct=0.10}` [CONSERVE] | T2 Bêtes | Voltigeur à ailes de plumes qui ouvre la chair en piqué. |
| zeal_inquisitor | ZEAL INQUISITOR | 2 | ampli | MOYEN | `on_hit burn {dps=5, dur=180}` [CONSERVE] + **`combat_start aura_stat {stat=atkInc, value=0.12, target=neighbors}`** [GREFFE v2 : 2e porteur d'EMPOWER — accès early rank-2, le prêtre-guerrier qui exhorte] | T1 Bûcher | Mitre, halo, fléau ; sa harangue de feu sacré fait frapper plus fort ceux qui le flanquent. |
| coil_viper | COIL VIPER | 2 | enabler | BAS-MOY | `on_hit poison {dps=3, dur=160}` [CONSERVE] + **`on_hit grant_affliction_if_absent {family=poison, dps=1, dur=120}`** [GREFFE v2 : le cobra ouvre une 2e plaie SI absente — pas de double-stack] | T3 Couvain | Serpent lové qui frappe deux fois là où la chair est encore saine. |
| web_recluse | WEB RECLUSE | 2 | enabler | BAS-MOY | `on_hit poison {dps=2, dur=200}` [CONSERVE] | T3 Couvain | Araignée à huit pattes ; sa morsure recluse ronge lentement. |
| siphon_jelly | SIPHON JELLY | 2 | enabler | BAS-MOY | `on_hit shock {add=1, cap=5}` [CONSERVE] | T5 Orage | Méduse à filaments urticants qui décharge un courant. |
| skull_colossus | SKULL COLOSSUS | 5 | carry | HAUT | `on_hit burn {dps=4, dur=200}` [CONSERVE] + **`on_kill heal_on_kill {value=8}`** [GREFFE v2 : payoff de combat NON-multiplicatif pour A16 constructs] | T1 / T8 | Crâne colossal incandescent ; chaque âme qu'il broie ranime un peu sa braise titanesque. |
| rust_sentinel | RUST SENTINEL | 4 | bruiser | MOYEN | `on_hit shock {add=1, cap=6}` [CONSERVE] | T5 / T8 | Automate-reliquaire à cœur électrique, bruiser-tank. |
| runestone_golem | RUNESTONE GOLEM | 4 | tank | MOYEN-HAUT | `combat_start shield_aura {12, target=neighbors}` [CONSERVE] | T8 Rouages / T6 | Golem de pierre runique qui dresse une garde sur ceux qui l'entourent. |
| ink_horror | INK HORROR | 2 | enabler | BAS-MOY | `on_hit poison {dps=3, dur=170}` [CONSERVE] | T3 Couvain | Anémone à tentacules qui crache une encre toxique abyssale. |
| deep_kraken | DEEP KRAKEN | 5 | carry | HAUT | `on_hit poison {dps=4, dur=200}` [CONSERVE] — carry brut (dmg 12) | T3 Couvain / T7 | Léviathan ; son étreinte venimeuse étouffe et empoisonne. |
| husk | HUSK | 1 | tank | BAS | stat-stick (vide) [CONSERVE] — plancher | T8 Rouages | Cadavre voûté qui a oublié de finir de mourir. |
| gnaw_rat | GNAW-RAT | 1 | enabler | BAS | `on_hit bleed {dps=1, dur=150, slowPct=0.08}` [CONSERVE] — micro | T2 Bêtes | Rat géant voûté qui grignote jusqu'au sang. |
| footman | THE STOKED HUSK | 1 | tank | BAS | stat-stick (vide) [CONSERVE] — plancher | T8 Rouages | Coquille rivetée de soldat avec une fournaise à la place du cœur. |
| mire_thing | MIRE THING | 1 | bruiser | BAS | stat-stick (vide) [CONSERVE] — plancher | T7 / T8 | Blob aux yeux internes qui suinte de la fosse. |

**Bilan de la passe (v2)** : **15 GREFFES** sur des unités dont le visuel + le nom les justifient,
réparties en deux familles de verbes :
- **Amplificateurs % (rares, accès-loterie volontairement bridé)** — 8 : `corruptor`+`stormcaller`
  vuln · `maggot_king`+`zeal_inquisitor` empower (2 points d'accès, rangs 3 et 2) · `bellows_priest`
  hâte-aura · `hookjaw` multicast-aura · `templar` armure-aura · `demon` aggro.
- **Verbes NON-multiplicatifs (bornés par nature, gros gain de ressenti, 0 nouvel ampli %)** — 7 :
  `marauder` execute · `carrion_pecker`+`skull_colossus` heal_on_kill · `siege_breaker` cleave
  (**seul hôte v1**) · `coil_viper` grant_affliction_if_absent · `plague_doctor` purge **bornée**.

**Pourquoi v2 ajoute les verbes non-multiplicatifs** : SAP/TFT/Bazaar ont ~100 % d'unités qui *font
quelque chose de distinct* ; la v1 laissait ~85 % du roster en DoT-pur (anormal, monoculture
renommée). Ces 7 verbes sont **tous des ops déjà câblés** (ops.lua), **bornés** (execute = état pur ;
heal_on_kill ≤ maxHp ; cleave profondeur-1 sans on_hit secondaire ; grant-if-absent ne double-stack
jamais ; purge bornée n'efface pas) → **aucun nouveau risque de snowball**.

**Compte de VERBES comportementaux distincts sur le roster** (digeste — cible ≤ ~16-18) : DoT poseurs
(burn/bleed/poison/rot/shock) + auras-DoT (4) + thorns + lifesteal + bonus_first + shield/shield_caster
+ regen + grant_team-transforms — **+ les 9 verbes agnostiques v2** : vuln, empower, hâte, multicast,
armure, aggro, execute, heal_on_kill, cleave, grant-if-absent, purge. Reste **minimal et lisible** : la
diversité d'archétype vient de la **combinatoire enabler×ampli**, pas d'un re-mapping massif risquant
l'équilibre. Tout le reste = **[CONSERVE]**.

---

## 3. CARTE D'ARCHÉTYPES — taxonomie par AXE D'AMPLIFICATION (v2)

> **Révision v2 (critique « le 16 comptait 5 réskins DoT »)** : la taxonomie ne se fait PLUS sur la
> famille DoT seule (poison/burn/bleed/rot/shock = 5 *saveurs* d'un même axe « Saturation »), mais sur
> l'**AXE D'AMPLIFICATION** — la *façon* dont les enablers se transforment en kill. C'est la vraie
> identité stratégique (réf SAP/TFT/Bazaar : un archétype = un *moteur*, pas une couleur de dégât).
>
> **5 axes d'amplification × familles DoT** :
> - **Marque** (vuln-on-hit) — `grant_vuln`, +% entrant, increased cappé (`VULN_INC_CAP=0.5`).
> - **Écho** (multicast) — `aura_stat multicast`, re-frappe entière (`MULTICAST_MAX=3` non-scalé).
> - **Forge** (empower) — `aura_stat atkInc`, +% sortant (`ATK_INC_CAP=1.5`).
> - **Spread** (propagation à la mort / contagion) — `on_death`/`spread`, profondeur 1.
> - **Saturation** (cap/stacks/no-cap) — empiler le DoT brut jusqu'au plafond (et le lever en T5).
>
> **Compte HONNÊTE : 11 archétypes-unités génuinement distincts** (moteurs différents), + 2 demi-
> identités à départager en sim. Les **reliques/commandants/murmures** (passes futures) pousseront le
> total vers ~16-18 *jouables* — mais on ne FORCE pas le compte par du bloat ici.

| # | Archétype (= MOTEUR) | Axe | Cœur (carry) | Enablers | Ampli (qui) | Relique/Cmd réservé | Anti-synergie volontaire |
|---|---|---|---|---|---|---|---|
| **A1 — Saturation** (le mur de stacks) | Saturation | witch, deep_kraken | spore_tick, coil_viper, web_recluse, chitin_drone, rot_grub, ink_horror | miasma_acolyte (aura-DoT) | **festering** (no-cap) ; Bol-du-Roi | **purge bornée** (plague_doctor) incline (n'efface plus) |
| **A2 — Marque** (la cible exposée) | Marque (vuln) | witch, deep_kraken, thunderhead | corruptor, stormcaller, bile_spitter | **corruptor + stormcaller grant_vuln** (2 accès) | Marque du Voyant | vuln = `max()`, NON cumulable → 2 marques ne snowball pas |
| **A3 — Forge** (la ligne qui frappe fort) | Forge (empower) | pyre_tender, bloodletter, thunderhead | (n'importe quel DoT-frappeur adjacent) | **maggot_king + zeal_inquisitor atkInc** (2 accès, rk 3/2) | Bannière de Sang ; cmd Tambour | empower ne touche QUE le dégât d'attaque, pas le DoT déjà posé |
| **A4 — Écho** (la rafale) | Écho (multicast) | bloodletter, vein_splitter, marauder | razorkin, gash_fiend, byakhee, gnaw_rat, wailing_shade | **hookjaw multicast-aura** (role:front) | **Couronne d'Échos** (cmd/relique) | multicast × **épines** (skeleton/aegis) auto-punit le greedy |
| **A5 — Spread** (la traînée) | Spread | wildfire_hound, plague_pyre, plague_bearer | pyre_herald, emberling, spore_tick, acid_maw | soot_acolyte / miasma_acolyte | ash_maw ; Communion Pestilentielle | cibles **isolées** (pas de voisin où sauter) → mort sur 1×1 |
| **A6 — Burst d'exécution** (la pince) | (déterministe, hors-DoT) | marauder | bandit, vein_splitter, siege_breaker | **marauder execute** + galvanizer first-strike | Couronne d'Échos | combats **longs** (burst d'ouverture s'essouffle) |
| **A7 — Cleave de ligne** (le déchireur) | Spread (frappe) | siege_breaker | bandit, marauder | **siege_breaker cleave** (seul hôte v1) | — (cmd à venir) | murs **mono-cible** ; bloqué par boucliers (`ignoreShield=false`) |
| **A8 — Tank/Taunt** (le mur de front) | (défensif, support) | gravewarden, aegis_warden | husk, footman, runestone_golem | templar (armure-aura) | cmd Tambour ; thorns reliques | **zéro pression DoT propre** → exige un carry derrière |
| **A9 — Bouclier-périodique** (la garde dorée) | (défensif, support) | oath_keeper | shieldbearer, bulwark_acolyte, ward_weaver | barrier_savant / mirror_ward / surge_warden | cmd Bris-Siège | siege_breaker / acid_maw adverses **dissolvent** |
| **A10 — Leurre/Sustain** (l'appât) | (sustain, aggro) | demon, hollow_gut | static_swarm, arc_warden, carrion_pecker, skull_colossus (heal-on-kill) | demon aggro (attire) | cmd Calice de Sang (lifesteal team) | **exécution** adverse (A6) sur low-hp ; anti-heal (pierceHeal) |
| **A11 — Constructs/wide** (les rouages) | (stats brutes) | runestone_golem, skull_colossus | footman, husk, mire_thing, kiln_warden | **synergie-famille-à-l'achat (F-RunState)** | cmd Roi des Rats (tier:1) ; reliques BAS | **aucun ampli %** → plafonne late, force un pivot |

**Demi-identités à départager en sim (pas comptées comme distinctes tant que non prouvées)** :
- **d1 — Slow-lock (la lente saignée)** : `tendon_render`+`hookjaw`+`slow_bleed` (`slowEnemies` team).
  Distincte de A4 (Écho) ? Aujourd'hui c'est du **bleed + contrôle de cadence**, pas un moteur de kill
  propre. **Reste une *saveur* de A1/A4** jusqu'à preuve d'un win-pattern propre (le slow seul ne tue
  pas). *Op manquant éventuel pour la rendre distincte* → cf. ci-dessous (« ajout moteur optionnel »).
- **d2 — Rot-attrition longue** : `necro_leech`+`patient_worm`+`pit_maw` (amputation PVmax + rampe).
  Distincte de A1 (Saturation) ? Le *vecteur* diffère (ampute le plafond vs empile le dps) mais le
  *moteur de draft* (« empile un DoT, attends ») est le même. **Saveur de A1** sauf si la sim montre
  un win-pattern propre (combats très longs où l'amputation domine).

**Honnêteté du compte** : **11 moteurs distincts** (A1-A11) ; les 5 familles DoT sont des *saveurs*
de A1/A2/A3/A5, pas des archétypes. C'est **digeste** (chaque ligne = un *plan de jeu* différent) et
**honnête** (on ne renomme pas la monoculture). Les leviers réservés — commandants (Tambour/Calice/
Aïeul/Roi-des-Rats/Couronne/Bris-Siège, §6 spec), reliques 3 paliers (Bannière de Sang / Marque du
Voyant / Couronne d'Échos, §5 spec), murmures — **ajoutent des moteurs** (ex. la Couronne d'Échos
donne un Écho accessible même sans `hookjaw`) → total *jouable* visé ~16-18, **sans bloat dans le
roster d'unités**.

**Ajout moteur OPTIONNEL (signalé, non supposé)** — pour rendre d1/d2 génuinement distincts si la sim
le réclame, **2 ops n'existent PAS** et devraient être ajoutés au lieu d'être supposés :
- `slow_skip_swing` (d1) : au-delà d'un seuil de slow cumulé, la cible **saute** un swing (vrai
  contrôle dur, pas juste un cooldown allongé). *Ajout moteur : new-op + lecture dans le timer.*
- `lifesteal_on_tick` (d2/A10) : le porteur se soigne d'une fraction des **dégâts de DoT** infligés
  (pas seulement de la frappe). *Ajout moteur : hook dans `tickDots` côté attribution.*
  → **Ne PAS les supposer dispo** : tant qu'ils ne sont pas codés, d1/d2 restent des saveurs.

**Anti-synergies de draft (tension)** : (1) **purge bornée** (plague_doctor) *incline* A1/A2/A5
(retire -4 stacks ou 1 famille, ne reset pas) → contre soft, pas binaire ; (2) **multicast × épines**
(A4 vs skeleton/aegis) auto-punit le greedy ; (3) **constructs A11** n'ont aucun ampli % → plafonnent
late ; (4) **exécution A6** mange A10 (leurre low-hp) ; (5) **cleave A7** est bloqué par les boucliers
A9. Ces collisions = le sel du draft.

---

## 4. ORDRE D'IMPLÉMENTATION par vagues (phase code, step 9)

> Chaque vague = un lot **vert + golden-rebaselinable** (sim saine — σ, entropie — avant commit).
> Les `[CONSERVE]` n'exigent rien (déjà en place) ; le travail réel = les **GREFFES agnostiques**.
> Pré-requis moteur (steps 1-8 spec §8.1) : K1/K2/K3 + new-ops **déjà câblés et gated** (vérifié
> dans `build.lua`/`ops.lua`). Donc step 9 = pure data.

| Vague | Contenu | Unités touchées | Golden |
|---|---|---|---|
| **9a — stat-sticks BAS** | Confirmer/borner les planchers « hantés » (vide ou micro-statut), tuning stats loi-des-doublons | bandit, husk, footman, mire_thing, skeleton, gnaw_rat, ash_moth, live_wire, spore_tick | inchangé (déjà gated/vide) |
| **9b — enablers DoT re-thématisés** | i18n (noms/lore canon) + confirmation des DoT [CONSERVE] ; **aucun changement méca** | tous les enablers DoT (≈40) | inchangé (i18n golden-neutre) |
| **9c — amplificateurs % (le cœur, un levier à la fois)** | **GREFFES** : corruptor+stormcaller `grant_vuln` ; maggot_king+zeal_inquisitor `aura_stat atkInc` ; bellows_priest `aura_stat haste` ; templar `aura_stat dmgReduce` (remplace shield_aura) ; **hookjaw `aura_stat multicast` EN PREMIER** ; demon `aggro` | corruptor, stormcaller, maggot_king, zeal_inquisitor, bellows_priest, templar, hookjaw, demon | **REBASELINE** (si une unité golden touchée) — sinon inchangé |
| **9c′ — verbes NON-multiplicatifs (v2)** | **GREFFES** : marauder `execute` ; carrion_pecker+skull_colossus `heal_on_kill` ; coil_viper `grant_affliction_if_absent` ; plague_doctor `on_low_hp purge` **bornée** ; **siege_breaker `cleave` (SEUL hôte) — BLOQUÉ tant que `tests/synergies.lua` cleave×multicast n'est pas vert** | marauder, carrion_pecker, skull_colossus, coil_viper, plague_doctor, siege_breaker | REBASELINE si touché ; **arc_warden/kiln_warden cleave = DIFFÉRÉS** (vague-2, après validation cleave) |
| **9d — carries** | Confirmer/tuner les gros-dmg amplifiables (witch, deep_kraken, thunderhead, pyre_tender, bloodletter, necro_leech) | les carries de §2 | REBASELINE si scénario golden inclut un carry |
| **9e — supports/contres** | Confirmer auras (soot/clot/miasma/decay), strip_shield, boucliers périodiques | bloc ward, auras-DoT | REBASELINE si touché |
| **9f — HAUT-tiers** | Confirmer transforms/croisés [CONSERVE] (grant_team, convert) ; valider les triples vuln×empower×grant_team via `tests/synergies.lua` | ash_maw, festering, pit_maw, slow_bleed, plague_pyre, marrow_drinker, venom_censer, wither_bloom | REBASELINE + golden re-figé |

**Ordre = dépendances + sécurité** : 9a/9b golden-neutres → committables tôt. 9c est le **lot critique**
(amplis %) → un levier à la fois.

**LISTE DE SURVEILLANCE (gravée — corrections v2 intégrées)** :
- **(a) `grant_vuln` = `max()`, PAS additif** (vérifié `ops.lua:348` `v.vulnInc = max(v.vulnInc or 0, val)`)
  + lecture cappée `VULN_INC_CAP=0.5` (`arena.lua:285`). ⟹ deux porteurs de marque (corruptor+stormcaller)
  **ne se cumulent JAMAIS dangereusement** (la justif Q-vuln-double est corrigée en ce sens).
- **(b) Backstops moteur réels** (à citer comme garde-fous, vérifiés `arena.lua:38-41`) :
  `HIT_DMG_CAP_MULT=7` (UNE frappe ≤ ×7 le `dmg` de base, applique aussi par sous-coup multicast),
  `MULTICAST_MAX=3` **non-scalé par niveau**, `ATK_INC_CAP=1.5`, `VULN_INC_CAP=0.5`. C'est ce qui rend
  la redondance d'accès (2 vuln, 2 empower) **sans risque de snowball**.
- **(c) 1er TEST de 9c = `hookjaw × Couronne d'Échos × poison`** (saturation weaken/vuln sous multicast)
  — AVANT toute autre greffe. C'est le pire combo composé (spec §6.4 / §9.1). Tant qu'il ne passe pas
  (lift < 1,6, TTK p10 stable), on ne pose pas les autres amplis.
- **(d) Couplage `dmgReduce` × `shield` après le swap templar** : vérifier que le win% du **bloc tank**
  (A8 + A9) ne dépasse pas **+2σ** (l'armure-aura empilée sur un mur de boucliers cumule deux couches
  défensives). Re-balayer en bande END (§9.2 spec).
- **(e) `siege_breaker cleave` BLOQUÉ** tant que `tests/synergies.lua` n'a pas validé **cleave×multicast**
  (morts simultanées, ordre §2.4.1 spec). Un seul hôte cleave en v1 ; arc_warden/kiln_warden différés.

---

## 5. QUESTIONS OUVERTES (avec défaut raisonnable)

| # | Question | Défaut proposé |
|---|---|---|
| **Q-multicast-host** (accès fiable) | `hookjaw` porte le **seul** multicast-unité (`aura_stat multicast target=role:front`). 1 porteur = loterie de boutique. Faut-il un 2e porteur ? | **Non — garder hookjaw seul MAIS le rendre fiablement accessible** : rk-2 + dans `U.pool` early (cotes hautes au tier bas). La **redondance d'accès** vient de la relique **Couronne d'Échos** (multicast role:front) + le commandant éponyme : deux canaux non-boutique. Multicast = l'effet le plus explosif → 1 seul porteur-unité est volontaire (le reste passe par des leviers bornés/rares). Magnitude +1, `MULTICAST_MAX=3`. |
| **Q-vuln-double** (CORRIGÉ v2) | `corruptor` **ET** `stormcaller` portent `grant_vuln` : redondance dangereuse ? | **Garder les deux — SANS risque** : `grant_vuln` pose en **`max()`** (`ops.lua:348`), PAS additif ; lecture cappée `VULN_INC_CAP=0.5` (`arena.lua:285`). Deux marques sur la même cible **ne s'additionnent pas** (la plus forte gagne). C'est de la **redondance d'ACCÈS** (deux archétypes, A2/A5) sans snowball — exactement ce que SAP/TFT font. |
| **Q-empower-host** (mismatch thème CORRIGÉ v2) | `maggot_king` (T4 Pourriture) porte empower-aura — mais l'empower booste le **dégât d'ATTAQUE des voisins**, pas le **rot du thème**. Mismatch méca/thème. | **Assumé + clarifié** : l'empower-aura sert les **voisins qui FRAPPENT** (carries d'attaque type bloodletter/pyre_tender/thunderhead), pas le rot de T4. Lore aligné : *« le pantin-tyran ordonne, et ceux qui le flanquent frappent à son rythme »* — il **commande**, il n'empoisonne pas ses alliés. Placement-conseil : maggot_king au **centre** (4 voisins) entouré de frappeurs, PAS d'autres rot-poseurs. 2e accès empower = `zeal_inquisitor` (rk 2, prêtre-guerrier qui exhorte) → deux points d'accès, rangs distincts. |
| **Q-templar-shield** | Remplacer le `shield_aura` de `templar` par une `dmgReduce`-aura retire un porteur de bouclier. Compensé ? | **Remplacer** (spec §3) : 7+ porteurs de `shield_aura` couvrent A9 ; `dmgReduce`-aura donne à T6 son ampli agnostique. **⚠ surveillance (d)** : re-vérifier le win% A8+A9 ≤ +2σ (armure × bouclier = double couche défensive empilable). |
| **Q-collisions-visuelles** | Collisions d'archetype (3 herons ; 4 cocons ; eye-wheels ; anglerfish ; eye-clusters) : silhouettes partagées. Gênant en draft ? | **Mitiger par palette/seed** (déjà distincts, identity-map §33) ; **ne PAS réassigner la family** (= toucher au visuel canon). Noms+lore canon différencient déjà. Lister au créateur seulement si une paire reste illisible en jeu. |
| **Q-op-manquant** (MIS À JOUR v2) | Tous les ops du plan sont-ils câblés ? | **Oui pour la v2** : execute/heal_on_kill/cleave/grant_affliction_if_absent/grant_vuln/purge + aura_stat (haste/atkInc/dmgReduce/regen/multicast/lifesteal/statInc) = **tous câblés** (ops.lua/build.lua). v2 **utilise** désormais 5 ops jadis orphelins (execute, heal_on_kill, cleave, grant_affliction_if_absent, purge). **Ops à AJOUTER seulement si la sim réclame d1/d2** (§3) : `slow_skip_swing`, `lifesteal_on_tick` — **signalés, NON supposés dispo**. `convert_dot` (généralisé) reste réservé aux reliques. |
| **Q-aggro-demon** | `aggro 25` sur `demon` (le leurre attire) = soft-tank lifesteal sans taunt. Interfère avec les vrais tanks (gravewarden 40) ? | **OK** : 25 < 40 (les tanks gardent la priorité) mais > standard (10) → le démon *tire un peu* le focus, cohérent « appât ». Inerte tant que les plateaux ne se remplissent pas (CLAUDE.md). |
| **Q-purge-borne** (v2) | `plague_doctor` purge : `combat_start` (v1) ou `on_low_hp` borné (v2) ? Quelle borne ? | **`on_low_hp` + bornée** (défaut §7 spec Q-purge-meta révisé) : retire **un nombre FIXE de stacks (-4)** OU **une seule famille**, jamais un reset total. Déclenché 1× à `<50 %` PV (edge-triggered, `_thresholdFired`). Rationale : la purge doit **incliner** le matchup poison, pas le hard-counter binairement (sinon elle efface l'archétype DoT dominant — risque noté spec §11 minors). |

---

## 6. Réserves & dette (pour la passe code)

- **Ladder choc HAUT non étendu** (1 unité finisher) : aucun `grant_team`-shock natif sur le roster ;
  le rôle finisher de T5 est tenu par la **relique Langue Fourchue** (`shockChain` existant). Étendre
  à un porteur unité (5/3/2) = hors scope step 9 (cf. CLAUDE.md dette).
- **Synergie-famille-à-l'achat (A16)** = effet **LOCAL** v1 (non servi en ghost tant que K-snapshot
  n'encode pas `statBonus`, spec §2.5.1). Le plan en tient compte : A16 reste jouable solo.
- **Commandants/reliques/murmures** = passes séparées (anticipées dans la carte §3, pas remplies ici).
  Les leviers `cleave`/`execute`/`heal_on_kill`/`grant_affliction_if_absent` leur sont réservés.
- **Tuning** : tous les chiffres (vuln 0.12-0.15, empower 0.12-0.20, hâte 0.12, multicast +1, execute
  threshold 0.25/bonus 0.60, heal-on-kill 4-8, aggro 25) = PLACEHOLDERS → balayage `tools/sim.lua`
  (§9.2 bandes EARLY/MID/END × reliques × commandants), un levier à la fois, seuil d'équilibre §9.3
  (win% ±2σ, lift < 1,6, entropie ≥ 0,90).

---

## v2 — révision post-critique (journal des changements)

> Passée 2 critiques adversariales (ambition/diversité + équilibrage/distinction). Verdict : **fondation
> excellente mais trop conservatrice sur les VERBES de base, et compte d'archétypes gonflé.** Changements
> intégrés (sans sur-étendre — total verbes comportementaux ≤ ~16-18) :

**1. GREFFES de verbes NON-multiplicatifs** (le gros gain de ressenti — réf SAP/TFT : ~100 % des unités
font qqch de distinct ; v1 = ~85 % DoT-pur, anormal). 7 ops **déjà câblés**, bornés par nature :
- `carrion_pecker` → `on_kill heal_on_kill {value=4}` (charognard cyclope se repaît).
- `marauder` → `on_attack execute {threshold=0.25, bonus=0.60}` **EN REMPLACEMENT du crit** (déterministe,
  thématique « la pince achève », **retire le seul verbe RNG du roster**).
- `siege_breaker` → `on_hit cleave {frac=0.5}` (**SEUL hôte cleave v1**) ; `arc_warden`+`kiln_warden`
  cleave **DIFFÉRÉS** (vague-2, bloqués tant que `tests/synergies.lua` cleave×multicast non vert).
- `coil_viper` → `on_hit grant_affliction_if_absent {family=poison, dps=1, dur=120}` (2e plaie si absente).
- `skull_colossus` → `on_kill heal_on_kill {value=8}` (payoff de combat non-multiplicatif pour A11 constructs).
- `plague_doctor` → purge déplacée sur `on_low_hp` + **BORNÉE** (-4 stacks ou 1 famille, jamais reset total ;
  la purge **incline**, n'efface pas → pas de hard-counter binaire du méta poison).

**2. ACCÈS aux amplificateurs** (1 porteur = loterie d'archétype, contraire à SAP/TFT/Bazaar). Aucun NOUVEAU
type d'ampli, mais **2 points d'accès fiables** :
- **empower** : 2e porteur `zeal_inquisitor` (rk 2, accès early, rang distinct de maggot_king rk 3) + relique
  Bannière-de-Sang + commandant Tambour (redondance hors-boutique).
- **multicast** : `hookjaw` reste seul (effet le plus explosif) MAIS rendu fiablement accessible (rk-2, pool
  early) + relique/commandant Couronne d'Échos (2 canaux non-boutique).
- **vuln** : reste à 2 (corruptor + stormcaller) — sûr car `max()` non-cumulable (point 4a).

**3. TAXONOMIE reclassée sur l'AXE D'AMPLIFICATION** (Marque/Écho/Forge/Spread/Saturation × familles DoT),
plus sur la famille DoT seule. **Compte HONNÊTE : 11 moteurs distincts** (A1-A11) — les 5 familles DoT sont
des *saveurs* de Saturation/Marque/Forge/Spread, pas des archétypes. 2 demi-identités (d1 slow-lock, d2
rot-attrition) **non comptées** tant que la sim ne prouve pas un win-pattern propre. Reliques/commandants/
murmures pousseront le *jouable* vers ~16-18 **sans bloat dans le roster d'unités**. **2 ops optionnels
SIGNALÉS** (non supposés) pour distinguer d1/d2 si besoin : `slow_skip_swing`, `lifesteal_on_tick`.

**4. Liste de surveillance + corrections** (§4 + §5) :
- (a) `grant_vuln` = **`max()`** (`ops.lua:348`) PAS additif, cappé `VULN_INC_CAP=0.5` → Q-vuln-double corrigé.
- (b) backstops cités : `HIT_DMG_CAP_MULT=7` + `MULTICAST_MAX=3` **non-scalé** (+ `ATK_INC_CAP=1.5`) = vrais garde-fous.
- (c) **1er test de 9c = `hookjaw × Couronne × poison`** (saturation weaken/vuln) AVANT toute autre greffe.
- (d) couplage `dmgReduce`×`shield` après swap templar : win% bloc tank (A8+A9) ≤ +2σ.
- (e) `maggot_king` empower sert les **voisins-frappeurs**, PAS le rot de T4 → lore + placement clarifiés (Q-empower-host).

**Inchangé** : les 8 amplis % (vuln×2, empower×2, hâte, multicast, armure, aggro) ; tous les DoT [CONSERVE] ;
la re-thématisation visuel→méca (§0/§1) ; les noms/lore canon. La v2 **ajoute** la couche de verbes
non-multiplicatifs et **assainit** le compte d'archétypes, sans toucher l'équilibre des familles DoT.
