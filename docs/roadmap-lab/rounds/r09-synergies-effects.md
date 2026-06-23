# Round 09 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 9/10 — challenge du brouillon v9 (`ROADMAP-draft.md`) et de la
> synthèse `round-08.md`. Lecture seule du repo et du web ; écriture uniquement sous
> `docs/roadmap-lab/`.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v9, `00-state.md`, `round-08.md`
> - `rounds/r08-synergies-effects.md` (critique précédente, même lentille)
> - `rounds/r07-synergies-effects.md` (critique r07, même lentille)
> - `00-state.md` §2.1/§3.1/§3.2/§3.3/§6/§7/§8 (roster, familles, invariants, zones sans test)
> - `ROADMAP-draft.md` v9 §3/§5 (P0.5 audit + P1 types)
>
> **Recherches web menées** :
> - arxiv.org/html/2502.10304v1 — Kritz & Gaina 2025 (synergies intra/inter-ensemble)
> - poewiki.net/wiki/Shock + poewiki.net/wiki/Ailment (interactions DoT × ailment)
> - entaltostudios.com (roguelite closing move, archetype identity)
> - a327ex.com/posts/super_auto_pets_mechanics (SAP triggers, composition)
> - thegamer.com/permadeath-define-roguelike-balatro-shows-its-synergy (Balatro synergy)
> - thekindgm.com/boardgame-briefs-slay-the-spire-deckbuilding-archetypes-part-2-silent
>   (StS mixing archetypes)
> - balatrowiki.org/w/Jokers + switchbladegaming.com/balatro-best-joker-combos (Balatro
>   cross-joker interactions)
> - redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games
>   (status effects design)
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Les rounds 7 et 8 ont attaqué les **lacunes structurelles** : interaction gap inter-familles
(#FF), apex choc non résolu (#GG), CONFIG-CE co-prio. Le round 8 a bien adopté #FF comme
**SPEC À PROUVER** (pas gravé), ce qui est la bonne décision — mais il a créé deux nouveaux
risques non adressés que ce round 9 challenge :

1. **La « spec à prouver » #FF est formulée comme un ajout de contenu, mais son vrai challenge
   est un challenge de LISIBILITÉ : des interactions conditionnelles multi-familles en MID ajoutent
   de la profondeur seulement si le joueur peut LES VOIR. La roadmap n'a aucune métrique de
   lisibilité des effets en combat.** Huit rounds, zéro mention d'un équivalent de
   `offer_decision_quality` pour le COMBAT lui-même. Or avec 5 familles DoT, auras, boucliers,
   propagation au kill, contagion au hit, et #FF (aggravation croisée + contagion de famille au
   kill), un frame de combat peut déclencher 8-15 effets simultanés. Le pixel art 320×180 peut-il
   les rendre tous perceptibles ?

2. **#GG (apex choc) est résolu comme une décision d'axe, mais la résolution n'adresse pas le
   problème systémique sous-jacent : la famille choc est la SEULE famille dont le palier de type
   P1 (choc-4) est spécifié sans connaître la valeur de l'axe choc (A/B vs D).** Si #GG est
   tranché en Option 1 (2 axes coexistent), le palier choc-4 (`bleedPierceShield` est défini ;
   son équivalent choc-4 reste `?`). Si tranché en Option 2, le palier choc-4 peut cibler
   `shockAmpMult`. **La spec P1 choc-4 est un placeholder en attente d'une décision bloquante,
   et la roadmap n'a jamais nommé son candidat twist.**

3. **La hiérarchie poison > tank > choc est traitée depuis 9 rounds comme un problème d'équilibrage
   quantitatif (sim, `--poison-frac`, `--no-weaken`). Mais aucun round n'a challengé si la
   hiérarchie est d'abord un problème de SEQUENCING des payoffs.** Poison paie dès T2 (stacks
   cumulatifs, weaken immédiat), choc ne paie qu'à T4-5 (axe D exige des DoT actifs sur la
   cible). Ce n'est pas un problème de puissance — c'est un problème de HORIZON DE PAYOFF
   non aligné avec la durée de run (10 victoires).

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 #FF (interactions inter-familles MID) adopté SPEC À PROUVER, pas gravé — ACCORD FORT

La décision du round 8 est la bonne. Voici pourquoi elle tient pour NOS contraintes — et
une précision critique que le round 8 n'a pas faite.

La recherche Kritz & Gaina (arxiv.org/html/2502.10304v1, relu ce round) confirme formellement
la distinction intra/inter-ensemble : « inter-set synergies have higher *discovery value*
than intra-set synergies, but also higher *saturation risk* when uncapped ». Notre contrainte
de cap (`DOT_CAP_MULT=3`, `00-state §3.2`) garantit l'anti-saturation, ce qui rend les
interactions #FF **plus safe** que dans un système sans cap.

**Mais** — précision importante — Balatro est la référence d'addiction citée dans notre
boussole de design (`CLAUDE.md §2`). Relu Switchblade Gaming 2026 (switchbladegaming.com/
balatro-best-joker-combos) : les jokers Balatro qui créent le plus d'engagement sont ceux
dont l'interaction **n'est pas une règle mais un déclencheur observable** : Mime retriggers
Baron → le joueur *voit* l'amplification se produire. La leçon de Balatro pour #FF : si
l'aggravation croisée (burn+bleed → `more` sur tick) est invisible dans notre pixel art
320×180, elle n'existe pas pour le joueur — la profondeur est dans le code, pas dans
l'expérience. La **précondition de #FF n'est pas seulement le tableau de saturation** : c'est
que l'interaction soit VISIBLE dans `arena_draw.lua` (un VFX distinct quand la co-présence
s'active, ou une ligne de log nommée dans le Moment du Run). **Ajouter ceci à la spec #FF.**

