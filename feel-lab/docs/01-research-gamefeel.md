# Feel Lab — Recherche #1 : Game-Feel / Juice (refs indé)

> Recherche multi-agents (2026-06-25), sourcée et recoupée. Légende : **[C]** consensuel/multi-sources ·
> **[S]** source unique fiable · **[I]** inférence d'adaptation à LÖVE/The Pit. Durées @60fps (1 frame ≈ 16,7 ms).

## 0. Principe-cadre — la "Juice Stack"
Le feedback EST le produit. Chaque événement empile des canaux indépendants qui se renforcent
*multiplicativement* : (1) animation, (2) particules, (3) effet d'écran (shake/flash), (4) audio, (5) haptique.
Tuner **en contexte dense**, pas sur un clic isolé (un effet seul paraît dramatique, en combat il écrase). **[C]**

## 1. HOVER
- Scale-up bouton **×1.05–1.10** (jamais >1.1). Carte : lift **−12px** (−24px si sélectionnée), scale ×1.08. **[C/S]**
- Durée **120–200ms**, sweet spot **~150ms** ; courbe **ease-out** (`cubic-bezier(0.33,1,0.68,1)`). **[C]**
- Le secret Balatro : un **`juice_up`** (punch de scale qui overshoot puis ressort), PAS un état statique +
  **tilt parallax** des couches vers le curseur (micro-motion = "vivant"). **[C]**
- Ombre projetée + glow teinté (faction). Anti-flicker : hover sur le parent, anime l'enfant. **[C]**
- **[I] The Pit** : `mouseEnter` → `juice_up(scale +0.06, rot ±0.02rad)` décroît ~0.15s + son hover. Lift/glow grimdark.

## 2. CLICK / PRESS
- **Feedback immédiat AVANT la résolution de l'action.** **[C]**
- Squash **0.97** au press (≤80ms, ease-in) ; release **120–180ms** ease-out ; punch overshoot **1.0→1.03→1.0** (back). **[C]**
- Flash bref (~80ms). Overshoot toléré : translate 15–20% / scale 5–10% max, JAMAIS sur opacité. **[C]**
- **[I]** boutons "à conséquence" (COMBAT/REROLL) : + screen-shake light + son success distinct.

## 3. DRAG & DROP (cœur du feel Balatro)
- **Lead-and-follow** : un objet logique suit la souris direct ; le visuel suit par **interpolation amortie**.
- Formule canonique (Tom Delalande) : `vel = vel*0.75 + (target-pos)*0.25 ; pos += vel` (spring discret, bouncy). **[C]**
- **Tilt/sway par vélocité X** : `desired = clamp((x-lastX)*0.85, ±MAX)` ; `rot = lerp(rot, desired, 12*dt)` ; repos → 0. MAX ≈ qq°. **[S]**
- Pickup : scale up (0.22→0.26) + ombre qui se détache + `sendToFront`. Drop : **snap magnétique amorti**, voisins poussés par inertie. **[C]**
- Swap pendant drag : comparer X aux voisines, swap slots, l'autre carte s'anime via le même follow. Son pickup ≠ drop. **[C]**
- **[I]** = LE plus gros gain "bonbon" pour un autobattler à plateau (le drag bench→case existe déjà).

## 4. TRANSITIONS DE SCÈNE
Durées : menus rapides ; in-game **150–200ms** ; main menu jusqu'à **300ms** ; >250ms commence à "laguer", jamais >1–2s. **[C]**

| Type | Feeling | Durée |
|---|---|---|
| Fade (→noir→retour) | respiration, masque le load | out/in 0.5s |
| **Dissolve** (bruit qui ronge) | mort/rêve — **grimdark ✓** | ~0.5s |
| Wipe directionnel | cut cinématique | ~0.3s |
| Slide/Push | navigation spatiale ("on traverse une porte") | 200–400ms |
| Iris / CircularWipe | focus | court |
| **Burn** (bord ember) | feu, reveal — **grimdark ✓** | — |
| "Deal" de cartes | distribution staggered (Balatro) | 30–50ms/carte |

