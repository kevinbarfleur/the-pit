# Document 01 — Fondations du moteur : déterminisme, grille, primitives, génération

> Suite de documentation-recette pour reproduire le générateur procédural de pixel art
> (bestiaire + attaques + biomes + transitions). Ce document couvre le **socle commun** :
> comment dessiner de façon déterministe en assemblant des primitives paramétriques.
>
> **Documents de la suite**
> - **01 — Fondations** (ce document) : déterminisme, grille, primitives, ombrage, ancres, discipline de génération.
> - 02 — Le champ de déplacement : animation idle (breathe / sway / flap / tentacles / writhe / legs / bob + yeux).
> - 03 — Le système d'attaque : enveloppe anticipation→frappe→récupération, les ~16 *kinds*, la couche d'effets, et les correctifs (déformation lissée, squash-and-stretch, overlapping action).
> - 04 — Biomes : décors en couches tileables, dithering ordonné, bruit, parallaxe.
> - 05 — Transitions : effets de changement de scène pilotés par une progression, fronts plumeux.
> - Annexe R — Dossier de recherche (état de l'art, références citables).

---

## 0. Principe directeur

Tout le système repose sur **une seule idée** : on ne dessine jamais « à la main » un sprite,
on **assemble des primitives géométriques paramétriques** (ellipses, tubes coniques, polygones,
tentacules…) sur une petite grille, à partir d'un **générateur pseudo-aléatoire seedé**. Le même
seed redonne toujours exactement le même résultat. L'animation n'est pas un jeu d'images dessinées :
c'est un **champ de déplacement par pixel** appliqué à la grille statique (Document 02).

Quatre piliers :

1. **Déterminisme** — un PRNG seedé (`mulberry32`) ; même seed ⇒ même créature.
2. **Assemblage de primitives** — une bibliothèque de fonctions de dessin réutilisables.
3. **Ancres sémantiques** — chaque archétype renvoie des points nommés (tête, colonne, membres…)
   que l'animation et l'attaque exploitent.
4. **Cohérence avant détail** — silhouette forte et lisible d'abord, détail ensuite.

Cible : grille **64×64** pour les créatures (rendu au scale 4 → 256×256), **192×108** pour les biomes.

---

## 1. Déterminisme

### 1.1 Le PRNG : mulberry32

Générateur 32 bits, minuscule et rapide, période 2³². Renvoie une **fonction** qui produit des flottants dans [0, 1) :

```js
function mulberry32(a){
  return function(){
    a |= 0; a = a + 0x6D2B79F5 | 0;
    var t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

var rnd = mulberry32(0xC0FFEE);
rnd(); // 0.2734…  — toujours la même suite pour ce seed
```

### 1.2 Décorréler les seeds (correctif issu de la recherche)

**Piège** : des seeds entiers proches (1, 2, 3…) produisent des suites corrélées — les créatures
voisines se ressemblent. **Toujours faire passer le seed par un hash** avant `mulberry32`.
Hash d'avalanche `xmur3` :

```js
function xmur3(str){
  for(var i=0,h=1779033703^str.length;i<str.length;i++){
    h=Math.imul(h^str.charCodeAt(i),3432918353);
    h=h<<13|h>>>19;
  }
  return function(){
    h=Math.imul(h^h>>>16,2246822507);
    h=Math.imul(h^h>>>13,3266489909);
    return (h^=h>>>16)>>>0;
  };
}

// Seed décorrélé + un générateur INDÉPENDANT par sous-système :
var seedFn = xmur3("creature#" + index);
var rndShape   = mulberry32(seedFn());  // silhouette
var rndPalette = mulberry32(seedFn());  // couleurs
var rndAnim    = mulberry32(seedFn());  // variations d'animation
```

Consommer de l'aléa dans un sous-système ne décale alors plus les autres. Pour la galerie, le stride
« nombre d'or » `master + i*0x9E3779B9 >>> 0` est déjà une décorrélation correcte ; le hash est la
version robuste.

> Référence : `mulberry32` skip ~1/3 des sorties 32 bits (test PractRand) — sans incidence pour du
> contenu visuel ; passer à `splitmix32` si on réutilise le PRNG pour de la simulation à grande échelle.

---

## 2. La grille et le rendu pixelisé

Une « grille » est un buffer 1D de couleurs (hex ou `null`), plus une liste d'yeux (pour l'animation des pupilles).

