# Implémentation d'UI de jeu — guide de référence (The Pit)

> **Objet.** La bible technique de l'implémentation UI : comment dimensionner, aligner, faire déborder,
> animer, sonoriser et styliser l'interface d'un jeu — **résolution-agnostique, lisible, qui a de l'impact**.
> Issu de 6 recherches sourcées (2026-06). À lire avant d'intégrer tout composant produit par le designer.
> Format de chaque règle : **Principe → Règle concrète (chiffrée) → Application LÖVE → Piège.**
>
> **Contexte The Pit.** Monde rendu en canvas virtuel **320×180** scalé **×4 entier → 1280×720**, letterboxé ;
> UI composée à la **résolution de référence 1280×720** (« px design ») et dessinée en **résolution native**
> (couche séparée, texte net). LÖVE 11.5, pixel-art 100% procédural, grimdark.
>
> Statut : guide **complet** — §1 Résolution · §2 Texte · §3 Layout/overflow · §4 Feel & impact (+ timing différé) ·
> §5 Son · §6 Shaders. Issu de 6 recherches sourcées indépendantes (voir les sources en fin de chaque section).

---

## 1. Résolution & scaling

**Architecture validée (la plus importante).** Deux **couches de rendu** distinctes — standard de l'industrie
pixel-art (Celeste, Hyper Light Drifter ; formalisé par Godot `canvas_items` stretch) :
- **MONDE** → canvas `320×180`, filtre `nearest`, blit à scale **ENTIER** (`floor(min(W/320, H/180))`) + letterbox.
- **UI / TEXTE** → dessinée **après**, en **résolution native** (espace 1280×720 via `push/translate/scale`),
  **fonts natives = texte net**. C'est exactement la décision actée dans CLAUDE.md ; la recherche la confirme.
- ⚠️ Ne **jamais** aplatir l'UI dans le surface monde puis tout scaler → le texte hérite du flou/gros pixels.

**Résolution de référence & unités virtuelles.** Concevoir pour 1280×720, **tout exprimer en unités de
référence**, jamais en pixels écran. `scale = min(W/REF_W, H/REF_H)` (mode *fit*) puis `push(); translate(offX,offY);
scale(scale)`. Pattern wiki exact `love.graphics.scale` : `translateX = (w - REF_W*scale)/2`.

**Modes de scaling — tableau de décision :**

| Mode | Calcul | Quand | Coût |
|---|---|---|---|
| **Fit** (letterbox) | `min(...)`, ratio gardé, barres noires | **Défaut** : compo intacte, neutralise ultrawide & 4:3 gratuitement | espace perdu |
| Fill (crop) | `max(...)`, déborde+rogné | fonds/ambiance plein écran | contenu coupé |
| Stretch | sx≠sy | **jamais** (déforme) | distorsion |
| **Integer** | `floor(min(...))` | **pixel-art** : pixels carrés égaux | vide (entier inférieur) |

**Pixel-art = scale ENTIER, point.** Un scale fractionnaire (ex. 1366/320 = 4,27×) fait des texels en blocs
4×4 **et** 5×5 → tailles inégales → **shimmer/crawling en mouvement**. Seul l'integer scale corrige (ou : upscale
à l'entier supérieur en point-sampling puis downscale **bilinéaire au composite final**). Snapper la caméra **ne
corrige PAS** le shimmer d'un ratio fractionnaire (autre problème).

**Aspect ratios & safe zones.** Marché : ~82% 16:9, ~10% 16:10, ~4% 21:9. Comme on est **fit+letterbox**, le
canvas UI reste toujours 16:9 → **pas de problème ultrawide**. Garder le critique en **safe zone ~90%**
(marge ~5%/bord ≈ 24–32px sur 1280×720, alignée 8px). **Ancrer** chaque élément à un point relatif (coin/bord/centre)
**+ inset en %**, jamais en position pixel absolue. Centre = réticule/prompts ; bords = santé/ressources/HUD.
**HUD stable** : ne jamais animer la *position de repos* d'un élément ; animer l'apparition/les valeurs.

**DPI / high-density.** Depuis LÖVE 11, `getWidth/getHeight`, la **souris** et `love.resize(w,h)` sont en
**unités DPI-scaled**, pas en pixels (sauf `usedpiscale=false`). `highdpi` = **no-op Windows/Linux** (Retina
macOS/iOS only) → ne pas compter dessus pour le scaling Windows 150% ; seul levier desktop = résolution de
référence + scale. `love.window.getDPIScale()` = 2.0 sur Retina ; `toPixels()/fromPixels()` pour convertir.

**LÖVE — API vérifiée (11.5) :** `setMode(w,h,{fullscreentype="desktop", vsync=1 (number!), msaa=0, highdpi,
usedpiscale, resizable, minwidth/minheight})` ; `updateMode` (ne reset pas les flags) ; **changer le mode efface
les canvases** ; `getDPIScale` ; `love.resize(w,h)` (unités DPI) ; `scale/translate/push/pop/origin` (ordre
**non commutatif** : translate **puis** scale) ; `newCanvas` + `setFilter("nearest","nearest")`. **Conversion
souris obligatoire** avec canvas virtuel : `mx = (getX()-translateX)/scale`. Référence d'implémentation à **ne pas
réinventer** : `Ulydev/push` (canvas+integer+DPI+letterbox+souris, ~250 l) ou `Oval-Tutu/shove`.

**RÈGLES D'OR.**
1. Concevoir à une **résolution de référence** (1280×720), tout en **unités virtuelles** — zéro pixel écran absolu.
2. **Deux couches** : monde 320×180 scalé entier + nearest ; UI/texte en **résolution native**.
3. **Scale entier** pour le pixel-art : `floor(min(W/320, H/180))`. Fractionnaire = shimmer.
4. **Fit + letterbox** par défaut (neutralise ultrawide/4:3).
5. **Ancrer** (coin/bord/centre) **+ inset %** ; jamais de position pixel littérale ; **HUD de repos immobile**.
6. **Safe zone ~90%** pour le critique.
7. **Souris : toujours convertir** vers l'espace cible (monde OU UI). Recalculer offsets/scale dans `love.resize`.
8. `vsync` = number, `msaa=0`, `nearest` partout. Vérifier chaque API sur love2d.org/wiki.

