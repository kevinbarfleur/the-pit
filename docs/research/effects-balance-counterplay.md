# The Pit — Counterplay, anti-dégénérescence & méthode d'équilibrage par sim

> Recherche 2026-06 sous la **Règle d'or** (sources primaires + Exa, citées par URL). Périmètre :
> **(1)** pièges classiques des systèmes DoT/stacking/amplification et comment les jeux les bornent ;
> **(2)** counterplay minimal jour-1 par famille (DoT, bouclier, choc/amplification, aggro, vitesse),
> **compatible avec notre ciblage 100% déterministe (zéro dé en combat)** ; **(3)** métriques de sim à
> ajouter pour détecter une synergie dégénérée ou une famille sur/sous-puissante (formules + seuils) ;
> **(4)** protocole d'auto-itération reproductible (lancer `tools/sim.lua` → lire `runs/report.json` →
> ajuster → relancer) pour converger vers un pool sain.
>
> Lanes voisines (NE PAS dupliquer) : DoT interne = agent 1 ; choc/modificateurs/aggro = agent 2 ;
> frameworks de paliers = agent 3. Ce doc reste sur **counterplay / anti-dégénérescence / méthode**.
> Contexte moteur : `engine-architecture.md` (effets data+ops+bus, déterminisme seedé, `tools/sim.lua`),
> `combat-model-decision.md` (vie par entité, ciblage colonne→taunt→aggro→tie-break, exposition-sigil).

---

## 0. Rappel de notre modèle (les contraintes que tout ce qui suit doit respecter)

