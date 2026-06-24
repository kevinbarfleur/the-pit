# Document 02 — Le champ de déplacement (animation idle)

> Prérequis : Document 01 (grille, primitives, ancres). Ce document explique **comment on anime**
> une créature **sans redessiner** : un seul champ de déplacement par pixel, piloté par un profil.

---

## 1. Le principe : déformer, ne pas redessiner

La grille `g` est dessinée **une seule fois** (statique). L'animation est une fonction
**`disp(x, y) → [dx, dy]`** qui, à chaque frame, déplace chaque pixel de sa position d'origine.
On ne stocke aucune image intermédiaire : on relit la grille et on dessine chaque pixel à
`(x+dx, y+dy)`.

```
pixel source (x,y) ──disp(x,y)──▶ fillRect( (x+dx)·scale, (y+dy)·scale )
```

Avantages : une créature = une grille + un petit profil de quelques nombres ; l'attaque (Document 03)
se greffe en **ajoutant un terme** à `disp`. Contrainte d'or : **toute déformation par région doit
être un dégradé lissé** (jamais un seuil dur), sinon le sprite se déchire.

---

## 2. La fonction de rendu animé : `blit`

Code réel intégral. Elle calcule le champ, dessine l'ombre portée, puis chaque pixel déplacé,
puis les effets d'attaque, puis les yeux animés.

