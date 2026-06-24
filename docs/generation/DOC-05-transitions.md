# Document 05 — Transitions de scène

> Une transition mélange une image **source A** vers une **cible B** (deux biomes aplatis, Document 04)
> en fonction d'une **progression `p` ∈ [0,1]**, pixel par pixel. Le parti pris est **la douceur** :
> fronts plumeux, faible contraste, aucune arête dure.

---

## 1. Le principe : une fonction du temps qui mélange A→B

Chaque transition est une fonction `f(OUT, A, B, p, t)` qui écrit le buffer de sortie `OUT` à partir
de `A`, `B`, de la progression `p` et du temps `t` (pour les ondulations animées). On distingue :

- **génériques** : marchent entre n'importe quels biomes (fondus, ondulations, iris) ;
- **adaptatives thématiques** : un effet caractérisé (vortex, marée, spores, voile).

Le registre :

```js
var TRANS=[
  {n:'Fondu doux',g:0,f:tCross},{n:'Fondu nuageux',g:0,f:tCloud},{n:'Ondulation',g:0,f:tRipple},
  {n:'Vague',g:0,f:tWaveSweep},{n:'Iris doux',g:0,f:tSoftIris},
  {n:'Vortex du Vide',g:1,f:tVortex},{n:'Maelström',g:1,f:tMaelstrom},{n:'Marée douce',g:1,f:tTide},
  {n:'Spores flottantes',g:1,f:tDriftSpore},{n:'Voile',g:1,f:tVeil}
];   // g:1 = adaptative thématique
```

---

## 2. Les helpers : hash, bruit, mélange

```js
// Hash entier déterministe (style FNV) → bruit stable, indépendant de l'ordre.
function hsh(x,y){var n=(x*374761393+y*668265263)>>>0;n=((n^(n>>>13))*1274126177)>>>0;
  return ((n^(n>>>16))>>>0)/4294967296;}

// Smoothstep (le front plumeux est construit avec).
function ss(a,b,x){x=(x-a)/(b-a);x=x<0?0:x>1?1:x;return x*x*(3-2*x);}

// Value-noise lisse (bilinéaire sur le hash) — nuages, voiles.
function vn(x,y,s){var xi=Math.floor(x/s),yi=Math.floor(y/s),xf=x/s-xi,yf=y/s-yi;
  var a=hsh(xi,yi),b=hsh(xi+1,yi),c=hsh(xi,yi+1),d=hsh(xi+1,yi+1);
  var u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf);
  return a*(1-u)*(1-v)+b*u*(1-v)+c*(1-u)*v+d*u*v;}

// Mélanges A↔B dans OUT.
function bl(o,A,B,i,w){o[i]=A[i]+(B[i]-A[i])*w;o[i+1]=A[i+1]+(B[i+1]-A[i+1])*w;o[i+2]=A[i+2]+(B[i+2]-A[i+2])*w;o[i+3]=255;}
function blj(o,A,B,i,j,w){o[i]=A[j]+(B[j]-A[j])*w;o[i+1]=A[j+1]+(B[j+1]-A[j+1])*w;o[i+2]=A[j+2]+(B[j+2]-A[j+2])*w;o[i+3]=255;} // mélange avec ÉCHANTILLONNAGE déplacé (source au pixel j)
function mx(o,i,r,g,b,a){o[i]=o[i]*(1-a)+r*a;o[i+1]=o[i+1]*(1-a)+g*a;o[i+2]=o[i+2]*(1-a)+b*a;o[i+3]=255;} // superpose une teinte
function cl(v,m){return v<0?0:v>=m?m-1:v;}                                                                   // clamp d'index
```

---

## 3. Le front plumeux : pourquoi c'est doux

L'idée centrale qui supprime les arêtes : au lieu de basculer A→B d'un coup à un seuil, on **élargit
le seuil** en une bande `[c-fw, c+fw]` traversée par `ss` (smoothstep), et on **élargit la course de
`p`** pour que la bande balaie tout l'écran.