**Sources.** love2d wiki (setMode/getDPIScale/resize/scale) · github.com/Ulydev/push · Oval-Tutu/shove ·
tanalin.com/en/articles/integer-scaling · gamedev.SE 131445 (DMGregory) · Unity Canvas Scaler · Godot Multiple
Resolutions · ITU-R BT.1848 / EBU R95 (safe zones) · GDQuest pixel setup · asobi.gg/thescreen.

---

## 2. Texte & typographie

**px design ≠ px écran.** Une taille de police a 2 mesures : sa hauteur en espace de composition (720p) et sa
hauteur physique (moniteur). Convertir : `px_écran ≈ px_design × (hauteur_écran/720)` (×1.5 sur 1080p). Seuil
« PC à 2 pieds » ≈ **18px body à 1080p** (Xbox XAG) → un **body 14px design ≈ 21px @1080p = OK**. **Jamais
< ~12px design** pour de l'info importante. Le `size` de `newFont` n'est **pas** la hauteur visible des glyphes → **mesure** (`Font:getHeight`).

**Hiérarchie = échelle modulaire mappée à des rôles** (caption/body/title/display), pas 14 tailles arbitraires :
- **Choisir le body d'abord** (UI dense : **14–16px design**), dériver le reste avec un ratio **serré 1.2 ou 1.25**
  (golden 1.618 **réservé aux 2 plus grands paliers**). Échelle pratique : `10·13·16·20·25·31·39·49`.
- **Hiérarchiser par couleur/casse/poids AVANT la taille.** En pixel-art sans graisse variable, **couleur + casse**
  sont les leviers. **Max 3 familles** à l'écran (on en a 4 : pixel-label, pixel-prose, blackletter, serif →
  blackletter+serif **cantonnés aux titres/flavor**).

**Lisibilité (chiffres) :** contraste **≥ 4.5:1** (7:1 optimal, éviter blanc/noir purs) · line-height body
**1.3–1.5×**, titres **1.05–1.2×** · measure **50–75 car./ligne** (≤80) · bloc ≤ 1/3 largeur écran ·
letter-spacing ≥ 0.12× si réglable. **TOUT-CAPITALES = labels courts seulement** (détruit la silhouette des mots ;
Xbox XAG demande une option casse-phrase) → Silkscreen pour « COMBAT/VICTOIRE », **jamais** prose/tooltip en caps
(cohérent `feedback-legible-font-for-content`).

**Alignement :** **gauche** par défaut pour tout bloc de lecture ; **jamais centré ni justifié** pour un paragraphe ;
**nombres alignés à droite** sur une largeur calculée pour le **max attendu**. Centré OK pour titre court/label/chiffre isolé.

**Pixel vs vectoriel vs SDF.** Pixel fonts (Silkscreen, Pixel Operator) **nettes UNIQUEMENT à taille native ×
entier** + `setFilter("nearest")` + **positions entières** (`math.floor`) ; tout scale fractionnaire/sous-pixel =
flou. Pour plusieurs tailles → **charger plusieurs fonts/BMFonts** (pas scaler une texture). **SDF/MSDF** (non natif
LÖVE ; atlas msdfgen + shader, réf `Keyslam/love-sdf-text`) **si** un texte doit scaler **librement** net + porter
outline/glow « gratuits » → idéal **titres blackletter** ; sinon pré-rendre en bitmap 2–3 tailles. Ne pas dessiner
du SDF dans le canvas 320×180.

**Overflow — décider PAR CONTEXTE (le cœur du sujet) :**