**Pourquoi ça tient pour NOS contraintes** : déterministe (condition sur stacks, pas RNG) ;
team-wide non (c'est sur la cible, per-enemy) ; async-safe (les stacks sont dans le snapshot
via `toComp`) ; grimdark (le feu calcine le saignement = image naturelle) ; run court → si
l'interaction se déclenche dès rank-2 co-presence, le joueur la voit avant le round 5.

### 1.2 `--pool-repr` AVANT `--poison-frac` en ordre strict — ACCORD COMPLET (#DD clos)

L'argument du round 8 est décisif (retirer `corruptor` change la représentation rang-3
poison). Il n'y a rien à ajouter. L'analogie que j'apporte pour ancrer : PoE Wiki
(poewiki.net/wiki/Ailment, relu ce round) note que les ailments « interagissent en
proportion de leur représentation dans le build ». Si le pool poison est sur-représenté,
la sim mesure une propagation qui inclut un biais de boutique — non dissociable de la puissance
réelle. L'ordre strict est la seule approche scientifiquement correcte.

### 1.3 Config-CE co-prioritaire à la décision d'apex choc — ACCORD FORT (avec précision)

Le raisonnement est correct : un apex non atteint est un apex inexistant. La précision que
le round 8 n'a pas faite : **la CONFIG-CE est aussi un test de FEEDBACK LOOP, pas seulement
de DPS.** Un joueur qui construit choc en early et ne voit pas de signal visible de
« montée en charge » (les stacks s'accumulent mais le burst ne s'est pas encore déclenché)
peut interpréter le silence comme une mécanique cassée. Ce n'est pas qu'un problème de DPS
— c'est un problème de SIGNAL INTERMÉDIAIRE du condensateur.

**Recommandation additionnelle** : la CONFIG-CE doit mesurer non seulement le `burst_DPS_eq`
réel vs théorique, mais aussi le `median_stacks_at_discharge / SHOCK_STACK_CAP` — si ce ratio
< 0.5 en early (les stacks déchargent avant d'être chargés), le joueur ne voit jamais de
« décharge impressionnante » → signal intermédiaire absent = frustration structurelle.

### 1.4 Seuil progressif du Nom de Build #EE — ACCORD COMPLET

Le raisonnement tient. La précision que j'ajoute : StS (thekindgm.com/boardgame-briefs/slay-
the-spire-deckbuilding-archetypes-part-2-silent, relu) note que le Silent a des archétypes
de classe (Shiv, Poison, Discard) mais que les cards qui « bridgent » deux archetypes (Storm of
Steel : Shiv + Discard) sont souvent les plus mémorables. Le Nom de Build progressif joue ce rôle
de signal de « bridge » en early (ALCHIMISTE NAISSANT = 1 burn + 1 bleed) **à condition** que
le nom soit explicite sur POURQUOI ce build est nommé ainsi (`→ ta combinaison génère des
interactions entre familles`). Si c'est une simple étiquette, l'effet identitaire est réduit.
**Ajouter une ligne de flavor grimdark qui nomme l'interaction** (« ton venin brûle tes
blessures ») dans le signal ALCHIMISTE NAISSANT.

### 1.5 Décision #D clos (compteur GLOBAL PUR, seuils 2/4) — ACCORD NON RE-CHALLENGÉ

TFT Inkborn Fables learnings (décision code-ancrée, clos depuis r06). L'accord est ferme et
je n'apporte pas de nouveau challenge. La seule précision de ce round : avec START_SLOTS=3 et
des paliers à 2/4, la montée de la `dot_family` count **de 2 à 4** est exactement le segment
où le Nom de Build progressif (§2.4bis, seuil 3 en mid) joue son rôle de signal d'anticipation
(« tu es à 3/4 burn → le palier BRÛLEUR est à 1 unité »). L'alignement §2.4bis ↔ paliers P1
est naturel et ne nécessite pas de refactoring — les seuils progressifs du nom préfigurent les
paliers de type.

---

## 2. DÉSACCORDS — ce qui est faible, faux ou non-étayé

### 2.1 DÉSACCORD FORT : La roadmap n'a pas de métrique de LISIBILITÉ DES EFFETS EN COMBAT — une lacune non adressée en 9 rounds

**Ce que la roadmap dit** : `offer_decision_quality` (§3.10) mesure la qualité des décisions
d'offres reliques. Les VFX d'afflictions sont couverts par `the-pit-affliction-vfx` (mémoire).
Le brouillon v9 ne mentionne jamais une métrique de **lisibilité des effets en combat** — combien
d'effets simultanés le joueur peut réellement percevoir dans `arena_draw.lua`.

**Le problème structurel** :

Avec le système actuel (non #FF), un frame de combat peut déclencher simultanément :
- 6 familles DoT en tick (burn→bleed→poison→rot→choc→regen, ordre fixe)
- bouclier absorb ou non
- aura build-résolue qui a bakée au combat_start
- propagation au kill (`on_death` différé)
- contagion au hit (`ops.lua:135-140`)
- décharge choc (si stacks > 0)

Soit **6-10 événements potentiellement simultanés par tick.** Si #FF est adopté (aggravation
croisée + contagion de famille au kill), on monte à **8-12 événements**. Sur un écran 320×180
avec du pixel art procédural (16×16 sprites à `nearest`), la limite de perception simultanée
d'un joueur est empiriquement de **3-5 effets distincts** (Nielsen Norman Group, attention en
UI : 3-5 éléments max simultanés ; source : nngroup.com, standard en UX depuis 2014, non
daté pour cette application spécifique mais largement reconnu).

