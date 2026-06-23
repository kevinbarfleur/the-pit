# roadmap-lab — Brief (mandat de la boucle nocturne)

> **But** : par **≥10 rounds de débat adversarial entre sous-agents**, converger vers une **roadmap
> complète, claire, priorisée et précise** pour faire de *The Pit* un **autobattler fun, addictif et
> compétitif** — avec l'envie d'**enchaîner les runs pour monter en ranked**. **Rien laissé au hasard.**
>
> Lancé en autonomie la nuit (user au repos). Tout se consigne et s'itère dans **`docs/roadmap-lab/`**.

## Méthode (adversariale, à chaque round)
1. **Propose** : des agents proposent des axes d'amélioration depuis des **lentilles distinctes** (ci-dessous).
2. **Challenge** : d'autres agents **lisent les rapports des rounds précédents** et les **contestent point par
   point** — d'accord / pas d'accord — en faisant **leur propre recherche web sourcée** pour comprendre
   *pourquoi* l'agent a proposé ça et *pourquoi* ils sont (ou non) d'accord. Citer les sources.
3. **Synthèse** : un agent acte le round → **consensus / litiges ouverts / preuves nouvelles** → `round-NN.md`.
4. **Itère** : chaque round s'appuie sur les précédents (lit les fichiers du dossier) jusqu'à convergence.

## Lentilles — TOUT y passe

### Méta / systèmes
- **Progression & économie** : shop-XP (passif + acheté), reroll, slots, vies/victoires, streaks. Courbe ?
- **Compétitif / ranked** : MMR, ladder, format des saisons, ce qui donne envie de **réenchaîner pour grimper** ;
  intégrité async (snapshots/ghosts), anti-snowball, équité perçue.
- **Boucle d'addiction / rétention** : variance vs agence, high-roll, near-miss, méta-progression (Grimoire),
  « one more run ». Ce qui retient sans frustrer.
- **Onboarding / courbe de complexité** : lisibilité, barreaux d'échelle (re-tier rang/complexité déjà engagé).

### Contenu (le cœur du fun — ne rien survoler)
- **Unités** (83) : distinctes ? identité lisible ? budget de puissance par rang cohérent ? **plates/redondantes** ?
  trous d'archétypes ? Le re-tier par complexité (rang 1→5) est-il sain ?
- **Synergies** : **adjacence positionnelle** (le voisin buffe) **+ synergies par TYPE** (encore un TODO) —
  y en a-t-il assez ? sont-elles **lisibles** ? créent-elles de **vraies décisions de placement/build** ?
- **Effets** : les **5 familles de DoT** (brûlure/saignement/poison/pourriture/choc) + **boucliers** + **auras** —
  équilibrées entre elles ? **interactions** intéressantes (contagion, propagation, conversions croisées) ?
  gaps ? La hiérarchie d'archétypes (cf. diagnostic : poison > tank > … > choc) est-elle un problème ?
- **Reliques** (18) : impactantes ? **build-defining** ? **activent des archétypes** ? équilibrées ? **lisibles** ?
  couverture suffisante ? le modèle « 1-parmi-3 + ±niveau de boutique » tient-il ?

## Analyse concurrentielle — ULTRA-APPROFONDIE (ne rien laisser au hasard)

Exigence user explicite : étude **ultra-avancée** des mécanismes de la concurrence — **comment** ça marche,
**pourquoi** ça marche, **ce qui est transférable** chez nous. **Interdit** : le survol et l'analogie paresseuse
(« X fait ça, copions »). **Obligatoire pour CHAQUE mécanisme** : *teardown → psychologie → maths → verdict de
transférabilité*.

### Jeux à disséquer (groupés par ce qu'ils enseignent)
- **Autobattlers** : **TFT** (cotes par niveau, leveling, augments, ranked, rotation de sets), **HS Battlegrounds**
  (tavern tiers, coût plat, MMR, casual↔compétitif), **Super Auto Pets** (async, simplicité, rétention — *notre réf*),
  **The Bazaar** (Reynad — autobattler **async PvP** par items, compétitif récent), **Backpack Battles** (recettes,
  rareté/round, async « Batomon-like »).
- **Boucle d'addiction / run-based** : **Balatro** (économie, escalade de score, combos de jokers, « one more run » —
  masterclass récente), **Slay the Spire** (archétypes/synergies, **design des reliques**, climb **Ascension**),
  **Hades** (pacing des boons, build-definition), **Binding of Isaac** (items, découverte).