```js
var fw=0.27;                       // demi-largeur du front (plus grand = plus plumeux)
var pp=p*(1+2*fw)-fw;              // p remappé pour que le front entre et sorte complètement
// pour chaque pixel : un champ c ∈ [0,1] (ex. un bruit, une distance…)
bl(o,A,B,i, ss(c-fw, c+fw, pp));   // mélange progressif au lieu d'un saut net
```

C'est le même principe que le dithering plumeux des biomes, mais en **mélange continu** de couleurs.

---

## 4. Transitions génériques (code réel)

```js
// Fondu uniforme.
function tCross(o,A,B,p,t){var w=ss(0,1,p);for(var i=0;i<A.length;i+=4)bl(o,A,B,i,w);}

// Fondu nuageux : le front suit un value-noise (deux échelles) → dissolution organique.
function tCloud(o,A,B,p,t){var fw=0.27,pp=p*(1+2*fw)-fw;
  for(var y=0;y<H;y++)for(var x=0;x<W;x++){var i=(y*W+x)<<2;
    var c=vn(x,y,22)*0.62+vn(x,y,9)*0.38; bl(o,A,B,i,ss(c-fw,c+fw,pp));}}

// Ondulation : un front circulaire + léger DÉPLACEMENT d'échantillonnage (vague qui passe).
function tRipple(o,A,B,p,t){var cx=W/2,cy=H/2,mr=Math.sqrt(cx*cx+cy*cy),fw=0.24,pp=p*(1+2*fw)-fw;
  for(var y=0;y<H;y++)for(var x=0;x<W;x++){var i=(y*W+x)<<2,dx=x-cx,dy=y-cy,dpx=Math.sqrt(dx*dx+dy*dy),d=dpx/mr;
    var amp=Math.cos((d-pp)*20)*4*Math.exp(-Math.abs(d-pp)*6);             // l'amplitude se concentre sur le front
    var ux=dpx>0.001?dx/dpx:0,uy=dpx>0.001?dy/dpx:0;
    var sx=cl(Math.round(x+ux*amp),W),sy=cl(Math.round(y+uy*amp),H);
    blj(o,A,B,i,(sy*W+sx)<<2,ss(d-fw,d+fw,pp));}}

// Vague balayée (horizontale) + Iris doux (front radial + halo) : même schéma.
function tWaveSweep(o,A,B,p,t){ /* base=x/W + sin(y…) ; déplacement sur le front */ }
function tSoftIris(o,A,B,p,t){ /* d=distance/mr ; mx() ajoute un anneau lumineux sur le front */ }
```

---

## 5. Transitions adaptatives thématiques (code réel)

Le **Vortex du Vide** — l'effet phare : déformation polaire continue (torsion + aspiration), avec un
cœur de néant qui grandit ; on échantillonne A avant la mi-course, B après.

```js
function tVortex(o,A,B,p,t){
  var cx=W/2,cy=H/2,mr=Math.sqrt(cx*cx+cy*cy),src=p<0.5?A:B,ph=Math.sin(p*Math.PI),vg=hexToRgb('#0a0418');
  for(var y=0;y<H;y++)for(var x=0;x<W;x++){var i=(y*W+x)<<2,dx=x-cx,dy=y-cy,
      rad=Math.sqrt(dx*dx+dy*dy),ang=Math.atan2(dy,dx),
      tw=(1-rad/mr)*6*ph,                 // torsion : plus forte au centre, pic à mi-course
      pull=1+ph*1.3*(1-rad/mr),           // aspiration : rapproche les pixels du centre
      sr=rad*pull,sa=ang+tw,
      sx=Math.round(cx+Math.cos(sa)*sr),sy=Math.round(cy+Math.sin(sa)*sr);
    if(sx<0||sx>=W||sy<0||sy>=H){o[i]=vg[0];o[i+1]=vg[1];o[i+2]=vg[2];o[i+3]=255;}   // hors-cadre = néant
    else{var j=(sy*W+sx)<<2;o[i]=src[j];o[i+1]=src[j+1];o[i+2]=src[j+2];o[i+3]=255;}
    var core=ph*32; if(rad<core) mx(o,i,vg[0],vg[1],vg[2],(1-rad/(core+0.001))*0.92);} // cœur de vide qui grandit
}
```