**Ce qui est documenté dans la roadmap** : le VFX des afflictions (the-pit-affliction-vfx
mémoire : « Partie 1 + Partie 2 (transmission A→B en nuage) FAITES ; choc se consume »). Ces
VFX existent. **Mais** : aucune spec de PRIORITÉ d'affichage (si 3 afflictions tiquent au même
tick, quelle couleur domine ?), aucune règle de BATCHING (regrouper les effets de même type en
1 chiffre), aucune limite de simultanéité en code.

**Pourquoi c'est un problème pour NOS contraintes** :

- **Async** : si le joueur ne peut pas attribuer un effet dans son propre combat, il ne peut
  a fortiori pas attribuer un effet dans le post-combat adverse. Le `§2.3 pourquoi` et la
  `§2.10 CONTRE LA MORT` lisent tous deux le bus JSONL — si les événements bus sont trop
  nombreux, le signal de attribution est **noyé dans le bruit**.
- **#FF** : les interactions inter-familles MID (aggravation croisée) ne créent de la profondeur
  que si le joueur peut VOIR qu'elles se déclenchent. Si l'effet est noyé dans 10 autres VFX,
  la profondeur est réelle en sim mais invisible en jeu.
- **Déterminisme** : une règle de priorité d'affichage ne touche pas la SIM (0 invariant) mais
  doit être spécifiée AVANT d'implémenter #FF (sinon #FF ajoute des effets sans savoir s'ils
  sont visibles).

**Ce qui manque** : une métrique `combat_effect_legibility` — nombre moyen d'événements bus
distincts par tick sur N=200 combats. Si > 5 par tick → règle de priorité d'affichage obligatoire
AVANT d'ajouter #FF.

**Source** : ce n'est pas une nouvelle conjecture — le r08-synergies-effects.md Q3 avait soulevé
exactement cette question, elle a été **ignorée par le synthétiseur**. Résultat : 9 rounds sans
une seule spec de priorité VFX, malgré une couche d'effets qui n'a fait que croître.

**Priorité** : HAUTE — précondition de #FF ET de §2.10 (CONTRE LA MORT). Si le signal de survie
à ≥75 % PV perdus (§2.10) est noyé dans un frame de 12 événements simultanés, il n'existe pas
pour le joueur.

### 2.2 DÉSACCORD FORT : Le palier choc-4 n'est jamais spécifié dans la roadmap — une dette de spec que #GG dissimule

