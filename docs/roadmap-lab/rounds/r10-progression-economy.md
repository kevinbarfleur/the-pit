# Round 10 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v10, intégré round 9). Accords
> argumentés (pourquoi ça tient) / désaccords sourcés (web vérifié ce round) / propositions
> concrètes, chiffrées, priorisées. Lecture seule du repo. Écriture uniquement sous
> `docs/roadmap-lab/`. 4 piliers respectés.
>
> **Sources primaires relues ce round** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v10 — §7.0-7.5, §2.5bis, §5.4, calendrier macro
> - `docs/roadmap-lab/00-state.md` §4 (constantes éco, boucle, XP-gating, cotes)
> - `docs/roadmap-lab/rounds/r09-progression-economy.md` (lentille identique)
> - `docs/roadmap-lab/round-09.md` §0 (14 adoptions majeures round 9)
> - `docs/roadmap-lab/seed/mechanics.md` — constantes `state.lua`
>
> **Sources web vérifiées ce round** :
> - TFT XP passive : leagueoflegends.fandom.com/wiki/Experience_(Teamfight_Tactics)
>   → passive = **2 XP/round** (confirmé, non 1/round comme The Pit) ; buy XP = **4g = 4 XP**
> - TFT leveling costs : lolchess.gg/guide/exp (niveaux, cumuls, table par set)
> - SAP gold+shop : superautopets.wiki.gg/wiki/Gold + superautopets.fandom.com/wiki/Shop
>   → reroll 1g, **TOUTES les unités 3g** (ratio reroll:achat = **1:3 constant**)
> - SAP experience (level-up pet) : superautopets.fandom.com/wiki/Experience
>   → 2 XP pour L2, 3 XP pour L3 (axe distinct du shop-tier XP dans The Pit)
> - Backpack Battles reroll scalant : steamcommunity.com/app/2427700/discussions/0/4035850678059688137/
>   → « auto-battlers need to force improvisation » ; approuvé 66 %, contesté 34 %
> - Entaltostudios : 5 Essential Tips to Make Your Roguelite Game Work (2025)
>   → visible progression milestones = driver du "one more run"
> - Machinations.io : opportunity cost (glossary) → shadow values, organize trade-offs
> - Amabile & Kramer 2011 : hbs.edu/faculty/Pages/item.aspx (The Progress Principle)
>   → small wins counter stagnation ; **contexte = travail, pas jeu vidéo** (nuance ci-dessous)

---

## 0. Thèse de ce round

Le round 9 a accompli le plus gros du travail sur l'économie : il a corrigé deux seuils
d'alarme faux (`reroll_dominance_T1`, `engagement_rate_T2`), exhumé la dérive du coût
relatif du reroll (1:1 → 1:5), et exigé la déclaration du rôle de la passive ([A] vs [B]).
Ces adoptions sont solides et ne méritent pas d'être re-challangées.

Ce round identifie **quatre zones insuffisamment fondées ou structurellement fragiles
dans v10** — non adressées par les neuf rounds précédents :

1. **DÉSACCORD FONDATIONNEL — La courbe XP `{2,5,10,18}` est calibrée pour un comportement
   acheteur de niveau hypothétique (« joueur actif »), mais la mécanique de passive 1/round
   crée un PLAFOND NATUREL qui détermine l'utilité réelle du BUY_XP par tier, et personne ne
   l'a calculé.**

2. **LACUNE DE SPEC — Le signal de coût d'opportunité du slot-unlock (§2.5bis, adopté R09)
   est mal ancré : il propose un calcul `(9 − slots)` qui mesure le POTENTIEL restant, pas le
   coût d'opportunité PRÉSENT de la décision. C'est une erreur de cadrage.**

3. **DÉSACCORD SUR L'ANALOGIE AMABILE & KRAMER (R09 §2.4) — La « passive comme rituel [B] »
   est sourcée sur une étude de motivation au travail de 2011. Ce transfert n'est pas validé
   pour le jeu : le mécanisme psychologique n'est pas le même.**

4. **TROU DE SPEC — La co-calibration shopTier/slots (§7.1 condition 4, `ratio < 1.5`) n'est
   jamais mise en tension avec la dynamique asymétrique de déblocage : les grants de slots sont
   fixes (rounds 2-7) mais la montée de tier est décision du joueur. En régime `rush_XP`, le
   joueur peut atteindre T3 au round 2 avec 3 slots. La co-calibration détecte ce cas — mais ne
   prescrit pas de REMÈDE, laissant la sim sans critère de résolution.**

---

## 1. Accords avec pourquoi ils tiennent pour NOS contraintes

### 1.1 Or fixe 10/round non reporté : accord total — 10e confirmation

