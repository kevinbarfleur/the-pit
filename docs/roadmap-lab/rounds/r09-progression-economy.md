# Round 09 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v9, intégré round 8) depuis la
> lentille progression-économie. Accords argumentés / désaccords sourcés / propositions
> concrètes, chiffrées, priorisées. Aucune modification du code du jeu. Lecture seule du repo.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v9 (intégral §2.5bis, §7.0-7.5, calendrier macro)
> - `docs/roadmap-lab/00-state.md` §4 (constantes éco, boucle `startRound`, XP-gating)
> - `docs/roadmap-lab/rounds/r08-progression-economy.md` (round précédent, lentille identique)
> - `docs/roadmap-lab/round-08.md` §0 (synthèse, 13 adoptions majeures)
> - `docs/roadmap-lab/competitive/tft.md` §1.2-1.3 ; `competitive/super-auto-pets.md` §2-3 ;
>   `competitive/balatro.md` §1-2 ; `competitive/backpack-battles.md`
> - `docs/roadmap-lab/seed/mechanics.md` §4 (constantes state.lua)
>
> **Sources web vérifiées ce round** :
> - TFT XP passive confirmée 2/round : wiki.leagueoflegends.com/en-us/TFT:Experience,
>   lolchess.gg/guide/exp, tft.ninja/guides/game-mechanics/leveling, op.gg/tft/game-guide/gold-xp
> - SAP gold : superautopets.wiki.gg/wiki/Gold (10/round, non reporté, reroll=1g)
> - Backpack Battles reroll scalant : steamcommunity.com/app/2427700/discussions/
>   0/4035850678059688137/ (coût doublé après 4 rerolls/round — décision communautaire 2/3)
> - Balatro économie : games.gg/balatro/guides/balatro-economy-guide/ (intérêts, tension
>   immediate-spend vs hold)
> - Game economy design - opportunity cost : gamedeveloper.com 2013 (shadow values)
> - Variable reward schedules : medium.com/design-bootcamp (Skinner Box, VRR)
>   numberanalytics.com/blog/mastering-reward-schedules-game-design (ratio variable optimal)

---

## 0. Thèse de ce round

Le round 8 a consolidé les accords structurels (or fixe, structure XP, barre XP, 3 régimes de
tension, 6e métrique `passive_vs_bought_ratio`). Ces décisions tiennent.

Ce round identifie **quatre zones non résolues ou insuffisamment fondées dans v9** :

1. **DÉSACCORD MAJEUR — La tension « reroll vs acheter » est modélisée comme statique, mais
   son COÛT RELATIF évolue exponentiellement à travers les tiers.** `REROLL_COST=1` représente
   100 % d'un rang-1, 50 % d'un rang-2, 33 % d'un rang-3, 25 % d'un rang-4, 20 % d'un rang-5.
   Le brouillon v9 note ce fait (§7.0/§7.1 tableau des régimes, §7.5) mais traite `REROLL_COST`
   comme un levier à trancher en P3 sans reconnaître que cette évolution est **une DÉCISION DE
   DESIGN ACTUELLEMENT ACTIVE**, pas un fait neutre à mesurer plus tard. Backpack Battles a
   résolu ce problème différemment (scalant après 4 rerolls/round) — et cette décision a été
   contestée par 1/3 de la communauté. La roadmap ne documente pas l'intention sous-jacente de
   `REROLL_COST=1` ni les alternatives.

2. **LACUNE DE SPEC — Le slot-unlock comme axe de progression de run n'est pas traité comme
   un SIGNAL D'IDENTITÉ, seulement comme une mécanique de déblocage.** Les slots 3→9 via
   `MAX_GRANTS=6` (rounds 2-7) constituent la progression VISIBLE du run. Or la roadmap les
   traite exclusivement comme une mécanique de leveling (`START_SLOTS`, `MAX_GRANTS`). Elle
   ne modélise pas le RYTHME psychologique de ce déblocage — le joueur découvre-t-il les slots
   comme des JALONS ou comme du bruit ? L'offre de slot arrive à chaque round 2-7 indépendamment
   des victoires/défaites ; un joueur en loss-streak reçoit des slots sans run productive.

3. **DÉSACCORD STRUCTUREL SUR LES RÉGIMES 1 ET 2 — Les seuils d'alarme des régimes early/mid
   sont proposés sans ancrage sur la structure réelle du budget.** `reroll_dominance_T1 > 0.25`
   et `engagement_rate_T2 < 0.50` sont présentés comme cibles empiriques (r08 §3.3). Mais
   avec `GOLD_PER_ROUND=10`, `REROLL_COST=1`, le budget autorise **10 rerolls gratuits après
   avoir dépensé 0 or en achats** — si le joueur cherche activement une unité précise, un ratio
   de 0.25 rerolls/or est déjà **économiquement prudent**, pas alarmiiste. Ces seuils ne sont
   pas calibrés sur la mécanique réelle ; ils sont arbitraires.