```js
function makeGrid(w,h){ return { w:w, h:h, data:new Array(w*h).fill(null), eyes:[] }; }

function set(g,x,y,c){
  x=x|0; y=y|0;
  if(x<0||y<0||x>=g.w||y>=g.h) return;   // clipping
  g.data[y*g.w+x] = c;
}
```

**Rendu** : `image-rendering: pixelated` côté CSS, et côté canvas on désactive le lissage et on
dessine chaque pixel comme un rectangle `scale×scale` :

```js
ctx.imageSmoothingEnabled = false;
for(var y=0;y<g.h;y++) for(var x=0;x<g.w;x++){
  var col = g.data[y*g.w+x];
  if(!col) continue;
  ctx.fillStyle = col;
  ctx.fillRect(x*scale, y*scale, scale, scale);
}
```

---

## 3. La bibliothèque de primitives

Chaque primitive écrit dans la grille via `set`. Elles sont la « boîte de Lego » de toutes les créatures.

### 3.1 Signatures (extrait du catalogue)

| Primitive | Signature | Rôle |
|---|---|---|
| `ellipse` | `(g,cx,cy,rx,ry,c)` | ellipse pleine |
| `disc` | `(g,cx,cy,r,c)` | disque plein |
| `line` | `(g,x0,y0,x1,y1,c)` | segment (Bresenham) |
| `tube` | `(g,pts,r0,r1,c)` | « capsule » conique le long d'une polyligne (rayon r0→r1) |
| `polygon` | `(g,pts,c)` | polygone plein (scanline) |
| `mass` | `(g,cx,cy,rx,ry,p)` | **volume ombré** (corps de créature) |
| `eye` | `(g,x,y,r,p)` | œil multi-couches + push dans `g.eyes` |
| `tentacle` | `(g,x0,y0,len,dir,amp,r0,r1,c)` | tentacule sinueux (descend en y) |
| `radTentacle` | `(g,cx,cy,ang,len,amp,r0,r1,c,rnd)` | tentacule rayonnant selon un angle |
| `maw` | `(g,x,y,w,p)` | gueule dentée |
| `outline` | `(g,oc)` | contour 1px autour de tout pixel non vide |

Convention de palette `p` : `{ deep, sh, base, hi, bone, eye, eyeDim, out }`
(profond, ombre, base, éclat, os, iris, iris sombre, contour).

### 3.2 Code des primitives clés