```js
function blit(g,canvas,scale,baseline,glowHex,floatMode,t,prof,A,p){
  var W=g.w,H=g.h;
  if(canvas.width!==W*scale){canvas.width=W*scale;canvas.height=H*scale;}
  var ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;
  ctx.clearRect(0,0,canvas.width,canvas.height);
  t=t||0;prof=prof||null;

  // Repères tirés des ancres : centre de masse, ligne de ventre, sol, hauteur de corps.
  var cx=32,cy=34,bodyR=10,bellyY=42,groundY=baseline||57;
  if(A){ if(A.mass&&A.mass[0]){cx=A.mass[0][0];cy=A.mass[0][1];bodyR=A.mass[0][2];}
         if(A.belly){bellyY=A.belly.y;} }
  var headSpan=Math.max(1,groundY-(cy-bodyR-6));

  // ---- LE CHAMP DE DÉPLACEMENT ----
  function disp(x,y){
    var dx=0,dy=0;
    if(prof){
      if(prof.bob){ dy+=prof.bob.amp*Math.sin(t*prof.bob.freq); }                       // flottaison verticale globale
      if(prof.breathe){ var s=prof.breathe.amp*Math.sin(t*prof.breathe.freq);            // respiration = scale autour du centre
        dx+=(x-cx)*s; dy+=(y-cy)*s; }
      if(prof.sway){ var f=Math.max(0,(groundY-y))/headSpan;                              // balancement gradué par la hauteur
        dx+=prof.sway.amp*Math.sin(t*prof.sway.freq+y*0.16)*f; }                          //   → 0 aux pieds, max en haut : pas de cassure
      if(prof.legs&&y>cy){ var side=(x<cx?-1:1);                                          // pattes : moitiés opposées en alternance
        dy+=prof.legs.amp*Math.sin(t*prof.legs.freq)*side; }
      if(prof.flap){ var d=Math.abs(x-cx);                                               // ailes : amplitude selon l'éloignement horizontal
        if(d>bodyR*0.9){ var wf=d-bodyR*0.9;
          dy+=-wf*prof.flap.amp*Math.sin(t*prof.flap.freq);
          dx+=(x<cx?1:-1)*wf*(prof.flap.fold||0)*(0.5+0.5*Math.sin(t*prof.flap.freq)); } }
      if(prof.tentacles&&y>bellyY){                                                       // tentacules : onde sinusoïdale sous le ventre
        dx+=prof.tentacles.amp*Math.sin(t*prof.tentacles.freq+y*0.45+x*0.3); }
      if(prof.writhe){                                                                    // reptation : onde en x et y
        dx+=prof.writhe.amp*Math.sin(t*prof.writhe.freq+y*0.6);
        dy+=prof.writhe.amp*0.5*Math.cos(t*prof.writhe.freq+x*0.5); }
      if(prof._atk){ var _ad=atkDisp(prof._atk,x,y,cx,cy,bellyY,groundY,headSpan,A);      // ← greffe de l'attaque (Document 03)
        dx+=_ad[0]; dy+=_ad[1]; }
    }
    return [dx,dy];
  }

  // ---- OMBRE PORTÉE (ou halo si flottant) ----
  if(baseline){
    var gr=hexToRgb(glowHex||'#000000');
    var bb=(prof&&prof.bob)?prof.bob.amp*Math.sin(t*prof.bob.freq):0;
    var ss=1-0.05*Math.abs(bb);                                  // l'ombre rétrécit quand la créature monte
    ctx.save();
    if(floatMode){
      ctx.fillStyle='rgba(0,0,0,0.22)';
      ctx.beginPath();ctx.ellipse(W*scale/2,(baseline+3)*scale,8*scale*ss,1.8*scale*ss,0,0,6.283);ctx.fill();
      ctx.fillStyle='rgba('+gr[0]+','+gr[1]+','+gr[2]+',0.10)';
      ctx.beginPath();ctx.ellipse(W*scale/2,30*scale,16*scale,14*scale,0,0,6.283);ctx.fill();
    }else{
      ctx.fillStyle='rgba('+gr[0]+','+gr[1]+','+gr[2]+',0.13)';
      ctx.beginPath();ctx.ellipse(W*scale/2,baseline*scale,18*scale,4*scale,0,0,6.283);ctx.fill();
      ctx.fillStyle='rgba(0,0,0,0.42)';
      ctx.beginPath();ctx.ellipse(W*scale/2,(baseline+1)*scale,11*scale*ss,2.4*scale*ss,0,0,6.283);ctx.fill();
    }
    ctx.restore();
  }

  // ---- DESSIN DES PIXELS DÉPLACÉS ----
  // rs : on agrandit d'1px le rectangle quand le corps respire/bat des ailes, pour boucher les trous.
  var rs=Math.ceil(scale)+((prof&&(prof.breathe||prof.flap))?1:0);
  for(var y=0;y<H;y++){ for(var x=0;x<W;x++){
    var col=g.data[y*W+x]; if(!col) continue;
    var d=disp(x,y);
    ctx.fillStyle=col;
    ctx.fillRect(Math.round((x+d[0])*scale),Math.round((y+d[1])*scale),rs,rs);
  }}

  // ---- EFFETS TRANSITOIRES D'ATTAQUE (projectiles, arcs…) ----
  if(prof._atk){ atkFx(ctx,scale,prof._atk,A,p,glowHex); }

  // ---- YEUX ANIMÉS (clignement + micro-saccades), indépendants du corps ----
  if(prof&&prof.eyes&&g.eyes&&g.eyes.length){
    var ES=function(cxp,cyp,rad,color){ctx.fillStyle=color;
      ctx.fillRect(Math.round((cxp-rad)*scale),Math.round((cyp-rad)*scale),
                   Math.round((2*rad+1)*scale),Math.round((2*rad+1)*scale));};
    for(var k=0;k<g.eyes.length;k++){
      var ex=g.eyes[k][0],ey=g.eyes[k][1],er=g.eyes[k][2];
      var de=disp(ex,ey);                       // l'œil suit la déformation du corps…
      var qx=ex+de[0],qy=ey+de[1];
      var ph=ex*1.3+ey*0.7;                     // …puis a sa propre phase (chaque œil cligne à son rythme)
      var bl=Math.sin(t*(prof.eyes.blink||0.9)+ph);
      if(bl>0.93){ ES(qx,qy,er,(p&&p.sh)||'#444'); }            // paupière fermée
      else if(er>=2){
        ES(qx,qy,er-1,(p&&p.eye)||glowHex||'#fff');            // iris
        var pdx=Math.round(Math.sin(t*(prof.eyes.dart||1.4)+ph));
        var pdy=Math.round(Math.cos(t*(prof.eyes.dart||1.4)*1.3+ph));
        ES(qx+pdx,qy+pdy,(er>=3?1:0),(p&&p.out)||'#111');      // pupille qui darde
      }
    }
  }
}
```

---

## 3. Le catalogue des profils idle

Chaque **terme** de `disp` n'est actif que si le profil `prof` le contient. Un profil = un objet
de quelques sous-objets `{amp, freq}`. Voici la sémantique :

| Terme | Effet | Gradation (anti-cassure) |
|---|---|---|
| `bob` | flottaison verticale globale | aucune (translation entière) |
| `breathe` | respiration (scale autour du centre) | proportionnel à la distance au centre |
| `sway` | balancement latéral | **× `(groundY-y)/headSpan`** → 0 aux pieds |
| `legs` | pattes, moitiés opposées | actif `y>cy` seulement |
| `flap` | ailes (lever + repli) | **× `(d-bodyR·0.9)`** → 0 près du corps |
| `tentacles` | onde sous le ventre | actif `y>bellyY` seulement |
| `writhe` | reptation (onde x/y) | globale, faible amplitude |
| `eyes` | clignement + saccades | indépendant, par œil |