4. **TROU CONCEPTUEL — La passive XP de 1/round est traitée comme un levier d'équilibre mais
   son rôle PSYCHOLOGIQUE de signal de progrès n'est pas distingué de son rôle MÉCANIQUE
   d'accélérateur.** Le round 8 a bien résolu le signal contextuel (§2.5bis enrichi) mais
   n'a pas posé la question : **faut-il que la passive soit mécanique (impact sur la courbe)
   ou rituel (signal de temps qui passe) ?** Si c'est mécanique, 1 XP/round est trop faible
   pour avoir un impact perçu (calcul r08 : ~13 XP sur 15 rounds). Si c'est rituel, le signal
   contextuel suffit — mais alors le chiffre 1 est arbitraire.

---

## 1. Accords avec pourquoi ils tiennent pour NOS contraintes

### 1.1 Or fixe 10/round non reporté : accord total — 9e confirmation

**Accord total.** La confirmation SAP reste définitive :
`superautopets.wiki.gg/wiki/Gold` : « 10 is gained each turn, but does not carry over turns ».
HS:BG, seul competitor avec un budget reportable (tavern tier reduce-by-1/round), est
l'exception fondée sur une **longue partie 30-45 min** avec des players vivants — notre
run court (10V) rend le signal de report illisible. L'or fixe est la **seule équité perçue
garantissable** en async (pas de lobby partagé pour signaler « l'adversaire épargne »).

**Pourquoi spécifiquement pour nos contraintes** : le `GOLD_PER_ROUND=10` non reporté crée
une **fenêtre de décision propre à chaque round** — le joueur décide séquentiellement sans
état inter-round à gérer. En async, ce stateless est une qualité (reproductibilité de
l'expérience, indépendance du contexte de session).

### 1.2 Structure XP (passive + achetable, ratio BUY_XP 1:1) : accord total

**Accord total sur la structure.** Le ratio BUY_XP 4:1 (4g = 4 XP) identique à TFT
(lolchess.gg/guide/exp : « spend 4 gold to gain 4 Experience ») est une décision neutre
psychologiquement — 4g = 4 XP = valeur face, pas de prime/décote. La tension vient du
CONTEXTE (que vaut 4 XP vers le prochain tier), pas du ratio lui-même. Accord maintenu.

### 1.3 Signal XP contextualisé §2.5bis (adoption r08) : accord total

**Accord total, adoption maintenue.** La ligne contextuelle (`delta > 4 → "N rounds ou M
BUY_XP"`) convertit un fait brut en coût d'opportunité lisible. Gamedeveloper.com 2013
(« help players organize trade-offs ») est la source correcte. La nuance sur la passive
comme *rituel vs mécanique* (§2.4 de ce round) ne remet pas en cause cette adoption —
elle la complète.

### 1.4 Les trois régimes de tension (adoption r08) : accord sur la STRUCTURE, désaccord sur les SEUILS

**Accord sur la structure des 3 régimes** (early=recherche / mid=engagement / pivot=T4).
La taxonomie des phases décisionnelles est juste. Le régime 2 (T2-T3, engagement rang-3)
est bien la zone où l'identité de build se décide.

**Désaccord sur les seuils d'alarme** — développé en §2.3 de ce round.

### 1.5 6e métrique `passive_vs_bought_ratio` (adoption r08) : accord total

**Accord total, adoption maintenue.** C'est la précondition décisive du choix
`{2,5,10,18}` vs `{2,5,10,20}`. Cible 20-50 % saine. Sans cette mesure, tout calibrage
de la courbe XP revient à tuner un paramètre sans connaître le comportement réel du joueur.

### 1.6 Co-calibration boutique/slots (§7.1 condition 4) : accord total

**Accord total.** La co-calibration `ratio = shopTier_moyen / slots_actifs_moyen < 1.5`
détecte le cas structurel où un joueur monte son tier trop vite vs ses slots débloqués —
il voit des unités chères qu'il ne peut pas placer. C'est la bonne métrique pour ce pattern.

### 1.7 Tableau §7.0 en PRÉCONDITION des sims P3 : accord total

**Accord total.** La règle « documenter l'intention AVANT de mesurer » est une discipline
de design fondamentale (Machinations.io 2025). Sans le tableau, les sims P3 produiraient
des chiffres sans verdict.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — `REROLL_COST=1` n'est pas un placeholder neutre : c'est une DÉCISION ACTIVE avec des implications profondes non documentées

**Claim implicite du brouillon v9** : `REROLL_COST=1` est un placeholder à trancher en
P3 via sim (§7.0 tableau d'intention : « garder tension faible vs scaler » = `[TBD]`).

**Le problème** : traiter `REROLL_COST=1` comme neutre en P3 ignore que le coût relatif
du reroll **évolue de 4× à travers les tiers dans le jeu actuel**, sans aucune intention
documentée de ce que cette évolution doit faire.

**Calcul (ancré sur `00-state.md §4.1` + `GOLD_PER_ROUND=10`) :**

| ShopTier | Unité dominante | Coût achat | Coût reroll | Ratio reroll/achat |
|----------|-----------------|------------|-------------|-------------------|
| T1       | rang-1          | 1g         | 1g          | **1:1** (équivalents) |
| T2       | rang-2          | 2g         | 1g          | **1:2** (reroll = ½ achat) |
| T3       | rang-3          | 3g         | 1g          | **1:3** (reroll = ⅓ achat) |
| T4       | rang-4          | 4g         | 1g          | **1:4** |
| T5       | rang-5          | 5g         | 1g          | **1:5** |

En T1, reroller coûte autant qu'acheter → la décision est binaire (coût identique = forme
différente de dépense). En T5, reroller coûte 5× moins → le ratio implicite **incite massivement
au reroll T5** au lieu d'acheter. C'est une décision de design ACTIVE, pas un fait neutre.

**Ce que Backpack Battles a résolu différemment** : leur scalant (doublement du coût après 4
rerolls/round) force l'improvisation plutôt que l'optimisation exhaustive.
([steamcommunity.com/app/2427700/discussions/0/4035850678059688137/](https://steamcommunity.com/app/2427700/discussions/0/4035850678059688137/) :
« auto-battlers need to force improvisation and creativity to stay fun. [...] without the
reroll increase the game becomes degenerate »). Cette décision a été **contestée par 1/3
de la communauté** — ce n'est pas une solution gratuite.

**Ce que SAP a résolu différemment** : `REROLL_COST=1` dans SAP, mais toutes les unités
coûtent **3g** (prix uniforme). Le ratio reroll/achat est donc **1:3 constants** (stable
à travers les tiers). Dans The Pit, le prix varie avec le rang → le ratio **n'est pas
constant**, ce qui signifie que SAP et The Pit ont des dynamiques fondamentalement
différentes malgré le même `REROLL_COST`.

**Ce qui manque dans la roadmap** : l'intention documentée du ratio T5 (1:5). Est-ce voulu
que le reroll soit 5× moins coûteux que l'achat en late ? Si non → scaler ou cap. Si oui →
l'expliquer dans le tableau §7.0. Le `[TBD]` actuel n'est pas une posture neutre : chaque
run joué avec `REROLL_COST=1` au T5 incite le joueur à reroller plutôt qu'acheter — c'est
de la dette de design qui s'accumule.

**Proposition concrète** (§3.1 de ce round).

**Source** : `00-state.md §4.1` (REROLL_COST=1, GOLD_PER_ROUND=10, cost=rank) ;
superautopets.wiki.gg/wiki/Gold (SAP prix uniformes 3g) ;
steamcommunity.com/app/2427700/discussions/ (Backpack scalant — analyse communautaire).

### 2.2 LACUNE — Le slot-unlock (rounds 2-7) est traité comme mécanique, pas comme SIGNAL DE PROGRESSION

**Claim implicite du brouillon v9** : les offres de slots (rounds 2-7, `MAX_GRANTS=6`,
`START_SLOTS=3`) sont une mécanique de déblocage dont la valeur se mesure via la co-
calibration shopTier/slots (§7.1, condition 4). Le slot-decline `+3 or` (option C) est
un trade-off tall/wide à mesurer en sim.

**Le problème** : la mécanique de slot-unlock génère un **événement visible toutes les
1 rounds pendant les rounds 2-7**. C'est potentiellement la progression LA PLUS VISIBLE
du jeu pour un nouveau joueur (le plateau grandit littéralement). Or la roadmap ne pose
aucune question sur la **psychologie de cet événement** — seulement sur la valeur de
l'or de refus.

**Deux patterns possibles** — et le brouillon n'en choisit pas un :

**Pattern A : slot-unlock = JALON DE PROGRESSION** (la grille qui grandit = signal de
montée en puissance). Nécessite que chaque slot débloqué soit **célébré** brièvement
(même 0.5 s d'animation pixel art qui grandit la grille). SAP le fait : chaque nouvelle
case de la boutique est visuellement nouvelle.
La progression « 3→4→5→...→9 slots en 7 rounds » couvre toute la phase de run principale
(victoires 1-7 approximativement). C'est un **arc progressif naturel**.

**Pattern B : slot-unlock = RESSOURCE À ARBITRER** (declin = or, accept = espace). C'est
le design actuel implicite avec le `+3 or` de refus. Nécessite que le joueur comprenne
la valeur d'opportunité du slot vs l'or — mais SANS BARRE XP ni coût d'opportunité visible
(équivalent à §2.5bis pour les slots), le joueur ne peut pas l'évaluer.

**Ce qui manque** : la roadmap §2.5bis contextualise le coût d'opportunité de BUY_XP vs
la passive. **Il n'existe pas d'équivalent pour le slot-decline.** Un joueur voit « ACCEPTER
le slot | REFUSER (+3 or) » sans contexte : valent 3 or maintenant autant qu'un slot qui
durera les 8 rounds restants ? C'est une décision à **horizon différent** non affichée.

**Conséquence** : si le tableau §7.0 documente `SLOT_DECLINE_GOLD=3` avec l'intention
« trade tall/wide », il doit aussi documenter la **lisibilité de ce trade** — sinon la
sim mesure un comportement de joueur aveugle.

**Ce n'est pas un re-lit du round 6 ou 7** (qui ont traité la mécanique) : c'est une
question sur le **signal** autour de la mécanique, symétrique à §2.5bis pour BUY_XP.

**Source** : `00-state.md §4.1` (START_SLOTS=3, MAX_GRANTS=6, SLOT_DECLINE_GOLD=3) ;
progression-economy-prd.md §3 (rejet de « slots via or ») ; §7.1 condition 4 (co-
calibration — traite la mécanique, pas le signal) ; r08-progression-economy.md §1.7.

### 2.3 DÉSACCORD STRUCTUREL — Les seuils d'alarme des régimes 1 et 2 ne sont pas calibrés sur la mécanique réelle

**Claim du brouillon v9** (§7.1, issu de r08-progression-economy.md §2.3) :
- Régime 1 : `reroll_dominance_T1 > 0.25` = alarme (pool peu diversifié)
- Régime 2 : `engagement_rate_T2 < 0.50` = alarme (niches rang-3 indistinctes)

**Le problème** : ces seuils sont présentés comme des cibles raisonnées mais ne sont
ancrés sur aucune mécanique.

**Dérivation de seuils calibrés (ancrage sur `00-state.md §4.1`)** :

**Régime 1 (T1)** : budget 10g, unités rang-1 coûtent 1g, reroll coûte 1g.
- Scénario « chercheur efficient » : il achète 2 rang-1 (2g) + fait 2 rerolls (2g) = 4g
  dépensés en décisions actives, 6g restants pour la suite. Ratio rerolls/achat = 2/2 = 1:1.
- Scénario « chercheur agressif » : 1 rang-1 (1g) + 4 rerolls (4g) = 5g. Ratio 4:1.
- Avec `SHOP_SIZE=5` et pool local (pas partagé comme TFT), la probabilité de voir une
  unité cible rang-1 sur 1 reroll ≈ `5/12 ≈ 42 %`. Après 3 rerolls, `P(voir la cible)
  ≈ 1 - (1-0.42)^3 ≈ 80 %`. **3 rerolls suffisent pour 80 % de certitude en T1.**
- `reroll_dominance_T1 = rerolls_T1 / or_total_T1 > 0.25` = alarme à 2.5 rerolls pour
  10g. Mais **3 rerolls = 30 % des 10g = décision légitime**, pas un signal d'alarme.
- **Seuil proposé comme alarme = 0.25 est trop bas** : il signale comme problématique
  un comportement de recherche économiquement efficace.

**Régime 2 (T2)** : `engagement_rate_T2 = P(achat rang-3 en 1er T2-round) > 0.50`.
- Le premier round en T2 signifie que le joueur a atteint shopTier 2 (seuil XP=2 avec
  la courbe {2,5,10,18}). En T2, cotes rang-3 = 20 % (00-state §4.3, table cotes T3
  row=30 rang-3, mais en T2 : 0 % rang-3).
- **En T2, les unités rang-3 ne sont PAS dans la boutique** (cotes 0 % en T2 selon
  00-state §4.3). L'`engagement_rate_T2` défini comme « acheter rang-3 en T2 » est
  **mécaniquement impossible** — le T3 n'ouvre les rang-3 qu'à 20 %.
- **La métrique telle que définie mesure un comportement impossible.** Il faut la
  redéfinir : `engagement_rate_T2 = P(acheter rang-2 ciblé [même famille 2 fois]
  en T2 vs reroller pour diversifier)` — c'est la vraie décision d'engagement de T2.

**Source** : `00-state.md §4.3` (cotes par tier : T2 = rang-3 à 0 %) ; calcul de
probabilité pool LOCAL (SHOP_SIZE=5, `pool = U.pool`, pas partagé) ; r08 §2.3 (origines
des seuils proposés).

### 2.4 TROU CONCEPTUEL — La passive XP est traitée comme un LEVIER sans choisir son RÔLE

**Claim du brouillon v9 (§7.1, §2.5bis)** : la passive XP de 1/round est un paramètre
mécanique à mesurer via `passive_vs_bought_ratio` ; son signal contextuel (§2.5bis) aide
le joueur à organiser le trade-off vs BUY_XP.

**Le problème** : avant de mesurer si la passive est « mécanique » ou « bruit » (6e
métrique), la roadmap doit décider **ce que la passive est censée être**.

**Deux rôles distincts, incompatibles en design :**

**Rôle A — Levier mécanique** : la passive contribue à la courbe XP de façon significative.
À 1/round sur 15 rounds = ~13 XP → atteint T4 vers round 11 (r08 §2.2). Si ce rôle est
voulu, il manque un signal de **momentum passif** — le joueur devrait percevoir que « dans
3 rounds, je monte passivement ». Le signal contextuel §2.5bis le fait partiellement (il
montre « N rounds ou M BUY_XP »), mais uniquement à la boutique, pas en dehors.

**Rôle B — Signal rituel de temps** : la passive 1/round crée un rythme perceptible de
progression sans être une ressource significative. Elle signale « chaque round, tu avances »
— un signal psychologique de progrès continu, même en défaite. (Amabile & Kramer 2011,
« The Progress Principle » : even small wins counter-momentum stagnation.)
Dans ce rôle, le chiffre 1 est arbitraire (2 ferait pareil psychologiquement tant que
c'est « petit mais présent »), et la `passive_vs_bought_ratio` n'est PAS la bonne métrique
(car si < 20 %, la réponse n'est pas « buff la passive » mais « garder le signal »).

**Ce qui manque** : documenter explicitement dans le tableau §7.0 :
- Ligne `XP_PASSIVE_RATE=1` : INTENTION = `[A] levier mécanique` OU `[B] rituel visuel`
- Si A → valider que 1/round suffit à créer le momentum (sinon 2 en round 8+ comme §3.5 r08)
- Si B → supprimer la passive de la `passive_vs_bought_ratio` (elle n'est pas censée y peser)

**Cette décision ne coûte rien** (doc, tableau §7.0) mais détermine la bonne interprétation
de la 6e métrique.

**Source** : r08 §2.2/§3.2 (passive_vs_bought_ratio) ; `00-state.md §4.2` (BUY_XP_AMOUNT=4,
passive 1/round) ; Amabile & Kramer 2011 (The Progress Principle, Harvard Business Review) ;
§7.1 `--xp-climax` critère à 4+1 conditions.

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 0 — DOC BLOQUANTE] Documenter l'intention de `REROLL_COST` par rapport à la courbe de coût relatif

**Quoi** : dans le tableau §7.0 (à rédiger avant P3), ajouter une ligne `REROLL_COST` avec
le tableau de coût relatif complet + l'intention tranchée :

```
| REROLL_COST | 1g | INTENTION [TBD user] : ...
  - Statique : reroll = 1g invariant, coût relatif décroît de T1 (100%) à T5 (20%)
    → VOULU : incite au reroll T5 (exploration late) → ou NON VOULU (scaler en T3+)
  - Scalant T3+ : ex. 1g en T1-T2, 2g en T3, 3g en T4+ (Backpack Battles pattern)
    → COÛT : divide par 2 le VRR boutique late (reroller devient moins spontané)
  - Cap quotidien (ex. 5 rerolls gratuits/round, puis +1g) : préserve le VRR early
    → COÛT : complexité de règle (« après 5 rerolls ça coûte plus » = apprentissage)

Comportement attendu en sim :
  - [STATIQUE] reroll_rate_T5 ≤ 1.5 × reroll_rate_T1 (on ne recolle pas à ∞)
  - [SCALANT] reroll_rate_T3 ≈ reroll_rate_T1 (iso-incitatif à travers les tiers)
Signal d'alarme :
  - reroll_T5 > 2.5× reroll_T1 → le ratio 1:5 incite massivement au reroll late = décider
```

**Précondition** : tableau §7.0 rédigé. **0 code.** ~30 min doc.

**Recommandation de fond** : conserver le `REROLL_COST=1` statique est cohérent avec SAP
(notre référence) **si on accepte que le late game The Pit favorise plus l'exploration que
l'engagement direct**. C'est défendable en grimdark (« le Puits montre ce qu'il veut »).
Mais le documenter comme VOULU, pas comme [TBD].

### 3.2 [PRIORITÉ 1] Ajouter le signal de coût d'opportunité du slot-unlock (§2.5bis symétrique)

**Quoi** : dans `build.lua`, à l'affichage de l'offre de slot (rounds 2-7), ajouter une
ligne contextuelle **au-dessous** de « ACCEPTER | REFUSER (+3 or) » :

```lua
-- Si le joueur est en T1-T2 et n'a pas encore 5 slots :
label_context = "Un slot = espace pour " .. (9 - state.slots) .. " unités supplémentaires
  d'ici la fin du run"
-- Si en T3+ :
label_context = "Refuser = " .. SLOT_DECLINE_GOLD .. " or maintenant (" ..
  math.ceil(SLOT_DECLINE_GOLD / BUY_XP_COST * 4) .. " XP équivalents)"
```

**Objectif** : créer la même lisibilité du trade-off que §2.5bis pour BUY_XP. Le joueur
voit le contexte de sa décision **sans prescription** (le signal montre le coût, pas la
bonne réponse).

**Coût** : ~1 h RENDER, 0 SIM, 0 invariant. Symétrique à §2.5bis (même pattern, même
précondition : tableau §7.0 doit inclure l'intention de `SLOT_DECLINE_GOLD`).

**Garde-fou DA** : formulation grimdark neutre. « Le Puits t'offre l'espace — ou son prix. »
Pas de recommandation implicite (le mot « optimal » est interdit dans ce signal).

**Zone sans test** → test headless que le label est correct pour les cas limites
(`slots=9` = pas d'offre, `slots=3` début de run).

### 3.3 [PRIORITÉ 1] Corriger les seuils d'alarme des régimes 1 et 2 (recalibrer)

**Correction du régime 1** (`reroll_dominance_T1`) :
- Seuil actuel : `> 0.25` = 2.5 rerolls/10g = alarme.
- **Recalibré** : avec `P(voir cible rang-1 en T1) ≈ 42 %/reroll`, 3 rerolls pour 80 %
  de certitude = 30 % du budget = comportement **sain de recherche efficiente**.
- **Nouveau seuil** : `> 0.45` (4.5 rerolls/10g = cherche après 3 sans succès = pool
  potentiellement trop dilué). Cibles sous-jacentes : si `reroll_dominance_T1 > 0.45`
  **ET** `achat_rang_1_T1 < 1.5` (n'achète pas non plus) → pool T1 trop homogène.

**Correction du régime 2** (`engagement_rate_T2`) :
- Définition actuelle : `P(achat rang-3 en 1er T2-round)` = **mécaniquement impossible**
  (cotes rang-3 en T2 = 0 %).
- **Redéfinition** : `engagement_rate_T2 = P(2e achat même famille rang-2 en T2 vs
  1er achat famille différente)`. Mesure si le joueur commence à **s'engager sur un axe**
  (2 rang-2 même famille = pré-activation d'un archétype) vs diversifier (2 familles
  = portefeuille). Cible : 40-60 % (ni mono-commit trop tôt, ni diversification plate).
- Cette redéfinition détecte le vrai signal d'engagement : « le joueur commence-t-il à
  construire une identité de build en T2 ? »

**Coût** : ~30 min correction doc dans §7.1 ; ~20 lignes `tools/sim.lua` (la 2e définition
nécessite de tracker les 2 derniers achats par famille en T2). 0 invariant.

### 3.4 [PRIORITÉ 1 — DOC SEULE] Documenter le RÔLE de la passive XP avant la 6e métrique

**Quoi** : dans le tableau §7.0, ajouter une ligne dédiée au rôle de la passive :

```
| XP_PASSIVE_RATE | 1/round | INTENTION : [A] ou [B] (décision user)
  [A] Levier mécanique : contribue ~35-40% de l'XP totale sur run médian (cible ratio 20-50%)
  [B] Signal rituel : crée un rythme de progrès perçu ; le chiffre 1 est un token, pas un levier
      → dans ce cas, passive_vs_bought_ratio n'est PAS le bon KPI pour la passive (c'est
         le KPI pour le BUY_XP — si passive est rituel, le ratio attendu = 15-25% naturellement
         sur un run actif ; si < 15% → le signal §2.5bis est insuffisant à contextualiser le rituel)
```

**Si l'user choisit [A]** : la 6e métrique s'applique avec les cibles r08 (20-50 %).
**Si l'user choisit [B]** : la 6e métrique mesure la santé du BUY_XP uniquement (cible
60-85 % bought dans ce cas — la passive est délibérément petite).

**Coût** : doc uniquement. ~20 min. Précondition du tableau §7.0.

### 3.5 [PRIORITÉ 2 — CONDITIONNEL] Évaluer un soft-cap du reroll T3+ plutôt qu'un scalant dur

**Quoi** : si la sim P3 révèle `reroll_T5 > 2.5 × reroll_T1` (§3.1 signal d'alarme),
envisager un **soft-cap par signal**, pas un scalant de coût :

```
Après 5 rerolls dans un round (todos les tiers) :
→ signal discret : « LE PUITS A MONTRÉ CE QU'IL AVAIT — les prochains rerolls
  coûteront le double » (1g → 2g)
→ un reroll de plus : 2g. Puis 3g. Cap à 4g.
→ RESET à 1g au round suivant.
```

**Pourquoi soft-cap > scalant dur** : le scalant dur de Backpack Battles a divisé la
communauté 66/33 % ([steamcommunity](https://steamcommunity.com/app/2427700/discussions/0/4035850678059688137/)).
Le signal avant le scalant préserve l'agence (le joueur SAIT avant de dépenser) et
reste cohérent avec la philosophie « transparence des règles » (§2.5bis, barre XP visible).

**Pourquoi CONDITIONNEL** : si `reroll_T5 ≤ 1.5 × reroll_T1` en sim, le scalant n'est
pas nécessaire — l'équilibre naturel du budget (T5 = unités plus chères = moins d'or
pour les rerolls) peut suffire. **Ne pas implémenter avant la mesure.**

**Coût si implémenté** : 3 lignes `state.lua` (compteur rerolls/round remis à 0 en
`startRound`), 0 invariant, rebaseline golden si le scénario inclut un reroll T3+.

---

## 4. Questions ouvertes

### Q1 — La courbe de slot-unlock (rounds 2-7) est-elle corrélée aux victoires/défaites ?

Actuellement : `MAX_GRANTS=6`, grants aux rounds 2-7 **indépendamment du score** (win ou
lose). Un joueur en loss-streak 5-0 reçoit tous ses slots via grants comme un joueur 3-0.
Est-ce voulu ? La grille qui grandit pendant une mauvaise session peut créer un signal positif
de progression même en défaite (pattern SAP « filet anti-tilt ») OU peut sembler incohérente
(« j'ai perdu 3 fois mais mon plateau grandit — pourquoi ? »).

**Deux options** :
- (a) Garder les grants fixes (rounds 2-7) : cohérent, simple, signal de temps, non lié au skill.
- (b) Lier 1 grant supplémentaire aux victoires (ex. tous les 3 wins = 1 slot bonus) : signal de
  compétence + progression visible. **MAIS** viole le principe « égalisateurs, pas gates »
  (CLAUDE.md §2) si un joueur en défaite stagne à 3 slots trop longtemps.

La option (a) est compatible avec le tableau §7.0 actuel. La documenter explicitement.

### Q2 — Le ratio `reroll_T5 / reroll_T1` peut-il être mesuré sans la politique `rush_XP` ?

La métrique de §3.1 (ratio de reroll par tier) nécessite des simulations qui distinguent les
rerolls par `shopTier` actif. La politique `rush_XP` monte rapidement → les rerolls T5 y sont
sur-représentés. La politique `standard` est plus représentative. **Préciser** que le ratio
doit être mesuré sur la politique `standard` uniquement (pas `rush_XP`) pour être interprétable.

### Q3 — Le slot-decline `+3 or` est-il comparable à un achat rang-3 partiel ?

`SLOT_DECLINE_GOLD=3` = même valeur qu'un rang-3. Le joueur qui refuse un slot en T3 peut
acheter une unité rang-3. C'est un trade EXACT en T3 — unique moment où le trade est transparent.
Avant T3 (< 3g/unité dominante) et après T3 (> 3g), le trade est asymétrique. Documenter ce
point de parité exact dans le tableau §7.0 (intention : c'est voulu pour le T3 ou accidentel ?).

### Q4 — Le tableau §7.0 couvre-t-il les constantes inter-dépendantes ?

Les constantes `BUY_XP_COST`, `REROLL_COST`, `SLOT_DECLINE_GOLD`, `GOLD_PER_ROUND` **ne sont
pas indépendantes**. Le tableau §7.0 les traite ligne par ligne ; mais il manque une section
« interactions déclarées » :
- `REROLL_COST` × `BUY_XP_COST` : si les deux sont à 1g et 4g, le reroll est 4× moins cher
  que l'XP — incite-t-on à reroller plutôt qu'à monter ?
- `SLOT_DECLINE_GOLD` × `REROLL_COST` : décliner un slot = 3 rerolls → is it intentional
  that refusing slots funds exploration more than leveling?

**Ces interactions doivent figurer dans le tableau** pour que la sim P3 sache quoi mesurer.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-8 :

1. **`REROLL_COST=1` n'est pas neutre** : son coût relatif évolue de 1:1 à 1:5 de T1 à T5.
   L'intention doit être documentée dans §7.0 AVANT la sim P3 — pas après.

2. **Le slot-unlock mérite un signal de coût d'opportunité** (symétrique à §2.5bis pour
   BUY_XP). Sans signal, le joueur décide aveuglément le trade slot/or.

3. **Les seuils d'alarme des régimes 1 et 2 sont incorrects** :
   - Régime 1 : seuil 0.25 trop bas (3 rerolls = 30 % du budget = comportement sain en T1).
   - Régime 2 : définition mécaniquement impossible (rang-3 à 0 % en T2).

4. **La passive XP doit être déclarée comme levier OU rituel** avant que la 6e métrique
   soit interprétable.

### Ce qui reste inchangé et tient (9e confirmation globale) :

- Or fixe 10/round : correct, 9e confirmation.
- Structure XP (passive + achetable, ratio 1:1) : saine.
- Barre XP §2.5bis + signal contextuel enrichi : maintenu.
- Tableau §7.0 en précondition des sims P3 : maintenu (+ 3 ajouts de ce round).
- 6e métrique `passive_vs_bought_ratio` : maintenu (+ condition de rôle A/B).
- 3 régimes de tension : structure correcte (seuils corrigés).
- REROLL_COST tranché par sim : méthode correcte (intention à documenter d'abord).
- Co-calibration shopTier/slots (condition 4) : maintenu.
- Pity-signal `max(3, 0.5×médiane)` + progression visuelle : accord fort.
- Gel conditionnel (report + REROLL_COST scalant) : correct structurellement.

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md §4.1-4.3`
  (REROLL_COST=1, BUY_XP_COST=4, BUY_XP_AMOUNT=4, GOLD_PER_ROUND=10,
  START_SLOTS=3, MAX_GRANTS=6, SLOT_DECLINE_GOLD=3, XP passive=1/round)
- `docs/roadmap-lab/ROADMAP-draft.md` v9 §2.5bis, §7.0-7.5, §7.1 régimes, tableau éco
- `docs/roadmap-lab/rounds/r08-progression-economy.md` (origines des seuils régimes 1-2,
  6e métrique, signal contextuel)
- `docs/roadmap-lab/round-08.md §0` (13 adoptions majeures — signal contextualisé adopté)

**Sources web vérifiées ce round** :
- [TFT XP — wiki.leagueoflegends.com](https://wiki.leagueoflegends.com/en-us/TFT:Experience)
  (passive = 2 XP/round confirmé)
- [TFT Leveling — lolchess.gg](https://lolchess.gg/guide/exp)
  (cumuls, breakpoints, table XP)
- [TFT Gold/XP — op.gg](https://op.gg/tft/game-guide/gold-xp)
  (passive 2/round confirmé)
- [SAP Gold — superautopets.wiki.gg](https://superautopets.wiki.gg/wiki/Gold)
  (10g/round, non reporté, reroll=1g, PRIX UNIFORMES 3g — crucial pour la comparaison)
- [Backpack Battles reroll scalant — steamcommunity.com](https://steamcommunity.com/app/2427700/discussions/0/4035850678059688137/)
  (doublement après 4 rerolls/round ; approuvé par 66 %, contesté par 33 % — données réelles)
- [Balatro économie — games.gg](https://games.gg/balatro/guides/balatro-economy-guide/)
  (intérêts, tension hold vs spend — modèle à intérêt ≠ nos contraintes)
- [Reward Schedules — numberanalytics.com](https://www.numberanalytics.com/blog/mastering-reward-schedules-game-design)
  (ratio variable optimal 20-30 % pour VRR maintenu)
- [Variable Rewards — medium.com/design-bootcamp](https://medium.com/design-bootcamp/product-design-and-psychology-the-mechanism-of-skinner-box-techniques-in-video-game-design-5b7315e2d7b4)
  (dopamine = anticipation, pas gratification — justifie le VRR boutique §2.9)
- Amabile & Kramer 2011, « The Progress Principle », Harvard Business Review
  (progress = motivation même en défaite — ancre le rôle B de la passive XP)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 9. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe
seedée / DA grimdark / pixel art procédural). 32 invariants non modifiés.
Désaccords sourcés par mécanique + web. Propositions chiffrées ancrant les constantes dans
state.lua (lues via 00-state.md). 9e confirmation des accords structurels.*