```js
// Ellipse pleine (tolérance 1.05 pour des bords pleins en pixel art)
function ellipse(g,cx,cy,rx,ry,c){
  cx=Math.round(cx); cy=Math.round(cy);
  rx=Math.max(1,Math.round(rx)); ry=Math.max(1,Math.round(ry));
  for(var y=-ry;y<=ry;y++) for(var x=-rx;x<=rx;x++)
    if((x*x)/(rx*rx)+(y*y)/(ry*ry)<=1.05) set(g,cx+x,cy+y,c);
}

function disc(g,cx,cy,r,c){
  cx=Math.round(cx); cy=Math.round(cy); r=Math.max(0,Math.round(r));
  for(var y=-r;y<=r;y++) for(var x=-r;x<=r;x++)
    if(x*x+y*y<=r*r+r*0.5) set(g,cx+x,cy+y,c);
}

// Tube conique : enchaîne des disques le long d'une polyligne, rayon interpolé r0→r1.
// C'est LA primitive d'or : pattes, tentacules, cous, membres, armes.
function tube(g,pts,r0,r1,c){
  if(pts.length===1){ disc(g,pts[0][0],pts[0][1],r0,c); return; }
  var segLens=[],total=0,i;
  for(i=1;i<pts.length;i++){ var l=Math.hypot(pts[i][0]-pts[i-1][0],pts[i][1]-pts[i-1][1]); segLens.push(l); total+=l; }
  if(total===0){ disc(g,pts[0][0],pts[0][1],r0,c); return; }
  var acc=0;
  for(i=1;i<pts.length;i++){
    var a=pts[i-1],b=pts[i],L=segLens[i-1],steps=Math.max(1,Math.ceil(L));
    for(var s=0;s<=steps;s++){
      var t=(acc+L*s/steps)/total;
      var x=a[0]+(b[0]-a[0])*s/steps, y=a[1]+(b[1]-a[1])*s/steps;
      disc(g,x,y,r0+(r1-r0)*t,c);
    }
    acc+=L;
  }
}

// Tentacule : polyligne sinueuse descendant en y, passée à tube().
function tentacle(g,x0,y0,len,dir,amp,r0,r1,c){
  var seg=Math.max(4,Math.floor(len/2)),pts=[];
  for(var s=0;s<=seg;s++){
    var t=s/seg, y=y0+len*t, x=x0+Math.sin(t*3.0+dir)*amp*t;
    pts.push([Math.round(x),Math.round(y)]);
  }
  tube(g,pts,r0,r1,c);
}

// Contour : tout pixel vide touchant un pixel plein devient couleur de contour.
function outline(g,oc){
  var w=g.w,h=g.h,src=g.data.slice();
  for(var y=0;y<h;y++) for(var x=0;x<w;x++){
    if(src[y*w+x]!==null) continue;
    var t = (x>0&&src[y*w+x-1]) || (x<w-1&&src[y*w+x+1]) || (y>0&&src[(y-1)*w+x]) || (y<h-1&&src[(y+1)*w+x]);
    if(t) g.data[y*w+x]=oc;
  }
}
```

> **Patte d'araignée articulée** (recette type) : deux `tube` enchaînés — fémur `attache→genou`,
> tibia `genou→pied` — avec un `disc` au genou. Des pattes **fines (rayon 1)** et **bien espacées**
> (genoux/pieds étalés) se lisent comme des pattes ; trop épaisses ou issues d'un point trop serré,
> elles fusionnent en « aile ».

### 3.3 Le modèle d'ombrage : `mass`

Le corps des créatures n'est pas une ellipse plate : c'est un **volume sphérique ombré** en couches
concentriques (profond → ombre → base → éclat), avec deux anneaux de **dithering** pour adoucir les
transitions :

```js
function mass(g,cx,cy,rx,ry,p){
  var sR=0.82,bR=0.56,hR=0.30;
  ellipse(g,cx,cy,rx,ry,p.deep);                 // jante sombre
  ellipse(g,cx,cy,rx*sR,ry*sR,p.sh);             // ombre
  ellipse(g,cx,cy,rx*bR,ry*bR,p.base);           // base
  ditherRing(g,cx,cy,rx*bR,ry*bR,rx*sR,ry*sR,p.base); // transition base→ombre
  ditherRing(g,cx,cy,rx*sR,ry*sR,rx,ry,p.sh);    // transition ombre→jante
  ellipse(g,cx-rx*0.26,cy-ry*0.32,rx*hR,ry*hR,p.hi); // éclat haut-gauche
}

// Anneau ditheré : un pixel sur deux (damier) entre deux ellipses.
function ditherRing(g,cx,cy,rxIn,ryIn,rxOut,ryOut,color){
  cx=Math.round(cx); cy=Math.round(cy);
  var ox=Math.ceil(rxOut),oy=Math.ceil(ryOut);
  for(var y=-oy;y<=oy;y++) for(var x=-ox;x<=ox;x++){
    var dOut=(x*x)/(rxOut*rxOut)+(y*y)/(ryOut*ryOut);
    var dIn =(x*x)/(rxIn*rxIn)+(y*y)/(ryIn*ryIn);
    if(dOut<=1.02 && dIn>1.0 && (((cx+x)+(cy+y))&1)===0) set(g,cx+x,cy+y,color);
  }
}
```