- **Combat à cooldowns, vie PAR ENTITÉ, déterministe.** `arena.lua` : timer→0 ⇒ l'unité frappe ;
  un seul **RNG seedé injecté** (offset d'`atkTimer` au spawn) ; **aucun autre dé en combat**.
- **Ciblage = fonction pure** : colonne avant (`depth = maxCol - cell.x`) → override `taunt` → `aggro`
  max → tie-break `row` (haut→bas) puis `slot`. Toute mécanique de contre doit rester **sans dé**
  (pas de « 20% d'esquive ») pour préserver l'invariant async/replay (`combat-model-decision.md`).
- **Effets = data** `{trigger, op, params, condition?, target?}` ; ajouter un contre = **+1 op + 1 ligne
  data**, jamais éditer la boucle. Le poison est aujourd'hui le seul DoT (witch : 2 dps/3 s,
  `victim.poison` **écrasé**, pas empilé) ; lifesteal/thorns/bonus_first/shield_aura complètent.
- **Conséquence directe** : nos contres seront **déterministes et conditionnels** (cleanse au tick,
  immunité courte fenêtrée, strip de bouclier, réduction de stacks, AoE/colonne anti-taunt), **jamais**
  probabilistes. C'est une force : ça transforme la frustration RNG en skill de placement (yomi).

---

## 1. Pièges classiques (DoT / stacking / amplification) et comment les jeux les BORNENT

Chaque piège est apparié à **comment de vrais jeux le bornent** et à **ce que The Pit doit en retenir**.

### 1.1 Boucle infinie « effet déclenche effet » (A→B→A)
Le cas d'école : `« quand je prends des dégâts, je me soigne 1 »` + `« quand je me soigne, je prends 1
dégât »` → boucle qui ne termine pas (ou explose le temps de résolution). C'est exactement le risque
quand on ouvrira `on_damaged`/`on_heal`/`on_kill` à la chaîne.
**Comment c'est borné :**
- **Limiter à une résolution par tour / par cause** : « once per turn » (flag) ou, plus souple,
  **once-per-cause** — un statut ne peut se redéclencher qu'une fois par *chaîne causale*. Réponse
  canonique de game-dev SE sur le sujet (https://gamedev.stackexchange.com/questions/201047/handling-infinite-combos) :
  « limiting a status to only resolve once per turn… one option to relax it is to limit each status to
  resolve once *per cause* », + **« having a maximum amount of nested resolving statuses »** (budget de
  profondeur) comme garde-fou ultime, + **file FIFO/priorité** pour l'ordre.
- **The Bazaar** a vécu les boucles de triggers et les borne par **cooldown interne / charge** (un item
  ne se « recharge » qu'1 s par évènement) (cf. `engine-architecture.md` §6.8, table des pièges).
**Retenu pour The Pit :** on a **déjà** la fondation (`engine-architecture.md` §6.4 : work-queue +
`MAX_STEPS = 256` + garde de réentrance `(source, event)`). Règle dure : **un effet ne s'auto-déclenche
jamais en cascade** sans (a) garde once-per-(source,event), (b) budget de profondeur. À activer **dès le
premier effet qui en déclenche un autre** (aujourd'hui aucun ne le fait — c'est pourquoi c'est différé).

### 1.2 Stacking exponentiel (modificateurs multiplicatifs qui s'emballent)
Empiler des `×` (plutôt que des `+`) crée une **progression géométrique** : 3× `+100%` = `+300%` en
additif mais **`+700%` en multiplicatif**, « out of hand rather easily »
(https://telegra.ph/The-curse-of-immortality-On-additive-and-multiplicative-combining-of-modifiers-10-27).
Même piège côté défense : multiplier les réductions amplifie vers l'**immortalité**
(http://talarian.blogspot.com/2014/12/indiedev-vive-les-resistances-models.html — « multiplicative…
nearly requiring players to specialize… hell to balance because runaway numbers »).
**Comment c'est borné :** séparer les **buckets** — `final = clamp((base + Σflat) * (1 + Σincreased) *
Π(more))` (PoE). L'`increased` (additif) est le pool « sûr » à distribuer largement ; le `more`
(multiplicatif) reste **rare et compté**. C'est exactement le modèle déjà acté
(`engine-architecture.md` §6.5).
**Retenu :** garder les buffs d'adjacence / niveaux dans `increased` (additif, commutatif,
déterministe) ; réserver `more` (×) aux **reliques signature rares** ; **plafonner** par un `clamp`
entier. Au **premier modificateur en % de stat**, implémenter les buckets (déjà au plan, §12).

### 1.3 « Double-dipping » : un même investissement scale deux fois
Le cas PoE historique : un modificateur de dégâts de feu boostait **et** le coup **et** l'ignite qu'il
causait (base de l'ignite = dégâts du coup), un **effet cumulatif** qui rendait DoT « some of the most
efficient sources of damage » et forçait à sous-tuner tout le reste
(https://www.pathofexile.com/forum/view-thread/1891944/page/1). GGG a **refondu** : l'ailment se
calcule comme **une valeur de dégâts séparée**, certains modificateurs n'affectent qu'**un** des deux
(https://www.pathofexile.com/forum/view-thread/1894879).
**Retenu :** quand on ajoutera des conversions (« 50% des dégâts en poison »), **interdire qu'un seul
buff scale les deux côtés**. Sentinelle de sim : si un seul stat fait grimper *à la fois* `attack` et
`poison` dans la part-de-dégâts d'une unité de façon corrélée, c'est un double-dip → le borner.

### 1.4 One-shot par amplification (la « vulnérabilité » qui empile)
Empiler des amplificateurs (`reçoit +X% de dégâts`) peut transformer un coup normal en exécution.
**Comment c'est borné :**
- **Slay the Spire** sépare **Vulnerable** (+50% dégâts d'attaque, **stack en *durée*** — on ne dépasse
  pas +50% en empilant, on l'allonge) de Strength (+flat, stack en *intensité*)
  (https://slaythespire.wiki.gg/wiki/Vulnerable, https://slaythespire.wiki.gg/wiki/Debuffs : « Poison
  is the ONLY Debuff with both Intensity and Duration stack types »). **Leçon clé : choisir, par statut,
  s'il stacke en *intensité* (puissance) OU en *durée* — rarement les deux.**
- **PoE** met un **cap dur** à l'amplification défensive : résistance mini **-200%**
  (https://pathofexile.fandom.com/wiki/Curse — « a negative resistance cap of -200% was added… includes
  monster resistances ») ; et la **pénétration ne descend jamais sous 0**
  (https://www.pathofexile.com/forum/view-thread/3870562).
**Retenu :** notre futur statut d'amplification (« choc/expose ») doit **stacker en *durée*, pas en
intensité** (façon Vulnerable), et tout `% de dégâts reçus` doit avoir un **cap dur**
(p. ex. `-50%` de mitigation max ⇒ jamais plus de +50% subis d'une seule source d'expose). Détail
mécanique de l'expose : lane agent 2.

### 1.5 Le DoT qui rend PV/tanks inutiles (« infinite attack »)
En autobattler, un DoT qui **ignore le bouclier** et **scale en stacks** rend les grosses barres de PV
non pertinentes. En **Hearthstone Battlegrounds**, Poisonous = « **infinite attack**, able to clear any
minion » → un poison-taunt domine (https://thegamehaus.com/sports/relearning-hearthstone-battlegrounds/2019/11/07/).
Blizzard a jugé Poisonous trop oppressant et l'a **remplacé par Venomous = même effet mais
*once-per-combat*** pour l'aligner sur Divine Shield/Reborn
(https://blizzardwatch.com/2023/05/09/battlegrounds-season-4-changes/).
**Comment c'est borné :** (a) **uptime/refresh** plutôt qu'**intensité** (PoE : poison stacke
indépendamment, donc on borne par la *cadence d'application*, pas l'uptime —
https://www.poewiki.net/wiki/Damage_over_time) ; (b) **once-per-combat** pour les effets « tueurs
absolus » ; (c) une **part de dégâts** plafonnée vs les attaques.
**Retenu :** notre poison **ignore le bouclier** (déjà le cas, `arena.lua:damage ignoreShield`) — donc
il faut un **contre dédié** (cleanse/regen, §2.1) sinon il invalide l'archétype tank. Sentinelle de
sim : `dmg_share[poison]` et la part DoT globale (cf. §3.2) — alarme si le DoT devient la 1re source.

### 1.6 Snowball ingérable & propagation incontrôlée
Effets qui se **propagent** (spread on death, chain) ou **gagnent en mourant** créent un emballement
non-borné. Risque de graphe : un **cycle amplifiant** dans le graphe d'effets (« after one complete
cycle you have more of any resource it can be used to amplify that resource »
https://leafwing-studios.github.io/Emergence/production-chains/index.html).
**Comment c'est borné :** **budget anti-boucle** (notre `MAX_STEPS`), **fork = même entité avec budget
décrémenté** (modèle survivor-like, `engine-architecture.md` §6.7), et **cap de propagation** (n sauts).
**Retenu :** toute future relique « chain/fork/spread » passe par l'**attaque-entité** avec **budget
décrémenté** (déjà conçu, différé §6.7/§12). Pas de propagation sans budget.

### 1.7 « Solved meta » : une seule compo viable
Pas un bug de combat mais l'**échec d'équilibrage** ultime. **TFT Set Fates** : les 5-coûts si forts que
la seule façon de jouer était « ignore tes traits, prends tous les 5-coûts »
(https://teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-teamfight-tactics-fates-learnings/).
**TFT Set 1** : champions **surchargés** (« too much going on in their kits ») = source d'imbalance
récurrente (https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/).
**Comment c'est borné :** **objectif d'entropie/diversité** sur la distribution des stratégies
gagnantes (§3) ; **dégraisser les kits** (un effet de trop = un vecteur de combo cassé) ; viser
« 1 forme/archétype = un pattern qui l'aime », pas un dominant universel (notre principe sigil).
**Retenu :** garder les unités/reliques **focalisées** (peu d'effets, lisibles) ; surveiller la
**diversité méta** par sim (entropie/Gini-Simpson) **plus** le win-rate (une unité peut être à 50% et
quand même *obligatoire* dans toutes les compos gagnantes — voir §3.4 co-occurrence).

### 1.8 Tableau récap des **bornes** (boîte à outils)
| Borne | Quand l'employer | Précédent sourcé |
|---|---|---|
| **Cap de stacks** (statut empilable max N) | DoT/amplification empilables | PoE2 : Poison/Bleed/Ignite **1 seul stack** par défaut (https://www.pathofexile.com/forum/view-thread/3633592) |
| **Stack en *durée* pas en *intensité*** | amplification, slows | StS Vulnerable/Weak (durée) vs Poison (les deux) (https://slaythespire.wiki.gg/wiki/Debuffs) |
| **Durée max / uptime borné** | tout DoT/buff temporaire | PoE : borner par cadence d'application (https://www.poewiki.net/wiki/Damage_over_time) |
| **Once-per-combat** | effets « tueurs absolus » | HSBG Venomous/Divine Shield/Reborn (https://blizzardwatch.com/2023/05/09/battlegrounds-season-4-changes/) |
| **Budget anti-boucle (profondeur)** | effet→effet | gamedev SE « max nested resolving statuses » (https://gamedev.stackexchange.com/questions/201047/handling-infinite-combos) |
| **Once-per-(source,event)** | triggers réactifs | idem ; déjà au plan §6.4 |
| **Hard cap de dégâts-pris / mitigation** | réductions & amplifications | PoE -200% res, cap 75% res, pén ≥ 0 (https://pathofexile.fandom.com/wiki/Curse) |
| **Diminishing returns** (au lieu de cap brut) | stats stackables continues | formules §1.9 |
| **Immunité/cleanse** | counterplay aux statuts | StS Artifact / Bazaar Cleanse (§2.1) |
| **« Less effect » multiplicatif sur cibles dures** | empêcher de trivialiser les boss/élites | PoE curse/exposure « less effect on bosses » 15/30/50% (https://www.poe2wiki.net/wiki/Exposure) |

### 1.9 Diminishing returns — formules prêtes à coder (déterministes, ordre-indépendantes)
Pour borner une stat empilable **sans** mur brutal :
- **Réduction multiplicative (jamais 100%)** : `reduction = 1 - (1 - r)^n` (n sources de force `r`) —
  « never exceed 100%… never go too far out of control »
  (https://gamedev.stackexchange.com/questions/197419/formula-for-stacking-percentages-to-keep-them-from-getting-out-of-control).
- **Asymptotique simple** : `y = A * x / (x + k)` → plafond `A`, jamais atteint ; `k` = « demi-vie »
  (https://gamedev.stackexchange.com/questions/109985/simple-diminishing-return-with-cap).
- **Additif-comme-increase (style armure PoE/WoW)** : `damageTaken = base * armor_const / (armor_const
  + armor)` — chute douce, pas d'immunité (https://toolhub.software/articles/rpg-damage-formulas/ ;
  http://talarian.blogspot.com/2014/12/indiedev-vive-les-resistances-models.html).
- **Cap propre + overcap tactique** : capper à 75–80% (Diablo/PoE) crée une couche « overcap » utile
  quand l'ennemi applique une réduction (https://toolhub.software/articles/rpg-damage-formulas/).
**Retenu :** toute future stat « stackable continue » (armure d'archétype tank, aggro, vitesse) passe
par **DR multiplicative ou asymptotique** + **clamp** — pas d'additif brut non borné. Reste déterministe
(somme/produit commutatifs) ⇒ compatible replay.

---

## 2. Counterplay minimal jour-1, par famille (déterministe, sans dé)

**Principe d'or** (déjà acté pour l'aggro, on l'étend à tout) : un contre **redistribue / annule, il
n'augmente pas le total brut**. Et **aucune famille ne doit être sans réponse** au jour-1 — sinon la
première relique de cette famille crée une « solved meta ». Tableau de livraison minimal :

### 2.1 Anti-DoT (contre poison / futurs DoT)
Le DoT ignore le bouclier ⇒ il lui faut des contres **dédiés** (sinon §1.5). Trois leviers, tous
déterministes :
- **Cleanse** : retirer X stacks/sec ou purge totale à un trigger. Précédents : **StS Artifact**
  « negate the application of the next debuff » + **Orange Pellets** purge tous les debuffs si on a joué
  attaque+skill+power (https://slaythespire.wiki.gg/wiki/Debuffs, https://slay-the-spire.fandom.com/wiki/Artifact) ;
  **Bazaar** : Heal retire **5% du soin** en poison/burn, skills **Cleanse** (« Cleanse half your Burn
  and Poison ») (https://thebazaar.wiki.gg/wiki/Poison, https://thebazaar.wiki.gg/wiki/Heal).
- **Regen / lifesteal** : surpasser le tick (mais Bazaar note que le **lifesteal ne nettoie pas** le
  poison — choix de design pour ne pas le rendre trop fort). On a déjà `lifesteal` (demon).
- **Immunité courte fenêtrée** : façon **Intangible** StS (« reduces all sources of HP loss to 1,
  including Poison ») (https://slaythespire.wiki.gg/wiki/Poison) — fenêtre **brève**, pas permanente.
**Livraison jour-1 :** op `cleanse` (retire `n` stacks de poison à `combat_start`/`on_attacked`/tick) +
une unité ou relique anti-DoT (p. ex. « Os » : `on_tick` purge 1 stack/s). C'est **+1 op + data**.

### 2.2 Anti-bouclier (contre shield_aura / futurs boucliers)
Le bouclier (templar Rempart) **absorbe avant les PV** (`arena.lua:damage`). Contres :
- **Strip / by-pass** : un effet qui **ignore le bouclier** (comme le poison/thorns le font déjà via
  `ignoreShield`) ou le **retire**. **Bazaar** : Poison **bypasses Shield** ; Burn **ignore à 50%** mais
  Shield **réduit le burn de 50%** (https://thebazaar.wiki.gg/wiki/Shield). **HSBG** : on pop les Divine
  Shields avec un **cleave/chump en première position** avant d'engager le vrai dégât
  (https://blizzpro.com/2019/12/05/besting-battlegrounds/).
- **Pénétration plate** : `damage += min(target.shield, pen)` ignoré — déterministe.
**Livraison jour-1 :** op `pierce_shield` (params `flat`/`pct`, retire du bouclier avant calcul) sur une
unité/relique « anti-armure ». Garde le poison/thorns comme by-pass naturel (déjà là).

### 2.3 Anti-amplification (contre futur « choc/expose »)
Avant même de livrer l'amplification, livrer son contre, sinon one-shot (§1.4) :
- **Réduction de stacks d'expose** (retire `n` stacks de l'amplification sur soi) — déterministe.
- **« Less effect » sur certains profils** (façon PoE boss : 15/30/50% less)
  (https://www.poe2wiki.net/wiki/Exposure) : un archétype tank pourrait avoir un **trait « stoïque »
  = subit moins d'amplification**.
- **Cap dur** du `% reçu` (§1.4). 
**Livraison jour-1 :** prévoir l'op `cleanse_stacks{status="expose", n}` **en même temps** que l'op
d'expose (détail mécanique de l'expose = agent 2 ; ici on n'exige que **le contre existe à la livraison**).

### 2.4 Anti-aggro (contre taunt / mur de tank)
Notre ciblage : `taunt` re-trie **dans la colonne** atteignable (n'inverse pas front/back). Pièges :
**mur max-aggro indéboulonnable**, **aggro-taxe obligatoire** (`combat-model-decision.md` §5). Contres
**déterministes** :
- **AoE / attaque-colonne** qui **frappe toute la colonne** quel que soit le taunt (le taunt redirige
  le *single-target*, pas l'AoE). HSBG : **cleave** pour ne pas se faire « mur-taunter »
  (https://blizzpro.com/2019/12/05/besting-battlegrounds/).
- **Strip de taunt / d'aggro** : un effet retire le flag `taunt` ou met l'aggro à 0. Précédent HSBG :
  **Sin'dorei Straight Shot** « remove Reborn and Taunt from the target »
  (https://hearthstone.fandom.com/wiki/Battlegrounds/Divine_Shield).
- **« Saut de ligne » (furtivité/assassin)** : relique **rare** qui ignore la colonne avant (façon
  assassin TFT) — **toujours assortie d'un contre positionnel** (la dette anti-bypass de
  `combat-model-decision.md` §3 : « aucun effet bypass-position sans contre positionnel »).
- **Aggro négatif (carry « discrète »)** = se met au fond de la file de ciblage (déjà câblé, inerte).
**Livraison jour-1 :** câblage **déjà présent** (`taunt`/`aggro` inertes). Quand on activera les valeurs
(plateaux pleins), livrer **en même temps** : 1 effet AoE-colonne **et** 1 strip-taunt. **Jamais le
taunt seul.** (Valeurs d'aggro = lane agent 2.)

### 2.5 Anti-vitesse (contre cadence rapide / futur haste)
`bandit` a déjà un `cd` court (cadence). Si on ajoute du **haste/CDR**, risque d'**emballement de
cadence** et de **breakpoints** dégénérés.
- **Borner le haste en LINÉAIRE non capé plutôt qu'en % capé** : Riot a remplacé le CDR (% capé à 40%,
  rendements **croissants** près du cap, build-warping) par l'**Ability Haste** (linéaire, sans cap, DR
  *naturelle* sur le cooldown : `CD_eff = CD/(1 + haste/100)`)
  (https://wiki.leagueoflegends.com/en-us/Haste,
  https://devtrackers.gg/leagueoflegends/p/2ff42db4-a-mathematicians-take-on-ability-haste-vs-cdr).
  ⇒ **on devrait modéliser notre accélération comme du haste additif** (chaque point vaut pareil en
  cadence, DR automatique sur l'intervalle) plutôt qu'un `-X% cd` multiplicatif.
- **Floor de cooldown (cap d'attack speed)** : LoL **hard-cap à 3.003 atk/s**
  (https://wiki.leagueoflegends.com/en-us/Attack_speed). ⇒ **clamp un `cd` minimum** (p. ex. ≥ 12
  ticks) pour éviter l'attaque-par-frame.
- **Contre en combat** : **slow** (augmente `cd`) — déterministe ; ou un défenseur qui **profite** des
  attaques rapides (épines/thorns sur chaque coup, déjà là : skeleton).
**Livraison jour-1 :** **floor de `cd`** dès qu'un effet le réduit ; op `slow{add_cd}` comme contre.

### 2.6 Tableau de couverture jour-1 (à tenir vrai en permanence)
| Famille (menace) | Effet existant | Contre minimal à garantir | Précédent |
|---|---|---|---|
| **DoT** (poison) | witch | `cleanse` / regen / immunité courte | StS Artifact/Intangible ; Bazaar Cleanse |
| **Bouclier** | templar | `pierce_shield` / by-pass (poison/thorns) | Bazaar poison bypass ; HSBG cleave |
| **Amplification** (futur expose) | — | `cleanse_stacks` + cap dur + « less effect » | PoE -200% / curse less-on-boss |
| **Aggro/Taunt** (futur) | câblé inerte | AoE-colonne **+** strip-taunt | HSBG cleave / Straight Shot |
| **Vitesse** (futur haste) | bandit (cd court) | floor de `cd` + `slow` | LoL Haste linéaire + cap AS |
**Règle de processus** : **on ne merge jamais une famille offensive sans son contre dans le même lot.**
(C'est la généralisation de la dette « contres à livrer dès le jour-1 » de `combat-model-decision.md`.)

---

## 3. Métriques de sim à AJOUTER pour détecter dégénérescence / familles sur-puissantes

> État actuel de `tools/sim.lua` : win-rate/unité (crédit « in winning comp », méthode Ludus),
> `dmg`/unité, `dmg` par **cause** (attack/poison/thorns), **TTK moyen**, `meta_stddev` + `meta_entropy`
> du vecteur de win-rate. Rapport actuel : σ≈0.039, entropie≈0.999 (sain *sur 6 unités quasi
> symétriques*). Ci-dessous : ce qui **manque** pour attraper les pathologies des §1–2. Toutes les
> formules sont **calculables headless** depuis l'event-log JSONL déjà émis (`damage` riche :
> src/cause/raw/absorbed/overkill/hpAfter).

### 3.1 Win-rate « propre » + plancher/plafond + intervalle de confiance
Le win-rate actuel **crédite toute unité de la compo gagnante** ⇒ biais (toutes >50% car symétrique).
Ajouter, par unité :
- **Plancher/plafond d'alerte** : `winrate ∉ [0.45, 0.55]` (cible serrée) ou `[0.40, 0.60]` (cible
  lâche) ⇒ flag. TFT confirme que **même 0.05 d'attack speed ou 50 PV** déplace énormément
  (https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/) ⇒ viser serré.
  Le standard académique d'équilibrage = **toutes les paires proches de 50%**
  (https://ar5iv.labs.arxiv.org/html/1907.01623).
- **Intervalle de confiance** (anti-bruit) : pour `p̂` sur `m` apparitions,
  `IC95 ≈ p̂ ± 1.96·√(p̂(1-p̂)/m)`. **Ne flagge que si l'IC entier est hors cible** (évite de sur-réagir
  à 30 samples). Le sim étant déterministe (chaque matchup = 0/1), on **couvre des matchups** (variété
  de seeds/compos), on ne « moyenne » pas un même duel (`engine-architecture.md` §8.5).
- **Seuil de samples** : ignorer toute unité avec `appear < 100` (sinon faux positifs).

### 3.2 Part de dégâts par **famille d'effet** + alerte de domination DoT
On a déjà `cause_dmg`. Ajouter :
- **Part par famille** `share_f = dmg_f / Σ dmg` et **alerte** : si une famille **non-attaque** (poison,
  futur burn…) dépasse un seuil, p. ex. `share_DoT > 0.35`, c'est le signal §1.5 (« DoT rend les PV
  inutiles »). Aujourd'hui poison≈1% (sain) — la sentinelle se justifie **avant** d'ajouter des DoT.
- **Ratio overkill** `overkill / raw` par unité/famille : un **overkill élevé** = burst/one-shot
  (§1.4) ; `overkill_ratio > 0.30` ⇒ flag « unité qui surtue » (souvent une amplification cassée).
- **Dégâts ignorant le bouclier** `share_ignoreShield` : si trop haut, le bouclier (templar) est
  invalidé ⇒ déséquilibre défense/offense.

### 3.3 Distribution de TTK (pas juste la moyenne) + non-conclusion
La **moyenne** cache les pathologies. Ajouter sur l'échantillon de TTK :
- **Médiane + p10/p90 + écart-type** `σ_TTK`. **TTK très court** (p10 bas) = méta one-shot/snowball
  (§1.6) ; **TTK très long / non-conclu** = stall (besoin de **Fatigue**, cf. `engine-architecture.md`
  §12). Anti-stall réel : PoE Sandstorm, Bazaar Sandstorm/Fatigue (`combat-model-decision.md` §7).
- **Taux de non-décision** `undecided = (N - decided)/N`. **Alerte si > 0%** (un combat doit conclure ;
  c'est un invariant de `tests/props.lua`). Dump seed+log du 1er non-conclu.
- **Histogramme** (buckets de ticks) écrit dans le report → repère une **bimodalité** (deux régimes :
  « race » vs « attrition ») qui signale souvent un combo dégénéré dans un seul mode.

### 3.4 Co-occurrence ↔ win-rate (détecteur de COMBO cassé)
**La métrique-clé manquante.** Une unité peut être à 50% **seule** et pourtant **obligatoire** (paire
toujours gagnante). On veut détecter les **paires/synergies** sur-puissantes (le cœur de la valeur du
jeu… et de son risque). Pour chaque **paire (i, j)** co-présente dans une compo :
- **Win-rate conditionnel de paire** `WR(i,j) = wins(i∧j) / appear(i∧j)`.
- **Lift de synergie** `lift(i,j) = WR(i,j) − 0.5·(WR(i) + WR(j))` : **excès** de la paire vs la moyenne
  de ses membres. `lift > +0.10` (et IC hors 0) ⇒ **combo sur-puissant** (candidat à nerf ciblé ou à
  une borne §1) ; `lift < −0.10` ⇒ **anti-synergie** (deux cartes qui se gênent — souvent un piège UX).
- Précédent méthodo : matrices de win-rate par matchup pour repérer décks dominants
  (https://www.eternalcentral.com/so-many-insane-plays-measuring-metagame-diversity-and-balance/ ;
  https://ar5iv.labs.arxiv.org/html/1907.01623). Le sim génère déjà des compos aléatoires ⇒ il suffit
  d'agréger les paires (`O(k²)` par compo, k≤9, trivial).
- Optionnel : **triplets** seulement pour les paires déjà flaggées (éviter l'explosion combinatoire).

### 3.5 Diversité méta : passer de l'entropie de win-rate à la diversité de **stratégies**
L'`entropy`/`stddev` actuels mesurent la **dispersion des win-rates** (utile : outlier = trop fort/
faible). Ajouter une mesure de **diversité des compos gagnantes** — c'est l'anti « solved meta » (§1.7) :
- **Gini-Simpson / Simpson Diversity Index** sur la distribution des compositions (ou archétypes/sigils)
  parmi les **gagnants** : `D = 1 − Σ p_a²` (p_a = fréquence de l'archétype a chez les gagnants). `D→1`
  = diversité saine ; `D` qui chute = méta en train de se « résoudre »
  (https://www.eternalcentral.com/so-many-insane-plays-measuring-metagame-diversity-and-balance/).
- **Fraction d'entropie max** (proxy de l'objectif académique « entropie de la stratégie mixte à
  l'équilibre de Nash ») : `H_norm = −Σ p_a·ln(p_a) / ln(A)` ∈ [0,1]
  (https://eprints.whiterose.ac.uk/id/document/1934774 ;
  https://github.com/nianticlabs/metagame-balance). **Alerte si `H_norm < 0.85`** (concentration).
- **Pick-rate vs win-rate** : une unité à **pick-rate très élevé ET win-rate>cible** = staple cassée ;
  **pick-rate très bas** (`appear` faible malgré tirage uniforme — ici contrôlé) = signal « unité
  morte ». TFT suit exactement ce couple (data/sentiment) (https://riotgrove.com/analytics/TeamfightTactics).

### 3.6 Indicateurs anti-dégénérescence ciblés (peu coûteux, fort signal)
- **Fréquence « jamais touchée »** : part d'unités **vivantes à la fin n'ayant subi aucun dégât**
  (`hpAfter == maxHp` toute la sim) ⇒ ciblage qui **ignore** des unités (souvent un bug d'exposition-
  sigil, dette connue : profils à `cell.x` flottant comme l'anneau) **ou** une carry sur-protégée.
- **Fréquence « one-shot »** : part de morts où **un seul coup** a fait passer de `maxHp` à 0
  (`raw ≥ maxHp` au 1er `damage` reçu) ⇒ §1.4 (burst dégénéré).
- **Taux de stacking moyen/max** (quand un statut empilable existera) : `mean/max` des stacks d'un statut
  au pic ⇒ valider que les **bornes §1.8** tiennent (alerte si `max_stacks` dépasse le cap prévu).
- **σ de la « santé » par unité** déjà calculé — garder, mais **lire avec §3.4** (σ basse + diversité
  basse = équilibré *mais* monotone ; σ basse + diversité haute = **l'objectif**).

### 3.7 Tableau « métrique → ce qu'elle attrape → seuil d'alerte »
| Métrique (formule) | Pathologie détectée | Seuil d'alerte (départ, à tuner) |
|---|---|---|
| `winrate` + IC95 par unité | unité sur/sous-puissante | IC entièrement hors `[0.45,0.55]`, `appear≥100` |
| `share_f = dmg_f/Σdmg` | famille (DoT…) domine | `share_DoT > 0.35` |
| `overkill/raw` | burst/one-shot | `> 0.30` |
| médiane & p10/p90 de TTK | méta race / stall | p10 < 60 ticks **ou** p90 > 3000 ticks |
| `undecided` | combat non-conclu | `> 0` (dump seed) |
| `lift(i,j)` co-occurrence | **combo cassé** | `|lift| > 0.10`, IC hors 0 |
| `D = 1−Σp_a²` (Gini-Simpson) | solved meta | `D < 0.80` |
| `H_norm` (entropie norm.) | concentration de stratégies | `< 0.85` |
| part « jamais touchée » | ciblage cassé / sur-protection | `> 0.15` |
| part « one-shot » | burst dégénéré | `> 0.10` |
| `max_stacks` (si statut empilable) | borne §1.8 percée | `> cap_prévu` |

> Garder **toutes les stats en entier** dans `report.json` (pas de float instable) pour des **diffs
> propres** en CI (`engine-architecture.md` §8.5/§8.6).

---

## 4. Protocole d'auto-itération (boucle reproductible vers un pool sain)

Boucle inspirée du process **TFT (data → expérience → sentiment)**
(https://gamerant.com/teamfight-tactics-balance-update-character-reworks/) et des frameworks
d'optimisation par sim (**Ludus** https://ojs.aaai.org/index.php/AAAI/article/view/21550 ;
**simming + board strings** TFT
https://teamfighttactics.leagueoflegends.com/en-us/news/dev/talking-tactics-game-analysis-team-gat/).
Adaptée à notre **sim déterministe seedée** + harnais existant.

### 4.1 La boucle (une « passe »)
1. **Mesurer** : `luajit tools/sim.lua N` → `runs/report.json` (+ stats §3). **Versionner** le report
   (`git`/copie horodatée) pour comparer passe-à-passe.
2. **Diagnostiquer** : lire dans **cet ordre de priorité** (le plus structurel d'abord) :
   `undecided` → outliers de `winrate` (IC) → `lift(i,j)` (combos) → `share_f`/overkill (familles) →
   diversité `D`/`H_norm`. **Un seul diagnostic dominant par passe.**
3. **Ajuster UN levier** (le plus grossier d'abord — voir 4.3), **petit pas**.
4. **Re-mesurer** avec **le même N et la même graine de scénarios** (`gen` seedé à 13579 dans
   `sim.lua`) → diff du report. Garder si ça **rapproche des cibles §3.7 sans en casser une autre**,
   sinon **revert**.
5. **Verrouiller** quand les **critères d'arrêt** (4.4) sont tenus.

### 4.2 Combien de combats par passe (N) ?
- **Itération rapide (dev)** : `N = 200–400` (le défaut). Suffisant pour voir les **gros** outliers ;
  c'est ce que produit déjà `report.json` (200, σ stable). Le sim académique tourne souvent **~50
  matchs/matchup** (https://eprints.whiterose.ac.uk/id/document/1934774) — ici on couvre la variété par
  seeds plutôt que par répétition.
- **Décision de verrouillage** : `N = 2000–5000` une fois, pour **resserrer les IC** avant d'acter un
  changement (réduit le bruit d'un facteur √). **Toujours `appear ≥ 100`/unité** sinon élargir N.
- **Reproductibilité** : N fixé + graine fixée ⇒ **même report** (le sim le garantit). Tout diff vient
  **du changement de data**, pas du bruit. C'est ce qui rend la boucle fiable.

### 4.3 Quels paramètres bouger EN PREMIER (du plus grossier au plus fin)
Ordre = **impact décroissant, risque de sur-ajustement croissant** :
1. **`cd` (cadence)** et **`hp`** — les deux plus gros leviers de win-rate (un combat = course de DPS
   effectif vs PV). TFT : « 0.05 attack speed ou 50 HP » = énorme
   (https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/). Bouger **un**
   des deux, **±5–10%**.
2. **`dmg`** — ajuste la part de dégâts et le TTK.
3. **`params` d'effet** (value/frac/dps/dur) — pour recadrer une **famille** (§3.2) ou un **combo**
   (§3.4). Préférer **dégraisser** (retirer/réduire un effet de trop) plutôt qu'empiler des correctifs
   (§1.7, « champions surchargés »).
4. **Bornes structurelles** (§1.8 : cap de stacks, once-per-combat, DR, hard cap) — **en dernier**, mais
   c'est la **vraie** réponse à un combo dégénéré (un combo cassé se **borne**, il ne se « -5% » pas).
5. **`cost`** (économie) — pour un déséquilibre **valeur** (forte mais chère) plutôt que **puissance**.
   (Détail éco/paliers = lane agent 3.)
**Anti-sur-ajustement (overfitting au sim) :**
- **Un levier à la fois**, petit pas, **revert si régression ailleurs** (sinon on « chasse » sa queue).
- Le sim joue des **compos aléatoires**, pas un joueur optimal ⇒ il attrape les **outliers grossiers**,
  pas la pointe du skill. **Ne pas micro-tuner** sous le bruit : si l'IC95 couvre la cible, **ne pas
  toucher** (le « WRN » académique — win-rate-après-nerf — formalise « ne change que ce qui domine »,
  https://ar5iv.labs.arxiv.org/html/1907.01623).
- **Minimiser les changements** (objectif multi-critère : équilibrer **en touchant le moins de cartes**,
  pour ne pas « disrupter » le reste — https://ar5iv.labs.arxiv.org/html/1907.01623).
- **Garder la donnée + le sim comme garde-fou, pas comme oracle** : TFT combine **data + expérience +
  sentiment** ; la sim ne remplace pas le ressenti de jeu, elle **présélectionne** les suspects.

### 4.4 Critères d'arrêt (« le pool est sain »)
Verrouiller une passe (et le pool) quand **tous** sont vrais à `N` élevé :
- `undecided == 0` (tous les combats concluent).
- **Aucune unité** hors `[0.40, 0.60]` de win-rate (cible lâche) ; idéalement `[0.45, 0.55]`, **IC
  inclus**.
- `meta_stddev` **sous seuil** (départ `< 0.05` ; le report actuel est à 0.039) **ET** diversité haute :
  `D ≥ 0.80` et `H_norm ≥ 0.85` (sinon « équilibré mais monotone »).
- **Aucun `|lift(i,j)| > 0.10`** persistant (pas de combo cassé / anti-synergie).
- **Aucune famille** > 0.35 de part de dégâts non voulue ; part « one-shot » < 0.10 ; part « jamais
  touchée » < 0.15.
- **Golden-log inchangé** sur les scénarios figés sauf changement **intentionnel** (rebaseline explicite)
  (`engine-architecture.md` §8.6).
**Important** : ces seuils sont des **placeholders de départ** (comme nos valeurs de passifs/aggro). Ils
se **re-tunent** quand les plateaux se remplissent (9 slots) et que l'aggro/les reliques entrent — le
protocole, lui, ne change pas.

### 4.5 Ce que `tools/sim.lua` doit gagner pour soutenir la boucle (résumé actionnable, sans coder ici)
- Émettre les stats §3 dans `report.json` (entier) : IC, médiane/p10/p90 TTK, `undecided`,
  `overkill_ratio`, `lift(i,j)` top-k, `D`, `H_norm`, parts « one-shot » / « jamais touchée ».
- **Mode A/B** : deux jeux de data (avant/après) sur **la même graine de scénarios** → un **diff** des
  cibles §3.7 (qui s'améliore, qui régresse). C'est l'outil de décision « keep/revert » de la boucle.
- **Flag-and-dump** : tout matchup qui viole un invariant (non-conclu, one-shot anormal) **écrit son
  event-log complet** (les logs lourds **seulement** pour les scénarios flaggés, §8.5).

---

## 5. Décisions actionnables (ce que ce doc tranche, à intégrer au plan moteur §12)

1. **Règle de processus dure** : *aucune famille offensive n'est mergée sans son contre déterministe
   dans le même lot* (§2.6) — généralise la dette « contres jour-1 ».
2. **Anti-boucle obligatoire au 1er effet→effet** : activer work-queue + `MAX_STEPS` + garde
   once-per-(source,event) (déjà conçu, §6.4) **avant** d'ouvrir `on_kill`/`on_death`/`on_heal` à la
   chaîne.
3. **Statuts d'amplification stackent en *durée*, pas en *intensité*** + **cap dur** du `% reçu` (§1.4) ;
   livrer `cleanse_stacks` **avec** l'expose (mécanique expose = agent 2).
4. **Accélération modélisée en haste additif** (DR naturelle) **+ floor de `cd`** (§2.5) — pas de
   `-X% cd` multiplicatif non borné.
5. **DR/clamp pour toute stat stackable continue** (armure tank, aggro, vitesse) via formules §1.9 —
   reste déterministe.
6. **Sim : ajouter les métriques §3** (priorité : `undecided`, `lift(i,j)`, `share_f`/overkill,
   diversité `D`/`H_norm`) + **mode A/B diff** (§4.5). C'est le levier #1 pour itérer sans deviner.
7. **Premiers contres data à écrire** (peu de code, +1 op chacun) : `cleanse` (anti-DoT),
   `pierce_shield` (anti-bouclier), `slow` (anti-vitesse). AoE-colonne + strip-taunt **quand** l'aggro
   s'active.

---

## 6. Index des sources (primaires d'abord, par thème)

**DoT / stacking / bornes (PoE & co.)**
- PoE DoT rework (double-dipping) — https://www.pathofexile.com/forum/view-thread/1891944/page/1 ·
  https://www.pathofexile.com/forum/view-thread/1894879 · https://www.pathofexile.com/forum/view-thread/1897612
- PoE Damage over time (stacking, « highest only » vs poison indépendant, cap 35.8M) —
  https://www.poewiki.net/wiki/Damage_over_time · cap 32-bit confirmé
  https://www.pathofexile.com/forum/view-thread/3349134 · https://www.poe-vault.com/poe2/news/poe2-dot-cap-found-breaks-ignite-damage
- PoE2 ailments 1-stack par défaut — https://www.pathofexile.com/forum/view-thread/3633592
- Status effect stacking (« conservation of PotencyDuration ») —
  https://www.gamedeveloper.com/design/a-status-effect-stacking-algorithm

**Bornes défensives / DR / immortalité / haste**
- -200% res cap, curse « less effect on bosses » 33/66% — https://pathofexile.fandom.com/wiki/Curse ·
  Exposure « less on Magic/Rare/Unique » 15/30/50% — https://www.poe2wiki.net/wiki/Exposure ·
  pénétration ≥ 0 — https://www.pathofexile.com/forum/view-thread/3870562 ·
  https://www.pathofexile.com/forum/view-thread/3755214
- Multiplicatif = immortalité / runaway — https://telegra.ph/The-curse-of-immortality-On-additive-and-multiplicative-combining-of-modifiers-10-27 ·
  http://talarian.blogspot.com/2014/12/indiedev-vive-les-resistances-models.html
- Formules DR / caps — https://gamedev.stackexchange.com/questions/197419/formula-for-stacking-percentages-to-keep-them-from-getting-out-of-control ·
  https://gamedev.stackexchange.com/questions/109985/simple-diminishing-return-with-cap ·
  https://toolhub.software/articles/rpg-damage-formulas/ ·
  https://gamedev.stackexchange.com/questions/104227/calculating-damage-reduction-of-armor-parts
- Haste linéaire vs CDR capé / cap d'attack speed — https://wiki.leagueoflegends.com/en-us/Haste ·
  https://devtrackers.gg/leagueoflegends/p/2ff42db4-a-mathematicians-take-on-ability-haste-vs-cdr ·
  https://wiki.leagueoflegends.com/en-us/Attack_speed

**Boucles infinies / budget anti-chaîne**
- gamedev SE « handling infinite combos » (once-per-turn / once-per-cause / max nested / FIFO) —
  https://gamedev.stackexchange.com/questions/201047/handling-infinite-combos
- Cycles amplifiants dans un graphe d'effets — https://leafwing-studios.github.io/Emergence/production-chains/index.html

**Counterplay par famille (DoT/shield/amplif/aggro)**
- The Bazaar : Shield (poison bypass, burn -50%) — https://thebazaar.wiki.gg/wiki/Shield · Poison
  (bypass, heal retire 5%) — https://thebazaar.wiki.gg/wiki/Poison · Heal/Cleanse —
  https://thebazaar.wiki.gg/wiki/Heal · Burn — https://thebazaar.wiki.gg/wiki/Burn · keywords —
  https://mobalytics.gg/the-bazaar/guides/keywords-and-terms
- Slay the Spire : Debuffs (Intensity vs Duration, Artifact) — https://slaythespire.wiki.gg/wiki/Debuffs ·
  Artifact — https://slay-the-spire.fandom.com/wiki/Artifact · Poison (Intangible) —
  https://slaythespire.wiki.gg/wiki/Poison · Vulnerable — https://slaythespire.wiki.gg/wiki/Vulnerable ·
  Weak — https://slaythespire.wiki.gg/wiki/Weak
- Hearthstone Battlegrounds : Taunt — https://hearthstone.wiki.gg/wiki/Battlegrounds/Taunt · Divine
  Shield / strip (Straight Shot) — https://hearthstone.fandom.com/wiki/Battlegrounds/Divine_Shield ·
  Reborn — https://hearthstone.wiki.gg/wiki/Reborn · Venomous (once-per-combat) —
  https://blizzardwatch.com/2023/05/09/battlegrounds-season-4-changes/ · positionnement / cleave anti-
  shield, poison = infinite attack — https://blizzpro.com/2019/12/05/besting-battlegrounds/ ·
  https://thegamehaus.com/sports/relearning-hearthstone-battlegrounds/2019/11/07/

**Méthode d'équilibrage par sim & diversité méta**
- Ludus (optimisation autobattler, métriques de santé méta) — https://ojs.aaai.org/index.php/AAAI/article/view/21550
- TFT process (data/experience/sentiment ; simming + board strings ; LP Delta ; 0.05 AS ; kits
  surchargés ; Fates 5-coûts) —
  https://gamerant.com/teamfight-tactics-balance-update-character-reworks/ ·
  https://teamfighttactics.leagueoflegends.com/en-us/news/dev/talking-tactics-game-analysis-team-gat/ ·
  https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/ ·
  https://teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-teamfight-tactics-fates-learnings/ ·
  data unités (pick/winrate) — https://riotgrove.com/analytics/TeamfightTactics
- Diversité / Gini-Simpson / entropie de stratégie / win-rate matrix —
  https://www.eternalcentral.com/so-many-insane-plays-measuring-metagame-diversity-and-balance/ ·
  https://ar5iv.labs.arxiv.org/html/1907.01623 (WRN, minimiser changements, 50% cible) ·
  https://eprints.whiterose.ac.uk/id/document/1934774 (win-rate target graph) ·
  https://github.com/nianticlabs/metagame-balance · https://www.southampton.ac.uk/~eg/AAMAS2023/pdfs/p2134.pdf
