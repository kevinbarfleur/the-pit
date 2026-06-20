# The Pit — Familles de DoT / altérations (conception)

> Conception de **4 familles de dégâts-sur-la-durée à identité distincte**, skill-expressives,
> compatibles avec la sim **déterministe seedée** à cooldowns (`docs/research/engine-architecture.md`,
> `combat-model-decision.md`). Document de **conception** (aucun code). Tous les modèles de référence
> sont **sourcés** (Règle d'or). Périmètre : DoT seulement — choc/amplification, modifiers et aggro
> sont couverts par d'autres agents.
>
> **Statut** : proposition à valider/itérer. Tous les chiffres sont des **PLACEHOLDERS** (équilibrage
> via `tools/sim.lua`). Le créateur a fourni des intuitions (brûlure-décroît / saignement-slow /
> poison-malus-de-valeur) reprises ici **après confrontation aux modèles réels** — affinées, pas
> copiées au pied de la lettre.

---

## 0. Sources primaires (modèles réels confrontés)

Les **trois altérations damageantes de Path of Exile** sont le banc d'essai de référence (le wiki
officiel est la source autoritaire). Chacune incarne un **axe de stacking différent** — c'est *le*
principe de design à voler :

| Modèle réel | Axe de stacking | Mécanique exacte (sourcée) |
|---|---|---|
| **PoE Ignite** | **1 instance « la plus forte »** | « only the one with the highest damage per second will cause damage at any given moment » ; basé sur **% du gros coup de feu** ; **durée fixe** (4 s) ; toutes les instances coexistent mais une seule tick. https://www.poewiki.net/wiki/Ignite |
| **PoE Bleed** | **1 instance « la plus forte » + conditionnel** | 70 %/s du coup physique, base 5 s ; **« only the strongest bleed deals damage »** ; **× 3 si la cible bouge / est Aggravated** (« deals an additional 140% damage per second if the enemy is moving »). https://www.poewiki.net/wiki/Bleeding |
| **PoE Poison** | **N instances indépendantes (cumulatif)** | « Poison is a cumulatively stacking debuff… There is no limit to the number of poison stacks » ; 30 %/s du coup phys+chaos, base 2 s ; **chaque stack a son timer**, ne se rafraîchit pas. https://www.poewiki.net/wiki/Poison |
| **PoE Scorch** (altération alterne) | **malus de défense, pas de dégâts** | « lowers Elemental Resistances by up to 30% » — un DoT-adjacent qui **affaiblit la cible** au lieu de la blesser. https://www.poewiki.net/wiki/Scorch |
| **PoE Proliferation** | **propagation** | « Elemental Ailments inflicted by Supported Skills **spread to other enemies** within a radius » ; « causes other enemies to be affected by the ailment that already exists ». https://www.poewiki.net/wiki/Elemental_proliferation |

Modèles ARPG complémentaires (principes de stacking) :

- **Last Epoch** : chaque application = **un stack à timer propre**, **n'expire pas par refresh**,
  empilable à l'infini ; « if you hit an enemy 3 times with 100% chance, you inflict 3 stacks of
  poison with SEPARATE TIMERS… Most ailments stack infinitely, but DO NOT refresh ». Le **nombre de
  stacks dans une fenêtre** = le levier DPS. https://www.lastepochtools.com/guide/section/ailment_duration_and_effectiveness
- **Grim Dawn** : DoT **par source** ; même source = **« highest damage takes precedence »** (remplace
  si plus fort, sinon attend) ; sources différentes s'additionnent. « given the same source, the DoT
  with the highest damage will take precedence ». https://forums.crateentertainment.com/t/grim-dawn-dots-for-dummies-a-primer/37738 · https://grimdawn.fandom.com/wiki/Game_Mechanics
- **Diablo 4** : DoT ciblé = **fusion + reset de durée** (rendements décroissants par tick) ; même
  source ne stacke pas (refresh), sources différentes oui ; **tick fixe 0,5 s**. https://www.ezg.com/blog/diablo-4-season-13-you-losing-damage-dot-stacking-secrents-revealed-guide

**Méta-principe de design (la leçon transversale)** : un DoT a **trois axes de stacking** possibles,
et **choisir un axe différent par famille = leur donner une identité distincte sans inventer de
règle nouvelle** :
1. **Intensité** (Grim Dawn / Ignite) : une instance, la plus forte gagne. Récompense les **gros
   coups**, punit le saupoudrage. Plafond naturel.
2. **Nombre** (PoE Poison / Last Epoch) : N instances indépendantes. Récompense la **cadence**
   (attack speed) et la **durée**. Croît sans plafond → demande un contre.
3. **Durée / refresh** (Diablo 4) : une instance, chaque coup prolonge/fusionne. Récompense la
   **constance** (uptime).

On assigne **un axe distinct à chacune de nos 4 familles** (§B). C'est la colonne vertébrale.

---

## A. Contraintes de notre moteur (ce que les familles DOIVENT respecter)