**Discipline de couleur (recherche)** : décaler la teinte plutôt que seulement la luminosité —
ombres plus froides/désaturées, lumières plus chaudes/saturées. Verrouiller une palette **avant**
de générer (nombre de couleurs limité). Garder le contraste de **valeur** plus important que la teinte
(test du plissement d'yeux).

### 3.4 L'œil (et l'accroche d'animation)

```js
function eye(g,x,y,r,p){
  x=Math.round(x); y=Math.round(y);
  disc(g,x,y,r+1,p.deep);                 // socle
  disc(g,x,y,r,p.eyeDim);                 // sclère sombre
  disc(g,x,y,Math.max(1,r-1),p.eye);      // iris
  set(g,x,y,p.out);                       // pupille
  if(r>=2){ set(g,x,y-1,p.out); set(g,x,y+1,p.out); }
  if(g.eyes) g.eyes.push([x,y,r]);        // mémorisé pour l'animation (clignement/regard)
}
```

`g.eyes` est consommé par le moteur d'animation (Document 02) pour faire cligner et bouger les pupilles
indépendamment du corps.

---

## 4. Un archétype : assembler + renvoyer des ancres

Un **archétype** est une fonction `(g, rnd, p) → ancres`. Elle assemble des primitives **et renvoie un
contrat d'ancres sémantiques** que l'animation/attaque exploitera.

```js
function aSpider(g,rnd,p){
  // 8 pattes : [ax,ay, genou_x, genou_y, pied_x, pied_y] côté gauche ; droite = miroir x→64-x
  var L=[[28,29,18,17,6,28],[28,31,15,24,3,40],[29,33,15,34,4,51],[30,35,20,41,10,57]];
  for(var i=0;i<L.length;i++){ var a=L[i];
    tube(g,[[a[0],a[1]],[a[2],a[3]]],1,1,p.sh);            // fémur
    tube(g,[[a[2],a[3]],[a[4],a[5]]],1,1,p.sh);            // tibia
    disc(g,a[2],a[3],1,p.base);                            // genou
    tube(g,[[64-a[0],a[1]],[64-a[2],a[3]]],1,1,p.sh);      // miroir
    tube(g,[[64-a[2],a[3]],[64-a[4],a[5]]],1,1,p.sh);
    disc(g,64-a[2],a[3],1,p.base);
  }
  mass(g,32,42,8,8,p);    // abdomen
  mass(g,32,29,5,4,p);    // céphalothorax
  // chélicères + grappe d'yeux …
  eye(g,30,27,1,p); eye(g,34,27,1,p);
  set(g,28,29,p.eye); set(g,32,26,p.eye); set(g,36,29,p.eye);

  return {
    head:    { x:32, y:29, r:5 },           // foyer de la morsure
    faceDir: [0,-1],                         // direction « avant » (l'attaque pousse vers là)
    spine:   [[32,33],[32,42]],
    limbs:   [[6,28],[58,28],[10,57],[54,57]],
    belly:   { x:32, y:42 },
    mass:    [[32,42,8],[32,29,5]],          // centres de volume (1er = corps principal)
    tailBase:null, flesh:true                // flags : float / halo / flesh
  };
}
```

### Le contrat d'ancres

| Ancre | Type | Utilisé par |
|---|---|---|
| `head` | `{x,y,r}` | morsure, rayon, projectile (origine), regard |
| `faceDir` | `[dx,dy]` | direction de toutes les attaques directionnelles |
| `spine` | `[[x,y]…]` | pivot des balayages d'arme (point bas = hanches) |
| `limbs` | `[[x,y]…]` | pieds/mains (impacts, ancrage au sol) |
| `belly` | `{x,y}` | frontière haut/bas du corps (régions d'animation) |
| `mass` | `[[x,y,r]…]` | centres de volume (corruption, squash, déplacement) |
| `tailBase` | `{x,y}` ou `null` | base de queue |
| `flesh/float/halo` | bool | ombre portée, lévitation, effets |

C'est ce contrat qui rend l'animation **générique** : un seul moteur anime 97 archétypes parce que
chacun expose les mêmes points nommés.

---

## 5. Le registre : familles, palettes, profils

- **`ARCHMAP`** : `{ clé → fonction d'archétype }` (ex. `spider: aSpider`).
- **`FAMILIES[]`** : `{ key, name, accent, archs:[clés], pals:[palettes], treat }` —
  une famille regroupe des archétypes partageant ambiance/palette/traitement.
- **`PROF`** : `{ clé de famille → profil d'animation idle }` (Document 02).
- **`treat(g,rnd,p,A)`** : passe de « corruption » optionnelle (taches, veines…) appliquée après l'assemblage.

Construction d'une carte de galerie :

```js
var rnd = mulberry32(cseed);
var p   = fam.pals[Math.floor(rnd()*fam.pals.length)];
var g   = makeGrid(64,64);
var A   = ARCHMAP[archName](g,rnd,p);   // assemble + renvoie les ancres
fam.treat(g,rnd,p,A);                   // corruption seedée
outline(g,p.out);                       // contour final
// → g prêt à être animé par blit(g,…,prof,A,p) (Document 02)
```

---

## 6. Discipline de génération propre (correctifs issus de la recherche)

Pour éviter le « chaotique / imprécis » à la génération :

1. **Silhouette d'abord.** Tester chaque archétype au plissement d'yeux : la forme se lit-elle d'un
   coup d'œil ? Un foyer dominant (gueule, œil colossal, bec) vaut mieux qu'un humanoïde générique.
2. **Couleur disciplinée.** Palette verrouillée, décalage de teinte dans l'ombrage, contraste de valeur.
3. **Dé-doublonnage des motifs.** Un motif fort (les yeux, par ex.) doit être **réservé** à une famille,
   pas saupoudré partout. Approche formelle (recherche) :
   - **Grammaire de créatures** : règles explicites d'adjacence des parties, nombre de parties par
     catégorie, symétries — la variété reste cohérente *par construction*.
   - **MAP-Elites** : discrétiser un espace de caractéristiques (ex. silhouette × nombre de membres ×
     température de palette) et ne garder **qu'un seul exemplaire** par case — supprime structurellement
     les doublons sur de nombreuses variantes.
4. **Passe structurelle simple, puis décoration contrainte** (leçon Spelunky) : poser d'abord la
   structure grossière, puis décorer en passes contraintes. Garder chaque règle aussi simple que possible.

---

## 7. Validation systématique

Deux filets de sécurité, à lancer à chaque modification :

```bash
# 1) Syntaxe : extraire le <script> et vérifier
awk '/<script>/{f=1;next}/<\/script>/{f=0}f' fichier.html > check.js
node --check check.js

# 2) Runtime : stub du canvas/DOM, construire CHAQUE archétype et le rendre
#    sur plusieurs frames → compter les erreurs (doit être 0).
```

Le harnais runtime stube `document`/`canvas`/`ctx` (no-ops pour `fillRect`, `ellipse`…), charge le
script, puis itère toutes les familles × archétypes et appelle le rendu sur plusieurs valeurs de temps
et de phase d'attaque. Objectif : **0 erreur** avant toute livraison.

> Astuce de revue visuelle : un **canvas enregistreur** (un `ctx` dont `fillRect` écrit dans un buffer
> RGBA) permet de **rendre des frames en PNG** côté Node — indispensable pour juger une silhouette ou
> une frame d'attaque sans ouvrir le navigateur.

---

### Prochain document

**Document 02 — Le champ de déplacement** : comment `disp(x,y)` déforme la grille statique
(breathe / sway / flap / tentacles / writhe / legs / bob), l'animation des yeux, et pourquoi ce champ
ne déchire jamais (dégradés lissés). C'est la base sur laquelle le système d'attaque (Document 03) se greffe.