| Stratégie | Quand | Éviter si |
|---|---|---|
| **Wrap multi-ligne** (défaut) | conteneur à **hauteur flexible** (descriptions, flavor, tooltips) | hauteur fixe critique |
| **Ellipsis (…)** | **label court, hauteur fixe** (nom d'unité en slot, titre de carte) **+ accès au texte complet** (survol) | info critique sans autre accès ; **jamais couper en plein mot** |
| **Shrink-to-fit borné** | doit tenir **1 ligne** dans boîte fixe ; binary-search taille, **plancher ~12px** | blocs de prose |
| **Scroll + fade de bord** | **gros volume** (journal, codex) ; affordance visible | labels courts ; fade **jamais** pour tronquer du texte (réservé scroll) |

Règle : hauteur flexible→wrap ; sinon label court→ellipsis+tooltip (front-load les mots-clés) ; 1 ligne
obligatoire→shrink borné ; volume→scroll+clip (`Draw.scissor`, cohérent `feedback-scrollable-containers`).

**Localisation / texte dynamique.** L'anglais est compact → **composer l'UI à 70% de l'espace, garder 30% de
marge** (allemand/finnois **+30–40%**, FR +15–25%, CJK = +hauteur de ligne, AR/HE = miroir RTL). **Ne jamais coder
une largeur en supposant la longueur du contenu.** Dimensionner chaque conteneur via `getWrap`/`getWidth` sur la
chaîne **résolue** `t(key)`. **Pseudo-localisation** (+30–50% + accents + crochets `[…]`) = outil n°1 pour révéler
débordements **et** concaténations. **Pas de `..`** : templates `t("relic.full", {name=…})`.

**LÖVE — API (11.5) :** `newFont(path,size)`/`newImageFont(image,glyphs)` **coûteux + non cachés → charger au
load**, table `Theme.fonts[role]` ; `Font:getWidth/getHeight` ; `Font:getWrap(text,limit) → width, lines[]`
(hauteur de bloc connue **avant** rendu) ; `print(s, floor(x), floor(y))` ; `printf(s,x,y,limit,align)` aligne
**dans [x, x+limit]** (pas autour de x) et calcule le wrap **avant** scale ; `setScissor` pour scroll. Pixel fonts :
**pas de hinting/AA**, nearest, tailles entières.

**RÈGLES D'OR.**
1. Composer l'UI **à 70% de l'espace** (30% de marge i18n) ; jamais de largeur supposant la longueur du texte.
2. **Body ≥ 14–16px design** (≥18 @1080p) ; jamais < 12px pour de l'info. Body d'abord, dérive le reste (ratio 1.2/1.25).
3. **Hiérarchie par couleur/casse AVANT taille** ; **3 familles max** ; blackletter/serif = titres/flavor courts.
4. **Tout-caps = labels courts seulement** ; **gauche** pour les blocs (jamais centré/justifié) ; **nombres à droite**.
5. Contraste **≥ 4.5:1** ; line-height body **1.4×** ; measure **50–75 car**.
6. **Pixel fonts = nearest + scale entier + positions entières** ; multi-tailles = plusieurs fonts, pas scaler une texture.
7. **SDF/MSDF** pour le texte qui scale librement + effets (titres) ; sinon bitmaps pré-rendus.
8. **Overflow par contexte** : wrap / ellipsis+accès / shrink borné / scroll+fade. Jamais couper en plein mot.
9. Charger tous les `Font` au **load** ; mesurer (`getWrap`) **avant** de dessiner ; `printf` aligne dans `[x,x+limit]`.
10. **Pseudo-localisation** (+30–50%) à chaque jalon ; pas de concaténation ; texte hors code via `t(key,vars)`.

**Sources.** love2d wiki (printf/Font:getWrap/FilterMode/newFont) · redblobgames.com/articles/sdf-fonts ·
github.com/Keyslam/love-sdf-text · Xbox Accessibility Guidelines 101 · indieklem.com (typographie) ·
alltools.dev (type scale/hierarchy) · wikimedia Codex (content-overflow) · subux.pro (truncation) ·
sandvox.io (text-expansion) · gridly.com (loc) · asobi.gg/considerations.

---

## 3. Layout, composition & overflow

**Ancrage (9 points).** Élément = `anchor` (0/0.5/1 en x,y) + `offset` (px design) + `pivot` (direction de
croissance). Position = `parent.origin + anchor*parent.size + offset - pivot*size`. HUD aux **coins** (or/vies
haut-gauche, COMBAT bas-droite), titres centrés haut — **jamais « tout centré »** (sort de l'écran en large).
On ancre dans l'espace design 1280×720 ; le letterbox gère le ratio. Helper à ajouter à `Layout` :
```lua
function Layout.anchored(parent, w, h, ax, ay, ox, oy, px, py)  -- px,py = pivot (défaut = anchor)
  px, py = px or ax, py or ay
  return { x = math.floor(parent.x + ax*parent.w + (ox or 0) - px*w + 0.5),
           y = math.floor(parent.y + ay*parent.h + (oy or 0) - py*h + 0.5), w = w, h = h }
end
```

**Alignement.** Axe principal `justify` = start/center/end/**between/around/evenly** ; axe croisé `align` =
start/center/end/**stretch** (+ baseline via `font:getAscent()` pour aligner des textes de tailles ≠). Défaut sain :
**`align="stretch"`** (supprime les trous). `justify` n'agit **que sans `flex`** → ne pas s'étonner qu'il soit inerte
avec un `{flex=1}`. (`Layout.flow` couvre déjà tout ça.)

**Quel système quand.** **Flex** (`row/column`) = 90% (barres, listes, header/footer). **Grid** = plateau 3×3,
boutique, galerie. **Absolu/ancré** = HUD, infobulles, badges, drag-fantôme. **Immediate-mode** (SUIT/ImGui) vs
**retained** : notre archi est l'**hybride idéal** — layout *calculé* (pur, testable headless) + dessin/interaction
*immédiats* (chaque frame). On garde. Grid manquant → à ajouter :
```lua
function Layout.grid(box, cols, rows, opts)  -- -> rects ligne par ligne (gap/pad), pixel-perfect
  -- cw=(inner.w-gx*(cols-1))/cols ; ch=(inner.h-gy*(rows-1))/rows ; floor chaque rect
end
```

**Espacement (grille 8pt).** Échelle design : **4, 8, 12, 16, 24, 32, 48, 64** (4 = sous-grille). `8` par défaut
entre composants ; label↔champ 4–8, item↔item 16–24, section↔section 32–48. **Toujours plus d'espace AUTOUR d'un
groupe qu'à l'intérieur** (règle anti-bordel n°1). Centraliser : `Theme.sp = {xs=4,sm=8,md=12,lg=16,xl=24,xxl=32,
huge=48}` ; **toute** valeur d'espacement vient d'un token, **jamais un littéral** dans une scène.

**Overflow (le cœur).**
- **Clip** : `setScissor` est en **pixels écran, hors transform stack** → reconvertir le rect design via
  `view.ox/oy/scale` (= notre `Draw.scissor`, correct). Imbrication (scroll-dans-panneau) → `intersectScissor` +
  pile sauver/restaurer (`Draw.pushScissor/popScissor`). Masque **non-rectangulaire** (coins arrondis) → stencil ;
  dans le canvas d'ambiance, exiger `setCanvas{canvas, stencil=true}` sinon **ignoré silencieusement**.
- **Scroll vertical** : `scroll`∈[0, `max(0,contentH-viewH)`] ; `itemY = listY + i*(rowH+gap) - scroll` ; **clip** ;
  **cull** (ne dessine que le visible) ; molette `scroll -= dy*pas_design` puis **clamp** ; thumb
  `h=max(28, viewH²/contentH)`. C'est **exactement** `grimoire.lua` → **factoriser en module `ScrollView`** réutilisable
  (build/boutique/codex). Inertie = nice-to-have (vel+friction), un clamp net suffit souvent. Manette/pages → préférer
  la **pagination** (index + flèches `‹ ›`) au scroll.
- **Affordance** : **fade de bord** (16–24px) affiché **conditionnellement** (haut si `scroll>0`, bas si
  `scroll<maxScroll`), **hors-scissor** et **non-interactif**. Réutiliser le profil d'alpha de `Draw.divider`.

**Responsive / taille inconnue.** `{flex=k}` = grow ; ajouter `max` (borne) ; **hug content** manquant =
`Layout.hug(font,s,padX,padY)` (taille = texte mesuré + padding ; `Chip.width` le fait déjà). **Le relative sizing
ne scale pas** → **panneaux en fixe+ancré** (largeur 320 design ancrée à droite), `flex`/% **uniquement** pour les
zones de remplissage (arène centrale). Layout en **2 passes** : tailles intrinsèques bottom-up (mesure) → placement
top-down (`Layout`), sinon cycle.

**Nine-slice.** Étirer un cadre sans déformer coins/bords = 9 `Quad` (créés **au load**, jamais par frame ; scale
**entier** en pixel-art). **MAIS notre `Frame.draw` procédural est supérieur** pour notre DA « forge » générée (zéro
asset, redimensionnable, palette Wraeclast) → **on garde `Frame.draw`** ; 9-patch réservé à un éventuel cadre texturé.

**Anti-« bordélique » (principes).** Hiérarchie (**3–4 niveaux max**, saut ≥1.25×, 1 rôle visuel = 1 niveau) +
proximité (espace) + cohérence + contraste + **moins de bordures** (espace + fond contrasté > traits ; `Frame`
remplace les traits) + **un seul focal** par section (COMBAT saturé, le reste muet) + **feedback** (jamais d'état
muet : hover/pressed/disabled via `Theme.btnState`/`Frame.button`). Test : **squint test** (plisser/flouter une
capture — si l'important disparaît, monter taille/contraste).

**4 ajouts à fort levier (notre code) :** (1) module **`ScrollView`** (factoriser le grimoire) + `pushScissor/popScissor` ;
(2) **`Layout.grid`** (plateau + boutique) ; (3) **`Layout.anchored` + `Layout.hug`** (HUD/infobulles/chips) ;
(4) échelle **`Theme.sp`** imposée partout.

**RÈGLES D'OR.**
1. **Une seule échelle d'espacement** (tokens `Theme.sp`), jamais de littéral ; plus d'espace autour d'un groupe que dedans.
2. **3–4 niveaux de hiérarchie max** (saut ≥1.25×, 1 rôle=1 niveau) ; squint test sur chaque écran ; **moins de bordures**.
3. **Ancrer aux 9 points** (HUD aux coins), pas tout-centré ; `align="stretch"` par défaut ; `justify` inerte avec un `flex`.
4. **Scissor = pixels écran hors transform** → reconvertir (`Draw.scissor`) ; imbriqué = `intersectScissor`+pile ; non-rect = stencil (+`stencil=true` en canvas).
5. **Scrollable = clip + offset + cull + clamp(chaque frame) + thumb** ; factoriser en `ScrollView` ; fade de bord conditionnel, hors-scissor, non-interactif.
6. **Souris en espace design avant tout hit-test** (surtout items scrollés) ; molette × pas en px **design**.
7. **Jamais `newQuad/newImage/newFont` dans draw/update** — bake au load (doctrine projet).
8. **Restaurer l'état graphique en sortant d'un bloc canvas** (scissor off + origin) — ne pas polluer le chemin scènes.
9. **Panneaux fixe+ancré, remplissage en flex/%** (le relative sizing ne scale pas) ; layout en 2 passes.
10. **Différer les overlays** (tooltip/dropdown/drag-fantôme) dans une passe de dessin **finale** (limite IMGUI du layering).

**Sources.** love2d wiki (setScissor/intersectScissor/setStencilTest/newQuad/wheelmoved) · Unity UI (anchors/auto-layout/
content-size-fitter) · MDN/W3C Flexbox · Refactoring UI · NN/g (proximité Gestalt) · 8pt grid (thehangline/mantlr) ·
SUIT (immediate-mode) · quad_slice/slicy (9-patch) · Compound (scrollbars/overflow).

## 4. Game feel, juice & feedback d'impact (+ timing d'action différée)

**Le juice EST le produit.** « Strip Balatro's animations and sounds and you have a calculator. » Le feedback n'est
pas du polish de fin — c'est ce qui rend une mécanique vivante. Définition (Jonasson/Purho) : **« maximum output for
minimum input ».** Et c'est une **couche RENDER pure** : elle vit dans `src/render`/`src/fx`/`src/scenes`, pilotée par
`dt` mural, écoute le bus, **ne touche jamais la SIM** (`combat`/`run`/`effects`/`board`) → déterminisme & golden intacts.

**Décompo Balatro (le modèle).** Une interaction empile **plusieurs canaux indépendants, SYNCHRONES** (anim de carte +
rebond séquentiel des jokers ~300ms qui *montre la causalité* + screen-shake dont l'intensité **encode la magnitude** +
particules + audio à pitch montant). Chiffres réels : hover `scale→1.05` (lerp 0.25/frame), **micro-respiration
permanente au repos** (`rot += sin(t)*0.0018`, `pos += sin(t)*0.44px` — la carte n'est JAMAIS statique = signature
« vivant »), tilt vers le curseur qui revient en ~0.1s. **Escalade** : le feedback grossit avec l'enjeu. → Pour The Pit,
la **résolution de combat** (DoT qui détonnent, synergies qui procent) est l'analogue du scoring : piloter le juice sur
l'event-log (attribution source/cause déjà présente).

**Hover — différence IMMÉDIATE.** Scale **1.03–1.05** + **lift 2–4px + ombre + glow** (en grimdark : liseré braise/rune,
pas glow blanc) + tilt optionnel ; **80–150ms ease-out** ; **son tick**. *L'arrivée du hover = la transition la plus
rapide du jeu* (pas de tween-in lent). Scale autour du **centre** (sinon dérive). ⚠️ Pixel-art : un scale 1.04× casse la
grille → préférer **lift/ombre/glow/tilt** comme signal, réserver le scale aux sprites hors-grille ou à un canvas séparé.

**Press — l'IMPACT.** **Squash 95% au pointer-DOWN** (pas au release : attendre le up « feels 30ms slower ») + flash bref
(1 frame). **Release = rebond 95%→~102% (overshoot) en `backout`** : un retour linéaire « feels dead ». Overshoot scale
max 5–10%.

### ⭐ 4.1 TIMING D'ACTION DIFFÉRÉE (le point crucial)
**Ne pas exécuter l'action au clic : jouer le feedback PUIS exécuter l'action ~0.1–0.25s après**, pour que l'utilisateur
*ressente* son clic avant que l'écran change. Validé par la recherche perceptuelle (contre-intuitif) :
- **Sagawa** : un délai clic→réponse **≤ 50ms se sent « too fast to be a consequence of the action »** ; l'**optimum
  confortable = 100–200ms** ; « a moderate delay may *increase* the user's sense of control ». **Plus rapide ≠ mieux.**
- **Kaaresoja (ACM)** : « perçu simultané au doigt » → **visuel 30–85ms, audio 20–70ms** ; qualité chute entre 100–150ms,
  mauvaise > 300ms. → le **feedback de press** (squash/flash/son) doit tomber en **30–85ms** ; c'est l'**action** qu'on diffère.
- **NN/g** : 0.1s = limite de la « manipulation directe ». **Doherty** : < 400ms = « addicting » ; « adding a delay can
  *increase* perceived value and trust ».

**Budget temporel d'un clic juteux :**

| t | étape | quoi |
|---|---|---|
| **0ms** | pointer-DOWN | squash 95% + flash + **son de press** (feedback IMMÉDIAT, fenêtre 30–85ms) |
| ~0–80ms | release | rebond/overshoot du bouton |
| **~100–250ms** | **différé** | **l'ACTION s'exécute** (transition, achat, lancement combat) |

→ réactivité *perçue* = 100% (feedback < 85ms), seule la *conséquence* est différée.

**Durées par type :** bouton/toggle mineur → action **~100ms** (>150ms « traîne ») · action lourde + transition (COMBAT,
achat, valider relique) → transition **200–350ms** qui *est* le délai (grimdark autorise le bord haut) · moment
dramatique (relique révélée, ascension/chute) → pause+slow+silence assumés **0.5–3s** · **garde-fou : jamais > ~400ms**
clic→conséquence hors moment dramatique.

**Anti « dead-click » (piège n°1) :** différer l'*action* = OK ; différer le *feedback* = INTERDIT (sinon clic dans le
vide → reclic/rage). **Le feedback part à t=0, seule l'action est différée.** **Input buffering** : pendant la fenêtre
press→fire, **bufferiser** le clic suivant (joueurs rapides) au lieu de l'ignorer ; **verrou** : le bouton ignore un
re-clic sur lui-même (anti double-achat) mais bufferise ailleurs.

### 4.2 Easing & animation
**ease-out par défaut** (départ rapide = réactif) ; **asymétrie entrée (ease-out) / sortie (ease-in)** ; linéaire =
mécanique (réservé aux barres de progression). **Ratio 60/30/10** (workhorse / secondaire / dramatique). **Toute UI ≤
600ms** (au-delà = laggy) ; durée ∝ distance/poids.

| Interaction | Courbe (flux) | Durée |
|---|---|---|
| Hover / focus | `quadout` | 100–150ms |
| Press-in / -out | `quadin` / `backout` | 70–120 / 120–180ms |
| Apparition / disparition | `cubicout` / `cubicin` | 200–250 / 150–200ms |
| Modale / drawer | out (open) / in (close) | 300–500ms |
| Barre XP / remplissage | ease-out sweep | 400–600ms |
| Transition de scène | ease-in-out | 400–600ms |

**12 principes Disney → UI** : squash&stretch (press), anticipation (micro wind-up avant grosse action), slow-in/out
(=easing), follow-through/overlapping (rebond + couches secondaires en retard), secondary action (ombre/glow/poussière),
timing (espacement = poids). **Hold/« sleep » (Vlambeer)** : geler quelques frames sur l'impact pour laisser le cerveau
traiter (→ hit-pause, §4.4).

### 4.3 Structure LÖVE
**Libs** : **flux** (rxi, 1 fichier, MIT) — `flux.to(obj, t, {vars}):ease("backout"):delay():after():oncomplete(fn)` ;
**hump.timer** — `Timer.after(s, fn)` pour différer l'action. Cohérent « dépendances minimales » (flux = 1 fichier, ou
tout maison ~40 lignes + un ressort amorti `v += (target-x)*k*dt; v *= damping; x += v*dt`). **Machine à états du bouton
idle→hover→press→fire** : au release, `flux` rebond + `Timer.after(0.12, onClick)` puis retour idle/hover. **Combat** :
`arena_draw.lua` écoute le **bus** (dégât/mort/détonation/proc) → déclenche tweens/particules/shake côté RENDER. **Jamais**
de tween/timer dans la SIM ; hit-pause = timer d'anim, **jamais** un blocage de boucle ni un freeze de la SIM seedée.

### 4.4 Impact du monde : shake / hit-pause / particules (parcimonie + accessibilité)
- **Hit-pause 20–120ms** sur chaque impact fort (Hades 80–120ms, son sur le **même frame**) = l'outil le plus rentable
  pour le « poids ». En LÖVE : timer de pause d'anim (décrémente par `dt`), pas un `sleep`.
- **Screen shake** = **trauma 0–1 décroissant, déplacement = trauma² × bruit Perlin** (pas un offset random = jitter) ;
  **1–2px en pixel-art**, spike + decay ~0.2s, **POSITIONNEL (pas de rotation** = mal des transports). Encode la magnitude.
- **Synchronie des 3 canaux** : visuel + audio + shake/pause au **MÊME frame** ; dérive **> 50ms = l'impact s'effondre**.
  (Nuance vs §4.1 : impact du *monde* = synchrone ; conséquence d'une *intention* utilisateur = différée.)
- **Barre-fantôme** (très grimdark) : la barre saute instantanément à la valeur (fait), une barre-fantôme claire tient
  l'ancienne ~400ms puis tween → on *voit* la perte (Dark Souls). Parfait pour la vie-par-entité.
- **Accessibilité (exigence, pas option)** : **slider d'intensité shake/flash** (scale tout shake actif) + photosensibilité
  (< 3 flashs/s, < 20% écran, désaturé — colle au grimdark). Option « Reduced Effect Intensity ».

### 4.5 Ton GRIMDARK
**« Dread is destroyed by spectacle » :** pas de feu d'artifice cathartique → **lourd, lent, contenu, organique**. Durées
vers le **haut** des fourchettes (press-out 180ms, transitions 300–350ms) ; shake court/sec/restreint ; **désaturé**
(braise/sang/os/bile, pas flash blanc) ; squash **dur + amorti** (pas bounce élastique mignon) ; micro-respiration **lente
et irrégulière** (chair qui palpite, pas carte qui jiggle) ; **silences** (retirer du feedback = tension). Moments forts :
couper le son → note grave tenue → ralenti → silence 1–3s. **Importer Balatro tel quel (glow blanc, élastique, confettis)
TUERAIT l'ambiance.** **Cohérence > brillance locale** : si un bouton squash, *tous* squashent.

**RÈGLES D'OR.**
1. **Feedback de press IMMÉDIAT (30–85ms), action DIFFÉRÉE (~100–250ms).** Sentir le clic avant que l'écran change.
2. **Un délai modéré augmente le contrôle perçu** (optimum 100–200ms ; ≤50ms = « pas causé par moi »). Plus rapide ≠ mieux.
3. **Jamais de dead-click** : différer l'action OK, le feedback jamais ; rester < 400ms clic→conséquence (hors moment dramatique). **Input-buffer** les joueurs rapides.
4. **Hover immédiat** (1.03–1.05 + lift/glow, 80–150ms ease-out, son tick) ; **press = squash 95% au DOWN + release overshoot `backout`** (retour linéaire = mort).
5. **ease-out par défaut, asymétrie in/out, ratio 60/30/10, ≤ 600ms** ; durée ∝ distance.
6. **Empile les canaux (Balatro) SYNCHRONISÉS pour les impacts du monde** (dérive > 50ms = impact effondré).
7. **Hit-pause 20–120ms** (timer d'anim, jamais freeze de SIM) ; **shake trauma²+bruit, 1–2px, positionnel, court** ; barre-fantôme pour la perte de vie.
8. **Slider intensité + photosensibilité** obligatoires.
9. **Grimdark = lourd/lent/contenu/organique/silencieux** ; ne pas importer le juice « mignon » de Balatro. **Cohérence > brillance locale.**
10. **Juice = RENDER pur** (`src/render`/`fx`/`scenes`, `dt` mural, bus) — jamais dans la SIM. **Toujours respirer** (micro-flottement permanent, version organique pour l'horreur).

**Sources.** blakecrosley.com/Balatro · « Juice it or lose it » (Jonasson/Purho) · Game Feel (Swink) · **Sagawa**
(journals.sagepub 10.2466/pms.99.3.924-930) · **Kaaresoja** (ACM 10.1145/2611387) · NN/g (response-times) · Doherty
(lawsofux) · web.dev/Material/baraa.app (easing) · gamejuice.co.uk (ui-feedback/screen-shake/juice-intention-matrix) ·
Art of Screenshake (Vlambeer) · strayspark + Xbox XAG-117/118 (accessibilité) · rxi/flux · hump.timer.

## 5. Feedback sonore (sound design d'UI grimdark)

**Un son = une fonction.** Mapper les **rôles** AVANT de designer (jamais 10 clics qui disent la même chose, jamais
réutiliser « confirm » pour « error »). Argument-massue : coupe le son de n'importe quel jeu → chaque press devient
une touche morte. **« Une UI qui *sonne* réactive *est perçue* réactive »** — le polish le plus rentable, le moins
d'ingénierie.

| Action | Caractère | Pool |
|---|---|---|
| **Hover** | tick très court (50–100ms), doux, bas volume | 3–4 |
| **Click/select** | transient net, court ; porte l'identité de marque | 3–4 |
| **Confirm/avant** | légèrement **ascendant** (on descend dans la pile) | 1–2 |
| **Back/cancel** | légèrement **descendant**, distinct du confirm | 1–2 |
| **Error/refus** | **différent en *caractère*** (muet, dissonant, downward) — jamais le confirm | 1–2 |
| **Achat/or** | sur la **réponse système** (après confirmation), pas au press | 1–2 |
| **Level-up/déblocage** | brève **phrase musicale** (pas un ton), l'asset le plus émotionnel | 1 |
| **Pickup/place (drag)** | « pick up » au grab, « set down » définitif au drop | 2–3 |
| **Transition de scène** | swoosh qui **se termine AVANT** que le nouvel écran apparaisse | 1 |

**⭐ Timing (valide ton point précis, données perceptuelles).**
- **Déclencher au PRESS (pointer-down), pas au release** — même frame que l'animation de press. (Sinon on ajoute le
  temps de course du clic = mou.)
- **Latence clic→son < ~70ms (idéal < 20ms)** ; la qualité chute fort entre 70–100ms. À 60fps, 1 frame = 16,7ms → « le
  jouer la frame du press » est confortablement dans la fenêtre.
- **Action différée = correcte ET sûre, dans CET ordre** : `t=0` son de *press* immédiat (« commande enregistrée ») →
  `t≈100–500ms` son d'*outcome* (ka-ching/thud/groan) **sur la résolution visuelle**. Études : un délai est toléré
  **si le 1er cue vient en premier et l'audio suit** (≤109ms = perçu synchrone, jusqu'à ~451ms acceptable). **L'inverse
  — audio AVANT le visuel — est rejeté.** Donc si tu diffères l'action, diffère/sépare le son pour matcher le visuel.

**Anti-fatigue (hover/click tirent en continu).** **Jamais 2× le même sample au même pitch.** (1) **pitch ±5–10%**
par jeu (sous ±2% = inutile, au-dessus de ±20% = remarqué) ; (2) **pool de variations** (3–4 hover/click, 1–2 rares) —
**pas** en pitch-shiftant 1 fichier (motif détectable) ; (3) **exclure le dernier index joué**. Recette de **famille
cohérente** = 3 couches : **transient (timing) + pitched (identité) + texture (foley)** ; rethème en ne changeant que la
couche pitched.

**Ton grimdark = matière organique, close-mic, dure (pierre/os/chair/métal/chaîne) pitchée DOWN + reverb de caverne
(convolution) + un sub-pulse de dread.** Modèles : **Darkest Dungeon** (UI = *objet physique du monde* : parchemin,
enclume — *le* modèle le plus copiable) ; **Dark Souls** (sparse beats busy : build/shop silencieux et spacieux,
réserver le musical/fort au combat et aux gros moments pour qu'ils ressortent) ; **Bloodborne** (intime, froid, dur,
low-rumble). Techniques horreur : pitch down 1–2 octaves ; deux tons à 1 demi-ton (battement dissonant) pour l'error ;
reverse-reverb pour les reveals/whispers ; sub-pulse sous le transient.

**Mixage & accessibilité.** UI **sous** le combat ; **cut par contraste (court+brillant), pas par volume** (carve
2–4 kHz). Bus UI « no-panic » (en LÖVE : un multiplicateur `master * uiVolume` appliqué à chaque play + limiter
émulé) ; **ducking** de l'ambiance sous un stinger important (lerp ~0,1–0,3s). **Sliders séparés (master/musique/SFX/
UI) + mute** (certains détestent le son d'UI). Silence en **arcs** : des phases calmes font cogner les impacts.

**LÖVE 11.5 (vérifié wiki).** `newSource(path,"static")` pour les **SFX** (RAM, latence nulle) / `"stream"` pour
**musique** ; **charger une fois au load** (jamais `newSource` par clic). **Chevauchement** : une Source = 1 playhead
→ re-`play()` ne fait rien ; pour superposer, **`Source:clone()` + un pool borné** (idiome `kikito/multisource.lua`).
**Cap LÖVE = 64 sources**, `:play()` renvoie `false` quand saturé → borner le pool (4–8/son). `setPitch/setVolume`
par play. **WAV pour SFX, OGG pour musique.** **RNG NON-seedé** pour le jitter pitch/volume (firewall SIM intact :
l'audio ne doit jamais toucher le RNG seedé du combat / golden-logs).

**SFX libres pour démarrer :** **Kenney Interface Sounds** (CC0, le plus propre) · **Sonniss GDC bundle**
(royalty-free, pas d'IA) · **ObsydianX** (CC0, à *assombrir*) · **Freesound** (filtrer CC0, pour les textures
organiques brutes) · **Stormwave Organic Fleshy** (payant, body-horror prêt). Workflow : Kenney pour la *structure*
→ rethémer vers Le Puits (pitch down + reverb cave + sub) → remplacer les 4–5 sons à plus forte valeur par du foley
organique custom.

**Palette de départ « Le Puits »** (chaque son = un objet physique dans un puits de pierre humide ; colle de famille =
transient pierre/grit + tail de caverne + sub-pulse sur les actions majeures) :

| Action | Matière / texture |
|---|---|
| Hover | tick de pierre/grit ou bone-tick, bas volume |
| Click/select | petite pierre qui s'emboîte + arête métallique rouillée |
| Confirm/avant | click pierre + résonance basse montante |
| Back/cancel | raclement de pierre descendant / chaîne qui se pose |
| Error | groan dissonant (2 demi-tons), muet, downward |
| Achat unité | pièces/fer sur pierre humide (PAS un ka-ching brillant), sur la réponse système |
| Vente / drag hors-plateau | drag humide + cliquetis de chaîne, descendant |
| Pickup / place | skin-stretch au grab / thud organique + sub au drop |
| Fusion → level-up | bone-crunch + swell résonant + sub, sous-couche musicale brève |
| Déblocage de slot | pierre qui grince en s'ouvrant + résonance qui résout |
| Swap de sigil | whoosh reverse-reverb + drone détuné (« non-euclidien ») |
| Relique offerte/acquise | whisper bed + drone + chime détuné, tail inversé |
| Transition build→combat | rumble de caverne qui résout **avant** l'apparition du combat |
| Victoire / Défaite | swell/gong résonant grave + relief / tolling + sub descendant, fade lent |

**RÈGLES D'OR.**
1. **Un son = une fonction** (mapper les rôles d'abord) ; error ≠ confirm (différent en *caractère*).
2. **Déclencher au PRESS**, même frame que le visuel ; **latence < 70ms** (idéal < 20ms).
3. **Action différée, ordre obligatoire** : son de *press* immédiat → son d'*outcome* sur la résolution visuelle (~0,1–0,5s). **Jamais l'audio avant son visuel.**
4. **Jamais 2× le même sample/pitch** : pitch **±5–10%** + **pool** (3–4 / 1–2) + exclure le dernier joué.
5. **Famille à 3 couches** (transient/pitched/texture) ; rethème en changeant la couche pitched.
6. **Grimdark = matière organique pitchée down + reverb cave + sub-pulse** ; modèle Darkest Dungeon (UI = objet réel).
7. **Sparse beats busy** : build/shop calmes, fort/musical réservé au combat et aux gros moments.
8. **UI sous le combat, cut par contraste** ; ducking ; **sliders séparés + mute**.
9. **LÖVE** : `static`/`stream` ; **load once** ; overlap via **`clone()` + pool borné** ; cap 64 (`:play()`→false) ; WAV/OGG.
10. **RNG non-seedé pour le jitter audio** (firewall SIM / golden intacts).

**Sources.** gamejuice.co.uk (ui-audio / audio-variation) · uxdesign.cc (button interactions) · ACM TAP 10.1145/2611387
+ Kaaresoja thesis + HAL hal-04169371 (seuils de latence) · gamedeveloper.com (Dark Souls) · Darkest Dungeon
(PowerUp Audio) · asoundeffect.com (horror techniques) · love2d wiki (newSource/Source/Source:clone) ·
kikito/ld-30 multisource · Kenney/Sonniss/Freesound (SFX libres).

## 6. Shaders & post-processing (surcouche cauchemardesque)

**Idée directrice (notre cas).** Le designer livre une UI **nette** (web/Figma) ; on l'implémente au pixel-perfect,
**puis** on ajoute une surcouche grimdark par shader. Règle d'or : **l'agressif vit sur le fond, les bords et les
pics d'événement — jamais sur le texte/les chiffres importants** (confiné par masque). Notre `main.lua` (canvas
320×180 → blit ×4 entier) est déjà la bonne fondation : le post-fx s'insère soit (a) sur le canvas 320×180 *avant*
le blit (effets « pixel/monde » : dither, palette-lock, pixelize, distorsion de fond — les motifs tombent sur la
grille), soit (b) sur un **canvas plein écran natif** *après* le blit (effets « qualité » : bloom des gravures,
vignette, grain fin, aberration douce — restent nets).

**Pipeline (3 primitives).** `newCanvas` / `setCanvas(c)`…`setCanvas()` / `newShader`+`setShader`. Multi-pass =
**ping-pong** entre 2 canvas (le blur séparable H puis V est le pattern de base de bloom/blur). Syntaxe GLSL **LÖVE**
(≠ générique) : fonction obligatoire `effect(vec4 color, Image tex, vec2 uv, vec2 screen)` ; **`Texel(tex,uv)`** (pas
`texture2D`) ; **`extern`** = `uniform` ; `number`=`float` ; `love_ScreenSize` fourni ; `Shader:send(name,val)` par
frame pour les uniforms animés ; `#pragma language glsl3` (après check `getSupported()`) pour les boucles dynamiques.
**Crée shaders/canvas UNE fois (love.load), jamais par frame.** Réf : **`vrld/moonshine`** (lib de post-fx LÖVE,
domaine public) — à **lire comme cookbook** et porter les 4-5 shaders utiles dans un `src/render/postfx.lua` alimenté
par nos propres canvas (ne pas empiler sa gestion de canvas sur notre blit).

**Catalogue (effet → usage → coût) :**

| Effet | Usage grimdark | Coût | Note |
|---|---|---|---|
| **Vignette** animée | assombrir coins, oppression ; `radius` qui **respire**/se resserre à la tension | 1 passe, ~gratuit | se greffe sur tout |
| **Grain** film mouvant | casse le « trop propre », salit | 1 passe + texture | **réso native**, opacity **0.05–0.15** |
| **Bloom/glow** (canal emissive) | ★ gravures qui **rayonnent/pulsent** au survol (l'impact !) | 3–5 passes | seuil global = bouillie → peindre l'émissif dans un canvas dédié, bloomer **lui seul**, sur canvas réduit ¼ |
| **Palette-lock / posterize** | ★ **unifie l'UI Figma nette avec tout le jeu** (« même artiste »), force la palette Wraeclast | boucle ≤16-32 (ou LUT 1D) | **réso virtuelle** ; commence par `posterize`, passe au palette-lock |
| **Dither Bayer 4×4** | « gravure sale » 1-bit (cohérent pixel-art) | 1 passe | **réso virtuelle** (`floor(uv*screen)`) sinon moiré ×4 ; combine avec palette-lock |
| **Pixelize** forcé | « forcer le pixelage » d'un élément net (cas Dead Cells), transitions | 1 passe (1 sample) | anime `size` 1→16 = dissolution |
| **Aberration chroma.** radiale | malaise, « réalité qui se fissure » | +2 samples | **réservée aux pics** (prendre un coup), masquée sur le texte |
| **Distorsion sin** | air vicié, « le Puits respire » | 1 passe | **fond/décor uniquement** (`background.lua`), jamais l'UI |
| **Scanlines** douces | rétro discret | faible | **pas** le CRT barrel complet (déforme le texte) |

**Cauchemardiser sans tuer la lisibilité (3 techniques de confinement) :**
1. **Flou sélectif par masque** : rendre un masque gris (blanc=flou bords, noir=net centre) → `mix(sharp, blurred, mask)`.
2. **Glow qui PULSE sur les gravures** = l'impact : bloom sur canal emissive + intensité **animée** :
   `pulse = 0.6 + 0.4*sin(t*6)` ; `*1.8` au survol ; `+flash` décroissant au clic. Le bouton ne « s'allume » pas plat — il **bave de la lumière**.
3. **Grain + respiration + vignette** pilotés par **un seul `time`** (+ un `tension` 0..1 dérivé des PV/vies de
   `run/state.lua`) : grain 8%, `vignette.radius = mix(0.85, 0.6, tension)` (l'écran « se ferme » quand ça tourne mal).
   Branché sur l'horloge à pas fixe, **100% côté RENDER** (firewall SIM intact).

**Impact d'un clic (le juice écran).** Envoyer `center` (position du clic en UV) + `wave_t` (1→0 décrémenté en Lua sur
~0.4s) → onde de choc qui s'étend : anneau `smoothstep(abs(dist-radius))`, offset UV `normalize(d)*strength`, léger
flash `c.rgb += strength`. Combiner flash + onde + pulse de glow + micro-distorsion. **Bref et net** (~0.4s). C'est le
pendant *écran* du feedback d'affliction déjà présent en combat.

**Dead Cells (3D→pixel) — transférable.** Le vrai secret = **render net → downscale SANS anti-aliasing → snap pixel**
(`Image:setFilter("nearest")` + scale entier ; jamais de downscale linéaire en 2 temps = bouillie). On n'a **pas
besoin de 3D** — juste cette discipline (qu'on a déjà au global). **Amélioration future** : baker des **normal maps**
procédurales des panneaux/gravures + lumière spéculaire qui balaye au survol → le rendu « métal/pierre ARPG forge ».

**Perf.** Coût ≈ passes × surface × samples. Leviers : 2-3 effets perma max, blur/bloom en **basse réso** puis agrandir,
dérouler les boucles (GLSL 1.20) ou glsl3 après check. `clear()` chaque canvas ; bloom = `setBlendMode("add",
"premultiplied")`. `nearest` sur tout canvas pixel ; `linear` seulement pour blur/bloom.

**RÈGLES D'OR.**
1. **Rends dans un Canvas, applique le shader dessus** (`newCanvas`/`setCanvas`/`setShader`) ; crée-les **une fois**.
2. **Chaque effet a une résolution** : pixel/monde (dither, palette, distorsion) → canvas 320×180 ; UI/qualité (bloom, vignette, grain) → canvas natif après blit. Mélanger = moiré ou bouillie.
3. **Syntaxe LÖVE** : `Texel` (pas `texture2D`), `extern` (=uniform), fonction `effect`.
4. **L'agressif sur fond/bords/pics ; le texte reste net** (confiner par masque).
5. **Subtil en permanence (grain 8%, vignette qui respire), fort sur l'événement (flash/onde/pulse ~0.4s).** Le contraste fait l'impact.
6. **Bloom = canal emissive dédié**, pas un seuil global (UI sombre).
7. **« Forcer le pixelage » = nearest + scale entier**, jamais downscale linéaire en 2 temps (Dead Cells + notre `main.lua`).
8. **Un seul `time` (+ `tension`) pilote tout**, côté RENDER (firewall SIM intact).
9. **Palette-lock/posterize sur la palette Wraeclast** = le shader « même artiste » qui unifie l'UI nette importée.
10. **moonshine en cookbook**, pas en dépendance bloc.

**Priorité d'implémentation (impact/effort) :** Vague 1 (ambiance ~gratuite) : **vignette animée** · **grain** ·
**posterize→palette-lock**. Vague 2 (l'impact) : **bloom emissive (gravures qui pulsent)** · **onde de choc + flash au
clic**. Vague 3 (finition) : flou sélectif par masque · aberration radiale modulée · dither Bayer + palette. **À
éviter/différer** : CRT barrel complet, distorsion sin globale (→ fond only), pipeline 3D Dead Cells complet.

**Sources.** love2d wiki (Shader/newShader/Shader:send/newCanvas/setCanvas/Beginner's Guide to Shaders) ·
github.com/vrld/moonshine (glow/vignette/filmgrain/pixelate/posterize/fastgaussianblur) · gameidea.org (shockwave) ·
libretro/glsl-shaders + hughsk/glsl-dither + landonferguson (Bayer horror) · Game Developer / 80.lv (Dead Cells 3D→pixel).