**Accord total, dernière confirmation nécessaire.**
`superautopets.wiki.gg/wiki/Gold` : « 10 is gained each turn, but does not carry over turns ».
La mécanique reste la plus sobre disponible en async. Elle isole chaque round comme une
fenêtre de décision indépendante — propriété particulièrement précieuse en async où le joueur
ne voit pas l'état de son adversaire. Un or reportable exigerait de raisonner sur le budget
interrun ET la montée de tier en même temps, doublant la charge cognitive sans payoff
proportionnel. Aucun concurrent async valide n'a le report.

**Spécifique à nos contraintes** : le run court (10 victoires), l'absence de lobby partagé, et
le déterminisme (budget reproductible) rendent le budget stateless doublement correct.
**Cette décision ne nécessite plus de confirmation à chaque round.** Elle peut passer en
section historique de la roadmap.

### 1.2 Structure XP (passive + achetable, ratio BUY_XP 4:1) : accord

**Accord sur la structure, avec une nuance sur l'ancrage TFT corrigée au round 8.**
TFT conforme : `leagueoflegends.fandom.com/wiki/Experience_(Teamfight_Tactics)` : buy XP = 4g
= 4 XP. Mais TFT passive = **2 XP/round** (pas 1). Le ratio passive/achetable dans The Pit est
donc **2× plus lent** que TFT sur la passive. Ce n'est pas un problème si le rôle [A]/[B] est
déclaré et si la courbe est calibrée dessus — mais ça implique que The Pit exige davantage
de BUY_XP actif pour progresser, ce que la 6e métrique devra mesurer.

**Pourquoi ça tient pour nos contraintes** : un run de 10-19 rounds avec 1 XP/round passive
génère 9-18 XP passive max. Avec `{2,5,10,18}` (cible P3), un joueur purement passif atteint
T4 vers le round 12 mais ne peut pas atteindre T5 seul. Ce T5-comme-récompense-du-BUY_XP-actif
est un design intent défendable en grimdark (« le Puits n'offre sa profondeur qu'à ceux qui
la cherchent »).

### 1.3 Signal §2.5bis barre XP contextualisée : accord total

**Accord total, adoption R07/R08 maintenue.** La ligne contextuelle `delta > 4 → "N rounds ou
M BUY_XP"` convertit un fait brut en coût d'opportunité actionnable.
`machinations.io/glossary/opportunity-cost` : « opportunity cost is the value of the next-best
alternative foregone » — rendre le coût d'opportunité lisible sans le prescrire est la bonne
implémentation. Aucun argument nouveau pour annuler cette adoption.

**Pourquoi ça tient** : le joueur voit `XP : 4/10 → Tier 3` et « +1 XP passif (6 rounds OU
2 BUY_XP) » — il peut décider d'accélérer ou d'attendre. Coût 0 en SIM, 0 invariant.
L'asymétrie informationnelle était la vraie fuite éco : elle est colmatée.

### 1.4 Tableau §7.0 en PRÉCONDITION des sims P3 : accord total

**Accord total.** Neuf rounds ont fourni la preuve par l'exemple : 5 seuils d'alarme (dont 2
FAUX) ont survécu parce que l'intention n'était pas documentée d'abord. Le renversement d'ordre
(intention → sim → verdict) est disciplinaire, pas cosmétique.