Logique **spatiale** : un panneau à droite slide depuis la droite (carte mentale). **[C]**
**[I]** build→combat = **dissolve/burn** ~300ms + shake léger ("on descend dans le Puits") ; réutiliser les shaders postfx
oniriques existants comme masques (Balatro fait *tout* en shaders).

## 5. POPUPS / MODALES — chorégraphie 2 couches
| Couche | Action | Durée | Courbe |
|---|---|---|---|
| Backdrop | dim **0.5–0.7** + blur **4–8px** | fade 200–250ms | ease-out |
| Panel in | scale **0.95→1.0** (jamais 0 ; partir de 0.88–0.96) + fade | **250–350ms** | back `(0.34,1.56,0.64,1)` |
| Panel out | scale 1→0.95 + fade | **~200ms** (plus rapide) | ease-in |
| Contenu | stagger des items | **30–50ms**/item | ease-out |
| Erreur | shake bref + overshoot 1.02→1.0 | ~300ms | — |

Chorégraphie "pro" : backdrop dim **d'abord**, puis panel ; fermeture = panel part **en premier**, puis backdrop.
Origin ancré au trigger pour popovers/tooltips. **Tooltip** : 0.96→1, **120–160ms, no bounce**, delay 300–500ms puis instantané. **[C]**

## 6. JUICE GLOBAL
### 6.1 Screen-shake "trauma-based" (Eiserloh/Vlambeer) — référence **[C]**
- Accumuler **`trauma ∈ [0,1]`** (gros évt +0.5, petit +0.1) ; `trauma -= decay*dt` ; **`shake = trauma²`** (ou ³).
- Déplacement via **Perlin** (`love.math.noise` natif LÖVE), PAS random/frame :
  `offX = maxOff * shake * noise(seedX, t*freq)` (idem Y, et roll par rotation, à doser).
- Valeurs : `maxOffset` modeste (qq px en virtuel 320×180) · `maxAngle` ~12° à doser · `decay` 0.5–0.8 · `freq ~20Hz` · `pow 2–3`.
- **4 tiers** : light 3–5f / medium 6–10f / heavy 12–20f / catastrophic 20+f — mapper CHAQUE évt à un tier.
- 4 erreurs : trop fort/long (nausée) · shake **uniforme** (illisible) · pas de toggle accessibilité · **shake sans audio = creux**.