Les autres adaptatives suivent le même esprit (déformation continue + voile thématique en `mx`) :

```js
function tMaelstrom(o,A,B,p,t){ /* torsion polaire + fondu ss() — tourbillon plus doux que le vortex */ }
function tTide(o,A,B,p,t){      /* fondu + ligne d'eau qui monte (mx bleu + écume) — une marée engloutit la scène */ }
function tDriftSpore(o,A,B,p,t){/* fondu + voile de spores (value-noise dérivant) + lucioles (hsh) */ }
function tVeil(o,A,B,p,t){      /* fondu + voile radial sombre qui se referme depuis les bords */ }
```

**Recette d'une adaptative** : (1) un mélange A→B (souvent `ss(0,1,p)`), (2) une **enveloppe de pic**
`Math.sin(p*π)` (0 aux extrémités, 1 au milieu) qui pilote l'intensité de l'effet thématique, (3) une
superposition `mx(...)` d'une teinte/halo qui apparaît puis disparaît. Endpoints garantis propres :
à `p=0` on voit A, à `p=1` on voit B.

---

## 6. Le pilote temporel : maintien A → transition → maintien B

```js
var H_A=0.6, T_T=1.8, H_B=1.1, TOTAL=H_A+T_T+H_B;     // tenir A, transitionner 1,8 s, tenir B
function frame(now){
  requestAnimationFrame(frame); var ts=now/1000; if(!start)start=now;
  var el=((now-start)/1000)%TOTAL;
  if(el<H_A) copyBuf(A);                                // on montre A
  else if(el<H_A+T_T) TRANS[cur].f(OUT,A,B,(el-H_A)/T_T,ts);   // p = progression dans la fenêtre de transition
  else copyBuf(B);                                      // on montre B
  // … puis blit de OUT (W×H) vers le canvas au scale 4 (nearest-neighbor)
}
```

`A` et `B` sont calculés une fois par `flatten(biomeIdx, seed)` (Document 04). La transition ne fait
que mélanger ces deux buffers — elle est indépendante du contenu des biomes.

---

## 7. Pourquoi ces transitions sont « douces » (et pas agressives)

Trois leviers, tous présents ci-dessus :

1. **Front plumeux large** (`fw` ≈ 0,2–0,27) + `ss` → pas de bord net, une dissolution.
2. **Faible contraste** : les voiles thématiques sont superposés à faible alpha (`mx(..., 0.2–0.4)`),
   jamais des aplats opaques.
3. **Déplacements d'échantillonnage doux** : les ondulations utilisent `Math.exp(-|d-pp|*k)` pour
   concentrer une petite amplitude sur le front et l'annuler ailleurs — la scène **ondule** au lieu de
   se **déchirer**. (Même philosophie anti-cassure que les animations : on lisse, on ne tranche pas.)

---

## Récapitulatif de la suite

| Doc | Sujet | Cœur technique |
|---|---|---|
| 01 | Fondations | déterminisme (mulberry32 + hash), grille, primitives, ombrage, ancres |
| 02 | Champ de déplacement | `disp` + `blit`, profils idle, dégradés lissés (anti-cassure) |
| 03 | Système d'attaque | enveloppe `_env`, ~16 kinds, `atkFx`, squash-stretch + phase-lag + smootherstep |
| 04 | Biomes | couches tileables, dithering Bayer, ridge sinus, parallaxe, dé-doublonnage |
| 05 | Transitions | mélange A→B, fronts plumeux, génériques vs adaptatives |
| R | Recherche | état de l'art citable (Disney 12, LBS/Verlet/IK, Spore, juice, PCG, noise) |

**Pistes d'extension** (validées par la recherche, non encore implémentées) : chaînes de **Verlet**
pour tentacules/queues, **IK deux-os** pour membres ciblant un point, **grammaire de créatures** +
**MAP-Elites** pour la variété sans doublon, **post-traitement GLSL** (pixelize → Bayer → masque
phosphore → scanlines → courbure → aberration → bloom) sur les biomes, et **export sprite-sheets**
(rendu de N frames d'attaque vers un atlas PNG + métadonnées de timing) pour portage LÖVE2D/Godot/Unity.