**Pourquoi ça tient** : sans le tableau, la sim P3 produirait des chiffres sans verdict
(le synthétiseur R08 l'a rappelé ; `machinations.io` 2025 le confirme). L'ajout des interactions
déclarées entre constantes (Q4 R09 : `REROLL_COST × BUY_XP_COST`, `SLOT_DECLINE_GOLD ×
REROLL_COST`) est correct et non redondant avec les lignes individuelles.

### 1.5 Trois régimes de tension + seuils CORRIGÉS au round 9 : accord sur la structure

**Accord sur les 3 régimes** (early=recherche / mid=engagement / pivot=T4). **Accord sur les
seuils corrigés** (`reroll_dominance_T1 > 0.45` + `achat_rang_1_T1 < 1.5` ; redéfinition
`engagement_rate_T2`). Le calcul du R09 est correct et ancré sur la mécanique réelle lue dans
`00-state §4.3`.

**Clarification de méthode** : le seuil `> 0.45` (4,5 rerolls/10g) est calibré sur la politique
`standard`. La roadmap le précise ; c'est correct. En politique `rush_XP`, le ratio peut être
structurellement plus élevé — la condition explicite « politique `standard` only » doit rester
dans la spec du drapeau sim.

### 1.6 Décision de documenter le RÔLE [A]/[B] de la passive AVANT la 6e métrique : accord

**Accord sur la décision, désaccord sur la source (§2.3 de ce round).**
La logique est juste : si la passive est [B] (rituel), `passive_vs_bought_ratio` mesure le mauvais
paramètre. La déclaration préalable est la bonne discipline. Mais la source Amabile & Kramer 2011
est faible pour ce contexte — voir §2.3 ci-dessous.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD FONDATIONNEL — Le plafond naturel de la passive manque au calibrage de la courbe XP

**Claim implicite du brouillon v10** (§7.1 `--xp-climax`) : la tension de la courbe `{2,5,10,18}`
se teste en mesurant si « T4 jamais passif à 15 rd / rush T5 ≥20 % du budget / etc. ». Les
4 conditions supposent un joueur qui fait des décisions BUY_XP.

**Le problème : le PLAFOND NATUREL de la passive n'est jamais calculé explicitement, et
personne ne pose la question de savoir si la courbe est COHÉRENTE avec ce plafond.**

**Calcul (ancré sur `00-state.md §4.1-4.3`) :**

Avec `XP_PASSIVE_RATE = 1/round`, passive dès round 2 (soit N−1 rounds sur N joués) :

| Durée de run | XP passive totale | Tier atteint passivement | Seuil manquant vers T5 |
|---|---|---|---|
| 10 rounds (court) | **9 XP** | T3 (seuil {2,5} = 5 XP atteint R6) | 9 XP (T5=18) |
| 14 rounds (médian) | **13 XP** | T3 → T4 au round 13 (seuil 10) | 5 XP |
| 19 rounds (long) | **18 XP** | **T5 passivement à R19** | 0 XP |

**Ce que ce calcul révèle :**

1. **Sur run court (10 rounds)**, le joueur passif n'atteint jamais T4. T4 est réservé aux
   joueurs qui BUY_XP activement — défendable en design (T4 = récompense de l'investissement).
   La courbe `{2,5,10,18}` est cohérente avec ce run.

2. **Sur run long (19 rounds)**, le joueur totalement passif atteint T5 à R19 — exactement
   au dernier round. Ce n'est pas un problème per se (il ne jouera probablement pas R19 sans
   victoires), mais la 6e métrique devrait constater que `passive_vs_bought_ratio` est structurellement
   **proche de 100 % sur les runs très longs** — la passive domine mécaniquement, pas par choix du joueur.

3. **Le cas non modélisé : la politique `rush_XP` sur run médian (14 rounds).** Si le joueur
   dépense 4g en BUY_XP au round 2 (XP=5 = T2 immédiat) puis 4g en R4 (XP=9), il atteint T3 à
   R5 mais **n'a pas dépensé en unités pendant 2 rounds**. Le budget de build est appauvri exactement
   quand les grants de slots sont actifs (rounds 2-7). La co-calibration §7.1 condition 4 est censée
   détecter ce cas, mais elle mesure le **ratio moyen par round**, pas la **paupérisation momentanée des
   rounds 2-5** (qui est le vrai risque de fun).

**Proposition concrète : ajouter une métrique `budget_starvation_early` — §3.1 de ce round.**

**Source** : `00-state.md §4.1-4.3` (XP_PASSIVE_RATE=1, XP_TO_LEVEL={2,5,8,12} actuel,
candidats {2,5,10,18}/{2,5,10,20}, GOLD_PER_ROUND=10, BUY_XP_COST=4) ; calcul direct.

### 2.2 DÉSACCORD — Le signal de coût d'opportunité du slot-unlock (§2.5bis, adopté R09) est mal cadré

**Claim adopté en R09 (progression §2.2, §2.5bis)** : ajouter une ligne contextuelle :
```
early (T1-T2, slots < 5) → "Un slot = espace pour {9 − slots} unités d'ici la fin du run"
```

**Le problème : `(9 − slots)` mesure le potentiel TOTAL restant, pas la valeur MARGINALE
du slot MAINTENANT.**

`9 − slots` est identique que la run soit au round 2 ou au round 7. Un joueur avec 4 slots au
round 2 voit « espace pour 5 unités » — pareil qu'un joueur avec 4 slots au round 7. Mais ces
deux situations ont une valeur radicalement différente :
- Round 2, 4 slots, 8 rounds restants = ce slot utilisera **8 rounds** (valeur élevée).
- Round 7, 4 slots, 3 rounds restants = ce slot utilisera **3 rounds** (valeur faible).

Le signal tel que formulé ne distingue pas les deux.

**Ce que le signal devrait mesurer** : la valeur marginale du slot = nombre de combats restants
× valeur espérée d'une unité supplémentaire. Une approximation simple et grimdark :
```
rounds_restants = WIN_TARGET - wins + lives   (borne haute de la durée restante)
-- mais WIN_TARGET et lives sont dans state.lua, accessibles hors SIM

early (slots < 5, rounds_restants > 6) →
  "Un slot = {rounds_restants} combats à venir — ou {SLOT_DECLINE_GOLD} or maintenant"
mid-late (rounds_restants ≤ 6) →
  "Refuser = {SLOT_DECLINE_GOLD} or ({ceil(SLOT_DECLINE_GOLD/BUY_XP_COST*BUY_XP_AMOUNT)} XP équivalents)"
  + "Il reste ~{rounds_restants} combats."
```

**Pourquoi ça importe** : un joueur qui refuse un slot au round 7 pour 3 or fait un choix
différent de celui qui refuse au round 2 — le signal actuel n'aide pas à les distinguer. En
async, l'horizon de run est une information que le joueur n'a pas toujours clairement en tête.
Un slot refusé tard est souvent un or inutile (le run finit avant de le dépenser).

**Coût** : lire `state.wins` et `state.lives` (déjà accessibles hors SIM dans `build.lua`) +
calculer `WIN_TARGET - wins + lives` comme borne haute. ~0.5 h supplémentaire vs le signal R09.
0 SIM, 0 invariant. Le garde-fou DA (grimdark, pas de mot « optimal ») s'applique.

**Source** : `00-state.md §4.1` (WIN_TARGET=10, START_LIVES=5, SLOT_DECLINE_GOLD=3,
BUY_XP_COST=4, BUY_XP_AMOUNT=4) ; gamedeveloper.com 2013 (« organize trade-offs » =
montrer l'horizon, pas seulement le prix).

### 2.3 DÉSACCORD SUR LA SOURCE — Amabile & Kramer 2011 est une analogie paresseuse pour la passive XP comme « rituel »

**Claim du brouillon v10 (§7.0, progression §2.4 R09)** : la passive XP peut jouer le rôle [B]
— « signal rituel de temps » — ancré sur Amabile & Kramer 2011 (« The Progress Principle:
even small wins counter-momentum stagnation »).

**Le problème : Amabile & Kramer étudient la motivation PROFESSIONNELLE, pas le jeu vidéo.
Le mécanisme psychologique n'est PAS le même.**

L'étude (hbs.edu/faculty/Pages/item.aspx?num=40692) porte sur 238 personnes dans 26 équipes
de projet en entreprise : leurs **émotions et motivation** augmentent quand elles perçoivent
des progrès sur un travail **signifiant**. Le mot-clé est **meaningful work** — le contexte
qui donne à chaque micro-progrès une valeur symbolique élevée.

Dans The Pit, +1 XP passif est **un chiffre invisible** (le joueur ne le voit pas) jusqu'à
l'ouverture de boutique. Même avec le signal §2.5bis, le joueur **n'a pas d'action pour
déclencher la passive** — elle arrive toute seule. Or Amabile & Kramer précisent que le
progrès motivant est celui **perçu comme résultat de l'effort du soi** (« forward movement in
meaningful work »). Un fait passif ne déclenche pas la même neurochimie que le progrès actif.

**Ce qui est réellement en jeu** : la vraie question n'est pas « est-ce un rituel ou un levier »
mais « **le joueur PERÇOIT-IL +1 XP comme son progrès ou comme du temps qui passe** ? » Si le
signal §2.5bis dit « +1 XP passif (6 rounds) » et que le joueur lit ça comme « je dois
patienter 6 rounds », la passive génère de l'ATTENTE, pas du progrès.

**La littérature correcte pour ce mécanisme** :

- **Nunes & Drèze 2006** (Journal of Consumer Research — « The Endowed Progress Effect ») :
  offrir un avantage initial (même minime) accélère la complétion d'un objectif **si cet
  avantage est PERÇU comme un effort du joueur**. Une passive invisible ne remplit pas cette
  condition.
- **Flow Theory (Csikszentmihalyi 1990)** : le progrès en jeu est motivant quand les
  challenges correspondent aux capacités. La passive ne crée pas de challenge, elle est un fait.
- **L'Endowed Progress Effect est la bonne source**, pas Amabile & Kramer : si la passive est
  présentée comme un « bonus de fidélité » (la DA peut le formuler grimdark : « LE PUITS
  T'ACCORDE SA MARQUE — un XP en silence chaque round »), elle devient un avantage perçu
  comme un don, pas un fait brut — ce qui motive la poursuite vers l'objectif (seuil du prochain
  tier).

**Proposition** : retirer Amabile & Kramer de la justification du rôle [B] et le remplacer par
l'Endowed Progress Effect (Nunes & Drèze 2006) — qui exige que l'avantage soit **perçu**. Cela
modifie la spec du signal §2.5bis : la passive doit être présentée comme un « don » actif du
Puits (1 clé i18n = 0 coût supplémentaire), pas comme un fait du temps.

**Impact sur la décision [A]/[B]** : l'Endowed Progress Effect suggère que [B] est viable **si
et seulement si** le signal perçu frame la passive comme un don avec intention, pas comme du
bruit mécanique. Si le signal est mal formulé, [B] génère de la frustration (attente passive)
au lieu de la motivation (progrès offert). La décision [A]/[B] dans le tableau §7.0 doit
inclure cette condition de framing.

**Source** : Nunes & Drèze 2006 (Journal of Consumer Research) ; Amabile & Kramer 2011
(hbs.edu — limitée au contexte de travail signifiant) ; Csikszentmihalyi 1990 (Flow Theory).

### 2.4 TROU DE SPEC — La co-calibration shopTier/slots détecte le problème mais n'a pas de REMÈDE

**Claim du brouillon v10 (§7.1 condition 4)** : détecter `ratio = shopTier_moyen / slots_actifs_moyen > 1.5`
comme signal d'alarme de déséquilibre structurel.

**Le problème** : la condition 4 détecte le déséquilibre mais ne prescrit aucun **remède en sim**.
Elle dit « calibrer ensemble OU limiter le rush aux rounds post-grant » — mais ces deux options ont
des implications radicalement différentes :

- **Option A (calibrer ensemble)** : rendre la montée de tier plus lente globalement, au risque
  d'appauvrir l'expérience des joueurs qui jouent `standard` (pas de rush).
- **Option B (limiter le rush aux rounds post-grant)** : soit en recalibrant `BUY_XP_COST` au
  début du run, soit en limitant le BUY_XP aux rounds > `MAX_GRANTS` (round 7+). Mais `MAX_GRANTS`
  est un événement d'état de run, pas une constante de coût — l'implémenter exigerait un coût
  variable dynamique, ce qui **n'est pas actuellement dans la spec de `state.lua`**.

**Ce qui manque** : un critère de sélection entre les deux options, AVANT la sim. Sans critère,
la sim P3 détecte « ratio > 1.5 » et le développeur ne sait pas quoi ajuster. La condition 4 est
une **détection sans résolution**.

**Proposition concrète** : ajouter au tableau §7.0 la hiérarchie de remèdes :
```
Si ratio > 1.5 en politique rush_XP (et ≤ 1.5 en standard) :
  → Remède 1 (sans code) : communication de coût d'opportunité (§2.5bis + slot-unlock contextualisé §2.2)
    — peut suffire si le ratio est dû à un choix informé et pas à un manque d'info.
  → Remède 2 (data) : augmenter BUY_XP_COST de T1 à T1+1 (ex. 4g → 5g en T1) → ralentit le rush.
  → Remède 3 (sim) : retirer l'option rush_XP de la politique de mesure (mesurer seulement standard)
    — si le problème ne se pose qu'en rush_XP, le problème est la politique, pas la courbe.
Hiérarchie : R1 > R2 > R3 (ne pas complexifier avant de mesurer si R1 suffit).
```

**Source** : `00-state.md §4.1-4.3` (MAX_GRANTS=6, BUY_XP_COST=4, START_SLOTS=3) ;
progression §2.2/§2.3 ; §7.1 condition 4.

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 0 — DOC BLOQUANTE] Ajouter `budget_starvation_early` au tableau §7.0

