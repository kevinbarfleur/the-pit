# Document 04 — Biomes : décors en couches tileables

> Le générateur de biomes produit des **arrière-plans pixel art** en couches parallaxables, tileables
> horizontalement, prêts pour un enrichissement shader. Même philosophie qu'ailleurs : déterministe,
> par assemblage, palettes eldritch limitées. Cible : **192×108**, rendu au scale 4.

---

## 1. Le modèle en couches

Un biome est un empilement de 6 calques, du fond vers l'avant :

```
sky   ── ciel / gradient de fond (le plus lointain)
far   ── silhouettes très lointaines (anneaux, structures)
mid   ── masse intermédiaire (montagnes, colonnes)
near  ── premier plan (cristaux, troncs, tentacules)
ground── sol + particules au sol
fog   ── brume atmosphérique (le plus proche)
```

Chaque calque est un buffer RGBA indépendant ; on les **aplatit** dans l'ordre à la fin (Document §6).
La parallaxe se fait en décalant le scroll de chaque calque par un facteur de profondeur.

Un biome est un objet `{ key, name, sub, accent, pal, build(L, rnd) }` où `build` peint les calques `L`.

---

## 2. Déterminisme et helpers de base

```js
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;
  var t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}

// Écriture dans un calque (buffer RGBA W×H), avec clipping.
function set(L,x,y,hex){x=x|0;y=y|0;if(x<0||x>=W||y<0||y>=H)return;
  var r=hexToRgb(hex);var i=(y*W+x)*4;L.d[i]=r[0];L.d[i+1]=r[1];L.d[i+2]=r[2];L.d[i+3]=255;}
```

---

## 3. Le dithering ordonné : la matrice de Bayer

Le secret du dégradé pixel art **stable en animation**. Contrairement au tramage par diffusion
d'erreur (séquentiel, instable d'une frame à l'autre), le **dithering ordonné** seuille chaque pixel
**indépendamment** via une matrice de seuils → idéal pour du contenu animé et pour un portage shader.

```js
const BAYER=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];   // matrice 4×4 classique
// usage : seuil = BAYER[y&3][x&3] / 16   (valeur dans [0,1[)
```

> Note (recherche) : le **blue noise** (void-and-cluster) répartit mieux les fréquences mais peut créer
> des motifs mouvants perceptibles sur du contenu animé ; **Bayer reste préférable pour les calques
> animés** (stable), blue noise réservé au statique.

---

## 4. Les primitives de décor

### 4.1 Gradient vertical tramé (`vgrad`)

Transition douce entre les couleurs d'une rampe, sans bandes, grâce au seuil de Bayer :

```js
function vgrad(L,ramp,y0,y1){y0=y0||0;y1=y1||H;
  for(var y=y0;y<y1;y++){
    var f=(y-y0)/(y1-y0);                          // position verticale 0→1
    var fi=f*(ramp.length-1),i0=Math.floor(fi),fr=fi-i0;
    for(var x=0;x<W;x++){
      var th=BAYER[y&3][x&3]/16;                   // seuil ordonné
      var idx=i0+(fr>th?1:0);                       // on monte d'un cran si la fraction dépasse le seuil
      if(idx>ramp.length-1)idx=ramp.length-1;
      set(L,x,y,ramp[idx]);
    }
  }
}
```

### 4.2 Ridgeline tileable (`ridge`) — somme de sinus à fréquences entières

Une silhouette de relief qui **se referme parfaitement** sur la largeur (donc tileable), parce que
toutes les fréquences sont **entières** sur la période `W` :

```js
function ridge(L,baseY,amp,color,rnd,oct,fill){
  oct=oct||3;var ph=[],fq=[],am=[];
  for(var o=0;o<oct;o++){ ph.push(rnd()*6.283); fq.push(o+1); am.push(amp/(o+1)); }  // octaves : fréq 1,2,3… amp décroissante
  for(var x=0;x<W;x++){
    var v=baseY;
    for(o=0;o<oct;o++){ v+=Math.sin(x/W*6.283*fq[o]+ph[o])*am[o]; }   // x/W*2π*fréquence_entière → wrap exact
    var yy=Math.round(v);
    if(fill){ for(var y=yy;y<H;y++)set(L,x,y,color); }                // remplir sous la crête (montagne pleine)
    else{ set(L,x,yy,color); set(L,x,yy+1,color); }                   // ou juste la ligne de crête
  }
}
```

C'est un **fBm 1D tileable** : somme d'octaves, amplitude ÷ par l'octave. (La recherche recommande le
*domain warping* d'Inigo Quilez pour enrichir sans casser la couture : évaluer `sin(x + bruit(x))`.)

### 4.3 Brume atmosphérique (`fog`)

Bande de brume dont la densité s'estompe vers les bords, tramée :

```js
function fog(L,y0,y1,color,density,rnd){
  var mid=(y0+y1)/2,half=(y1-y0)/2;
  for(var y=y0;y<y1;y++){
    var edge=1-Math.abs((y-mid)/half); if(edge<0)edge=0;             // 1 au centre de la bande → 0 aux bords
    for(var x=0;x<W;x++){
      var th=(BAYER[y&3][x&3]+(((x*7+y*13)%4)))/20;                  // Bayer + bruit haché pour casser la grille
      if(th<density*edge) set(L,x,y,color);
    }
  }
}
```

