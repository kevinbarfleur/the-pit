# Document 03 — Le système d'attaque

> Prérequis : Documents 01 et 02. L'attaque **réutilise** le champ de déplacement : un terme s'ajoute
> à `disp`, et une couche d'effets transitoires se dessine par-dessus. Une seule enveloppe temporelle
> et ~16 *kinds* couvrent les 97 archétypes.

---

## 1. La greffe : trois points d'insertion

Le système d'attaque n'est pas un moteur séparé. Il se branche en trois endroits de `blit`
(Document 02) :

1. **Dans `disp`** — un terme `atkDisp(...)` s'ajoute aux termes idle :
   ```js
   if(prof._atk){ var _ad=atkDisp(prof._atk,x,y,cx,cy,bellyY,groundY,headSpan,A); dx+=_ad[0]; dy+=_ad[1]; }
   ```
2. **Après les pixels** — la couche d'effets :
   ```js
   if(prof._atk){ atkFx(ctx,scale,prof._atk,A,p,glowHex); }
   ```
3. **Dans la carte** — un attribut `atk` (le *kind* + ses paramètres) et un état de tir.

`prof._atk` vaut `null` au repos, et `{k, pr, ph}` pendant une attaque (`k` = kind, `pr` = params,
`ph` = phase 0→1).

---

## 2. L'enveloppe temporelle : anticipation → frappe → récupération