**Quoi** : dans `eco-decisions.md` (§7.0), ajouter une ligne/métrique :

```
| BUDGET_STARVATION_EARLY | —  | INTENTION : détecter si la politique rush_XP appauvrit
  le budget de build pendant les rounds de slot-grant (rounds 2-7, quand les cases
  se débloquent et que le joueur voudrait aussi acheter des unités).
  Signal d'alarme : sur N=100 combats en politique rush_XP, mesurer le
  nombre_d'achats_rounds_2_7 / nombre_d'achats_total_R09_sans_rush.
  Si < 0.6× → le joueur rush sacrifie trop de diversité early pour monter de tier.
  Cibles : 0.6-0.9× (rush appauvrit un peu mais reste viable) ; < 0.6× = problème de fun.
```

**Pourquoi PRIORITÉ 0** : les sims P3 incluent `rush_XP` comme politique à tester, mais aucune
métrique ne mesure son coût sur la qualité du build early. Sans cette mesure, « rush est viable »
sera déduit du seul win-rate, qui ne capte pas l'expérience de 4 rounds sans acheter d'unités.

**Coût** : doc, ~20 min. 0 code, 0 invariant. Précondition de l'interprétation de la condition 4.

### 3.2 [PRIORITÉ 1] Corriger le signal slot-unlock pour intégrer l'horizon de run