### La table `PROF` (un profil par famille — extrait réel)

```js
var PROF={
  _default:{breathe:{amp:0.018,freq:1.8},eyes:{blink:0.9,dart:1.3}},
  bete:    {legs:{amp:0.7,freq:3.0},breathe:{amp:0.02,freq:2.0},eyes:{blink:0.9,dart:1.2}},
  cephalo: {tentacles:{amp:1.3,freq:2.4},breathe:{amp:0.03,freq:1.8},eyes:{blink:0.9,dart:1.4}},
  gelatine:{breathe:{amp:0.05,freq:2.2},eyes:{blink:0.8,dart:1.2}},
  spectre: {bob:{amp:1.4,freq:1.5},sway:{amp:1.2,freq:1.2},eyes:{blink:0.8}},
  aile:    {flap:{amp:0.22,freq:3.6,fold:0.06},bob:{amp:1.2,freq:1.8},eyes:{blink:0.9,dart:1.3}},
  arachnide:{legs:{amp:0.6,freq:3.6},breathe:{amp:0.025,freq:2.0},eyes:{blink:1.0}},
  colosse: {legs:{amp:0.6,freq:2.4},breathe:{amp:0.025,freq:1.8},eyes:{blink:0.8,dart:1.1}},
  larve:   {writhe:{amp:0.8,freq:2.8},breathe:{amp:0.04,freq:2.2},eyes:{blink:1.1}},
  // … ~40 familles : mortvivant, demon, insecte, golem, culte, spore, abyssal, cristal,
  //   ombre, essaim, annelide, seraphin, canide, rongeur, meduse, pendu, chimere, automate…
};
```

**Profil = personnalité de mouvement.** Un `rongeur` respire vite et fort (`breathe amp:0.045, freq:3.6`),
un `cristal` bouge à peine (`amp:0.02, freq:1.4`), un `spectre` flotte et ondule sans pattes. C'est le
même moteur ; seuls les nombres changent.

---

## 4. Pourquoi ça ne déchire jamais

Le piège classique (et le bug qu'on a corrigé sur le système d'attaque) : un seuil dur du type
`if(y<bellyY) déplacer` crée une **frontière nette** — les pixels juste au-dessus bougent, ceux
juste en-dessous non → le sprite se **fend**. C'est exactement l'analogue d'un poids de skinning
binaire (1 d'un côté, 0 de l'autre) qui déchire toujours un maillage.

La parade, présente partout dans `disp` : **un facteur lissé** qui tend vers zéro à la frontière.
Exemple, le `sway` :

```js
var f=Math.max(0,(groundY-y))/headSpan;        // 1 en haut → 0 aux pieds (continu)
dx+=prof.sway.amp*Math.sin(...)*f;             // le corps fléchit, les pieds restent plantés
```

C'est le **poids de skinning normalisé** version par-pixel : chaque pixel est une fraction continue
de la déformation, jamais un tout-ou-rien. **Règle générale du moteur** : toute déformation localisée
se multiplie par un dégradé `_sstep`/falloff, jamais par un booléen. (Document 03 applique la même
règle, renforcée par la recherche : *linear blend skinning*, Σ poids = 1.)

---

## 5. La boucle d'animation (squelette)

```js
var _alast=0;
function _animLoop(now){
  requestAnimationFrame(_animLoop);
  if(now-_alast<33) return;            // ~30 fps
  _alast=now; var t=now/1000;
  for(var i=0;i<CARDS.length;i++){
    var c=CARDS[i];
    try{ blit(c.g,c.cv,GAL_SCALE,57,c.p.eye,c.fl,t,c.prof,c.A,c.p); }catch(e){}
  }
}
requestAnimationFrame(_animLoop);
```

Chaque carte conserve sa grille `g`, son canvas `cv`, son profil `prof`, ses ancres `A`, sa palette `p`.
La boucle ne fait que rappeler `blit` avec le temps courant. Le Document 03 enrichit cette boucle pour
alterner idle ↔ attaque.

---

### Prochain document
**Document 03 — Le système d'attaque** : l'enveloppe anticipation→frappe→récupération, les ~16 *kinds*
(lunge, swing, lash, skitter…), la couche d'effets `atkFx`, et les correctifs validés par la recherche
(squash-and-stretch à volume conservé, overlapping action par phase-lag, smootherstep).