Le cœur du *game feel*. `_env(ph)` renvoie deux courbes : **windup** (anticipation, l'unité se ramasse)
et **strike** (la frappe, qui claque puis tient brièvement avant de relâcher). On utilise le
**smootherstep de Perlin** (6t⁵−15t⁴+10t³, dérivées 1ʳᵉ *et* 2ᵈᵉ nulles aux bords) pour des
départs/arrêts plus propres que le smoothstep classique.

```js
function _sstep(a,b,x){x=(x-a)/(b-a);x=x<0?0:x>1?1:x;return x*x*(3-2*x);}              // smoothstep
function _smoo(a,b,x){x=(x-a)/(b-a);x=x<0?0:x>1?1:x;return x*x*x*(x*(x*6-15)+10);}     // smootherstep (Perlin)

function _env(ph){
  return [
    _sstep(0,0.24,ph) - _sstep(0.24,0.40,ph),   // windup : monte (0→0.24) puis se résorbe (0.24→0.40)
    _smoo(0.30,0.44,ph) - _smoo(0.66,0.92,ph)   // strike : frappe rapide (0.30→0.44), tient, relâche en douceur (0.66→0.92)
  ];
}
```

Profil temporel obtenu :

```
        windup        strike (tenue)        recovery
  ph:  0 ─▶ 0.24 ─▶ 0.40 ─▶ 0.44 ════ 0.66 ─▶ 0.92 ─▶ 1
        ramasse      FRAPPE  ─ maintien ─   relâche
```

Le **maintien** au sommet de la frappe (plateau 0.44→0.66) joue le rôle d'un **hit-stop** léger : la
pose de frappe reste lisible quelques frames (principe « *Stop for big moments* » / impact freeze).

---

## 3. Les helpers de déformation

```js
// Squash-and-stretch À VOLUME CONSERVÉ : étire le long de fd (facteur 1+s), comprime en perpendiculaire (1/(1+s)).
function _dscale(x,y,cx,cy,fd,s){
  var rx=x-cx,ry=y-cy,
      al=rx*fd[0]+ry*fd[1],          // composante le long de la direction de frappe
      ex=rx-al*fd[0], ey=ry-al*fd[1],// composante perpendiculaire
      ka=1+s, kp=1/(1+s);
  return [(cx+al*ka*fd[0]+ex*kp)-x, (cy+al*ka*fd[1]+ey*kp)-y];
}
function _nrm(v){var d=Math.hypot(v[0],v[1])||1;return [v[0]/d,v[1]/d];}  // normalise un vecteur
function _h2(x,y){var n=(x*12.9898+y*78.233)*43758.5453;return n-Math.floor(n);} // hash pseudo-aléatoire stable
```

`_dscale` est la traduction directe du principe Disney **squash-and-stretch** : on conserve l'aire
(ce qui s'allonge s'amincit), ce qui évite l'effet « ballon » et donne du poids à l'élan.

---

## 4. `atkDisp` : les ~16 *kinds* de déformation

Code réel intégral. Chaque kind lit `fd` (direction de l'attaque = `A.faceDir`), l'enveloppe
`(wu, st)`, et les ancres, puis renvoie le déplacement du pixel.

```js
function atkDisp(atk,x,y,cx,cy,bellyY,groundY,headSpan,A){
  var ph=atk.ph,e=_env(ph),wu=e[0],st=e[1],fd=_nrm(A.faceDir||[0,-1]),pr=atk.pr||{},k=atk.k;
  var reach=pr.reach||8,pull=pr.pull||3,dx=0,dy=0,head=A.head||{x:cx,y:cy-8,r:4};
  var bR=(A.mass&&A.mass[0])?A.mass[0][2]:9;

  // — Élans directionnels (corps entier) avec squash-and-stretch + petit arc —
  if(k==='lunge'){var m=st*reach-wu*pull,pp=[-fd[1],fd[0]],sq=_dscale(x,y,cx,cy,fd,st*0.22-wu*0.16);
    dx=fd[0]*m+pp[0]*st*1.8+sq[0]; dy=fd[1]*m+pp[1]*st*1.8+sq[1];}
  else if(k==='pounce'){var m2=st*reach-wu*pull*0.5,sq2=_dscale(x,y,cx,cy,fd,st*0.20-wu*0.18);
    dx=fd[0]*m2+sq2[0]; dy=fd[1]*m2*0.5-st*(pr.leap||7)+wu*(pr.crouch||3)+sq2[1];}
  else if(k==='bite'){var dh=Math.hypot(x-head.x,y-head.y),f=Math.max(0,1-dh/(head.r+8)),
      m3=st*reach-wu*pull,bp=[-fd[1],fd[0]];                                  // morsure : ne déplace que la tête (falloff f), + petit arc
    dx=(fd[0]*m3+bp[0]*st*1.6)*f; dy=(fd[1]*m3+bp[1]*st*1.6)*f;}

  // — Armes / membres : rotation et cisaillement gradués (overlapping action) —
  else if(k==='swing'){var side=pr.side||(fd[0]>=0?1:-1);var px=cx,py=bellyY+1,
      lag=Math.min(0.13,Math.max(0,py-y)*0.006),                              // PHASE-LAG : plus on est haut (l'arme), plus on retarde
      el=_env(ph-lag),angg=(-el[0]*0.55+el[1]*1.6)*side,                      //   → l'arme TRAÎNE derrière le bras (suivi)
      rx=x-px,ry=y-py,ca=Math.cos(angg),sa=Math.sin(angg),hf=_sstep(0,10,py-y);// hf : rotation lissée, 0 aux hanches → pas de cassure
    dx=((px+rx*ca-ry*sa)-x)*hf; dy=((py+rx*sa+ry*ca)-y)*hf;}
  else if(k==='claw'){var hf2=Math.max(0,(groundY-y)/headSpan);hf2*=hf2;      // griffe : cisaillement latéral gradué par la hauteur
    var dir=fd[0]!==0?fd[0]:1; dx=(st*reach*dir-wu*pull*dir)*hf2; dy=-st*2.5*hf2;}
  else if(k==='lash'){if(y>bellyY-2){var f2=Math.min(1,(y-(bellyY-2))/Math.max(1,groundY-(bellyY-2))),
      el2=_env(ph-f2*0.16),stl=el2[1],wul=el2[0];                             // PHASE-LAG le long du tentacule : la pointe traîne = fouet
    dx=fd[0]*stl*reach*2.2*f2-wul*pull*fd[0]*f2; dy=fd[1]*stl*reach*0.9*f2-stl*3.2*f2;}}

  // — Incantations / éruptions / impacts —
  else if(k==='cast'){if(y<bellyY){var u=Math.max(0,(bellyY-y)/Math.max(1,bellyY-(cy-12)));
    dx=-fd[0]*(wu*3+st*2.2)*u; dy=-fd[1]*wu*2*u+st*0.8;}}                      // recul du buste, lissé vers le haut
  else if(k==='smite'){dy=-st*4.5+wu*1.6; dx=(x-cx)*st*0.03;}                  // se cabre vers le ciel
  else if(k==='shard'){var s2=st*0.09-wu*0.14; dx=(x-cx)*s2; dy=(y-cy)*s2;}    // inspire puis explose radialement
  else if(k==='slam'){var hf3=Math.max(0,(groundY-y)/headSpan);hf3*=hf3;       // abat le haut du corps au sol (gradué)
    dy=(-wu*7+st*10)*hf3+st*0.6;}
  else if(k==='surge'){var s3=-wu*0.16; dx=(x-cx)*s3+fd[0]*st*reach+(_h2(x,y)-0.5)*st*4.5;
    dy=(y-cy)*s3+fd[1]*st*reach+(_h2(y,x)-0.5)*st*4.5;}                        // déferlante chaotique (hash) vers l'avant
  else if(k==='wing'){var d2=Math.abs(x-cx);if(d2>bR*0.85){var wf=d2-bR*0.85;  // coup d'aile + bond avant
    dy=(-wu+st)*wf*0.8; dx=(x<cx?1:-1)*wf*st*0.35;} dx+=fd[0]*st*3; dy+=fd[1]*st*3;}
  else if(k==='engulf'){var mc=pr.mouth?{x:pr.mouth[0],y:pr.mouth[1]}:head,    // aspire le décor vers la gueule puis recrache
      ddx=x-mc.x,ddy=y-mc.y,dd=Math.hypot(ddx,ddy),nd=_nrm([ddx,ddy]),f3=Math.max(0,1-dd/(pr.mr||14));
    dx=nd[0]*(wu*4-st*6)*f3; dy=nd[1]*(wu*4-st*6)*f3;}
  else if(k==='spew'){var s4=st*0.07; dx=(x-cx)*s4; dy=(y-cy)*s4;             // vomit : gonfle + projette par la tête
    var dh2=Math.hypot(x-head.x,y-head.y),fh=Math.max(0,1-dh2/(head.r+7));
    dx+=fd[0]*st*3*fh; dy+=fd[1]*st*3*fh;}
  else if(k==='gaze'){var s5=st*0.06-wu*0.04; dx=(x-cx)*s5; dy=(y-cy)*s5;}    // regard : le corps se tend, l'effet fait le travail

  // — Cas spéciaux —
  else if(k==='phase'){var m6=st*reach-wu*pull;                               // clignote/translate avec ondulation
    dx=fd[0]*m6+Math.sin(ph*9+y*0.3)*st*2.2; dy=fd[1]*m6;}
  else if(k==='multi'){var parts=pr.parts||[];                               // MULTI-PARTIE : chaque partie a SA boucle décalée
    for(var pi=0;pi<parts.length;pi++){var P=parts[pi];
      var lp=((ph*(pr.loops||2)+(P.off||0))%1+1)%1;                          //   phase locale propre à la partie
      var le=_env(lp),lst=le[1],lwu=le[0],pf=_nrm(P.fd||[0,-1]);
      var dpx=x-P.x,dpy=y-P.y,ddp=Math.hypot(dpx,dpy),ff=Math.max(0,1-ddp/(P.r||5));
      if(ff<=0)continue;                                                     //   falloff autour du centre de la partie
      if(P.mode==='swipe'){var sg=pf[0]!==0?pf[0]:1; dx+=(sg*lst*(P.reach||7)-lwu*2*sg)*ff; dy+=-lst*2*ff;}
      else{var mm=lst*(P.reach||7)-lwu*2.5; dx+=pf[0]*mm*ff; dy+=pf[1]*mm*ff;}
    }}

  // — SKITTER : pattes qui gesticulent dans tous les sens (rotation par patte, déphasée) —
  if(k==='skitter'){var ox=pr.ox!=null?pr.ox:cx,oy=pr.oy!=null?pr.oy:cy,
      sdx=x-ox,sdy=y-oy,sr=Math.hypot(sdx,sdy),sang=Math.atan2(sdy,sdx),lf=_sstep(5,11,sr); // lf : 0 sur le corps → 1 sur les pattes
    if(lf>0){var stt=Math.max(st,0.35*_sstep(0.30,0.45,ph)*(1-_sstep(0.80,1.0,ph)));
      var th=(pr.amp||0.6)*Math.sin(ph*(pr.freq||11)+sang*2.7)*lf*stt,          // rotation oscillante, déphasée par l'angle de la patte
          ca2=Math.cos(th),sa2=Math.sin(th),nx=sdx*ca2-sdy*sa2,ny=sdx*sa2+sdy*ca2,
          rd=(pr.rad||3.2)*Math.sin(ph*8+sang*1.6+1.0)*lf*stt;                  // + extension/rétraction radiale
      dx=(nx-sdx)+Math.cos(sang)*rd; dy=(ny-sdy)+Math.sin(sang)*rd;}}

  return [dx,dy];
}
```

### Carte mentale des kinds

| Famille de geste | Kinds | Mécanisme clé |
|---|---|---|
| Élan du corps | `lunge`, `pounce`, `bite` | translation `fd` + squash-stretch + arc |
| Arme / membre | `swing`, `claw`, `lash` | rotation/cisaillement **gradué** + **phase-lag** (suivi) |
| Sortilège / souffle | `cast`, `smite`, `shard`, `spew`, `gaze`, `surge` | tension/expansion + effet `atkFx` |
| Impact / masse | `slam`, `wing`, `engulf` | abattement gradué / aspiration |
| Spéciaux | `phase`, `multi`, `skitter` | translation ondulée / parties indépendantes / pattes folles |

---

## 5. `atkFx` : la couche d'effets transitoires

Projectiles, arcs de lame, ondes de choc, rayons, gerbes d'éclats… dessinés **après** les pixels, en
fondu via `sp`/`fade`. Extrait réel (helpers + quelques effets) :

```js
function atkFx(ctx,sc,atk,A,p,glow){
  var ph=atk.ph,k=atk.k,pr=atk.pr||{},fd=_nrm(A.faceDir||[0,-1]),head=A.head||{x:32,y:26,r:4};
  var sp=_sstep(0.30,0.62,ph); if(sp<=0) return;             // l'effet ne vit que pendant la frappe
  var fade=1-_sstep(0.66,0.90,ph);
  var col=pr.fx||glow||(p&&p.eye)||'#fff', hot=(p&&p.bone)||'#fff';
  var mass0=(A.mass&&A.mass[0])?A.mass[0]:[32,34,9],cx=mass0[0],cy=mass0[1];

  function blk(gx,gy,s,c){ctx.globalAlpha=fade;ctx.fillStyle=c;
    ctx.fillRect(Math.round(gx*sc),Math.round(gy*sc),Math.max(1,Math.round(s*sc)),Math.max(1,Math.round(s*sc)));ctx.globalAlpha=1;}
  function ln(x0,y0,x1,y1,s,c){var n=Math.max(2,Math.ceil(Math.hypot(x1-x0,y1-y0)));
    for(var i=0;i<=n;i++)blk(x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,s,c);}

  if(k==='cast'){var ox=head.x+fd[0]*(head.r+1),oy=head.y+fd[1]*(head.r+1),     // projectile qui s'éloigne de la tête
      px=ox+fd[0]*sp*30,py=oy+fd[1]*sp*30;
    blk(px,py,3,col);blk(px-fd[0]*3,py-fd[1]*3,2,hot);blk(px-fd[0]*6,py-fd[1]*6,1,col);blk(ox,oy,2,hot);}
  else if(k==='swing'||k==='claw'){var R=(pr.reach||8)+7,base=Math.atan2(fd[1],fd[0]),arcs=k==='claw'?4:1; // arc(s) de lame balayé(s)
    for(var a=0;a<arcs;a++){var off=(a-(arcs-1)/2)*0.20,a0=base-0.7+sp*1.2;
      for(var s2=0;s2<9;s2++){var aa=a0+s2*0.15+off;blk(cx+Math.cos(aa)*R,cy+Math.sin(aa)*R*0.8,s2<2?2:1,s2<3?hot:col);}}}
  else if(k==='slam'){var rr=sp*26;for(var i2=0;i2<18;i2++){var an=i2/18*6.283;  // onde de choc au sol (anneau qui s'étend)
      blk(32+Math.cos(an)*rr,56+Math.sin(an)*rr*0.3,1,col);blk(32+Math.cos(an)*rr*0.7,56+Math.sin(an)*rr*0.3*0.7,1,hot);}}
  else if(k==='gaze'){ln(head.x,head.y,head.x+fd[0]*sp*30,head.y+fd[1]*sp*30,2,col);    // rayon depuis la tête
    ln(head.x,head.y,head.x+fd[0]*sp*30,head.y+fd[1]*sp*30,1,hot);}
  // … shard (gerbe d'éclats), spew (cône), smite (foudre verticale), wing (rafales),
  //   engulf (anneau qui se referme), surge (déferlante), multi (impacts par partie),
  //   lunge/pounce/bite (poussière à l'impact), skitter (petites projections).
  ctx.globalAlpha=1;
}
```

Principe (issu de « *The Art of Screenshake* » / « *Juice it or lose it* ») : **l'effet vend l'impact**.
Particules, arcs et ondes scalés sur `sp` rendent la frappe lisible même à petite échelle, là où la
seule déformation du corps ne suffirait pas.

---

## 6. La table `ATK` : un kind par archétype

```js
var ATK={
  // morts-vivants
  skeleton:{k:'swing',side:-1}, skeletonquad:{k:'pounce'}, revenant:{k:'claw'},
  // bêtes / démons
  dragon:{k:'bite',reach:7}, behemoth:{k:'pounce',reach:7,leap:4}, direcat:{k:'pounce'},
  fiend:{k:'claw'}, imp:{k:'claw'}, mantis:{k:'claw',reach:8},
  // céphalo / abyssal
  octopus:{k:'lash'}, squid:{k:'lash'}, reef:{k:'lash'},
  // arachnides → SKITTER (pattes folles), origine au centre du corps
  spider:{k:'skitter',ox:32,oy:37}, widow:{k:'skitter',ox:32,oy:38},
  // multi-partie : la chimère, chaque tête/griffe/aile frappe sur sa boucle
  // chimera:{k:'multi',loops:2,parts:[{x:..,y:..,fd:[..],r:..,reach:..,off:0}, …]},
  // … 97 entrées au total
};
```

Choisir un kind = décrire **comment cette créature frappe**, pas la redessiner. Les `params` (reach,
side, leap, mouth, parts, ox/oy, fx…) ajustent l'amplitude et la géométrie.

---

## 7. La boucle : alterner repos ↔ attaque

```js
var ATK_ON=true, IDLE_DUR=1.3, ATK_DUR=1.05, CYCLE=IDLE_DUR+ATK_DUR;

function _animLoop(now){
  requestAnimationFrame(_animLoop);
  if(now-_alast<33) return; _alast=now; var t=now/1000;
  for(var i=0;i<CARDS.length;i++){
    var c=CARDS[i], ap=null;
    if(c.fire!=null){                                    // tir manuel (clic) prioritaire
      var e=t-c.fire; if(e<=ATK_DUR) ap=Math.max(0,e)/ATK_DUR; else c.fire=null;
    }
    if(ap==null && ATK_ON && c.atk){                     // sinon cycle auto, décalé par carte (i*0.13)
      var ofs=(t+i*0.13)%CYCLE-IDLE_DUR; if(ofs>=0) ap=ofs/ATK_DUR;
    }
    c.prof._atk=(ap!=null && c.atk)?{k:c.atk.k,pr:c.atk,ph:ap}:null;  // injecte la phase d'attaque
    try{ blit(c.g,c.cv,GAL_SCALE,57,c.p.eye,c.fl,t,c.prof,c.A,c.p); }catch(e2){}
  }
}
```

- **Clic sur une carte** → `c.fire=now` → une attaque jouée immédiatement.
- **Décalage `i*0.13`** → les cartes n'attaquent pas toutes en même temps (vague visuelle).
- Boutons « ⚔ attaques auto/off » et « ▶ frapper tout » (met `fire=now` sur toutes les cartes).

---

## 8. Les correctifs validés par la recherche (et où ils sont)

| Correctif | Principe | Emplacement |
|---|---|---|
| **Déformation lissée** (anti-cassure) | poids de skinning normalisés (LBS, Σ poids = 1) ; jamais de seuil dur | `hf`/`hf2`/`hf3`/`f`/`f2` dans `swing`/`claw`/`slam`/`bite`/`lash` |
| **Squash-and-stretch** | volume conservé (étire ⊥ comprime) | `_dscale` dans `lunge`/`pounce` |
| **Overlapping action (suivi)** | les extrémités traînent → fouet | `lag`/`el` dans `swing`, `el2` dans `lash` |
| **Smootherstep** | départs/arrêts C²-continus | `_smoo` dans `_env` |
| **Hit-stop** | maintien de la pose de frappe | plateau 0.44→0.66 de `_env` |
| **Juice** (l'effet vend le coup) | particules/arcs/ondes scalés sur la frappe | `atkFx` |

> Références citables (voir Annexe R / dossier de recherche) : Thomas & Johnston *The Illusion of Life* ;
> Jakobsen « Advanced Character Physics » (GDC 2001) ; Juckett « Analytic Two-Bone IK » ; Hecker et al.
> (Spore, SIGGRAPH 2008) ; Penner easing + smootherstep de Perlin ; Nijman « The Art of Screenshake » ;
> Jonasson & Purho « Juice It or Lose It ».

**Pistes non encore implémentées** (recommandées par la recherche, pour aller plus loin) : remplacer
les profils sinusoïdaux passifs (tentacules, queues) par des **chaînes de Verlet** (Jakobsen) pour un
suivi émergent ; **IK analytique deux-os** pour un membre qui doit *atteindre une cible précise*.

---

### Prochain document
**Document 04 — Biomes** : décors en couches tileables, dithering ordonné de Bayer, ridgelines par
somme de sinus entières, brume, parallaxe, et dé-doublonnage des motifs.