**Quoi** : remplacer dans la spec §2.5bis (§2.2 de ce round) la ligne contextuelle du slot-unlock :

```lua
-- Calcul de l'horizon restant (hors SIM, state accessible dans build.lua)
local rounds_remaining_est = math.max(0, (WIN_TARGET - state.wins) + state.lives - 1)

-- Signal contextuel early (slots < 5 ET horizon > 5)
if rounds_remaining_est > 5 then
  label_slot = "Un slot = " .. rounds_remaining_est .. " combats à venir" ..
               " — ou " .. SLOT_DECLINE_GOLD .. " or maintenant."
else
  -- Signal contextuel late : 3 or vaut plus qu'un slot à cet horizon
  label_slot = "Refuser = " .. SLOT_DECLINE_GOLD .. " or" ..
               " (" .. math.ceil(SLOT_DECLINE_GOLD / BUY_XP_COST * BUY_XP_AMOUNT) ..
               " XP équivalents) — il reste ~" .. rounds_remaining_est .. " combats."
end
```

**Garde-fou DA** : « LE PUITS T'OFFRE L'ESPACE — ou son prix. Il ne restera pas longtemps. »
Pas de prescription (le joueur choisit). `rounds_remaining_est` est une BORNE HAUTE (le run
peut durer moins) — formuler comme « ~N combats » (tilde = approximation assumée).