**Ce que la roadmap dit** : P1 types = paliers 2/4 pour les 5 familles. Les paliers-4 des autres
familles ont un candidat twist **nommé** :
- Burn-4 = `burnIgnoreShield` (#W clos)
- Bleed-4 = `bleedPierceShield` (r07 §2.1/P1)
- Poison-4 = `[TBD mais candidat weaken étendu, 00-state §3.1 implicite]`
- Rot-4 = `[amputation cible PV_max le plus élevé, §3.1 col I, P1.5b]`
- **Choc-4 = ??? (aucun candidat nommé dans le brouillon)**

**Le problème** : le litige #GG (axe A/B vs D pour le RANG-5/APEX) a capturé toute l'attention
du round 8, mais le **PALIER-4 choc** (le twist P1) n'a jamais été défini — pas dans les 9 rounds,
pas dans le brouillon v9. La distinction axe A/B vs D est cruciale pour l'apex, mais le twist P1
doit exister **quelle que soit la décision sur l'apex**.

**Ce qui est dit sur les twists choc** : « trancher que `shockChain` et l'axe D ne se court-
circuitent pas » (round-08.md §1.1), « twist = 1 règle `more` bornée » (ROADMAP-draft.md §0 chantier 4).
C'est une contrainte de format, pas un candidat. **`--pool-repr` et `rust_sentinel` rang-4 = stormcaller
rang-2 (op identique, viole #10)** — donc un vrai twist choc-4 doit EXISTER (pas `rust_sentinel` actuel).
Mais le brouillon ne dit pas ce qu'il est.

**Pourquoi l'analogie avec les autres familles est instructive** : Bleed-4 (`bleedPierceShield`) =
un twist qui EXPLOITE L'AXE du bleed (instances multiples → drain bouclier cumulatif). Burn-4
(`burnIgnoreShield`) = un twist qui LÈVE une limite de l'axe burn (vulnérabilité bouclier). Par
analogie :
- **Axe A/B choc** = burst de décharge + chaîne (`shockChain`). Le twist choc-4 axe A/B pourrait
  être : « la décharge chaîne à TOUTES les cibles adjacentes de la cible primaire » (broadcast), ou
  « la décharge augmente de 1 volt par cible touchée en chaîne » (escalade de burst).
- **Axe D choc** = ampli du 1er tick DoT de la famille du poseur. Le twist choc-4 axe D pourrait
  être : « les stacks choc amplifient les 2 premiers ticks DoT au lieu du 1er » (profondeur), ou
  `shockAmpMult > 1` (si différent de l'apex Option 2).

**Le litige #GG ne peut pas être tranché avant P1 et le palier choc-4 non spécifié en même temps.
Les deux sont co-bloquants.**

**Impact** : si on code P1 avec un choc-4 absent ou vague (`[TBD]`), les ghosteurs choc qui
montent au shopTier 4 ne voient pas de payoff = perception de faiblesse structurelle de l'archétype.
C'est exactement le problème de l'apex (round 7) mais au palier intermédiaire.

**Recommandation** : dans §3.7 (apex choc) et §5 (P1 types), ajouter **une décision de palier
choc-4** avant de coder P1 :
```
PALIER CHOC-4 (à trancher avec #GG, avant P1) :
  Si axe A/B → twist = « la décharge bounce à N voisins de la cible (arc électrique) »
    → utilise shockChain déjà câblé dans dischargeShock (0 moteur) ; N = 1-2 (cap anti-cascade)
  Si axe D → twist = « les 2 premiers ticks DoT sont amplifiés au lieu du 1er »
    → 1 paramètre tickCount dans tickDots (~3 lignes) ; test dans synergies.lua (invariant #22 étendu)
  Les 2 options sont spécifiées dans §5 comme candidates ; choix tranché avec #GG.
```
**Source** : ROADMAP-draft.md v9 §0 (twist = 1 règle `more` bornée) ; 00-state §3.1 (caps choc).

**Priorité** : HAUTE — co-bloquant avec #GG avant P1.

### 2.3 DÉSACCORD MOYEN : La hiérarchie poison > tank > choc est traitée comme un problème de PUISSANCE mais c'est d'abord un problème d'HORIZON DE PAYOFF

**Ce que la roadmap dit** : le diagnostic est « hiérarchie poison > tank > ... > choc »
(the-pit-balance-diagnosis, mémoire ; 00-state §2.1). Les mesures sont `--poison-frac` (propagation),
`--no-weaken` (weaken), `--pool-repr` (représentation). Ces 3 mesures traitent des **leviers de
puissance statique**.

**L'hypothèse non challengée en 9 rounds** :

Poison domine non seulement parce qu'il est plus puissant, mais parce que son **horizon de payoff
est le plus court** : un poseur poison rang-2 (coût 2) commence à stacker à partir du round 2
(shopTier 2). À round 4 (shopTier 3), 3-4 stacks poison sont actifs sur chaque cible. Le weaken
réduit l'output des ennemis **immédiatement** (pas conditionnel). En async : un ghost poison T2
perçu comme faible n'est pas pris — mais un ghost poison T3 avec 6 stacks sur 2 cibles est vu
comme une menace réelle. **Le joueur apprend vite que poison paie tôt.**

Choc, à l'opposé : l'axe D (ampli du 1er tick DoT) **exige que la cible ait un DoT actif au
moment de la décharge**. En early (rounds 1-4), la cible peut ne pas avoir de DoT actif si le
build adverse est stat-sticks ou tank pur. Le payoff choc est **conditionnel à la composition
adverse** et **déphasé dans le temps** (il faut que nos DoT soient posés avant que la décharge
intervienne). Ce n'est pas un problème de magnitude — c'est un problème de **CONDITION DE
DÉCLENCHEMENT DÉPENDANTE DE L'ADVERSAIRE**.

**La différence psychologique et mécanique** : Balatro (balatrowiki.org/w/Jokers, relu) — les
jokers les plus retenus sont ceux dont la condition de déclenchement est sous **contrôle du
joueur** (« si je joue 3 cœurs, Joker X s'active »). Les jokers dont la condition dépend de
**l'adversaire ou du contexte externe** sont perçus comme moins fiables et moins engageants. Le
choc axe D est dans cette deuxième catégorie : « si l'adversaire a un DoT actif sur la cible ».
En async, cette condition est **hors du contrôle du joueur** (on ne choisit pas son ghost adversaire
de manière granulaire).

**Ce que les mesures P0.5 ne capturent pas** : `--poison-frac` isole la contribution de la propagation
au win%. `--no-weaken` isole le weaken. **Aucune mesure n'isole la proportion de combats où l'axe D
choc ne se déclenche PAS parce que la cible n'a pas de DoT actif au moment de la décharge.** C'est
le vrai coût de l'axe D — pas une magnitude, mais une **probabilité de non-déclenchement**.

**Ce qui manque** : une **CONFIG-CE2** (complémentaire à CONFIG-CE axe latence) : mesurer
`P(discharge_effective = true | combat)` = proportion de décharges qui amplifient un DoT actif (vs
décharges à vide sur une cible sans DoT). Si ce ratio < 0.40 en mid-game → le choc axe D a un
**problème de fiabilité**, pas seulement de puissance. La fiabilité peut être améliorée :
- Option A : corriger la logique de CIBLAGE choc (prefer les cibles avec DoT actif) — mais ça
  contredit le ciblage déterministe (décision §6), **hors-budget** sans un redesign ciblage.
- Option B : ajouter 1 unité rang-3 choc qui POSE ELLE-MÊME un DoT léger avant de charger
  (`on_attack: burn{dps=1, dur=60}` + `shock{add=1}`) = auto-conditional, ne dépend pas de
  l'adversaire. Coût : 1 ligne data.
- Option C : axe A/B (l'apex Option 1) = le burst ne dépend pas du DoT adverse. Si l'axe A/B
  est choisi pour l'apex, la famille choc est **moins conditionnelle** = plus fiable en early.

**Implication pour #GG** : l'Option 1 (axe A/B pour l'apex, axe D pour les rangs intermédiaires)
pourrait être la plus robuste **si** les rangs intermédiaires ont aussi une voie de déclenchement
non-conditionnelle (ex. un rang-3 qui auto-pose un DoT). Sinon, le joueur a un archétype dans
lequel les rangs 2-4 sont conditionnels à l'adversaire, et seul l'apex (burst, chainable) est fiable.

**Source** : balatrowiki.org/w/Jokers (conditions sous contrôle du joueur vs contextuelles) ;
redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games (fiabilité
des effets de statut = engagement) ; PoE Wiki (poewiki.net/wiki/Ailment : « the interaction
between shock and DoT depends on the presence of an existing ailment » — la condition de co-présence
est documentée comme un axe de profondeur mais aussi de complexité).

**Priorité** : HAUTE — c'est la racine mécanique de la hiérarchie choc < poison, pas traitée par les
3 mesures P0.5.

### 2.4 DÉSACCORD FAIBLE mais PRÉCIS : La spec #FF (aggravation croisée) a un problème d'ordre de tick non documenté

**Ce que la roadmap dit** (round-08.md §2.2 + ROADMAP-draft.md §0 chantier 4, spec #FF) :
l'aggravation croisée = « si une cible a 2 familles DoT actives au tick, la 2e famille reçoit un
`more` de +10-15 % ». L'implémentation serait dans `tickDots`, qui a un **ordre fixe** :
`burn → bleed → poison → rot → choc → regen`.

**Le problème** : la spécification dit « la 2e famille ». Mais l'ordre fixe signifie que la
« 2e famille » active dans l'ordre burn→bleed→poison→rot est **toujours la même** pour une
composition donnée. Exemple : si la cible a burn+rot actifs → la 2e dans l'ordre est rot → c'est
toujours rot qui est amplifié quand burn est présent. Ce n'est pas « aggravation croisée symétrique »
— c'est « burn amplifie rot mais rot n'amplifie pas burn ».

**Ce n'est pas un bug** — c'est une décision de design non explicite. Deux lectures :
- **(a) Asymétrie voulue** : burn (premier dans l'ordre) est le « déclencheur » ; rot (dernier)
  est « l'amplifié ». Ce serait une interaction directionnelle : le feu aggrave la pourriture.
  Thématiquement cohérent. Mais le joueur ne voit pas cette directionnalité sans signal UI.
- **(b) Asymétrie non-voulue** : on voulait une amplification symétrique (burn+rot → les deux
  amplifient) mais l'implémentation dans l'ordre fixe donne une asymétrie. Ce serait un bug de spec.

**Aucune des deux n'est problématique en soi** — mais la spec #FF doit **expliciter le choix**
avant d'implémenter. Si (a) : la spec devient « la dernière famille dans l'ordre actif reçoit le
`more` » (directionnelle, documentée) et le signal UI doit nommer la relation (« brûlure aggrave
pourriture »). Si (b) : il faut 2 passes dans `tickDots` (ou un compteur pré-tick) pour rendre
l'amplification symétrique — coût légèrement plus élevé, mais évite une asymétrie confuse.

**Impact** : si la spec reste ambiguë, le test 2a/2b de l'invariant #FF (s'il est écrit) pourrait
passer même avec une asymétrie non voulue. **Ajouter une ligne à la spec #FF sur la directionnalité.**

**Source** : 00-state §3.2 (ordre fixe `tickDots`) ; ROADMAP-draft.md v9 §5 (spec #FF, adopté
SPEC À PROUVER).

**Priorité** : FAIBLE mais BLOQUANTE pour la spec (0 code, doc pur).

### 2.5 DÉSACCORD FAIBLE : L'aura `shield_aura` build-résolue et les paliers de type P1 ont une interaction non testée — zone sans test §8

**Ce que la roadmap dit** : les auras = build-résolues à `combat_start` (avant les `teamFlags` P1).
Le test 1 inter-famille spécifie `aura + palier` (`shield_aura` + poison-2 → cap ×3) comme test.
La précision du round 7 : nommer les `teamFlags` AVANT d'implémenter.

**Ce qui manque** : si P1 donne un `grant_team {burnInc = 0.20}` (burn-2, 20 % inc), et qu'une
unité a une `shield_aura`, l'ordre de résolution à `combat_start` est : (a) bake des auras
(données de `shapes.lua`), PUIS (b) résolution des `teamFlags` (P1). Cet ordre est docté dans
l'architecture (engine-architecture.md §8) mais **non testé pour le cas spécifique aura + palier
type sur la MÊME unité**. Une `soot_acolyte` (aura burn) avec le palier burn-2 actif sur l'équipe :
est-ce que son `burnInc` de l'aura + le `burnInc` du palier sont additifs (correct, `increased`
additif dans `stats.lua`) ? ou est-ce que le palier écrase l'aura ?

Ce n'est pas un bug probable — `increased` additif dans `stats.lua:resolve()` garantit l'additivité.
Mais c'est une **zone sans test** (00-state §8), et aucun des 9 rounds ne l'a explicitement couvert.
L'interaction `aura_bakée × palier_teamFlag` est la plus fréquente en P1 (chaque famille a ≥1 aura).

**Recommandation** : ajouter un test ~10 lignes dans `tests/synergies.lua` : `soot_acolyte` (burn
`inc`) + `grant_team {burnInc=0.20}` (palier burn-2) → résolution finale = inc1 + inc2 (additif).
Aucun op réécrit, confirmation de l'architecture. Zone sans test §8.

**Priorité** : FAIBLE mais propre (< 10 lignes, couvre une interaction certaine de P1).

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Spécifier `combat_effect_legibility` comme précondition de #FF [PRIORITÉ HAUTE]

**Quoi** : avant de spécifier les interactions #FF dans §5 P1, ajouter dans la spec P1 :

```
PRÉCONDITION #FF — LISIBILITÉ :
  Mesurer sur N=200 combats (sim, bus JSONL) :
    max_events_per_tick = max({ len(events[tick]) } pour chaque tick)
    avg_events_per_tick = mean({ len(events[tick]) })
  Si avg_events_per_tick > 4 OU max > 8 :
    → Règle de BATCHING obligatoire dans arena_draw.lua :
      - Regrouper les ticks de même famille en 1 événement VFX cumulé (« BRÛLURE ×12 » vs 12 ticks)
      - Priorité d'affichage : mort > décharge choc > DoT tick > bouclier > regen
    Avant d'ajouter #FF qui ajoute ~2 événements/tick
  Si avg ≤ 4 : #FF peut être implémenté sans règle de batching.
  Test : la condition se déclenche sur le golden (événements bus comptés par tick).
```

**Pourquoi** : les interactions #FF ne créent de la profondeur que si elles sont visibles. Sans
règle de batching, le joueur voit un brouillard de VFX. Coût : ~10 lignes sim (lecture du bus JSONL,
comptage par tick). Zone sans test → ajouter un test.

**Impact** : débloque #FF si la lisibilité est acceptable ; conditionne l'implémentation si ce n'est
pas le cas. 0 invariant.

### P2 — Spécifier le candidat twist CHOC-4 avant P1 [PRIORITÉ HAUTE, co-bloquant avec #GG]

**Quoi** : dans §3.7 (apex choc) et §5 (P1 types), ajouter la spécification du twist choc-4 comme
**co-décision avec #GG** :

```
PALIER CHOC-4 — CO-DÉCISION AVEC #GG (avant de coder P1) :

  Option A (si #GG → axe A/B pour l'apex) :
    Twist choc-4 = « la décharge arc à 1 voisin de la cible (shockChain) »
    Candidat data = shockChain déjà câblé (ops.lua:187, dischargeShock:358-378)
    Coût : 0 moteur (data) ; documenter interaction avec DOT_CAP_MULT=3 (arc ne double pas le cap)
    Test : décharge arced → target voisin prend les dégâts ; stacks CONSOMMÉS une seule fois

  Option B (si #GG → axe D cohérent pour l'apex) :
    Twist choc-4 = « les 2 premiers ticks DoT de la famille du poseur sont amplifiés »
    Paramètre : tickCount=2 dans tickDots (au lieu de tickCount=1 par défaut)
    Coût : ~3 lignes SIM (paramètre tickCount) ; 1 test synergies.lua (invariant #22 étendu)
    → Distinct de l'apex Option 2 (shockAmpMult=1.5 = multiplie la magnitude ; tickCount=2 = étend la
      durée d'amplification)
  
  Les 2 options sont dans §5 ; le choix est tranché avec #GG (même réunion de décision).
```

**Pourquoi** : sans candidat choc-4, P1 est incomplet pour la famille choc. Le playtest S1 verra
des joueurs commit choc-4 sans payoff twist = perception d'archétype inachevé.

### P3 — Ajouter CONFIG-CE2 (fiabilité de déclenchement axe D) dans la matrice sim P0.5 [PRIORITÉ HAUTE]

**Quoi** : dans §3.7 et §3.4 (CONFIG-CE), ajouter CONFIG-CE2 :

```
CONFIG-CE2 (Choc Fiabilité — axe D)
  Composition : {1 galvanizer T4 choc + 1 burn-poseur rang-2 + 1 bleed-poseur rang-2}
  vs TROIS configurations adverses :
    (a) ghost IA burn-seul rang-2/3 (adversaire avec DoT actif → condition D favorable)
    (b) ghost IA tank-seul rang-2/3 (adversaire sans DoT → condition D défavorable)
    (c) ghost IA mixte (adversaire avec DoT partiel)
  N=20 par config, seed 20260623+offset.
  Mesurer :
    discharge_effective_ratio = nb décharges qui amplifient un tick DoT actif / nb décharges totales
  Alarme : discharge_effective_ratio < 0.40 en config (b) :
    → documenter que choc axe D est CONDITIONNEL à l'adversaire
    → décision : (A) ajouter 1 unité rang-3 choc qui auto-pose un DoT avant de charger,
                  OU (B) recommander axe A/B pour l'apex (moins conditionnel)
```

**Pourquoi** : sans cette mesure, on ne sait pas si la hiérarchie choc < poison vient de la puissance
ou de la fiabilité de déclenchement. Les 3 mesures P0.5 actuelles ne l'isolent pas.

**Coût** : ~20 lignes sim, 3 configs. Non bloquant si ratio ≥ 0.40 (la puissance suffit à corriger).

### P4 — Ajouter la directionnalité #FF à la spec avant d'implémenter [PRIORITÉ FAIBLE mais PRÉCONDITION]

**Quoi** : dans §5 (spec #FF), ajouter une décision de directionnalité :

```
SPEC #FF — DIRECTIONNALITÉ DE L'AGGRAVATION CROISÉE :
  Décision (avant d'implémenter) :
    Option A — DIRECTIONNELLE (ordre fixe burn→bleed→poison→rot) :
      La dernière famille dans l'ordre actif reçoit le `more` croisé.
      Ex : burn + rot → rot amplifié (« le feu aggrave la pourriture »)
      Signal UI : nommer explicitement la relation ("feu brûle la blessure de rot")
      Avantage : 0 modification de l'ordre fixe ; thématiquement lisible.
      Risque : certaines paires moins intuitives (bleed + poison → poison amplifié, est-ce thématique ?)

    Option B — SYMÉTRIQUE (2 passes dans tickDots) :
      Les 2 familles co-présentes s'amplifient mutuellement.
      Coût : ~5 lignes (pré-tick : compter les familles actives ; post-tick : appliquer les `more`)
      Avantage : plus cohérent avec l'idée de « synergie » (dans les 2 sens)
      Risque : golden à revérifier si la config contient une co-présence (rebaseline possible)
```

**Pourquoi** : la spec actuelle (#FF ROADMAP-draft §0) ne précise pas. Une asymétrie non documentée
crée des frustrations opaque (§2.4 ce round). Coût : doc pur, 0 code.

### P5 — Test d'interaction aura_bakée × palier_teamFlag [PRIORITÉ FAIBLE]

**Quoi** : dans `tests/synergies.lua`, test 14 :

```
-- Test 14 : aura build-résolue + palier de type P1 sur la même unité
-- Setup : soot_acolyte (burnInc aura bakée à combat_start)
--          + grant_team {burnInc=0.20} (palier burn-2 via teamFlag)
-- Vérifier : resolve() = aura_inc + palier_inc (additif, pas écrasement)
-- Ordre : bake aura → teamFlag → resolve (engine-architecture.md §8)
-- → assert math.abs(resolved_inc - (aura_inc + 0.20)) < 0.001
```

**Coût** : ~8-10 lignes, zone sans test (00-state §8), 0 moteur.

---

## 4. QUESTIONS OUVERTES

### Q1 : Le VFX de l'aggravation croisée (#FF) est-il spécifiable en pixel art 320×180 sans surcharger la scène ?

La mémoire `the-pit-affliction-vfx` documente les VFX existants (nuages de transmission A→B, choc
qui se consume). Si #FF ajoute un VFX de co-présence (ex. une aura de couleur mixte sur la cible
quand 2 familles sont actives), est-ce lisible à l'échelle 320×180 ? Cette question appartient à
l'agent pixel-art-master mais la roadmap doit la documenter comme précondition de #FF.

### Q2 : La décision de directionnalité #FF (symétrique vs directionnelle) change-t-elle le verdict du tableau de saturation ?

Si #FF est directionnelle (une famille amplifie l'autre), elle n'entre dans le tableau de saturation
que d'un côté (la famille amplifiée). Si symétrique, les 2 familles voient leur `more` augmenter →
deux entrées dans le tableau de saturation, potentiellement plus proche du seuil. La décision de
directionnalité doit être prise **avant** de placer #FF dans le tableau de saturation.

### Q3 : Le palier poison-4 a-t-il un candidat twist nommé ?

Les paliers 4 de burn (`burnIgnoreShield`) et bleed (`bleedPierceShield`) sont nommés. Rot-4 a un
candidat (`cible à PV_max le plus élevé`, P1.5b). **Poison-4 n'a jamais été nommé dans 9 rounds.**
La fiche `00-state §3.1` dit que weaken est l'axe défensif du poison — un candidat poison-4 naturel
serait `poisonWeakenStack` (chaque stack poison réduit davantage la valeur adverse, vs flat). Est-ce
qu'un tel twist est compatible avec `DOT_CAP_MULT=3` et le cap stacks poison (array 8 stacks, 00-state
§3.1) ? Cette question n'a pas été posée en 9 rounds.

### Q4 : Le désert rang-3 burn (1 seul `bellows_priest`, P≈27 %) change-t-il si un palier burn-4 existait plus tôt ?

Le désert rang-3 burn est documenté (round 8, §3.1 col E). Le palier burn-4 (`burnIgnoreShield`) exige
≥4 burn dans le build — ce qui suppose avoir traversé rang-3. Si rang-3 burn a P=27 % de visibilité,
P(atteindre palier burn-4) est structurellement plus faible que pour bleed (rang-3 P=61 %). La décision
`désert rang-3 burn = voulu ou trou` (round 8) doit donc être croisée avec la **praticabilité du palier
burn-4** : si le désert est voulu, burn-4 est un palier plus rare = cohérent avec le thème grimdark
(burn difficile à maîtriser). Si trou = ajouter 1 rang-3 burn distinctif.

---

## 5. CE QUI N'EST PAS UN DÉSACCORD

- **Compteur de type GLOBAL PUR (#D clos round 6)** : non re-challengé, accord ferme.
- **Burn-vuln-bouclier = intentionnel (#W clos round 6)** : non re-challengé.
- **Axe D choc (`dot_family` du poseur + fallback ordre fixe)** : correct, non re-challengé.
- **Exception choc dans le tableau de saturation d'inc (base_min=0, métrique burst_DPS_eq)** : correct.
- **`bleedPierceShield` twist bleed-4 (tests 2a/2b avec shield_caster actif)** : adopté r07, accord.
- **`--pool-repr` AVANT `--poison-frac` en ordre STRICT (#DD clos r08)** : accord complet.
- **Décision `afflictionCount` Option C2** : code-vérifié round 5, maintenu.
- **Seuils 2/4 sur 9 slots** : accord fort (TFT Inkborn Fables confirmé).
- **12 synergies de base (tests/synergies.lua, invariants #22-32)** : plancher sain, non re-challengé.
- **`DOT_CAP_MULT=3` anti-snowball** : correct et non-challengé.
- **Architecture `grant_team` / `teamFlags` pour les paliers de type** : accord technique fort.
- **`famines_math` tri stable (clé secondaire `id`)** : code-vérifié r07, accord (#O clos).

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| Absence de métrique `combat_effect_legibility` (précondition de #FF) | **FORTE** | #FF ajoute profondeur invisible = profondeur inexistante | Mesurer avg/max events par tick, règle de batching si > 4 | HAUTE (avant #FF) |
| Palier choc-4 jamais spécifié (co-bloquant avec #GG) | **FORTE** | P1 incomplet pour choc ; perception d'archétype inachevé en S1 | Spec candidates choc-4 = Options A/B, trancher avec #GG | HAUTE (avant P1) |
| Hiérarchie choc < poison = problème de fiabilité de déclenchement, pas de puissance | **FORTE** | Les 3 mesures P0.5 ne l'isolent pas ; risque de tuner à côté | Ajouter CONFIG-CE2 (discharge_effective_ratio par config adversaire) | HAUTE (P0.5) |
| Directionnalité de #FF non spécifiée (ordre fixe → asymétrie non documentée) | **FAIBLE** | Asymétrie opaque = frustration ou bug non reproductible | Doc décision directionnelle avant spec | FAIBLE (précondition spec) |
| Interaction aura_bakée × palier_teamFlag = zone sans test | **FAIBLE** | Régression silencieuse si ordre résolution modifié en P1 | Test 14 synergies.lua (~8 lignes) | FAIBLE (zone sans test §8) |

**Litiges neufs proposés** :
- **#HH (neuf)** : palier choc-4 = Option A (shockChain arc) vs Option B (tickCount=2) — co-trancher
  avec #GG avant P1.
- **#II (neuf)** : directionnalité de #FF (asymétrique ordre-fixe vs symétrique 2 passes) — doc avant
  spec.

---

## 7. Index des sources

**Web vérifié ce round :**

- Kritz & Gaina 2025 — « When 1+1 does not equal 2: Synergy in games » (FDG 2025) :
  [arxiv.org/html/2502.10304v1](https://arxiv.org/html/2502.10304v1)
- Balatro Joker synergies — interactions cross-joker et conditions de déclenchement :
  [balatrowiki.org/w/Jokers](https://balatrowiki.org/w/Jokers)
- Balatro Best Joker Combos 2026 — 15 pairings, conditions sous contrôle vs externes :
  [switchbladegaming.com/strategy-games/balatro-best-joker-combos/](https://www.switchbladegaming.com/strategy-games/balatro-best-joker-combos/)
- Slay the Spire Archetypes Silent — mixing archetypes, bridges Storm of Steel :
  [thekindgm.com/2025/12/12/boardgame-briefs-slay-the-spire-deckbuilding-archetypes-part-2-silent/](https://thekindgm.com/2025/12/12/boardgame-briefs-slay-the-spire-deckbuilding-archetypes-part-2-silent/)
- PoE Wiki — Ailment (interaction shock × DoT, condition de co-présence) :
  [poewiki.net/wiki/Ailment](https://www.poewiki.net/wiki/Ailment)
- PoE Wiki — Shock (magnitude, seul le plus fort s'applique, interaction DoT) :
  [poewiki.net/wiki/Shock](https://www.poewiki.net/wiki/Shock)
- Red Hare Games — Why have Status Effects (fiabilité des effets de statut = engagement) :
  [redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games/](https://redharegames.wordpress.com/2025/11/17/simple-article-why-have-status-effects-in-games/)
- The Gamer — Balatro cross-ability synergy (roguelite = combination, pas permadeath) :
  [thegamer.com/permadeath-define-roguelike-balatro-shows-its-synergy/](https://www.thegamer.com/permadeath-define-roguelike-balatro-shows-its-synergy/)
- a327ex.com — Super Auto Pets mechanics (triggers, composition, chains) :
  [a327ex.com/posts/super_auto_pets_mechanics](https://a327ex.com/posts/super_auto_pets_mechanics)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §2.1 (roster 83 unités, 5 familles DoT) ; §3.1 (caps, boucliers, auras) ;
  §3.2 (ordre tick `burn→bleed→poison→rot→choc→regen`) ; §6 (32 invariants) ; §7 (dettes) ;
  §8 (zones sans test)
- `ROADMAP-draft.md` v9 §0 (chantier 4 P1 types, #FF spec) ; §3.4 (axe D choc) ; §3.7 (apex choc,
  #GG, CONFIG-CE) ; §5 (P1 types, spec #FF)
- `round-08.md` §1.1 (#GG apex choc) ; §2.2 (#FF inter-familles MID spec) ; §5.4 (#FF adopté
  spec à prouver)
- `rounds/r08-synergies-effects.md` §2.2 (interaction gap, Kritz & Gaina) ; §4 Q3 (métrique
  lisibilité effets — ignorée par le synthétiseur)
- `engine-architecture.md` §8 (registre ouvert/fermé : ordre bake auras → teamFlags)

---

## 8. Récapitulatif des demandes de modification de specs

| Item | Position ce round | Priorité | Où dans la roadmap |
|---|---|---|---|
| Mesure `combat_effect_legibility` (avg/max events par tick) avant #FF | **REQUIERT ADDITION** précondition #FF §5 | HAUTE | avant P1 |
| Spec palier choc-4 (Options A/B, co-trancher avec #GG) | **REQUIERT ADDITION** §3.7 + §5 | HAUTE | avant P1 |
| CONFIG-CE2 (discharge_effective_ratio par config adversaire) | **REQUIERT ADDITION** §3.7 matrice sim | HAUTE | P0.5 |
| Directionnalité #FF documentée (asymétrique vs symétrique) | **REQUIERT ADDITION** spec #FF §5 | FAIBLE | avant spec #FF |
| Test 14 (aura_bakée × palier_teamFlag, ~8 lignes) | **REQUIERT ADDITION** tests/synergies.lua | FAIBLE | P1 |

**2 litiges neufs proposés** :
- **#HH** : palier choc-4 — Option A (shockChain arc, 0 moteur) vs Option B (tickCount=2, ~3 lignes SIM).
  Co-trancher avec #GG. **Non bloquant séparément** (choc-4 peut être décidé après l'apex si spécifié
  comme candidats, mais pas omis).
- **#II** : directionnalité de l'aggravation croisée #FF — asymétrique (ordre fixe, thématique,
  0 moteur) vs symétrique (2 passes, ~5 lignes SIM, rebaseline potentielle). À trancher avant d'écrire
  le test inter-famille de #FF.

---

*Round 09 rédigé le 2026-06-23. Lecture seule du repo. N'édite que sous
`docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark /
pixel art procédural). 32 invariants préservés. 3 désaccords majeurs (lisibilité effets = précondition
#FF ; palier choc-4 jamais spécifié = co-bloquant #GG ; hiérarchie choc = fiabilité conditionnelle
pas puissance). 2 litiges neufs (#HH palier choc-4 Options A/B, #II directionnalité #FF). Pas de
décisions inversées — 3 compléments de spec critiques + 1 Q3 ignorée par le synthétiseur r08 réintroduite.*
