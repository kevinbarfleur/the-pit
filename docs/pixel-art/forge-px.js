/* ============================================================
   FORGE-PX — moteur pixel-art PREMIUM (The Pit)
   Dark fantasy cauchemardesque. Grille basse-réso assumée,
   gros pixels nets (×PX nearest-neighbor), biseaux DURS et
   propres (teintes franches, aucun bruit aléatoire).
   window.ForgePX.boot(rootEl, {accent, restless})

   SOURCE CANONIQUE — récupérée du projet claude.ai/design
   "Prototype grimdark pixel-perfect" (fichier Forge UI.dc.html).
   À PORTER en Lua/LÖVE (src/ui/forge.lua) — cf. ui-artisan.
   ============================================================ */
(function () {
  "use strict";

  var PX = 4;          // taille d'un pixel d'art à l'écran (net, nearest-neighbor)
  var RESTLESS = true;

  /* ---- maths ---- */
  function mulberry32(a){ return function(){ a|=0; a=a+0x6D2B79F5|0; var t=Math.imul(a^a>>>15,1|a); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; }; }
  function clamp(v){ return v<0?0:v>1?1:v; }
  function mix(a,b,t){ return [a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t]; }
  function hexRgb(h){ h=h.replace('#',''); return [parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)]; }
  function pulse(t,s){ return clamp(0.5+0.3*Math.sin(t*1.6+s)+0.16*Math.sin(t*0.73+s*2.1)); }
  function elerp(a,b,k){ return a+(b-a)*k; }

  /* ---- palettes (franches, dark fantasy) ---- */
  var PLATE={ top:hexRgb('#191222'), bot:hexRgb('#0a0612'), vig:hexRgb('#040108') };
  var METAL={ outline:hexRgb('#080503'), deep:hexRgb('#34250f'), mid:hexRgb('#6a5022'), base:hexRgb('#9c7a36'), hi:hexRgb('#d8b65e'), spec:hexRgb('#f6e6a4') };
  var SCLERA={ pale:hexRgb('#d8cfb6'), shade:hexRgb('#9c917a'), vein:hexRgb('#9c2222') };
  var PUPIL=hexRgb('#070409');
  var BLOOD={ d1:hexRgb('#1c060c'), d2:hexRgb('#5a1018'), d3:hexRgb('#9c2020'), hot:hexRgb('#e8483c') };

  var ACCENTS={
    gold:  {dark:hexRgb('#7a5e24'),mid:hexRgb('#c49a3e'),bright:hexRgb('#f2d98a')},
    blood: {dark:hexRgb('#5a1414'),mid:hexRgb('#c03a30'),bright:hexRgb('#ff6a52')},
    bile:  {dark:hexRgb('#2c440e'),mid:hexRgb('#6f9e26'),bright:hexRgb('#aee048')},
    violet:{dark:hexRgb('#3a1e54'),mid:hexRgb('#7a44b4'),bright:hexRgb('#cf9cff')}
  };
  var ACC=ACCENTS.gold;
  function setAccent(n){ if(ACCENTS[n])ACC=ACCENTS[n]; }

  var LIQ={
    blood:  {dark:hexRgb('#2a060a'),mid:hexRgb('#8c1c20'),bright:hexRgb('#ec5040')},
    mana:   {dark:hexRgb('#0a1428'),mid:hexRgb('#22508e'),bright:hexRgb('#5ea0f0')},
    essence:{dark:hexRgb('#180a30'),mid:hexRgb('#4e2488'),bright:hexRgb('#bc8cf4')}
  };
  var FAM={
    flesh: {c:hexRgb('#cc5a44'),d:hexRgb('#3a1410'),shape:'bar'},
    order: {c:hexRgb('#dcb85c'),d:hexRgb('#4a3814'),shape:'cross'},
    bone:  {c:hexRgb('#d0c098'),d:hexRgb('#473a2c'),shape:'diamond'},
    arcane:{c:hexRgb('#c47cae'),d:hexRgb('#33182c'),shape:'star'},
    abyss: {c:hexRgb('#b86a8e'),d:hexRgb('#2a1220'),shape:'disc'}
  };
  var AFFL={
    burn:  {c:hexRgb('#f0903a'), bmp:["001000","001100","011110","111110","011100"]},
    poison:{c:hexRgb('#8fd06a'), bmp:["001000","011100","111110","111110","011100"]},
    bleed: {c:hexRgb('#e8483c'), bmp:["001000","011100","111110","110110","011100"]}
  };

  /* ============================================================ */
  function Buf(w,h){ this.w=w; this.h=h; this.d=new Uint8ClampedArray(w*h*4); }
  Buf.prototype.set=function(x,y,c,a){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; this.d[i]=c[0];this.d[i+1]=c[1];this.d[i+2]=c[2];this.d[i+3]=(a==null?255:a*255); };
  Buf.prototype.blend=function(x,y,c,a){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; var ba=this.d[i+3]/255,na=a+ba*(1-a); if(na<=0)return; for(var k=0;k<3;k++)this.d[i+k]=(c[k]*a+this.d[i+k]*ba*(1-a))/na; this.d[i+3]=na*255; };
  Buf.prototype.add=function(x,y,c,k){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; if(this.d[i+3]===0)this.d[i+3]=255; this.d[i]=Math.min(255,this.d[i]+c[0]*k);this.d[i+1]=Math.min(255,this.d[i+1]+c[1]*k);this.d[i+2]=Math.min(255,this.d[i+2]+c[2]*k); };
  Buf.prototype.toCanvas=function(cv){ var ctx=cv.getContext('2d'); var id=ctx.createImageData(this.w,this.h); id.data.set(this.d); ctx.putImageData(id,0,0); };

  /* ---- texte basse-réso ---- */
  var _tc={};
  function textMask(txt,size){ size=size||9; var key=size+'|'+txt; if(_tc[key])return _tc[key];
    var sp=Math.round(size*0.66), o=document.createElement('canvas'); o.width=Math.max(1,txt.length*sp+2); o.height=size+3;
    var oc=o.getContext('2d'); oc.imageSmoothingEnabled=false; oc.textBaseline='top'; oc.font=size+'px "Courier New",monospace'; oc.fillStyle='#fff';
    var cx=1; for(var i=0;i<txt.length;i++){ oc.fillText(txt[i],cx,1); cx+=sp; }
    var d=oc.getImageData(0,0,o.width,o.height).data, pix=[], mnx=9999,mxx=0,mny=9999,mxy=0;
    for(var y=0;y<o.height;y++)for(var x=0;x<o.width;x++){ if(d[(y*o.width+x)*4+3]>120){ pix.push([x,y]); if(x<mnx)mnx=x;if(x>mxx)mxx=x;if(y<mny)mny=y;if(y>mxy)mxy=y; } }
    var m={ w:(mxx-mnx+1)||1, h:(mxy-mny+1)||1, pix:pix.map(function(p){return [p[0]-mnx,p[1]-mny];}) };
    _tc[key]=m; return m;
  }
  function text(buf,txt,ax,y,color,o){ o=o||{}; var m=textMask(txt,o.size||9); var ox=o.left?ax:Math.round(ax-m.w/2),i,p;
    if(o.shadow){ for(i=0;i<m.pix.length;i++){ p=m.pix[i]; buf.set(ox+p[0]+1,y+p[1]+1,o.shadow); } }
    if(o.glow>0.02){ for(i=0;i<m.pix.length;i++){ p=m.pix[i]; buf.add(ox+p[0]-1,y+p[1],ACC.mid,o.glow*0.5); buf.add(ox+p[0]+1,y+p[1],ACC.mid,o.glow*0.5); buf.add(ox+p[0],y+p[1]-1,ACC.mid,o.glow*0.5); } }
    for(i=0;i<m.pix.length;i++){ p=m.pix[i]; var c=o.glow>0.02?mix(color,ACC.bright,clamp(o.glow)):color; buf.set(ox+p[0],y+p[1],c); }
    return m.w;
  }
  function measure(txt,size){ return textMask(txt,size||9).w; }

  /* ---- bitmaps ---- */
  function blit(buf,bmp,x,y,color){ for(var r=0;r<bmp.length;r++)for(var c=0;c<bmp[r].length;c++){ if(bmp[r][c]==='1')buf.set(x+c,y+r,color); } }

  /* ============================================================
     PRIMITIVES NETTES
     ============================================================ */
  function plate(buf,x0,y0,x1,y1,press,disabled){
    var top=PLATE.top,bot=PLATE.bot;
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){
      var vy=(y-y0)/Math.max(1,y1-y0), col=mix(top,bot,vy);
      var ed=Math.min(x-x0,x1-x,y-y0,y1-y);
      if(ed<2)col=mix(col,PLATE.vig,0.5*(2-ed)/2);
      if((y&1)===0)col=mix(col,[0,0,0],0.10);            // scanline propre
      if(press>0)col=mix(col,PLATE.vig,press*0.22);
      if(disabled)col=mix(col,[28,26,32],0.42);
      buf.set(x,y,col);
    }
  }
  function frame(buf,x0,y0,x1,y1,o){
    o=o||{}; var th=o.t||3, M=o.metal||METAL;
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){
      var dT=y-y0,dB=y1-y,dL=x-x0,dR=x1-x,dm=Math.min(dT,dB,dL,dR);
      if(dm>=th)continue;
      var lit=(dm===dT||dm===dL), col;
      if(dm===0)col=M.outline;
      else if(dm===th-1) col=o.accent? mix(ACC.dark,ACC.bright,lit?0.75:0.28) : (lit?M.base:M.deep);
      else col= lit? mix(M.hi,M.base,(dm-1)/Math.max(1,th-2)) : mix(M.deep,M.mid,(dm-1)/Math.max(1,th-2));
      if(o.disabled)col=mix(col,[44,42,38],0.55);
      buf.set(x,y,col);
    }
    // étincelle ponctuelle haut-gauche
    if(!o.disabled){ buf.set(x0+1,y0+1,M.spec); }
  }
  function rivet(buf,x,y,M){ M=M||METAL; buf.set(x,y,M.base); buf.set(x+1,y,M.deep); buf.set(x,y+1,M.deep); buf.set(x+1,y+1,M.outline); buf.set(x,y,M.spec); }
  function dropShadow(buf,W,yb,press){ for(var dy=0;dy<2;dy++)for(var x=2;x<W-2;x++){ var edge=Math.abs(x-W/2)/(W/2); buf.blend(x,yb+dy,[0,0,0],(0.55-dy*0.22)*(1-edge*0.5)*(1-press*0.6)); } }

  function diamond(buf,cx,cy,r,fill,edge,spec){
    for(var y=-r;y<=r;y++)for(var x=-r;x<=r;x++){ var m=Math.abs(x)+Math.abs(y); if(m<=r){ buf.set(Math.round(cx+x),Math.round(cy+y), m>=r-0.5?edge:fill); } }
    if(spec)buf.set(Math.round(cx-r*0.3),Math.round(cy-r*0.3),spec);
  }
  function pill(buf,x0,y0,x1,y1,col){ var h=y1-y0,r=h/2,cyl=(y0+y1)/2; for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){ var ins=true; if(x<x0+r)ins=Math.hypot(x-(x0+r),y-cyl)<=r+0.3; else if(x>x1-r)ins=Math.hypot(x-(x1-r),y-cyl)<=r+0.3; if(ins)buf.set(x,y,col); } }

  /* ============================================================
     ŒIL CAUCHEMARDESQUE (net, injecté de sang)
     ============================================================ */
  function drawEye(buf,cx,cy,r,open,glow,t,seed,opts){
    opts=opts||{};
    var squash=opts.squash||0.62, gaze=opts.gaze, pupil=opts.pupil||'slit', blood=opts.blood||0;
    var bt=(t*0.6+seed*2.3)%6.0, blink=bt>5.6?(1-Math.abs(bt-5.8)/0.2):0;
    var op=clamp(open*(1-clamp(blink))), ry=r*squash*op;
    if(ry<0.6){ for(var x=-r;x<=r;x++)buf.set(Math.round(cx+x),Math.round(cy),mix(METAL.deep,[0,0,0],0.4)); return; }
    var y,X,Y,ex,ey;
    // sclère
    for(y=-Math.ceil(ry);y<=Math.ceil(ry);y++)for(x=-Math.ceil(r);x<=Math.ceil(r);x++){
      ex=x/r; ey=y/ry; if(ex*ex+ey*ey>1)continue;
      var base=mix(SCLERA.pale,SCLERA.shade, clamp(Math.abs(ex)*0.5+Math.abs(ey)*0.55));
      if(blood>0)base=mix(base,BLOOD.d3,blood*0.18);
      buf.set(Math.round(cx+x),Math.round(cy+y),base);
    }
    // veines (délibérées, propres)
    var nv=2+Math.round(blood*3), rnd=mulberry32((seed*101)|0);
    for(var v=0;v<nv;v++){ var a=rnd()*6.28, vx=cx+Math.cos(a)*r*0.96, vy=cy+Math.sin(a)*ry*0.96;
      for(var k=0;k<Math.ceil(r*0.6);k++){ ex=(vx-cx)/r; ey=(vy-cy)/ry; if(ex*ex+ey*ey<=1)buf.blend(Math.round(vx),Math.round(vy),SCLERA.vein,0.42+blood*0.3); vx+=(cx-vx)*0.18+(rnd()-0.5)*0.4; vy+=(cy-vy)*0.18; } }
    // iris + pupille
    var gx=0,gy=0; if(gaze){ var dx=gaze[0]-cx,dy=gaze[1]-cy,dl=Math.hypot(dx,dy)||1,mo=r*0.30; gx=dx/dl*mo; gy=dy/dl*mo*squash; } else { gx=Math.sin(t*0.5+seed)*r*0.22; gy=Math.cos(t*0.4+seed*1.3)*ry*0.4; }
    var ir=Math.max(2,Math.round(r*0.52));
    for(y=-ir;y<=ir;y++)for(x=-ir;x<=ir;x++){ var d=Math.hypot(x,y); if(d>ir)continue; var ax=gx+x,ay=gy+y; if((ax/r)*(ax/r)+(ay/ry)*(ay/ry)>1)continue;
      var dd=d/ir, col=mix(mix(ACC.mid,ACC.bright,glow),ACC.dark,dd), isP;
      isP = pupil==='slit'? (Math.abs(x)<ir*0.30*(1-0.32*Math.abs(y)/ir)) : dd<0.46;
      if(isP)col=PUPIL; else if(dd>0.84)col=mix(col,[0,0,0],0.5);
      buf.set(Math.round(cx+ax),Math.round(cy+ay),col);
    }
    buf.set(Math.round(cx+gx-ir*0.3),Math.round(cy+gy-ir*0.3),[255,255,255]);
    // paupières
    for(x=-r;x<=r;x++){ ex=x/r; if(Math.abs(ex)>1)continue; var lh=Math.sqrt(Math.max(0,1-ex*ex))*ry; buf.set(Math.round(cx+x),Math.round(cy-lh),mix(METAL.deep,[0,0,0],0.35)); buf.set(Math.round(cx+x),Math.round(cy+lh),mix(METAL.deep,[0,0,0],0.55)); }
  }

  /* ============================================================
     BOUTON + nuée d'yeux
     ============================================================ */
  var DROP=2, TH=3;
  function genEyes(W,hslab,seed,label,size){
    var rnd=mulberry32((seed*9301+7)|0), m=textMask(label,size||9), lw=m.w, lh=m.h;
    var lx0=Math.round(W/2-lw/2)-2, lx1=Math.round(W/2+lw/2)+2, ly0=Math.round(hslab/2-lh/2)-1, ly1=Math.round(hslab/2+lh/2)+1;
    var n=Math.max(2,Math.min(7,Math.round((W-2*TH)/16))), eyes=[], tries=0;
    while(eyes.length<n&&tries<n*16){ tries++;
      var r=2+Math.floor(rnd()*3);
      var ex=TH+r+rnd()*(W-2*(TH+r)), ey=TH+r*0.7+rnd()*(hslab-2*TH-r*1.4);
      if(ex>lx0-r&&ex<lx1+r&&ey>ly0-r&&ey<ly1+r)continue;
      var ok=true; for(var j=0;j<eyes.length;j++){ if(Math.hypot(ex-eyes[j].ex,ey-eyes[j].ey)<(r+eyes[j].r)*0.95){ ok=false; break; } }
      if(!ok)continue;
      eyes.push({ex:ex,ey:ey,r:r,squash:0.5+rnd()*0.28,pupil:rnd()<0.7?'slit':'round',blood:rnd()<0.5?0.4+rnd()*0.6:0,phase:rnd()*10});
    }
    return eyes;
  }
  function drawButton(buf,W,H,press,eyeOpen,glow,seed,label,disabled,eyes,gaze,size,t){
    var hslab=H-DROP, slabY=Math.round(press*DROP);
    dropShadow(buf,W,hslab,press);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    plate(buf,x0+TH,y0+TH,x1-TH,y1-TH,press,disabled);
    if(!disabled&&eyes&&eyeOpen>0.02){ for(var i=0;i<eyes.length;i++){ var e=eyes[i];
      var g=gaze?[gaze[0],gaze[1]]:null;
      drawEye(buf,Math.round(e.ex),Math.round(slabY+e.ey),e.r,eyeOpen,glow,t,seed+e.phase,{squash:e.squash,pupil:e.pupil,blood:e.blood,gaze:g});
    } }
    frame(buf,x0,y0,x1,y1,{t:TH,accent:!disabled,disabled:disabled});
    rivet(buf,x0+3,y0+3,METAL); rivet(buf,x1-4,y0+3,METAL); rivet(buf,x0+3,y1-4,METAL); rivet(buf,x1-4,y1-4,METAL);
    if(disabled){ for(var dx=x0+6;dx<x1-6;dx+=3){ buf.set(dx,y0+1,hexRgb('#2a200f')); buf.set(dx,y1-1,hexRgb('#2a200f')); } }
    text(buf,label,W/2,slabY+Math.round((hslab-(size||9)*0.78)/2),disabled?hexRgb('#5a5040'):hexRgb('#f0d68e'),{size:size||9,glow:disabled?0:glow*0.6,shadow:hexRgb('#1a1206')});
  }

  function drawEcoBtn(buf,W,H,press,glow,seed,label,cost,disabled,t){
    var hslab=H-DROP, slabY=Math.round(press*DROP);
    dropShadow(buf,W,hslab,press);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    plate(buf,x0+2,y0+2,x1-2,y1-2,press,disabled);
    frame(buf,x0,y0,x1,y1,{t:2,accent:!disabled,disabled:disabled});
    rivet(buf,x0+2,y0+2,METAL); rivet(buf,x0+2,y1-3,METAL);
    var cy=slabY+Math.round((hslab-7)/2);
    text(buf,label,(W-(cost!=null?9:0))/2,cy,disabled?hexRgb('#5a5040'):hexRgb('#e8cd84'),{size:8,glow:disabled?0:glow*0.5,shadow:hexRgb('#1a1206')});
    if(cost!=null){ var gx=x1-6, gy=slabY+hslab/2; diamond(buf,gx,gy,2,disabled?ACC.dark:ACC.bright,ACC.dark,disabled?null:[255,255,255]); text(buf,String(cost),gx-7,gy-3,disabled?hexRgb('#5a5040'):hexRgb('#e8dcc0'),{left:true,size:8}); }
  }

  function drawIconBtn(buf,W,H,press,glow,seed,kind,t){
    var hslab=H-DROP, slabY=Math.round(press*DROP);
    dropShadow(buf,W,hslab,press);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    plate(buf,x0+2,y0+2,x1-2,y1-2,press,false);
    frame(buf,x0,y0,x1,y1,{t:2,accent:true});
    rivet(buf,x0+2,y0+2,METAL); rivet(buf,x1-3,y0+2,METAL); rivet(buf,x0+2,y1-3,METAL); rivet(buf,x1-3,y1-3,METAL);
    var cx=Math.round(W/2),cy=Math.round(slabY+hslab/2),col=mix(METAL.hi,ACC.bright,glow*0.7),r=Math.round(hslab*0.26);
    if(kind==='sigil'){ var amp=0.4+glow*1.2+press*0.6; for(var s=0;s<5;s++){ var a=s/5*6.28-1.57, ax=Math.round(cx+Math.cos(a)*r+Math.sin(t*3+s)*amp), ay=Math.round(cy+Math.sin(a)*r+Math.cos(t*3+s)*amp); for(var rr=0;rr<r;rr++)buf.set(Math.round(cx+(ax-cx)*rr/r),Math.round(cy+(ay-cy)*rr/r),col); } buf.set(cx,cy,ACC.bright); }
    else if(kind==='left'||kind==='right'){ var dir=kind==='left'?-1:1; for(var k=-r;k<=r;k++){ var xx=Math.round(cx-dir*r*0.4+dir*Math.abs(k)*0.8); buf.set(xx,cy+k,col); buf.set(xx-dir,cy+k,mix(col,METAL.outline,0.4)); } }
    else if(kind==='gear'){ blit(buf,["010010","111111","110011","110011","111111","010010"],cx-3,cy-3,col); }
  }

  /* ============================================================
     ORBE + nageuse (net)
     ============================================================ */
  function drawOrb(buf,W,H,level,liq,seed,t){
    var cx=W/2-0.5,cy=H/2-0.5,Rc=Math.min(W,H)/2-0.5,rIn=Rc-2;
    var surfB=cy+rIn-2*clamp(level)*rIn;
    function sAt(x){ return surfB+Math.sin(x*0.5+t*2.0)*1.0+Math.sin(x*0.21-t*1.3)*0.6; }
    var y,x;
    for(y=Math.floor(cy-rIn);y<=Math.ceil(cy+rIn);y++)for(x=Math.floor(cx-rIn);x<=Math.ceil(cx+rIn);x++){
      var dx=x-cx,dy=y-cy,d=Math.sqrt(dx*dx+dy*dy); if(d>rIn+0.4)continue;
      var nx=dx/rIn,ny=dy/rIn,sph=clamp(0.5+(-nx*0.5-ny*0.6)*0.55),edge=1-Math.pow(clamp(d/rIn),3)*0.6,surf=sAt(x),col;
      if(y>=surf){ var depth=clamp((y-surf)/(rIn*2)); col=mix(liq.bright,liq.dark,clamp(0.1+depth*1.2)); col=mix(col,liq.mid,0.3); col=mix(mix(col,[0,0,0],0.42*(1-sph)),col,0.55); col=[col[0]*edge,col[1]*edge,col[2]*edge]; if(y<surf+1.2)col=mix(col,liq.bright,0.7); }
      else { col=mix(hexRgb('#0a0712'),hexRgb('#1a1430'),sph); col=[col[0]*edge,col[1]*edge,col[2]*edge]; }
      buf.set(x,y,col);
    }
    // nageuse
    var ct=((t*0.07+seed*0.37)%1);
    if(ct<0.5){ var prog=ct/0.5, hx=cx-rIn-3+prog*(2*rIn+6), hy=cy+rIn*0.2+Math.sin(t*1.3+seed)*rIn*0.2;
      for(var sg=0;sg<9;sg++){ var bx=hx-sg*1.3, by=hy+Math.sin(t*2.2-sg*0.55)*2.0, br=Math.max(0.6,1.7-sg*0.12);
        for(var oy=-Math.ceil(br);oy<=Math.ceil(br);oy++)for(var ox=-Math.ceil(br);ox<=Math.ceil(br);ox++){ if(ox*ox+oy*oy>br*br)continue; var XX=Math.round(bx+ox),YY=Math.round(by+oy); if(Math.hypot(XX-cx,YY-cy)>rIn-1)continue; if(YY>=sAt(XX))buf.blend(XX,YY,[4,2,6],0.6); } }
      var ehx=Math.round(hx),ehy=Math.round(hy); if(ehy>=sAt(ehx)&&Math.hypot(ehx-cx,ehy-cy)<rIn-1){ buf.set(ehx,ehy,ACC.bright); buf.add(ehx,ehy,ACC.bright,0.8); }
    }
    // reflet
    var sx=cx-rIn*0.36,sy=cy-rIn*0.4,sa=rIn*0.4,sb=rIn*0.24;
    for(y=Math.floor(sy-sb);y<=Math.ceil(sy+sb);y++)for(x=Math.floor(sx-sa);x<=Math.ceil(sx+sa);x++){ var exx=(x-sx)/sa,eyy=(y-sy)/sb,e=exx*exx+eyy*eyy; if(e>1)continue; buf.add(x,y,[255,255,255],(1-e)*0.32); }
    // anneau métal net
    var rOut=Rc,rInr=Rc-2;
    for(y=Math.floor(cy-Rc-1);y<=Math.ceil(cy+Rc+1);y++)for(x=Math.floor(cx-Rc-1);x<=Math.ceil(cx+Rc+1);x++){ var dx2=x-cx,dy2=y-cy,d2=Math.sqrt(dx2*dx2+dy2*dy2); if(d2<rInr-0.5||d2>rOut+0.5)continue; var lit=(-dx2/d2*0.4-dy2/d2*0.55); var col2=(d2>=rOut-0.5||d2<=rInr+0.5)?METAL.outline:(lit>0?mix(METAL.mid,METAL.hi,lit):mix(METAL.deep,METAL.mid,-lit)); buf.set(x,y,col2); }
    rivet(buf,Math.round(cx-1),Math.round(cy-Rc+1),METAL); rivet(buf,Math.round(cx-1),Math.round(cy+Rc-2),METAL); rivet(buf,Math.round(cx-Rc+1),Math.round(cy-1),METAL); rivet(buf,Math.round(cx+Rc-2),Math.round(cy-1),METAL);
  }

  /* ============================================================
     JAUGE DE VIE + faim + segments + alarme
     ============================================================ */
  function drawGauge(buf,W,H,val,segs,t){
    var barH=8, x0=2,y0=2,x1=W-3,y1=barH-3, innerW=x1-x0+1, deep=hexRgb('#070409');
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)buf.set(x,y,mix(hexRgb('#0a0712'),hexRgb('#181226'),((x+y)&1)*0.3));
    var low=val<0.25, breath=Math.sin(t*2)*0.5, spasm=low?Math.sin(t*9)*1.2:0, fwf=innerW*clamp(val)+breath+spasm, p=low?(0.55+0.45*Math.sin(t*7)):1;
    var acc=LIQ.blood;
    for(var y2=y0;y2<=y1;y2++){ var frontX=x0+fwf+Math.sin(y2*0.9+t*3)*0.8;
      for(var x2=x0;x2<=x1;x2++){ if(x2>frontX)break; var col=mix(acc.dark,acc.mid,0.4+((x2+y2)&1)*0.18);
        var ff=(frontX-x2)/innerW, sa=0; for(var k=0;k<segs.length;k++){ if(ff<sa+segs[k].frac&&ff>=sa)col=mix(segs[k].color,col,0.3); sa+=segs[k].frac; }
        if(y2<y0+1)col=mix(col,acc.bright,0.5); else if(y2>y1-1)col=mix(col,deep,0.45);
        if(low)col=mix(col,acc.bright,(p-0.55)*0.5);
        buf.set(x2,y2,col);
      }
      var fx=Math.round(frontX); if(fx>=x0&&fx<=x1){ buf.set(fx,y2,mix(acc.bright,acc.mid,0.2)); buf.add(fx+1,y2,acc.mid,0.5*p); }
    }
    frame(buf,0,0,W-1,barH-1,{t:2});
    if(low){ for(var b=0;b<2;b++){ var dx=Math.round((Math.sin(t*2+b)*0.5+0.5)*(W-6))+3; buf.blend(dx,barH+((t*4+b*3)|0)%4,BLOOD.hot,0.5); } }
    var ix=1; for(var s=0;s<segs.length;s++){ if(segs[s].bmp){ blit(buf,segs[s].bmp,ix,barH+1,segs[s].color); ix+=7; } }
  }

  /* ============================================================
     CADRE 9-SLICE + respiration + veines + œil
     ============================================================ */
  function veins(buf,x0,y0,x1,y1,seed,t){
    var starts=[[x0+3,y0+3,0.8],[x1-3,y0+3,2.4],[x0+3,y1-3,5.5],[x1-3,y1-3,3.9]];
    for(var s=0;s<4;s++){ var rnd=mulberry32((seed*7+s*131)|0), len=Math.round((5+rnd()*5)*(0.7+0.3*pulse(t,seed+s))), x=starts[s][0],y=starts[s][1],dir=starts[s][2];
      for(var i=0;i<len;i++){ buf.blend(Math.round(x),Math.round(y),BLOOD.d2,0.7); if(i%3===1)buf.add(Math.round(x),Math.round(y),BLOOD.d3,0.4*pulse(t,seed+s+i)); dir+=(rnd()-0.5)*0.7; var nx=Math.min(x-x0,x1-x),ny=Math.min(y-y0,y1-y); if(Math.min(nx,ny)>5)dir+=(nx<ny?(x<(x0+x1)/2?0.4:-0.4):(y<(y0+y1)/2?0.4:-0.4)); x+=Math.cos(dir);y+=Math.sin(dir); if(x<x0+1||x>x1-1||y<y0+1||y>y1-1)break; }
    }
  }
  function drawPanel(buf,W,H,t,title){
    var B=3;
    plate(buf,B,B,W-B-1,H-B-1,0,false);
    for(var y=B+1;y<H-B-1;y++)for(var x=B+1;x<W-B-1;x++){ var m=Math.sin(x*0.5+t*0.6)+Math.sin(y*0.6-t*0.5); if(m>1.4)buf.blend(x,y,[6,4,12],0.18*(m-1.4)); }
    veins(buf,B,B,W-B-1,H-B-1,77,t);
    var ec=((t*0.09+0.3)%1), eo=ec<0.16?Math.sin(ec/0.16*Math.PI):0;
    if(eo>0.01)drawEye(buf,Math.round(W*0.7),Math.round(H*0.58),4,clamp(eo),0.5,t,909,{blood:0.6});
    frame(buf,0,0,W-1,H-1,{t:B,accent:true});
    rivet(buf,B,B,METAL); rivet(buf,W-B-1,B,METAL); rivet(buf,B,H-B-1,METAL); rivet(buf,W-B-1,H-B-1,METAL);
    if(title)text(buf,title,W/2,4,hexRgb('#e8cd84'),{glow:0.4+0.14*pulse(t,2),shadow:hexRgb('#1a1206'),size:9});
  }
  function drawTooltip(buf,W,H,t,lines){
    var B=2; plate(buf,B,B,W-B-1,H-B-1,0,false); veins(buf,B,B,W-B-1,H-B-1,42,t);
    frame(buf,0,0,W-1,H-1,{t:B,accent:true}); rivet(buf,B,B,METAL); rivet(buf,W-B-1,B,METAL); rivet(buf,B,H-B-1,METAL); rivet(buf,W-B-1,H-B-1,METAL);
    var y=4; for(var i=0;i<lines.length;i++){ text(buf,lines[i].txt,5,y,lines[i].gold?hexRgb('#e8cd84'):(lines[i].color||hexRgb('#b8a98c')),{left:true,glow:lines[i].gold?0.3:0,size:lines[i].size||8,shadow:hexRgb('#120c06')}); y+=(lines[i].gap||9); }
  }
  function drawBanner(buf,W,H,word,kind,t){
    var col=kind==='defeat'?hexRgb('#c43830'):hexRgb('#dcb85c'), glo=kind==='defeat'?BLOOD.hot:ACC.bright, my=Math.round(H/2);
    for(var ry=-1;ry<=1;ry+=2){ var yy=my+ry*(H/2-2); for(var x=3;x<W-3;x++){ var a=1-Math.abs(x-W/2)/(W/2-3); buf.set(x,yy,mix(METAL.outline,METAL.hi,0.55*a)); } }
    text(buf,word,W/2,my-5,mix(col,glo,0.25*(0.7+0.3*Math.sin(t*3))),{size:13,shadow:METAL.outline});
  }

  /* ============================================================
     CARTE DE RELIQUE
     ============================================================ */
  function drawRelicCard(buf,W,H,state,relic,t){
    var sel=state==='selected', hov=state==='hover', B=3;
    plate(buf,B,B,W-B-1,H-B-1,sel?-0.15:0,false);
    veins(buf,B,B,W-B-1,H-B-1,33,t);
    frame(buf,0,0,W-1,H-1,{t:B,accent:sel||hov});
    rivet(buf,B,B,METAL); rivet(buf,W-B-1,B,METAL); rivet(buf,B,H-B-1,METAL); rivet(buf,W-B-1,H-B-1,METAL);
    var f=FAM[relic.fam], cx=W/2, y=9, g=sel?(0.6+0.4*pulse(t,1)):(hov?0.4:0.2);
    // gemme bakée
    diamond(buf,cx,y+6,7,mix(f.d,f.c,0.45),mix(f.c,ACC.bright,g*0.6),[255,255,255]);
    drawEye(buf,cx,y+6,3,g,g,t,5,{blood:0.5,squash:0.7});
    y+=16;
    text(buf,relic.name.toUpperCase(),cx,y,hexRgb('#e8cd84'),{glow:sel?0.6:0.3,size:9,shadow:hexRgb('#1a1206')}); y+=10;
    for(var x=6;x<W-6;x++){ var a=1-Math.abs(x-cx)/((W-12)/2); buf.set(x,y,mix(METAL.outline,METAL.hi,0.5*a)); } diamond(buf,cx,y,2,ACC.bright,ACC.dark); y+=5;
    text(buf,relic.effect,cx,y,hexRgb('#d9bd6a'),{size:8}); y+=10;
    text(buf,relic.flavor,cx,y,hexRgb('#8a7d66'),{size:8});
  }

  /* ============================================================
     ATOMES
     ============================================================ */
  function drawTypePip(buf,W,H,fam,t){
    var f=FAM[fam], r=Math.floor(Math.min(W,H)/2)-1, cx=Math.round(W/2),cy=Math.round(H/2),c=f.c,e=mix(f.c,[0,0,0],0.45);
    if(f.shape==='bar'){ for(var y=-1;y<=1;y++)for(var x=-r;x<=r;x++)buf.set(cx+x,cy+y,Math.abs(x)>r-1?e:c); }
    else if(f.shape==='cross'){ for(var k=-r;k<=r;k++){ buf.set(cx+k,cy,Math.abs(k)>r-1?e:c); buf.set(cx,cy+k,Math.abs(k)>r-1?e:c); buf.set(cx+k,cy-1,c); buf.set(cx+1,cy+k,c); } }
    else if(f.shape==='diamond'){ diamond(buf,cx,cy,r,c,e,[255,255,255]); }
    else if(f.shape==='star'){ for(var s=0;s<5;s++){ var a=s/5*6.28-1.57; for(var rr=0;rr<=r;rr++)buf.set(Math.round(cx+Math.cos(a)*rr),Math.round(cy+Math.sin(a)*rr),rr>r-1?e:c); } buf.set(cx,cy,c); }
    else { for(var yy=-r;yy<=r;yy++)for(var xx=-r;xx<=r;xx++){ var d=Math.hypot(xx,yy); if(d<=r)buf.set(cx+xx,cy+yy,d>r-1?e:c); } }
    buf.add(cx-1,cy-1,[255,255,255],0.3);
  }
  function drawLevelPips(buf,W,H,n,t){ for(var i=0;i<n;i++)diamond(buf,3+i*5,H/2,2,mix(ACC.mid,ACC.bright,0.5+0.5*pulse(t,i)),ACC.dark,[255,255,255]); }
  function drawGem(buf,W,H,on,t){
    var cx=W/2-0.5,cy=H/2-0.5,Rc=Math.min(W,H)/2-0.5;
    for(var y=Math.floor(cy-Rc);y<=Math.ceil(cy+Rc);y++)for(var x=Math.floor(cx-Rc);x<=Math.ceil(cx+Rc);x++){ var dx=x-cx,dy=y-cy,d=Math.hypot(dx,dy); if(d<Rc-2||d>Rc+0.4)continue; var lit=(-dx/d*0.4-dy/d*0.5); buf.set(x,y,(d>Rc-0.5||d<Rc-1.5)?METAL.outline:(lit>0?mix(METAL.mid,METAL.hi,lit):METAL.deep)); }
    var r=Rc-3, g=on?(0.55+0.45*pulse(t,2)):0;
    for(var y2=-r;y2<=r;y2++)for(var x2=-r;x2<=r;x2++){ var m=Math.abs(x2)+Math.abs(y2); if(m>r)continue; var c; if(on)c= m>=r-0.5?mix(ACC.dark,ACC.mid,0.5):mix(ACC.mid,ACC.bright,g*(1-m/r)); else c= m>=r-0.5?hexRgb('#2a200f'):hexRgb('#120c08'); buf.set(Math.round(cx+x2),Math.round(cy+y2),c); }
    if(on){ buf.add(Math.round(cx-r*0.3),Math.round(cy-r*0.3),[255,255,255],0.6); buf.add(Math.round(cx),Math.round(cy),ACC.bright,g*0.5); }
  }
  function drawDivider(buf,W,H,t){
    var my=Math.floor(H/2);
    for(var x=0;x<W;x++){ var a=1-Math.abs(x-W/2)/(W/2); buf.set(x,my,mix(METAL.outline,METAL.hi,0.55*a)); buf.set(x,my+1,mix(METAL.outline,METAL.base,0.4*a)); }
    var trav=((t*0.32)%1.4-0.2)*W; for(var dx=-4;dx<=4;dx++){ var X=Math.round(trav+dx),f=Math.max(0,1-Math.abs(dx)/4); if(X>0&&X<W){ buf.add(X,my,ACC.bright,f*0.7); buf.add(X,my+1,ACC.mid,f*0.4); } }
    diamond(buf,Math.floor(W/2),my,2,mix(METAL.base,METAL.hi,0.5+0.3*pulse(t,1)),METAL.outline,ACC.bright);
  }
  function drawEyeRing(buf,W,H,open,glow,t,seed){ var cx=W/2-0.5,cy=H/2-0.5,Rc=Math.min(W,H)/2-0.5;
    for(var y=Math.floor(cy-Rc);y<=Math.ceil(cy+Rc);y++)for(var x=Math.floor(cx-Rc);x<=Math.ceil(cx+Rc);x++){ var dx=x-cx,dy=y-cy,d=Math.hypot(dx,dy); if(d<Rc-2||d>Rc+0.4)continue; var lit=(-dx/d*0.4-dy/d*0.5); buf.set(x,y,(d>Rc-0.5||d<Rc-1.5)?METAL.outline:(lit>0?mix(METAL.mid,METAL.hi,lit):METAL.deep)); }
    drawEye(buf,cx,cy,Rc-3,open,glow,t,seed,{blood:0.6,squash:0.8});
  }

  /* ============================================================
     WIDGETS / BOOT
     ============================================================ */
  var widgets=[];
  function mkCanvas(aw,ah){ var cv=document.createElement('canvas'); cv.width=aw; cv.height=ah; cv.style.width=(aw*PX)+'px'; cv.style.height=(ah*PX)+'px'; cv.style.display='block'; cv.style.imageRendering='pixelated'; cv.style.background='transparent'; return cv; }
  var CAP="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:10px;letter-spacing:.03em;color:#7a6f58;margin-top:9px;text-align:center;white-space:nowrap;";
  function elN(tag,style,txt){ var e=document.createElement(tag); if(style)e.style.cssText=style; if(txt!=null)e.textContent=txt; return e; }
  function cell(host,aw,ah,cap,click){ var box=elN('div','display:flex;flex-direction:column;align-items:center;flex:none;'); var cv=mkCanvas(aw,ah); if(click)cv.style.cursor='pointer'; box.appendChild(cv); if(cap!=null)box.appendChild(elN('div',CAP,cap)); host.appendChild(box); return cv; }
  function W2(cv,fn,opts){ opts=opts||{}; var w={cv:cv,st:opts.st||{},interactive:!!opts.interactive,ease:opts.ease||null,vis:true,aw:cv.width,ah:cv.height}; w.draw=function(t){ var b=new Buf(w.aw,w.ah); fn(b,w.aw,w.ah,w.st,t); b.toCanvas(cv); }; widgets.push(w); return w; }
  function hov(cv,st){ cv.addEventListener('mouseenter',function(){st.hover=1;}); cv.addEventListener('mouseleave',function(){st.hover=0;st.active=0;}); cv.addEventListener('mousedown',function(){st.active=1;}); window.addEventListener('mouseup',function(){st.active=0;}); }
  function track(cv,st,W,H){ function tr(e){ var r=cv.getBoundingClientRect(); st.gx=(e.clientX-r.left)/r.width*W; st.gy=(e.clientY-r.top)/r.height*H; } cv.addEventListener('mousemove',tr); cv.addEventListener('mouseenter',tr); }
  function easeBtn(st){ var pg=st.active?0.95:(st.hover?0.55:0),pp=st.active?1:0,po=st.hover?1:0; st.glow=elerp(st.glow||0,pg,0.22); st.press=elerp(st.press||0,pp,0.3); st.eyeOpen=elerp(st.eyeOpen||0,po,0.16); }
  function easeSmall(st){ var pg=st.active?0.95:(st.hover?0.55:0),pp=st.active?1:0; st.glow=elerp(st.glow||0,pg,0.22); st.press=elerp(st.press||0,pp,0.3); }

  /* ---- données ---- */
  var RELICS=[{name:'Bloodstone',fam:'flesh',effect:'+15% lifesteal',flavor:'"It drinks first."'},{name:'Drowned Coin',fam:'abyss',effect:'steal 2 gold/kill',flavor:'"Wrong change."'}];

  var BUILD={};

  BUILD.BTN=function(host){
    var aw=60,ah=13,sz=9;
    [['rest',{eyeOpen:0,glow:0,press:0}],['hover',{eyeOpen:1,glow:0.55,press:0}],['pressed',{eyeOpen:1,glow:0.95,press:1}]].forEach(function(p,i){
      var seed=11+i, eyes=genEyes(aw,ah-DROP,seed,'DESCEND',sz), st=Object.assign({},p[1]); st.gx=aw*0.5; st.gy=4;
      var cv=cell(host,aw,ah,p[0]);
      W2(cv,function(b,W,H,st,t){ drawButton(b,W,H,st.press,st.eyeOpen,st.glow,seed,'DESCEND',false,eyes,[st.gx,st.gy],sz,t); },{st:st});
    });
    var cd=cell(host,60,13,'disabled'); W2(cd,function(b,W,H,st,t){ drawButton(b,W,H,0,0,0,99,'SEALED',true,null,null,sz,t); },{st:{}});
    var lc=cell(host,76,13,'live — hover & move',true); var le=genEyes(76,13-DROP,77,'ENTER THE PIT',sz); var lst={hover:0,active:0,glow:0,press:0,eyeOpen:0,gx:38,gy:5}; hov(lc,lst); track(lc,lst,76,13);
    W2(lc,function(b,W,H,st,t){ drawButton(b,W,H,st.press,st.eyeOpen,st.glow,77,'ENTER THE PIT',false,le,[st.gx,st.gy],sz,t); },{st:lst,interactive:true,ease:easeBtn});
  };
  BUILD.ECO=function(host){
    [['rest',{glow:0,press:0}],['hover',{glow:0.55,press:0}],['pressed',{glow:0.95,press:1}]].forEach(function(p,i){ var cv=cell(host,34,11,p[0]);
      W2(cv,function(b,W,H,st,t){ drawEcoBtn(b,W,H,st.press,st.glow,30+i,'REROLL',1,false,t); },{st:Object.assign({},p[1])}); });
    var cd=cell(host,34,11,'disabled'); W2(cd,function(b,W,H,st,t){ drawEcoBtn(b,W,H,0,0,40,'LEVEL',8,true,t); },{st:{}});
  };
  BUILD.ICON=function(host){
    [['sigil','sigil'],['left','‹ prev'],['right','next ›'],['gear','settings']].forEach(function(k,i){ var cv=cell(host,12,12,k[1],true); var st={hover:0,active:0,glow:0,press:0}; hov(cv,st);
      W2(cv,function(b,W,H,st,t){ drawIconBtn(b,W,H,st.press,st.glow,50+i,k[0],t); },{st:st,interactive:true,ease:easeSmall}); });
  };
  BUILD.ORB=function(host){
    [['Vitae',LIQ.blood,101,0.78],['Mana',LIQ.mana,102,0.54],['Essence',LIQ.essence,103,0.40]].forEach(function(p){ var cv=cell(host,30,30,p[0].toLowerCase()+' — drag',true); var st={val:p[3]};
      function sv(e){ var r=cv.getBoundingClientRect(); st.val=clamp(1-(e.clientY-r.top)/r.height); } cv.addEventListener('click',sv); cv.addEventListener('mousemove',function(e){ if(e.buttons&1)sv(e); });
      W2(cv,function(b,W,H,st,t){ drawOrb(b,W,H,st.val,p[1],p[2],t); },{st:st,interactive:true}); });
  };
  BUILD.GAUGE=function(host){
    [['healthy',0.82,[]],['afflicted',0.6,[{frac:0.22,color:AFFL.poison.c,bmp:AFFL.poison.bmp},{frac:0.12,color:AFFL.burn.c,bmp:AFFL.burn.bmp}]],['critical < 25%',0.16,[{frac:0,color:AFFL.bleed.c,bmp:AFFL.bleed.bmp}]]].forEach(function(p){ var cv=cell(host,60,16,p[0]);
      W2(cv,function(b,W,H,st,t){ drawGauge(b,W,H,p[1],p[2],t); },{st:{}}); });
  };
  BUILD.PANEL=function(host){ var cv=cell(host,56,34,'9-slice — breathes & watches'); W2(cv,function(b,W,H,st,t){ drawPanel(b,W,H,t,'GRIMOIRE'); },{st:{}}); };
  BUILD.TOOLTIP=function(host){ var cv=cell(host,52,30,'hover sheet'); var L=[{txt:'ASH-MAW',gold:true,gap:11,size:9},{txt:'HP70 DMG6 CD6s',color:hexRgb('#9a8a72'),gap:11,size:8},{txt:'Each hit ignites.',color:hexRgb('#8a7d66'),size:8}]; W2(cv,function(b,W,H,st,t){ drawTooltip(b,W,H,t,L); },{st:{}}); };
  BUILD.DIVIDER=function(host){ var cv=cell(host,80,6,'divider — pulse'); W2(cv,function(b,W,H,st,t){ drawDivider(b,W,H,t); },{st:{}}); };
  BUILD.BANNER=function(host){ [['VICTORY','win'],['DEFEAT','defeat']].forEach(function(p){ var cv=cell(host,72,22,p[1]); W2(cv,function(b,W,H,st,t){ drawBanner(b,W,H,p[0],p[1],t); },{st:{}}); }); };
  BUILD.RELIC=function(host){ [['rest',0],['selected',1]].forEach(function(p){ var cv=cell(host,46,56,p[0]); W2(cv,function(b,W,H,st,t){ drawRelicCard(b,W,H,p[0],RELICS[p[1]],t); },{st:{}}); }); };
  BUILD.GEM=function(host){ [['inert',false],['awake',true]].forEach(function(p){ var cv=cell(host,14,14,p[0]); W2(cv,function(b,W,H,st,t){ drawGem(b,W,H,p[1],t); },{st:{}}); });
    var lc=cell(host,14,14,'live — click',true); var lst={on:false}; lc.addEventListener('click',function(){lst.on=!lst.on;}); W2(lc,function(b,W,H,st,t){ drawGem(b,W,H,st.on,t); },{st:lst,interactive:true}); };
  BUILD.EYE=function(host){ var cv=cell(host,18,18,'seal'); W2(cv,function(b,W,H,st,t){ drawEyeRing(b,W,H,0.9,0.7,t,3); },{st:{}}); };
  BUILD.TYPEPIP=function(host){ ['flesh','order','bone','arcane','abyss'].forEach(function(f){ var cv=cell(host,12,12,f); W2(cv,function(b,W,H,st,t){ drawTypePip(b,W,H,f,t); },{st:{}}); }); };
  BUILD.LEVELPIPS=function(host){ [1,2,3].forEach(function(n){ var cv=cell(host,3+n*5,8,'lvl '+n); W2(cv,function(b,W,H,st,t){ drawLevelPips(b,W,H,n,t); },{st:{}}); }); };

  function boot(root,opts){
    opts=opts||{}; setAccent(opts.accent||'gold'); RESTLESS=opts.restless!==false; widgets.length=0;
    Array.prototype.forEach.call(root.querySelectorAll('[data-host]'),function(h){ var b=BUILD[h.getAttribute('data-host')]; if(b){ try{ h.innerHTML=''; b(h); }catch(e){ console.warn('builder',h.getAttribute('data-host'),e); } } });
    if('IntersectionObserver' in window){ var cvMap=new Map(); var io=new IntersectionObserver(function(es){ es.forEach(function(e){ var w=cvMap.get(e.target); if(w)w.vis=e.isIntersecting; }); },{rootMargin:'140px'}); widgets.forEach(function(w){ cvMap.set(w.cv,w); io.observe(w.cv); }); }
    widgets.forEach(function(w){ w.draw(0); });
    var last=0; function loop(now){ requestAnimationFrame(loop); var iv=RESTLESS?42:130; if(now-last<iv)return; last=now; var t=now/1000; for(var i=0;i<widgets.length;i++){ var w=widgets[i]; if(!w.vis)continue; if(w.interactive&&w.ease)w.ease(w.st); w.draw(t); } }
    requestAnimationFrame(loop);
    return { setAccent:function(n){ setAccent(n); widgets.forEach(function(w){ w.vis=true; }); }, setRestless:function(v){ RESTLESS=v; } };
  }
  window.ForgePX={ boot:boot, _v:2 };
})();