Lu dans `arena.lua` / `engine-architecture.md` (la conception s'y plie strictement) :

1. **Tick à pas fixe seedé.** `Arena:update(frameDt, t)` tourne ~1/60 s. Le poison existant accumule
   en sous-unité : `acc += dps * (frameDt/60)` puis inflige `floor(acc)` (les fractions reportent).
   **Tout DoT doit ticker par accumulation entière** (jamais de float infligé) → reproductible à
   l'octet, golden-log stable. `dps` est en **dégâts/seconde**, `remaining`/`dur` en **frames**
   (3 s = 180). On garde cette convention.
2. **Zéro RNG non-seedé.** Toute « chance » passe par `condition = { kind="chance", value=p }`
   (résolue via `ctx.arena.rng:random()` dans `engine.lua`). Mais **préférer le déterministe** : nos
   altérations seront surtout **« toujours appliquées »** (pas de chance-to-X) pour rester
   async-vérifiables et lisibles — le hasard de PoE (chance d'ignite) n'a pas sa place en combat.
3. **Effet = donnée** `{ trigger, op, params, condition?, target? }`. Un nouvel op = 1 fonction
   pure-sim `(ctx, params, e)`, enregistrée. **Jamais éditer la boucle de combat** — sauf le **bloc
   de tick des statuts** dans `update` (aujourd'hui codé en dur pour `poison`), qu'on doit
   **généraliser en table de statuts** (cf. §F.1, refactor structurant proposé).
4. **L'unité porte l'état du DoT.** Aujourd'hui `u.poison = {dps, remaining, acc, source}`. On passe
   à `u.dots = { burn=…, bleed=…, poison=…, rot=… }` (ou liste pour les stacks) — une table par
   famille, lue par le tick généralisé.
5. **Ordre = array + ipairs.** Les stacks de poison (axe « nombre ») vivent dans un **array**, itéré
   par `ipairs`, tie-break par `seq` d'application monotone (jamais `pairs`). `table.sort` non
   stable → tri explicite si besoin de « la plus forte ».
6. **Petits nombres, combats 1–12 s, Fatigue ~17 s.** Les DoT doivent rester lisibles : ~2–8 dégâts/s,
   durées 2–6 s. Un DoT ne doit pas être un mur de chiffres flottants illisible.
7. **Le bouclier (shield) existe.** Décision de design **par famille** : qui ignore le bouclier, qui
   non. (Le poison v0 l'ignore déjà ; cohérent avec PoE où bleed/poison « bypass Energy Shield ».)
8. **Synergie par adjacence + duplicatas 3→niveau.** Chaque famille doit offrir des **hooks
   d'adjacence** (un voisin amplifie/propage) et **scaler proprement au niveau** (intensité ET effet).

---

## B. Vue d'ensemble : 4 familles, 4 identités, 4 axes

| Famille | Fantasy grimdark | Axe de stacking | Subtilité signature | Ignore bouclier ? | Élément/source |
|---|---|---|---|---|---|
| **BRÛLURE** (Burn) | chair qui cuit, cendres, bûcher | **Intensité** (1 instance, la + forte) **+ décroissance** | **décroît automatiquement** (dur à maintenir) ; **se propage** aux voisins | **Non** (le feu lèche le bouclier d'abord) | Feu |
| **SAIGNEMENT** (Bleed) | hémorragie, plaie ouverte, sang noir | **Intensité** (1 instance) **+ conditionnel** | **ralentit la vitesse d'attaque** de la cible (blessée → lente) ; **× quand la cible agit/bouge** | **Oui** (le sang coule sous l'armure) | Physique |
| **POISON** (Venom) | venin, putréfaction, contagion | **Nombre** (N stacks indépendants) | **malus sur la VALEUR des capacités** de la cible (shield/heal/dégâts −X %) | **Oui** (déjà le cas v0) | Toxique/Chaos |
| **POURRITURE** (Rot/Wither) | nécrose, décrépitude, le Puits qui dévore | **Durée / accumulation** (1 instance qui **enfle**) | **s'aggrave avec le temps** (DPS croît tant qu'on entretient) ; **emporte une partie des PV max** | **Oui** | Néant/Abysse |

> **Pourquoi 4 et pas 3** : les 3 intuitions du créateur (brûlure/saignement/poison) couvrent
> Intensité-décroissante / Intensité-conditionnelle / Nombre. Il manquait l'axe **Durée-croissante**
> (le « entretiens-moi et je deviens monstrueux »). **POURRITURE** le comble, colle parfaitement au
> thème du Puits (descente, nécrose, savoir qui ronge), et donne l'**anti-thèse de la brûlure**
> (l'une décroît, l'autre croît) — tension de design propre. Le type `Abysse` (demon) existe déjà.

**Lecture croisée des axes** (ce qui rend chaque famille *jouée* différemment) :
- **BRÛLURE** = burst. Tu veux **un gros pic** (front-loader) puis ça s'éteint → enabler de finisher,
  ou propagation pour toucher le plateau. Punit le DoT « lent ».
- **SAIGNEMENT** = contrôle. Faible en dégâts bruts mais **affaiblit la cadence** ennemie → tempo,
  protège ta carry, synergise avec tout ce qui dépend du temps.
- **POISON** = scaling. Plus tu **empiles vite** (cadence, voisins), plus ça monte. **+ malus de
  valeur** = casse les tanks/soigneurs/boucliers adverses. Demande un **contre** (cap/cleanse).
- **POURRITURE** = investissement. Lente à démarrer, **monstrueuse si entretenue**, **ampute les PV
  max** (dégâts permanents au combat). Récompense les combats longs / le maintien.

---

## C. BRÛLURE (Burn) — *« La chair se souvient du feu »*

### C.1 Identité & fantasy
La brûlure est un **brasier** : intense mais éphémère. Elle frappe fort tout de suite puis **meurt
d'elle-même**. Thème : un bûcher qu'il faut **réalimenter** ou il s'éteint ; les cendres qui
**s'envolent vers le voisin**. Mécaniquement = un **burst-enabler** qui punit la patience.

### C.2 Modèle mécanique précis
- **Pose** : un coup `on_hit` applique une brûlure de DPS = `pct × dégâts du coup` (modèle Ignite : « %
  du coup », https://www.poewiki.net/wiki/Ignite). PLACEHOLDER : `pct = 0.6` du coup, base 3 s.
- **Stacking = INTENSITÉ** (PoE Ignite / Grim Dawn « highest takes precedence ») : **une seule
  brûlure tick** — la plus forte. Une nouvelle application **remplace si DPS plus élevé**, sinon
  ignorée (on **ne rafraîchit pas** la durée par défaut → c'est ce qui la rend « dure à maintenir »).
  *Choix vs PoE* : PoE garde toutes les instances en mémoire ; nous, par simplicité sim et lisibilité,
  on **garde une instance** `{dps, remaining, decayEvery, decayPct, source}` et on compare au remplacement.
- **Décroissance auto (SIGNATURE)** : toutes les `decayEvery` secondes, `dps = floor(dps × (1 −
  decayPct))`. PLACEHOLDER : `decayEvery = 1 s`, `decayPct = 0.30` → une brûlure de 9 DPS fait
  9 → 6 → 4 → 2 → … Elle **s'effondre** si on ne la rallume pas. Inverse exact de la POURRITURE.
- **Tick** : accumulation entière comme le poison v0 (`acc += dps × frameDt/60` ; inflige `floor(acc)`).
  **N'ignore PAS le bouclier** (le feu attaque l'enveloppe) — la distingue de poison/bleed/rot.
- **Refresh par ré-allumage** : un coup de feu sur une cible déjà en feu **rallume** au plus haut DPS
  ET **remet la durée** (donc on PEUT la maintenir, mais il faut frapper — d'où l'archétype « entretien »).
- **Expiration** : `remaining ≤ 0` → on retire. Si `dps` atteint 0 par décroissance avant la fin →
  retiré aussi (plus rien à infliger).

### C.3 Subtilité formalisée : décroissance + propagation
- **Décroissance** : ci-dessus (`decayEvery`, `decayPct`).
- **Propagation (SIGNATURE croisée plateau)** : à la **mort** d'une unité en feu (ou via un op dédié),
  la brûlure **saute aux ennemis adjacents** (graphe du plateau) au DPS courant (× un `spreadPct`).
  Modèle Proliferation (« spread to other enemies within radius », https://www.poewiki.net/wiki/Elemental_proliferation)
  + Legacy of Fury (« Kill a Scorched Enemy to Burn each surrounding Enemy »,
  https://www.poewiki.net/wiki/Scorch). **Lit `board:neighbors(slot)`** → zéro code par sigil, et la
  forme du plateau (anneau = boucle de propagation !) devient un axe de build. Budget anti-boucle :
  une unité **déjà en feu ne re-propage pas** ce tick (règle Proliferation : « an enemy with a
  proliferated ailment will not proliferate that ailment themselves »).

### C.4 Counterplay
- **Patience** : l'IA/adversaire qui ne meurt pas vite voit la brûlure **s'éteindre** (décroissance) →
  les tanks à gros PV la diluent naturellement. C'est le contre intégré.
- **Anti-propagation** : éparpiller ses unités sur une forme à **peu d'arêtes** (ligne) limite la
  chaîne ; placer un « pare-feu » (unité immunisée/coupe-feu) entre deux voisins.
- **Cleanse/soin burst** : un soin > DPS restant éteint la fenêtre (la brûlure étant courte, un seul
  gros heal suffit souvent).

### C.5 Descripteurs `{trigger, op, params}` à ajouter
- **Nouvel op** `burn` (trigger `on_hit`) :
  `{ pct=0.6, dur=180, decayEvery=60, decayPct=0.30, refresh=true }` → pose/rallume `u.dots.burn`.
- **Nouvel op** `spread_burn_on_death` (trigger `on_death`, porté par l'unité qui meurt OU écouté par
  un effet) : `{ frac=0.7 }` → copie la brûlure aux voisins via le graphe. **Nouveau trigger
  effectif** : `on_death` est déjà émis par le bus (`arena.lua:165`), il suffit d'y abonner les effets.
- **Nouveau champ d'état** : `u.dots.burn = { dps, remaining, acc, decayEvery, decayAcc, decayPct, source }`.
- **Nouveau hook de tick** (généralisé, §F.1) : décrémente `remaining`, applique la décroissance, tick
  les dégâts (shield NON ignoré).

---

## D. SAIGNEMENT (Bleed) — *« Plus tu luttes, plus tu te vides »*

### D.1 Identité & fantasy
Une **plaie ouverte**. Faible en dégâts bruts, mais elle **handicape** : la créature blessée frappe
plus lentement (douleur, faiblesse). Thème : le sang noir qui goutte, l'ennemi qui ralentit en se
vidant. Mécaniquement = un **outil de tempo/contrôle**, pas un pic de dégâts.

### D.2 Modèle mécanique précis
- **Pose** : `on_hit` applique un saignement de DPS = `pct × dégâts du coup` (modèle Bleed PoE : « 70%
  per second of the base physical damage », https://www.poewiki.net/wiki/Bleeding). PLACEHOLDER :
  `pct = 0.5`, base 4 s. **N'ignore le bouclier que partiellement ?** → décision : **ignore le
  bouclier** (PoE : bleed bypass ES ; thème : le sang coule sous l'armure). Le saignement est **bas
  DPS** par design (c'est le slow qui le porte).
- **Stacking = INTENSITÉ + CONDITIONNEL** (modèle Bleed) : une seule instance tick (la plus forte) ;
  **ne se rafraîchit pas** seul. La **valeur tient en deux composantes distinctes** (fidèle à PoE :
  « Base Bleeding Damage and Extra Bleeding Damage are distinct things ; you can only be affected by
  one of each ») :
  - **base** (tick passif, bas) ;
  - **extra** (le multiplicateur conditionnel, §D.3).
- **Tick** : accumulation entière. Ignore le bouclier.
- **Le SLOW est un effet d'application, pas de tick** : poser/rafraîchir le bleed pose un **malus de
  cadence** sur la cible (`u.atkSlow`), retiré à l'expiration du bleed. Implémentation : la cadence
  effective = `u.cd × (1 + atkSlow)` (plus le cd est grand, plus elle frappe lentement) **ou**
  `u.atkTimer` qui s'écoule à vitesse réduite. *Vérif moteur* : `arena.lua:210` fait
  `u.atkTimer = u.atkTimer - frameDt` et `u.atkTimer = u.cd` au déclenchement → on multiplie le
  **rechargement** par `(1 + atkSlow)` quand on reset le timer (déterministe, simple).

### D.3 Subtilité formalisée : slow de cadence + bonus conditionnel « quand la cible agit »
- **Slow d'attaque (SIGNATURE)** : tant que le bleed est actif, la cible voit sa **vitesse d'attaque
  réduite** de `slowPct` (PLACEHOLDER 20 %). C'est *le* cœur de l'identité — un DoT de **contrôle**.
- **Transposition du « +140 % si la cible bouge » (PoE) → « si la cible AGIT »** : on n'a pas de
  mouvement, mais on a l'**action** (l'attaque). Règle : **chaque fois que la cible saignante
  attaque** (`on_attack` sur elle-même, ou un compteur), le bleed inflige un **burst d'« extra »**
  (× `aggravateMult`, PLACEHOLDER × 2 sur le tick suivant) — « se vider en se battant ». Cela crée la
  boucle thématique : *elle frappe → elle saigne plus → mais elle frappe plus lentement à cause du
  slow*. Tension délicieuse (modèle Aggravated, https://www.poewiki.net/wiki/Bleeding).
  - **Alternative plus simple** (si la boucle est trop complexe à équilibrer) : le bleed inflige
    juste **base** + le slow ; le « extra-on-act » devient un **palier T2** (twist), pas le socle.

### D.4 Counterplay
- **Cibles passives / défensives** : une unité à très faible cadence (tank) souffre peu du slow et
  déclenche rarement l'extra → contre naturel.
- **Cleanse / heal** : retire le bleed (et donc le slow). Le bleed étant bas DPS, on le subit
  surtout pour le **tempo**, pas pour mourir → le contre est de **ne pas dépendre de la cadence**.
- **Course à la vitesse** : empiler de la vitesse d'attaque sur SA propre carry contre une enemy
  team de bleed (le slow devient relatif).

### D.5 Descripteurs `{trigger, op, params}` à ajouter
- **Nouvel op** `bleed` (trigger `on_hit`) :
  `{ pct=0.5, dur=240, slowPct=0.20, aggravateMult=2.0 }` → pose `u.dots.bleed` + pose `u.atkSlow`.
- **Nouveau champ d'état** : `u.dots.bleed = { dps, remaining, acc, slowPct, source, extraPending }`
  et `u.atkSlow` (somme des slows actifs, lue au reset du timer d'attaque).
- **Nouveau trigger d'usage** : abonner un handler à l'**attaque de la cible** pour armer
  `extraPending` (la cible « se vide en frappant »). Réutilise `on_attack` (déjà câblé) mais **côté
  porteur du bleed = la victime** → nécessite un petit hook « quand une unité saignante agit »
  (cf. §F.2).
- **Modif moteur minimale** : au reset `u.atkTimer = u.cd` (`arena.lua:213`), multiplier par
  `(1 + (u.atkSlow or 0))`. **Une ligne**, ordre-indépendante, déterministe.

---

## E. POISON (Venom) — *« Le sang tourne, et avec lui tes forces »*

### E.1 Identité & fantasy
Le **venin contagieux**. DPS moyen, mais surtout il **corrompt** : sous poison, les capacités de la
cible **valent moins** (un bouclier de 15 n'en vaut plus que 11). Thème : putréfaction, affaiblissement
systémique, contagion lente. Mécaniquement = **scaling par cadence** + **debuff de valeur** = l'anti-
tank / anti-soigneur / anti-bouclier de la méta.

### E.2 Modèle mécanique précis
- **Pose** : `on_hit` ajoute **un stack** `{dps, remaining, acc, source}` à la **liste** `u.dots.poison`
  (array). Modèle PoE Poison / Last Epoch : **cumulatif, N instances indépendantes, timers séparés,
  pas de refresh** (« 3 stacks with SEPARATE TIMERS… stack infinitely but DO NOT refresh »,
  https://www.lastepochtools.com/guide/section/ailment_duration_and_effectiveness ;
  https://www.poewiki.net/wiki/Poison). PLACEHOLDER : `dps = 2`, base 3 s par stack (≈ l'actuel).
- **Stacking = NOMBRE** (l'axe distinctif) : le DPS total = **Σ des stacks actifs**. Plus tu frappes
  vite (cadence, voisins, duplicatas), plus ça monte. **C'est déjà presque le poison v0**, sauf qu'on
  passe de **1 instance écrasée** à **N instances cumulées** (changement à faire — v0 écrase, cf.
  `ops.lua:37` `ctx.victim.poison = {…}`).
- **Tick** : chaque stack accumule indépendamment (array + ipairs). **Ignore le bouclier** (déjà v0).
  Pour la **perf** (engine-architecture §9 : pas d'alloc en boucle chaude) : array dense, **swap-remove**
  des stacks expirés (jamais `table.remove` au milieu), tie-break `seq`.
- **Cap anti-explosion** : l'axe « nombre » croît sans plafond → **cap de stacks** (PLACEHOLDER 8,
  écho du Crimson Dance « 8 strongest applications » de PoE bleed) **ou** stacks au-delà du cap
  **fusionnent dans le plus ancien** (refresh partiel). À tuner via sim (le piège « boucle infinie /
  dégâts exponentiels » est documenté, engine-architecture §6.8).

### E.3 Subtilité formalisée : malus sur la VALEUR des capacités (le débuff signature)
- **« Affaiblissement » (SIGNATURE)** : tant qu'au moins 1 stack de poison est actif, **les valeurs
  produites par les ops de la cible sont réduites de `weakenPct`** (PLACEHOLDER −25 %). Concrètement,
  la cible empoisonnée :
  - donne **moins de bouclier** (son `shield_aura` rend 14 → 11) ;
  - **soigne moins** (lifesteal 50 % → 37 %) ;
  - inflige **moins de dégâts** (`ctx.amount × (1 − weakenPct)`).
  - *Option d'intensité* : `weakenPct` **scale avec le nombre de stacks** (ex. −4 %/stack, cap −40 %)
    → le débuff de valeur devient une 2ᵉ raison d'empiler. Aligne les deux mécaniques (nombre →
    dégâts ET affaiblissement).
- **Implémentation moteur** : un **multiplicateur lu dans le pipeline d'effets**. Le `ctx` d'`hit`
  expose la victime ; un op `apply_weaken` pose `u.weaken` ; les ops de **production** de la cible
  (shield_aura au build, lifesteal/dmg en combat) **lisent `source.weaken`** et multiplient. Modèle
  buckets « more » (engine-architecture §6.5 : `Π(more)`, commutatif → déterministe). **Note de
  timing** : `shield_aura` est résolu **au build** (avant combat) ; le malus de bouclier ne peut donc
  s'appliquer **qu'aux boucliers (re)calculés pendant le combat**, ou via une **réduction du bouclier
  courant** à l'application du poison (choix plus simple et lisible : « le venin ronge ton bouclier »
  → `shield = floor(shield × (1 − weakenPct))` une fois, à la 1re pose). À trancher en implémentation.

### E.4 Counterplay
- **Cleanse / anti-poison** : un op qui **retire des stacks** (purge) casse le scaling — contre direct
  et nécessaire (à livrer dès qu'une unité poison existe).
- **Burst > DoT** : tuer vite avant que les stacks montent (le poison est lent à démarrer).
- **Ne pas dépendre des valeurs débuffées** : une équipe sans bouclier/soin ignore l'axe
  « affaiblissement » (n'en subit que les dégâts).
- **Cap de stacks** (§E.2) = contre **systémique** intégré (empêche le one-shot par empilement).

### E.5 Descripteurs `{trigger, op, params}` à ajouter
- **Refactor de l'op** `poison` : passe d'**écrasement** à **push de stack** dans l'array
  `u.dots.poison`. `{ dps=2, dur=180 }`. (Migration : `witch` garde sa data, change de comportement.)
- **Nouvel op** `apply_weaken` (peut être fusionné dans `poison` ou séparé pour réutilisation) :
  `{ pct=0.25, perStack=0.04, cap=0.40 }` → pose/maj `u.weaken`.
- **Nouveau champ d'état** : `u.dots.poison = { {dps,remaining,acc,seq,source}, … }` (array) et
  `u.weaken` (float, recalculé au tick selon le nb de stacks).
- **Modifs de lecture** (ops de production lisent le malus) : `lifesteal` et le calcul de `ctx.amount`
  multiplient par `(1 − source.weaken)`. **Ordre-indépendant** (un seul facteur). Ne touche pas la
  boucle de combat, seulement les ops concernés (ouvert/fermé respecté).

---

## F. POURRITURE (Rot / Wither) — *« Le Puits réclame sa part »*

### F.1 Identité & fantasy
La **nécrose qui s'étend**. Lente à démarrer, **monstrueuse si entretenue** : son DPS **croît avec le
temps** (l'inverse exact de la brûlure). Et elle **ampute** : une fraction des dégâts ronge les **PV
max** (perte permanente au combat). Thème : la décrépitude du Puits, la chair qui se dissout, le savoir
qui dévore. Mécaniquement = **investissement long terme** + **dégâts d'usure permanents**.

### F.2 Modèle mécanique précis
- **Pose** : `on_hit` pose ou **renforce** `u.dots.rot` (UNE instance qui **enfle**, ne se multiplie
  pas). Modèle Diablo 4 « targeted DoT : aggregate + reset duration » (axe Durée),
  https://www.ezg.com/blog/diablo-4-season-13-you-losing-damage-dot-stacking-secrents-revealed-guide —
  mais **inversé** : au lieu de rendements décroissants, on fait **croître le DPS**.
- **Stacking = DURÉE / ACCUMULATION** (l'axe distinctif) : chaque coup `on_hit` **ajoute `growth` au
  DPS courant** et **remet la durée** (refresh). PLACEHOLDER : `dps` démarre à 1, `+1` par coup, base
  4 s, **cap DPS** (PLACEHOLDER 10) pour la lisibilité. Tant que tu entretiens → ça enfle ; si tu
  arrêtes → ça expire (et **redémarre de bas** la prochaine fois). Récompense le **focus prolongé**.
- **Croissance passive (variante)** : alternativement, `dps += ramp` **par seconde** tant qu'actif
  (croît même sans frapper, tant que pas expiré) → encore plus « investissement ». À choisir vs la
  croissance par coup (par coup = plus interactif ; par temps = plus passif). **Reco : par coup**
  (interactif, lisible, contrôlable).
- **Tick** : accumulation entière. **Ignore le bouclier** (la pourriture ronge la matière).
- **Expiration** : `remaining ≤ 0` → retiré, `dps` perdu (réinitialise).

### F.3 Subtilité formalisée : aggravation temporelle + amputation des PV max
- **Aggravation (SIGNATURE)** : le DPS **monte** (§F.2) — anti-brûlure assumé.
- **Amputation des PV max (SIGNATURE 2)** : une fraction `maxHpFrac` des dégâts de pourriture est
  **retirée des PV max** de la cible (pas seulement des PV courants) → **dégâts permanents au combat**,
  la cible ne peut plus être soignée au-delà. PLACEHOLDER : 20 % du tick ampute `maxHp`. Thème fort
  (« le Puits réclame sa part »), et **contre dur aux soigneurs/lifesteal** (complémentaire du malus
  de valeur du poison : poison réduit le **taux** de soin, pourriture réduit le **plafond**). *Vérif
  moteur* : `arena.lua` a `maxHp` et `hp` séparés ; réduire `maxHp` et clamp `hp = min(hp, maxHp)`
  est trivial et déterministe.

### F.4 Counterplay
- **Disengage / kill rapide** : si l'adversaire **cesse de l'entretenir** (sa source meurt, change de
  cible), la pourriture **expire avant d'enfler** → tuer la source de rot est le contre prioritaire.
- **Burst > usure** : la pourriture est lente ; un combat court la neutralise.
- **Sur-PV / régénération de maxHp** (relique) : contre l'amputation. Rare, façon counter-tech.
- **Cap DPS** : empêche l'usure de devenir un one-shot (lisibilité + équilibrage).

### F.5 Descripteurs `{trigger, op, params}` à ajouter
- **Nouvel op** `rot` (trigger `on_hit`) :
  `{ base=1, growth=1, dur=240, capDps=10, maxHpFrac=0.20, refresh=true }` → pose/enfle `u.dots.rot`.
- **Nouveau champ d'état** : `u.dots.rot = { dps, remaining, acc, growth, capDps, maxHpFrac, source }`.
- **Nouveau comportement de damage** : le tick de rot appelle `arena:damage` avec une option
  `{ amputate = maxHpFrac, ignoreShield=true }` → après le retrait de PV, réduit `maxHp`. **Petite
  extension de `Arena:damage`** (1 branche), ou op post-tick dédié. Ordre-indépendant.

---

## G. Refactor moteur requis (transversal aux 4 familles)

> Aucune de ces familles n'est codée ici ; ci-dessous **ce qu'il faudra ouvrir** côté moteur. Tout
> respecte l'ouvert/fermé sauf le point §G.1 (généralisation du tick, qui *remplace* le cas spécial
> `poison` actuel — c'est une dette à résoudre, pas un ajout ad hoc).

### G.1 Généraliser le tick de statuts (le seul refactor structurant)
Aujourd'hui `arena.lua:194-203` **code en dur** le tick du poison dans `update`. Avec 4 familles, il
faut une **table de statuts** + une **boucle de tick générique** :
- `u.dots = { burn?, bleed?, rot?, poison={…stacks} }` — une entrée par famille (poison = array).
- Une fonction `tickDots(u, frameDt)` itérée dans `update` (array/ipairs, ordre fixe **burn → bleed →
  poison → rot** pour le déterminisme) qui, par famille : décrémente `remaining`, applique
  décroissance/croissance, accumule (`acc += dps×frameDt/60`), inflige `floor(acc)` via `arena:damage`
  (avec le bon `ignoreShield`/`amputate`/`cause`), retire si expiré.
- **C'est le bloc autorisé à grandir** (comme la boucle de combat est fermée, le **tick de statuts
  est l'unique endroit** qui connaît les familles). Chaque nouvelle famille = +1 branche **ici** + 1
  op de pose. Acceptable et borné (4 familles, pas 400).

### G.2 Nouveaux triggers à brancher (déjà émis ou triviaux)
- `on_death` (déjà émis, `arena.lua:165`) → **propagation de brûlure** (abonner un handler).
- « **quand la cible saignante agit** » → réutiliser `on_attack` côté victime (le bleed arme un
  `extraPending` lu au tick suivant). Pas de nouveau trigger global, juste un drapeau sur l'unité.
- `combat_start` (déjà là) → reset des `dots` (sécurité).

### G.3 Nouveaux champs d'état d'unité (récap)
`u.dots` (table) ; `u.atkSlow` (bleed) ; `u.weaken` (poison) ; `maxHp` déjà présent (rot l'ampute).
Tous **sérialisables** (nombres/tables plates) → compatibles snapshots async/replay (aucune closure).

### G.4 Attribution event-log (équilibrage)
Chaque tick passe par `arena:damage(… {cause="burn"/"bleed"/"poison"/"rot", source=…})` → l'event-log
JSONL attribue les dégâts **par famille** (engine-architecture §8.2). `tools/sim.lua` pourra sortir
**part de dégâts par altération**, TTK, uptime moyen → équilibrage empirique des PLACEHOLDERS.

---

## H. Règle des 3 paliers + ~10 unités par famille (esquisses)

> **Convention paliers** (briefée) : **T1 basique** (l'effet nu, enabler lisible) · **T2 twist** (une
> torsion de la règle) · **T3 transform/clutch** (change la donne, dont ≥ 1 **croisement entre
> familles**). **5×T1 / 3×T2 / 2×T3 par famille.** Noms EN provisoires. Chiffres = **PLACEHOLDERS**.
> Pseudo-descripteurs en `{trigger op params}`. Pensée **enabler → payoff**.

### H.1 BRÛLURE (Burn) — burst, décroît, propage
**T1 (5)**
1. **Emberling** — chaff feu. `{on_hit burn {pct=0.5,dur=180}}`. L'enabler de base.
2. **Cinder-Cur** — cadence rapide, petites brûlures qui **rallument** souvent. `{on_hit burn {pct=0.4,dur=120,refresh=true}}`.
3. **Pyre-Tender** — gros coup lent → grosse brûlure de départ (front-load). `{on_hit burn {pct=0.9,dur=180}}`.
4. **Ash-Moth** — coût bas, brûlure qui **décroît vite** (très éphémère mais gratuite). `{on_hit burn {pct=0.6,dur=120,decayPct=0.45}}`.
5. **Soot-Acolyte** — adjacence : **+pct de brûlure** aux brûlures de ses voisins. `{combat_start aura_burn_pct {bonus=0.15, target=neighbors}}`.

**T2 (3) — twist**
6. **Bellows-Priest** — **anti-décroissance** : ses brûlures décroissent moitié moins (maintien facilité). `{on_hit burn {pct=0.6,dur=180,decayPct=0.15}}`.
7. **Wildfire-Hound** — à la **mort d'un ennemi en feu**, propage aux voisins (active la signature plateau). `{on_death spread_burn_on_death {frac=0.7, target=enemy_neighbors}}`.
8. **Kiln-Warden** — **convertit le surplus** : si une nouvelle brûlure serait plus faible (donc ignorée), elle **rallume + prolonge** au lieu d'être perdue (anti-feel-bad). `{on_hit burn {pct=0.5,dur=180, mode="extend_if_weaker"}}`.

**T3 (2) — transform / clutch**
9. **The Ash-Maw** *(transform)* — **toutes** les brûlures de l'équipe gagnent la propagation à la mort + **ne décroissent plus** tant que cette unité vit (change l'archétype entier). `{combat_start grant_team {tag="burn", noDecay=true, spreadOnDeath=true}}`.
10. **Plague-Pyre** *(croisement BRÛLURE×POISON)* — quand sa **brûlure se propage**, elle **applique aussi un stack de poison** au voisin touché (enabler croisé : le feu sème le venin). `{on_death spread_burn_on_death {frac=0.6, alsoPoison={dps=2,dur=120}}}`.

### H.2 SAIGNEMENT (Bleed) — bas DPS, slow de cadence, conditionnel
**T1 (5)**
1. **Razorkin** — chaff bleed + slow léger. `{on_hit bleed {pct=0.4,dur=240,slowPct=0.15}}`.
2. **Gash-Fiend** — saignement un peu plus fort, slow standard. `{on_hit bleed {pct=0.5,dur=240,slowPct=0.20}}`.
3. **Hookjaw** — gros slow, dégâts minimes (pur contrôle de tempo). `{on_hit bleed {pct=0.3,dur=300,slowPct=0.30}}`.
4. **Leech-Thorn** — bleed bas + **épines** (renvoi), punit qui le frappe (réutilise `thorns`). `{on_hit bleed {pct=0.4,dur=180}} + {on_attacked thorns {value=3}}`.
5. **Clot-Mender** — adjacence : ses voisins **appliquent aussi un petit bleed** (semeur de plaies). `{combat_start aura_grant_bleed {pct=0.2, target=neighbors}}`.

**T2 (3) — twist**
6. **Bloodletter** — **active le « extra-on-act »** : quand la cible attaque, le bleed inflige un burst ×2 (le payoff conditionnel). `{on_hit bleed {pct=0.5,dur=240,slowPct=0.20,aggravateMult=2.0}}`.
7. **Tendon-Render** — le slow **scale avec les PV manquants** de la cible (plus elle saigne, plus elle ralentit). `{on_hit bleed {pct=0.4,dur=240, slowScalesMissingHp=true}}`.
8. **Vein-Splitter** — **deux instances** de bleed plus faibles (anticipe un « bleed-stacking » façon Crimson Dance, cap 2). `{on_hit bleed {pct=0.3,dur=240, stacks=2, cap=2}}`.

**T3 (2) — transform / clutch**
9. **The Slow Bleed** *(transform)* — **tous** les bleeds de l'équipe **stackent jusqu'à 3** et le slow devient **global d'équipe ennemie** (l'archétype « la mort par mille coupures »). `{combat_start grant_team {tag="bleed", bleedCap=3, slowAura=true}}`.
10. **Marrow-Drinker** *(croisement SAIGNEMENT×POURRITURE)* — sur une cible **déjà saignante**, ses coups **convertissent le bleed en pourriture** (le sang noir devient nécrose : enabler → payoff d'usure). `{on_hit if_target_has=bleed convert_to_rot {base=2,growth=1}}`.

### H.3 POISON (Venom) — N stacks, scaling cadence, malus de valeur
**T1 (5)**
1. **Witch** *(existant, à migrer)* — stacks de venin. `{on_hit poison {dps=2,dur=180}}` (push de stack).
2. **Spore-Tick** — cadence rapide, petits stacks (empile vite). `{on_hit poison {dps=1,dur=180}}`.
3. **Bile-Spitter** — stacks moyens + **malus de valeur** de base. `{on_hit poison {dps=2,dur=180}} + {on_hit apply_weaken {pct=0.20}}`.
4. **Rot-Grub** — stacks **longue durée** (entretien facile du total). `{on_hit poison {dps=2,dur=300}}`.
5. **Miasma-Acolyte** — adjacence : voisins **+1 dps** par stack de poison qu'ils posent. `{combat_start aura_poison_dps {bonus=1, target=neighbors}}`.

**T2 (3) — twist**
6. **Corruptor** — le **malus de valeur scale avec les stacks** (−4 %/stack, cap −40 %) → anti-tank/soin. `{on_hit poison {dps=2,dur=180}} + {on_hit apply_weaken {perStack=0.04, cap=0.40}}`.
7. **Plague-Bearer** — **propage 1 stack** aux voisins de la cible à chaque pose (contagion). `{on_hit poison {dps=2,dur=180, spread={dps=1, target=enemy_neighbors}}}`.
8. **Acid-Maw** — **ronge le bouclier** : à la 1re pose, `shield = floor(shield × (1−0.30))` (le venin dissout l'armure). `{on_hit poison {dps=2,dur=180, shieldEat=0.30}}`.

**T3 (2) — transform / clutch**
9. **The Festering** *(transform)* — **supprime le cap de stacks** de l'équipe ET +1 s de durée à tous les poisons (l'archétype « empilement infini » — à équilibrer prudemment, cf. piège exponentiel). `{combat_start grant_team {tag="poison", noCap=true, durBonus=60}}`.
10. **Venom-Censer** *(croisement POISON×BRÛLURE)* — quand un ennemi atteint **≥ N stacks** de poison, il **prend feu** (gros burst de brûlure = le payoff du build « accumule puis détonne »). `{on_tick if_target_stacks>=5 ignite_burst {pct=2.0, dur=120}}`.

### H.4 POURRITURE (Rot / Wither) — enfle avec le temps, ampute les PV max
**T1 (5)**
1. **Rot-Hound** — pourriture de base qui enfle par coup. `{on_hit rot {base=1,growth=1,dur=240}}`.
2. **Carrion-Pecker** — cadence rapide → enfle vite (mais cap bas). `{on_hit rot {base=1,growth=1,dur=180,capDps=6}}`.
3. **Maggot-King** — démarrage lent, **cap haut** (récompense le long terme). `{on_hit rot {base=1,growth=1,dur=300,capDps=12}}`.
4. **Necro-Leech** — pourriture + **amputation renforcée** des PV max. `{on_hit rot {base=1,growth=1,dur=240,maxHpFrac=0.35}}`.
5. **Decay-Tender** — adjacence : voisins **+growth** sur leur pourriture. `{combat_start aura_rot_growth {bonus=1, target=neighbors}}`.

**T2 (3) — twist**
6. **The Patient Worm** — la pourriture **croît même sans frapper** (ramp passif/seconde tant qu'active). `{on_hit rot {base=1, passiveRamp=1, dur=240}}`.
7. **Hollow-Gut** — **convertit l'amputation en soin** pour le porteur (vol de PV max : la pourriture nourrit). `{on_hit rot {base=1,growth=1, amputateHealsMe=0.5}}`.
8. **Blight-Spreader** — quand une cible **meurt** sous pourriture, **pose une pourriture** aux voisins (l'usure se propage à la mort). `{on_death spread_rot {base=2, target=enemy_neighbors}}`.

**T3 (2) — transform / clutch**
9. **The Pit-Maw** *(transform, signature thème)* — **tous** les DoT de l'équipe **amputent** désormais les PV max (×maxHpFrac) tant que cette unité vit (le Puits réclame sa part — change toutes les familles). `{combat_start grant_team {tag="alldots", amputateAll=0.15}}`.
10. **Wither-Bloom** *(croisement POURRITURE×SAIGNEMENT/POISON)* — sa pourriture **ralentit la cadence ET réduit les valeurs** de la cible proportionnellement au DPS de rot (fusionne les signatures slow + malus dans l'usure qui enfle ; ultime anti-stat.). `{on_hit rot {base=2,growth=1, slowPerDps=0.03, weakenPerDps=0.03}}`.

---

## I. Synthèse des nouveaux ops / triggers / champs (récap pour l'agent moteur)

**Ops de pose (1 par famille + variantes)** :
`burn`, `bleed`, `rot`, `poison` (refactor : push de stack) ; auras `aura_burn_pct`,
`aura_grant_bleed`, `aura_poison_dps`, `aura_rot_growth` ; débuffs `apply_weaken` ;
propagation `spread_burn_on_death`, `spread_rot`, poison `spread` ; croisements
`convert_to_rot`, `ignite_burst`, `alsoPoison` ; équipe `grant_team`.

**Triggers** : tous **déjà émis** ou triviaux — `on_hit`, `on_attack` (côté victime pour bleed),
`on_death` (propagations), `combat_start` (auras/team/reset), `on_tick` (seuils, ex. Venom-Censer).
**Aucun trigger temps-réel** ; tout reste déterministe et seedé.

**Champs d'état d'unité** (sérialisables) : `u.dots = {burn?, bleed?, rot?, poison=[…]}` ;
`u.atkSlow` (bleed) ; `u.weaken` (poison) ; amputation via `maxHp` existant.

**Refactor structurant unique** : généraliser le **tick de statuts** d'`arena.lua` (le cas `poison`
codé en dur devient une **table de familles** + `tickDots()`), ordre fixe burn→bleed→poison→rot.

**Modifs moteur ponctuelles** (bornées, ordre-indépendantes) : reset du timer d'attaque ×`(1+atkSlow)`
(bleed) ; lecture de `source.weaken` dans les ops de production (poison) ; option `amputate` dans
`Arena:damage` (rot) ; `ignoreShield` **par famille** (burn=non ; bleed/poison/rot=oui).

---

## J. Tableau de cohérence final (les 4 identités tiennent ensemble)

| | BRÛLURE | SAIGNEMENT | POISON | POURRITURE |
|---|---|---|---|---|
| **Axe** | Intensité ↓ | Intensité + cond. | Nombre | Durée ↑ |
| **Courbe DPS** | pic puis **décroît** | plat (bas) | **monte** (par stacks) | **monte** (par entretien) |
| **Joué pour** | burst / finish | tempo / contrôle | scaling / anti-stat | usure / permanent |
| **Signature** | décroissance + propagation | **slow de cadence** + extra-on-act | **malus de valeur** | aggravation + **ampute maxHp** |
| **Bouclier** | **léché** (non ignoré) | ignoré | ignoré | ignoré |
| **Contre clé** | patience (s'éteint) | cibles passives / cleanse | cleanse / cap | disengage (expire) |
| **Plateau** | propage par arêtes (anneau) | slow d'équipe (T3) | contagion voisins | propage à la mort |
| **Anti-soin** | non | non | réduit le **taux** | réduit le **plafond** |

Les **4 axes de stacking sont orthogonaux** → 4 manières *distinctes* de jouer le DoT, sans règle
redondante. Les croisements T3 (feu→poison, sang→rot, poison→feu, rot→slow+malus) créent l'espace
« enabler → payoff » entre familles. **Tension d'archétype propre** : BRÛLURE (décroît) ⇄ POURRITURE
(croît) ; POISON (taux de soin) ⇄ POURRITURE (plafond de soin) ; SAIGNEMENT = le seul orienté
**contrôle** plutôt que dégâts.

---

## K. Questions ouvertes (à trancher avant implémentation)

1. **Brûlure** : garder **1 instance** (notre simplification) ou les N instances de PoE (mémoire +
   lisibilité) ? Reco : 1 instance.
2. **Saignement** : le « extra-on-act » est-il le **socle T1** ou un **twist T2** ? (Complexité
   d'équilibrage de la boucle frappe→saigne-plus↔slow.) Reco : T2 (socle = base + slow).
3. **Poison** : **cap de stacks** (8 ?) ou **fusion au-delà du cap** ? (Anti-explosion.) Reco : cap +
   tune via sim.
4. **Poison/malus de valeur** : réduire le **taux** (recalcul) ou **manger le bouclier courant** une
   fois (plus simple) ? Reco : manger le bouclier + réduire taux de soin/dégâts.
5. **Pourriture** : croissance **par coup** (interactive) ou **par temps** (passive) ? Reco : par coup.
6. **Amputation maxHp** : trop punitif vs soigneurs ? La réserver à **T2+** (pas le T1) ?
7. **Ordre de tick** burn→bleed→poison→rot : suffisant pour le déterminisme, ou besoin d'un `seq`
   global cross-familles ? (Probablement l'ordre fixe suffit.)
8. **`ignoreShield` de la brûlure** : « léché » (non ignoré) est un choix thématique — valider qu'il
   ne rend pas la brûlure trop faible contre les compos à bouclier (sim).

---

## L. Index des sources (primaires d'abord)

- **PoE Ignite** (1 instance la plus forte, % du coup, durée fixe) — https://www.poewiki.net/wiki/Ignite
- **PoE Bleeding** (1 instance la plus forte, 70 %/s, +140 % si la cible bouge / Aggravated, base/extra distincts) — https://www.poewiki.net/wiki/Bleeding
- **PoE Poison** (cumulatif, N stacks indépendants illimités, 30 %/s, timers séparés, bypass ES) — https://www.poewiki.net/wiki/Poison
- **PoE Scorch** (altération qui **affaiblit** : −résistances, pas de dégâts) — https://www.poewiki.net/wiki/Scorch
- **PoE Ailment** (taxonomie, élémentaire vs non-élémentaire, seuil d'altération) — https://www.poewiki.net/wiki/Ailment
- **PoE Elemental Proliferation** (propagation aux ennemis proches ; « ne se re-propage pas soi-même ») — https://www.poewiki.net/wiki/Elemental_proliferation
- **PoE Legacy of Fury** (tuer un Scorched → brûle les ennemis adjacents) — https://www.poewiki.net/wiki/Scorch
- **PoE Infernal Legion** (ignite de zone basé sur la vie) — https://poe2db.tw/us/Infernal_Legion_I
- **Last Epoch — Ailment stacking** (chaque application = stack à timer propre, empile à l'infini, ne refresh pas ; le nombre de stacks/fenêtre = le DPS) — https://www.lastepochtools.com/guide/section/ailment_duration_and_effectiveness · https://steamcommunity.com/app/899770/discussions/0/3789254716322831209/
- **Grim Dawn — DoT par source** (« highest damage takes precedence » par source ; sources différentes s'additionnent ; effet plus faible attend la fin du plus fort) — https://forums.crateentertainment.com/t/grim-dawn-dots-for-dummies-a-primer/37738 · https://grimdawn.fandom.com/wiki/Game_Mechanics
- **Diablo 4 — DoT ciblé** (fusion + reset de durée, rendements décroissants ; tick fixe 0,5 s ; même source refresh, sources différentes stackent) — https://www.ezg.com/blog/diablo-4-season-13-you-losing-damage-dot-stacking-secrents-revealed-guide · https://game8.co/games/Diablo-4/archives/415224
- **PoE 2 Ignite/Poison** (magnitude % du coup, ne stacke pas / poison stacke ; Flammability, Compounding Ignite) — https://www.poe2wiki.net/wiki/Ignite · https://poe2db.tw/us/Poison

> Voir aussi : `docs/research/engine-architecture.md` (§6 effets, §8 sim, §9 perf),
> `docs/research/combat-model-decision.md` (vie par entité, ciblage déterministe),
> `src/effects/ops.lua` (poison v0 à refactorer), `src/combat/arena.lua` (tick à généraliser).
