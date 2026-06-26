# Feel Lab — Recherche #6 : Animation de level-up / fusion (« ta-ta-ta-TAAA »)

> Comment les autobattlers mettent en scène la fusion de copies (TFT 3★, HS Battlegrounds triple, SAP…).
> **[C]** consensuel/sourcé · **[I]** inférence d'adaptation.

## Structure multi-étapes canonique **[C]** (durées **[I]** calées grimdark)
| Étape | Durée | Courbe | Contenu |
|---|---|---|---|
| 0. Anticipation | 80-140ms | ease-out, recul | la cible se tasse, les copies « frémissent » (le pic de dopamine arrive AVANT la récompense) |
| 1. Convergence | 250-400ms/copie, **staggerées** | **ease-IN** (`p*p`) | les âmes volent vers la cible en accélérant |
| 2. Impact(s) | 1 par arrivée | — | flash local + petit shake + « tic » sonore = le **« ta »** |
| 3. Climax | 300-500ms | **back/overshoot** | freeze + flash + onde de choc + burst radial + squash-stretch + pip pop = le **« TAAA »** |
| 4. Settle | 200-400ms | ease-out amorti | la cible retombe, l'aura s'estompe, le pip doré reste |

Total ~**0,9-1,3 s** (level-up simple). Premier feedback **<100ms** après le clic. Ne JAMAIS bloquer l'input.

## Le RYTHME (cœur de la demande) **[I appuyée]**
- N copies = **N beats staggerés** (pas simultanés), espacement **90-130ms**, **qui se resserrent** vers le climax.
- **Pitch montant** à chaque « ta » (+1 demi-ton → tierce) — c'est le « dopamine ding » (bright/court, ici en
  timbre grimdark via l'échelle mineure de `SFX.ladder`). La montée **visuelle** (micro-pulse de scale + glow
  croissant) double la montée sonore (synchro).
- **3 copies vs cascade longue** : compresser le stagger au-delà de ~4 beats, ou **re-trigger escaladé** (préféré).

## Couches de juice du climax **[C]** — la SYNCHRO <50ms est critique
Flash 50-100ms · squash→stretch (back overshoot, volume constant) · onde de choc (anneau qui fade) · burst
radial **20-30 particules** · **screen-shake trauma²** (Eiserloh ; amplitude PETITE 2-10px) · **hitstop 50-150ms**
· number/pip pop · **son** (montée + impact grave final). *« Trois éléments parfaitement synchronisés > dix mal
synchronisés »* — au frame du climax, TOUT part au même frame. Priorité (IEEE Lin 2022) : **hitstop, son, shake**.

## Origines hétérogènes (plateau / banc / **boutique**) **[I appuyée]**
- Traînées (lire la trajectoire) + **arc de Bézier** (point de contrôle décalé vers le haut) > ligne droite quand 3+ convergent.
- **Carte boutique** : ajouter un **beat d'aspiration** (~100ms : la carte se soulève/scale-up) AVANT que l'âme parte,
  sinon l'âme « détachée » paraît incohérente (piège). Limiter le nb de trails simultanés visibles.

## Cascade (escalade, pas répétition) **[I appuyée — réf TFT rank-up ceremonies]**
Eau → Feu → Foudre : effets qui **persistent plus longtemps + couvrent plus d'écran** à chaque palier. Deux
approches : **A** escalade séquentielle (chaque fusion son climax, plus court+intense) ; **B** compression (un seul
méga-climax au niveau final + un compteur « LVL 1→3 »). Pour une boucle, **B** (anti-traîne).

## Pièges **[C]**
1. Trop long → frustrant en boucle (débat anim 3★ TFT). **<1,3s, compressible, jamais bloquant.**
2. Illisible (trop de particules) → « leading the eye » vers UN point, shake petit, ≤30 particules.
3. Pas de payoff (« number go up » sans punch) → il FAUT hitstop + shake + son grave final.
4. Incohérence quand l'origine est le shop (faire réagir la carte).
5. Désynchro <50ms = impact effondré (le piège le plus insidieux).
6. Habituation → varier légèrement (pitch/scale/positions ±) garde le dopamine frais.

## 3 propositions comparables (implémentées : `lib/levelup.lua` style=`burst`/`orbit`/`slam`)
- **A « Convergence + Burst »** *(le plus sûr)* : âmes staggerées en arc + pitch montant ; dernière arrivée →
  flash + hitstop + shake + burst radial + squash-stretch + pip pop. Aura dorée persiste.
- **B « Orbite + Implosion »** *(grimdark)* : les âmes orbitent en spirale resserrée puis **implosent** en un seul
  « TAAA » → shockwave + shake fort. Vortex lovecraftien.
- **C « Stagger Slam »** *(le plus punchy, Dead Cells)* : chaque arrivée = micro-hitstop (40ms) + flash + shake
  croissant → « TA. TA. TA. » très scandé ; promotion = le plus gros slam.
**Reco [I]** : **A** comme base + le micro-shake croissant de **C** + l'escalade pleine-puissance (« big ») pour le **niveau 3** seulement (rare = mérite le spectacle).

## Réutilisation dans le vrai jeu
Point d'entrée UNIQUE `Build:spawnMergeFx` (`build.lua:421`) — tous les chemins de fusion y passent. Lui passer
`{ sources=[{x,y,kind}], target={x,y}, color, toLevel, big }`. Ingrédients déjà présents : `Feel.approach`
(easing), burst de mort (`arena_draw.lua`), shake (`arena_draw`/`cmdShake`), `Badge.levelPips`, hooks son
`Feel.onPress/onHover`. À créer : hitstop, shake-en-build, pitch-ladder audio. RENDER-pur → golden intact.

Sources : Eiserloh GDC 2016 (trauma²) · Jonasson/Purho « Juice It or Lose It » · socratopia (sync<50ms, hitstop) ·
eastondev (flash/particules/staging) · gamejuice (XP bar, Rule of Three, shake tiers) · Jaden Lee/Riot (TFT
rank-up ceremonies, « leading the eye ») · unwinnable/ideatogame (pitch montant) · zleague (débat anim 3★).