- **Compétitif / ranked & rétention** : **Marvel Snap** (ladder, collection, « one more game »), ranked TFT/HS
  (MMR, saisons, récompenses), **courses seeded/leaderboard** (Balatro stakes, StS daily).
- **Synergies & types** : traits TFT, types Pokémon, combos Balatro, archétypes StS.
- **POSTMORTEMS (aussi instructifs que les succès)** : **Dota Underlords** (déclin), **Storybook Brawl** (mort),
  **Artifact** (échec) → *pourquoi ils sont morts* = ce qu'il ne faut **PAS** faire.

### Pour CHAQUE jeu, exiger (sinon le rapport est rejeté au round suivant)
1. **Boucle cœur + mécanismes PRÉCIS** (pas vague) : économie, escalade, déblocage, variance, méta-progression.
2. **Les MATHS, chiffrées et SOURCÉES** : tables de cotes, courbes XP/or/coûts, taux d'escalade, tailles de pool, cadences.
3. **La PSYCHOLOGIE** : *pourquoi* ça hook (renforcement variable, near-miss **sous agence**, high-roll, dette/anticipation,
   competence growth, FOMO/ladder). Citer recherche/GDC/interviews — **pas d'intuition non sourcée**.
4. **Structure compétitive** : ce qui fait **réenchaîner pour grimper** (ladder, stakes, saisons, leaderboards, intégrité).
5. **VERDICT DE TRANSFÉRABILITÉ à The Pit** *(le livrable clé)* : le « pourquoi ça marche » survit-il à NOS contraintes —
   **async par snapshots** (zéro live), **run court (10 victoires)**, **sim déterministe**, **grimdark procédural** ? Si oui,
   *comment* l'adapter précisément ; sinon, *pourquoi* et **quoi mettre à la place**.

### Règle adversariale spécifique à la concurrence
Les agents doivent **contester les verdicts de transférabilité** des autres : un « TFT fait X » n'est recevable que si le
**mécanisme psychologique/mathématique sous-jacent** tient dans notre contexte async/court/déterministe. **Démonter les
analogies paresseuses**, sourcer chaque désaccord. Une conclusion non étayée par un *pourquoi* mécaniste = à re-challenger.

## Ancrage (INGÉRER, ne pas re-dériver — puis CHALLENGER/ÉTENDRE)
- **Code/data réels** : `src/data/units.lua`, `src/data/relics.lua`, `src/effects/`, `src/board/`,
  `src/run/state.lua`, `src/net/` (snapshots), `src/gen/` (génération créatures).
- **Tests** (ce qui est garanti) : `tests/synergies.lua`, `tests/props.lua`, `tests/golden.lua`, `tests/run.lua`.
- **Recherche & décisions existantes** : `docs/research/*` (gd-research-result, relics-design, effects-dot-families,
  combat-model-decision, autobattler-design…), **`docs/research/progression-economy-prd.md`** (chantier en cours),
  et la mémoire projet. **Les agents doivent les lire d'abord**, puis pointer accords/désaccords avec recherche à l'appui.

## Garde-fous (NON négociables)
- **Recherche + roadmap UNIQUEMENT — AUCUNE modification du code du jeu pendant la nuit.** Les agents lisent
  le repo et le web ; ils n'éditent que des fichiers dans `docs/roadmap-lab/`.
- Respecter les **piliers** : multijoueur **async par snapshots** (jamais de temps réel), **sim déterministe
  seedée**, **DA grimdark**, **pixel art 100 % procédural**. Toute idée qui les casse doit être **signalée** comme telle.
- **Citer les sources** de toute affirmation de design (jeux de réf, articles, données). Pas d'assertion d'API non vérifiée.
- Petits nombres, build simple → profondeur émergente (réf SAP/Batomon). Égalisateurs, pas de gates.

## Sorties (dans `docs/roadmap-lab/`)
- `00-state.md` — état des lieux ancré (ressources réelles + ce qui est déjà décidé).
- `round-01.md … round-NN.md` — chaque round de débat (propositions, challenges sourcés, synthèse).
- **`ROADMAP.md`** — la roadmap finale : **priorisée**, **précise**, **chiffrée si possible**, séquencée en jalons,
  couvrant méta **ET** contenu (unités/synergies/effets/reliques), orientée **fun + addictif + ranked compétitif**.

## Séquence d'amorçage
Lancé **après** la finition des reliques (Lots 4-6 du PRD). À ce moment le repo contient déjà : roster re-tiéré
(12/23/18/20/10), shop-XP, marchand /3 combats, reward au level-up, reliques ±niveau. Le lab analyse donc le **jeu le plus à jour**.