### 4.4 Sol + particules (`ground`), rayons (`rays`), anneaux (`rings`), toiles (`webs`)

```js
function ground(L,baseY,ramp,rnd){
  for(var y=baseY;y<H;y++){var f=(y-baseY)/(H-baseY),idx=Math.min(ramp.length-1,(f*ramp.length)|0);
    for(var x=0;x<W;x++){var th=BAYER[y&3][x&3]/16,ii=th<0.5?idx:Math.min(ramp.length-1,idx+1);set(L,x,y,ramp[ii]);}}
  var n=(W*0.7)|0; for(var k=0;k<n;k++)set(L,(rnd()*W)|0,baseY+((rnd()*(H-baseY))|0),ramp[0]); // cailloux épars
}
// rays   : colonnes de lumière en biais (seuil Bayer décroissant vers le bas)
// rings  : anneaux concentriques tramés (un lointain tourbillon)
// webs   : segments de toile tramés dans le haut de la scène
```

Toutes ces primitives **wrappent en x** (`((x|0)%W+W)%W`) pour rester tileables.

---

## 5. Exemple de biome : « Le Vide » (`build`)

Code réel — montre comment on compose les calques (gradient radial de ciel, anneaux lointains d'un
tourbillon, planétoïdes au premier plan, tentacules, brume) :

```js
build:function(L,rnd){
  var P=this.pal,cx=96,cy=50;var R=P.sky;
  // ciel : gradient RADIAL tramé (vers un point de fuite)
  for(var y=0;y<108;y++)for(var x=0;x<192;x++){
    var dx=(x-cx)/1.25,dy=(y-cy),f=Math.min(1,Math.sqrt(dx*dx+dy*dy)/72);
    var fi=f*(R.length-1),i0=fi|0,fr=fi-i0,th=BAYER[y&3][x&3]/16;
    set(L.sky,x,y,R[Math.min(R.length-1,i0+(fr>th?1:0))]);
  }
  // spirale du tourbillon (calque mid) + anneaux (calque far)
  for(var a=0;a<24;a++){var an=a/24*6.2832;
    for(var d=22;d<72;d++){ if((d%9)<2) set(L.mid,(cx+Math.cos(an)*d*1.25)|0,(cy+Math.sin(an)*d)|0,P.mid); }}
  rings(L.far,cx,cy,P.far,rnd,7);
  // planétoïdes (calque near)
  for(var k=0;k<3;k++){var gx=20+((rnd()*150)|0),gy=70+((rnd()*30)|0);
    for(var sgi=0;sgi<7;sgi++) discL(L.near,gx+sgi*2,gy-Math.round(Math.sin(sgi*0.7)*2),2,P.near);
    set(L.near,gx,gy,'#2a1e14');}
  featuresRow(L.near,108,3,P.near,'tentacle',rnd,16,28);   // rangée de tentacules tileable
  fog(L.fog,30,90,P.mid,0.22,rnd);                          // brume
}
```

---

## 6. Aplatissement (compositing) et parallaxe

```js
var ORDER=['sky','far','mid','near','ground','fog'];
function flatten(idx,seed){
  var buf=new Uint8ClampedArray(W*H*4); for(var i=0;i<buf.length;i+=4)buf[i+3]=255;
  if(idx<0)return buf;
  var rnd=mulberry32(seed>>>0),Ls={};
  for(var o=0;o<ORDER.length;o++)Ls[ORDER[o]]=Layer();      // un calque vide par couche
  BIOMES[idx].build(Ls,rnd);                                 // peindre
  for(o=0;o<ORDER.length;o++){var d=Ls[ORDER[o]].d;          // composer du fond vers l'avant
    for(i=0;i<buf.length;i+=4){ if(d[i+3]>0){ buf[i]=d[i];buf[i+1]=d[i+1];buf[i+2]=d[i+2]; } }}
  return buf;
}
```

**Parallaxe** (au moment du rendu animé) : décaler le scroll de chaque calque par un facteur de
profondeur (`sky` immobile, `fog`/`near` plus rapides), et wrapper modulo `W` — possible précisément
parce que chaque calque est tileable.

---

## 7. Dé-doublonnage des motifs (discipline anti-chaos)

Le piège : saupoudrer le **même** motif fort partout (on avait le motif « yeux qui s'ouvrent » dans
trop de biomes). Règle appliquée : **un motif signature est réservé à un seul biome**.

- Forêt d'Yeux → les yeux (amplifiés, sa signature).
- Vide → débris / planétoïdes ; Chair → gueules ; Galeries → plaques + larves ;
  Dévoreur → couronne de crocs ; Ruche → alvéoles + larves ; Catacombes → ossements + cierges.

Formalisation (recherche) : **grammaire** (quels motifs autorisés par biome) + **MAP-Elites** (un seul
exemplaire par case d'un espace de caractéristiques) pour garantir la variété sans répétition.

---

### Prochain document
**Document 05 — Transitions** : les effets de changement de scène pilotés par une progression `p`,
avec fronts plumeux (smoothstep) pour éviter les arêtes dures, génériques vs adaptatives thématiques.