**Précondition** : `WIN_TARGET` et `START_LIVES` doivent être accessibles depuis `build.lua`
(vérifier qu'ils sont exportés depuis `state.lua` ou accessibles en lecture sans la couche SIM).
Zone sans test → test headless aux cas limites (`wins=0/lives=5` ; `wins=9/lives=1`).

**Coût** : ~1 h RENDER (légèrement plus que la spec R09 mais plus précis). 0 SIM, 0 invariant.

### 3.3 [PRIORITÉ 1 — DOC] Remplacer Amabile & Kramer par l'Endowed Progress Effect dans la spec du rôle [B]

**Quoi** : dans le tableau §7.0 (ligne `XP_PASSIVE_RATE`), remplacer la référence Amabile & Kramer
par la spec suivante :

```
XP_PASSIVE_RATE | 1/round | INTENTION [A] ou [B] (décision user) :
  [A] Levier mécanique : contribue à la courbe XP ; passive_vs_bought_ratio cible 20-50 %.
      → 1/round sur 15 rounds = 13 XP max (T4 vers R13) ; T5 exclusivement actif.
  [B] Signal rituel perçu comme don actif (Endowed Progress Effect, Nunes & Drèze 2006) :
      → PRÉCONDITION : le signal §2.5bis doit framer la passive comme un DON GRIMDARK
        du Puits (« LE PUITS T'ACCORDE SA MARQUE ») — pas comme un fait du temps.
        Si ce framing est absent, [B] génère de l'attente (frustration), pas du progrès.
      → passive_vs_bought_ratio attendu 15-25 % naturel ; NE PAS ajuster la passive
        si < 20 % (c'est voulu si [B]) ; ajuster le SIGNAL si < 15 %.
      → Source : Nunes & Drèze 2006 (JCR) — endowed progress = avantage perçu comme
        effort du soi → motivation de complétion. Amabile & Kramer 2011 (travail signifiant
        en entreprise) n'est PAS transférable sans condition de framing.
```

**Coût** : doc, 20 min. 0 code. Modifie la précondition d'interprétation de la 6e métrique.

### 3.4 [PRIORITÉ 1 — DOC] Ajouter la hiérarchie de REMÈDES à la condition 4 (co-calibration)

**Quoi** : dans §7.1 condition 4, ajouter :

```
Si ratio > 1.5 en rush_XP (ET ≤ 1.5 en standard) :
  Remède 1 [sans code, en // P0] : vérifier si les signaux §2.5bis + slot-unlock (§3.2) suffisent
    à réduire le ratio (comportement de joueur informé vs aveugle — la différence peut être le signal,
    pas la mécanique).
  Remède 2 [data] : BUY_XP_COST T1 → 5g (ralentit le rush sans bloquer ; retest condition 4 + `--xp-climax`).
  Remède 3 [mesure] : exclure rush_XP de la co-calibration (mesurer que standard si le problème est propre
    à la politique rush_XP — évite de pénaliser les joueurs standard pour compenser la politique extreme).
  Ordre strict : R1 avant R2 avant R3 (ne pas complexifier avant de mesurer).
```

**Coût** : doc, 20 min. 0 code. Précondition de l'interprétation de la sim P3 condition 4.

### 3.5 [PRIORITÉ 2 — CONDITIONNEL] Calculer explicitement le plafond naturel de la passive pour la courbe candidate

**Quoi** : avant de figer `{2,5,10,18}` vs `{2,5,10,20}` en P3, calculer pour CHAQUE courbe :

```
Pour {2,5,10,18} :
  - Round où un joueur PASSIF atteint chaque tier (policy = 0 BUY_XP) :
    T2 = R3 (2 XP passive R2+R3)
    T3 = R6 (5 XP passive R2-R6)
    T4 = R12 (10 XP passive R2-R12) ← sur run médian 14R, atteint R12 = OK
    T5 = R19 (18 XP passive R2-R19) ← sur run long 19R, atteint juste à la fin
  - Verdict : T5 = exclusivement actif (run court-médian). Correct si voulu.
  - Risque : sur run long 17-19R, T5 passif élimine la tension finale.

Pour {2,5,10,20} :
  - T5 = R21 (jamais passivement sur un run normal).
  - Verdict : T5 = toujours actif. Plus propre pour [A], plus frustrant si le joueur ne BUY_XP pas.
```

Ce tableau (5 lignes, 0 code) doit figurer dans `eco-decisions.md` AVANT `--xp-climax` — il permet
de prédire si la sim va valider ou invalider chaque courbe sans la lancer.

**Coût** : doc, 15 min, arithmétique simple. Évite une itération sim si la courbe candidate est
déjà incohérente avec l'intention déclarée.

---

## 4. Questions ouvertes

### Q1 — La dérive du ratio reroll/achat (1:1 → 1:5) est-elle PERÇUE par le joueur ?

La roadmap documente la dérive mécaniquement (R09 §2.1, §7.0). Mais le joueur perçoit-il
consciemment que reroller coûte proportionnellement moins en T5 ? En async (pas de lobby, pas
de spectateur), la référence est sa propre session. Si le joueur ne perçoit pas la dérive,
l'incitation à reroller massivement en T5 peut apparaître comme un « flow naturel » — ce qui est
positif (exploration grimdark late). Mais si le comportement de reroll massif T5 est non voulu, il
faut savoir si le signal informatif (§2.5bis dit le coût d'opportunité mais pas le ratio implicite)
suffit à équilibrer. La sim mesure le comportement ; la décision UX est séparée.

**Option à trancher (§7.0 `REROLL_COST` ligne intention)** : si le ratio 1:5 est voulu comme
« exploration late grimdark », l'écrire explicitement dans le tableau §7.0 comme INTENTION (pas
TBD) — pour ne pas passer P3 à chercher un problème qui est en fait un choix.

### Q2 — La passive XP doit-elle varier selon la progression (escalade conditionnelle) ?

Le brouillon §11 mentionne « escalade de la passive +2 en round 8+ » comme idée à l'étude.
L'argument de design serait : la passive plus forte en late compenserait l'or de moins disponible
(le joueur dépense plus sur des unités chères). Mais cette escalade complexifie la courbe et peut
masquer la tension T4 → T5. La décision dépend du rôle [A]/[B] : si [A], l'escalade peut accélérer
l'accès à T5 late de façon prévisible ; si [B], l'escalade doit être communiquée (sinon elle viole
la prévisibilité de règle du rituel). **À trancher dans §7.0 AVANT la sim.**

### Q3 — Le `pivot_T4_decision_rate` est-il mesuré sur des décisions INFORMÉES ?

La 5e métrique (`P(BUY_XP vs achat rang-4 en T4)`, cible 30-70 %) suppose que le joueur peut
comparer les deux options. Avec la barre XP §2.5bis en place (prévu P0), la décision est informée.
Mais **les sims P3 sont lancées AVANT P0** dans le calendrier actuel (P0 est v0.9, P3 est v0.12).
La métrique `pivot_T4_decision_rate` mesurée sur une simulation sans le signal §2.5bis = comportement
de joueur aveugle. La note du tableau §7.0 doit préciser : **mesurer cette métrique sur des runs
simulés avec la barre XP active** (ou documenter que les sims P3 calibrent pour le comportement sans
signal, et que la barre XP la corrigera → calibrage conservateur).

### Q4 — Le slot-decline comme « espace pour N unités » vs « or + XP » : quel FRAMING ?

Le signal slot-unlock proposé (§3.2) montre deux axes : espace (slots restants à débloquer) et or
(SLOT_DECLINE_GOLD). Une question non posée : le joueur qui refuse systématiquement les slots
alimente-t-il l'XP ou le build direct ? `SLOT_DECLINE_GOLD=3` = 3 or → 0.75 BUY_XP (ratio 3:4).
Ce n'est pas un rapport naturel. Documenter dans §7.0 si le refus de slot est pensé comme
alternative au BUY_XP (cohérence de l'arbre décisionnel boutique) ou comme orné pur.

---

## 5. Synthèse des challenges clés pour la roadmap

### Ce qui doit changer par rapport aux rounds 1-9 :

1. **Ajouter la table du plafond passif** dans `eco-decisions.md` avant `--xp-climax` : 5 lignes
   arithmétiques qui prédisent l'impact de chaque courbe candidate et évitent une itération sim.

2. **Corriger le signal slot-unlock** (§2.5bis) pour intégrer l'horizon de run (`rounds_remaining_est`)
   au lieu du potentiel brut `(9 − slots)`. Même coût de dev, signal plus précis.

3. **Remplacer Amabile & Kramer par Nunes & Drèze 2006** (Endowed Progress Effect) pour le rôle [B]
   de la passive, avec la précondition de framing grimdark. L'analogie HBR-travail était paresseuse.

4. **Ajouter la hiérarchie de remèdes** à la co-calibration §7.1 condition 4 : sans critère de
   résolution, la condition 4 est une détection sans verdict (exactement ce que le tableau §7.0
   est censé éviter).

5. **Trancher l'intention `REROLL_COST=1` en T5** dans §7.0 comme VOULU ou NON VOULU (pas TBD) :
   la dérive 1:5 est documentée R09 mais l'intention est encore ouverte. Un TBD en P3 = 9 rounds
   de sim avec un comportement late non intentionnel ou intentionnel non distingué.

### Ce qui reste inchangé et tient (10e confirmation globale) :

- Or fixe 10/round : **définitif, peut passer en historique.**
- Structure XP (passive + achetable, ratio 4:1) : saine, à calibrer avec le plafond passif.
- Barre XP §2.5bis + signal contextuel : maintenu (+ signal slot-unlock à corriger §3.2).
- Tableau §7.0 en précondition des sims P3 : maintenu (+ 4 ajouts de ce round).
- 6e métrique `passive_vs_bought_ratio` : maintenu (+ condition de framing [B]).
- 3 régimes de tension + seuils corrigés R09 : maintenus.
- Co-calibration shopTier/slots (condition 4) : maintenu (+ hiérarchie de remèdes §3.4).
- Décision `REROLL_COST` tranchée par sim `tools/sim.lua` : maintenu (+ signal d'alarme R09).

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md §4.1-4.3`
  (XP_PASSIVE_RATE=1, XP_TO_LEVEL={2,5,8,12}, BUY_XP_COST=4, BUY_XP_AMOUNT=4,
  GOLD_PER_ROUND=10, REROLL_COST=1, START_SLOTS=3, MAX_GRANTS=6, SLOT_DECLINE_GOLD=3,
  WIN_TARGET=10, START_LIVES=5, SHOP_SIZE=5, MAX_TIER=5)
- `docs/roadmap-lab/ROADMAP-draft.md` v10 — §2.5bis, §7.0-7.5, §7.1 conditions 1-4
- `docs/roadmap-lab/rounds/r09-progression-economy.md` — seuils régimes 1-2 corrigés, slot signal, rôle [A]/[B]
- `docs/roadmap-lab/round-09.md §0` — 14 adoptions, seuils code-vérifiés

**Sources web vérifiées ce round** :
- [TFT Experience — leagueoflegends.fandom.com](https://leagueoflegends.fandom.com/wiki/Experience_(Teamfight_Tactics))
  (passive 2 XP/round confirmé ; buy XP 4g = 4 XP)
- [TFT Leveling — lolchess.gg](https://lolchess.gg/guide/exp)
  (table niveaux, cumuls XP, confirmation de la passive)
- [SAP Gold — superautopets.wiki.gg](https://superautopets.wiki.gg/wiki/Gold)
  (10g/round non reporté ; reroll 1g ; toutes unités 3g = ratio 1:3 constant)
- [SAP Shop — superautopets.fandom.com](https://superautopets.fandom.com/wiki/Shop)
  (coûts des unités SAP confirmés 3g)
- [Backpack Battles reroll scalant — steamcommunity.com](https://steamcommunity.com/app/2427700/discussions/0/4035850678059688137/)
  (doublement après 4 rerolls ; 66 % pro / 34 % contra)
- [Roguelite progression milestones — entaltostudios.com](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)
  (visible milestones = driver "one more run")
- [Opportunity Cost — machinations.io](https://machinations.io/glossary/opportunity-cost)
  (shadow values, organize trade-offs dans les systèmes de jeu)
- [The Progress Principle — hbs.edu](https://www.hbs.edu/faculty/Pages/item.aspx?num=40692)
  (Amabile & Kramer 2011 : contexte travail signifiant en entreprise — **non directement transférable**)
- Nunes & Drèze 2006 (Journal of Consumer Research) — Endowed Progress Effect :
  avantage initial perçu comme effort du soi → motivation de complétion (source correcte pour [B])

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 10/10. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe
seedée / DA grimdark / pixel art procédural). 32 invariants non modifiés.
4 désaccords sourcés (calcul mécanique + web vérifié). 3 propositions doc prioritaires, 1
RENDER, 1 conditionnel. 4 questions ouvertes pour la synthèse finale.*