### 6.2 Hitstop / freeze-frame **[C]**
`time_scale=0` pendant N ms puis retour, via timer qui **IGNORE le timescale** (piège #1). Light **30–50ms** / heavy **60–100ms** /
crit **100–150ms**. Ne pas empiler, réserver aux gros coups/kills.

### 6.3 Combo impact complet **[C]**
Coup lourd = hitstop 60ms + trauma 0.5 + stretch arme + squash cible + burst particules + SFX basses (tout subtil, ensemble = "wow").

### 6.4 Tweening + squash&stretch (Juice it or lose it) **[C]**
Easing sur *tout* changement de propriété ; squash&stretch + wobble ressort au rebond ; motion-stretch selon vélocité ;
particules ("jamais trop"), flash, "donner des yeux à tout".

### 6.5 Number-roll juicy (très Balatro) **[S]**
Les nombres **roulent** (slot machine), digits staggered 50ms, courbe back `(0.34,1.56,0.64,1)` ; le compteur grossit ;
un combo qui finit se **brise** (shatter) plutôt que disparaître.

## 7. SON / SFX (canal le plus sous-estimé)
- **Pitch ±5–10%** à chaque lecture (`pitch = rand(0.95,1.05)`) — efficace sans être perceptible. ±2% inutile, ±20% incohérent. **[C]**
  LÖVE : `Source:setPitch(2^(semitones/12))` (1 demi-ton = ×1.0595). Combiner avec random volume ±10% + pool no-repeat.
- **Pitch montant pour escalade/combo** (signature Balatro) : +1 demi-ton/cran ; les 5 cartes jouent **C-D-E-F-G** ; nombres synchronisés au pitch. **[C]**
- **Layering** : transient + body + sub-bass, volumes légèrement randomisés. **[C]**
- Vocabulaire distinct (recettes synthé, lib `seslen`) :

| Son | Recette | Durée |
|---|---|---|
| hover | sine 2.4 kHz | 25 ms |
| click/tick | sine 4 kHz | 3 ms |
| pop | triangle 1200→320 Hz | 90 ms |
| swoosh (drag) | noise bandpass 400→4000 Hz | 240 ms |
| toggle | sine 700+1100 / inversé | 110 ms |
| coin | square 988+1320 Hz | 180 ms |
| success | arpège C-E-G-C | 360 ms |

Hover : throttle ~40ms, interrupt l'instance précédente. **Shake sans son = creux.**

## 8. DOPAMINE / ADDICTION
1. **Ratio variable** (Skinner) mais **décisions du joueur changent le résultat** (≠ casino). **[C]**
2. **Scaling exponentiel** (cible ×1.5–2/palier) ; échec = "j'ai mal calculé" → "encore une". **[C]**
3. **"Number go up" juicy** = le payoff EST fabriqué par le juice, pas par les maths. **[C]**
4. **Feedback loop par-seconde** : input → réponse immédiate ET lisible → satisfaction kinesthésique. **[C]**
5. **Near-miss / no-wasted-run** (chaque run frôle un palier, progresse toujours). **[C]**
6. Friction zéro entre runs, sessions courtes. **[C]**
7. **Étude Kao (n≈1699)** : juice **success-dependent** (proportionnel à la difficulté de l'action : kill > hit > swing)
   ↑ enjoyment via compétence ; la **curiosité** (variabilité/découverte) = plus fort prédicteur. **[S]**
   → **doser le juice selon l'enjeu** + récompenser la découverte (synergies révélées une par une).
- **[I] The Pit** : payoff qui escalade avec l'investissement — combat gagné sur combo de reliques → cascade
  séquentielle (chaque relique "bounce", total qui monte, pitch qui grimpe) = juicy ET pédagogique (enseigne les synergies en 300ms).

## CHEAT-SHEET (paramètres de départ codables)
| Interaction | Effet | Valeur | Courbe | Son |
|---|---|---|---|---|
| Hover | scale+lift+glow+juice_up | ×1.06, −12px, punch +0.06 ~150ms | ease-out | hover (sine 2.4k, throttle 40ms, ±5%) |
| Press | squash | 0.97, ≤80ms | ease-in | click grave |
| Release | punch | 1.0→1.03→1.0, 120–180ms | back | — |
| Drag follow | spring découplé | `vel=vel*0.75+(tgt-pos)*0.25` | ressort | pickup |
| Drag tilt | rot par vélocité X | `clamp(dx*0.85,±0.12rad)`, lerp 12·dt | — | — |
| Drop | snap amorti + push voisins | magnetic damping | — | drop |
| Screen shake | trauma²+Perlin | maxOff qq px, freq 20Hz, decay 0.6, pow 2 | — | apparié obligatoire |
| Hitstop | time_scale 0 | light 40 / heavy 80 / crit 120 ms | timer ignore-timescale | bass |
| Modal in | dim+scale | backdrop 0.6/blur6px 220ms; panel 0.95→1 300ms | back | swoosh |
| Modal out | scale+fade | 1→0.95, 200ms | ease-in | — |
| Tooltip | scale+fade ancré | 0.96→1, 130ms, no bounce, delay 350ms | ease-out | hover |
| build→combat | dissolve/burn + shake | ~300ms | — | transition |
| Number roll | digits staggered | 50ms/digit | back | pitch montant |
| Combo SFX | +1 demi-ton/cran | ×1.0595^n | — | C-D-E-F-G |

## Sources clés
Eiserloh GDC "Juicing Your Cameras With Math" (trauma shake) · "Juice it or lose it" Jonasson/Purho (`grapefrukt/juicy-breakout`) ·
"Art of Screenshake" Nijman/Vlambeer · Balatro : blakecrosley.com, cccChoice/Medium, Mix and Jam, Tom Delalande (`YntG_mSE0d4`),
Mostly Mad (`x5RVUs6Qhls`) · Hitstop : kindatechnical, MoreMountains Feel · SFX : gamejuice audio-variation, gamedeveloper "Power of Pitch Shifting", seslen ·
Modales/courbes : NN/g, agent-skills (dylantarre/mblode), kitlab · Dopamine : Kao/KIT, theconversation, ejaw, armchairarcade.
