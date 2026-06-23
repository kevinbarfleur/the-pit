/* ============================================================
   PIT FORGE — moteur pixel-art (handoff board, The Pit)
   Style « forge gothique » : plaques sombres, métal biseauté,
   rivets, liseré or, texte binarisé, AUCUNE texture bruitée.
   Résolution interne ×4, rendu net 1:1, formes retravaillées.
   Expose window.PitForge.boot(rootEl, {accent, restless}).
   ============================================================ */
(function () {
  "use strict";

  /* ---- réglages globaux ---- */
  var R = 4;          // résolution interne (pixels fins)
  var SCALE = 1;      // rendu net 1:1
  var GRIME = 0.85;   // dosage de la crasse
  var RESTLESS = true;

  /* ---- maths / hash ---- */
  function mulberry32(a){ return function(){ a|=0; a=a+0x6D2B79F5|0; var t=Math.imul(a^a>>>15,1|a); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296; }; }
  function hash2(x,y,s){ var n=((x|0)*374761393+(y|0)*668265263+(s|0)*982451653)>>>0; n=(n^(n>>>13))>>>0; n=Math.imul(n,1274126177)>>>0; return ((n^(n>>>16))>>>0)/4294967296; }
  function hgi(v){ return (v/R)|0; }
  function hexRgb(h){ h=h.replace('#',''); return [parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)]; }
  function mix(a,b,t){ return [a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t]; }
  function elerp(a,b,k){ return a+(b-a)*k; }
  function clamp(v){ return v<0?0:v>1?1:v; }
  function orgPulse(t,seed){ return clamp(0.5+0.30*Math.sin(t*1.6+seed)+0.16*Math.sin(t*0.73+seed*2.1)+0.09*Math.sin(t*3.1+seed*0.5)); }
  var BAYER=[[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];

  /* ---- palettes ---- */
  var GOLD={deep:'#140d05',sh:'#332611',base:'#63502a',mid:'#92753e',hi:'#c6a456',glow:'#f2d98a'};
  var BG={top:hexRgb('#15101e'),bot:hexRgb('#09070e'),vig:hexRgb('#040308')};
  var VERDIGRIS=hexRgb('#2c3a28'), GRIME_C=hexRgb('#150f08'), GRIME_DARK=hexRgb('#0c0805');
  var VEIN=hexRgb('#2a0810'), VEIN_HOT=hexRgb('#7a1828');
  var ACCENTS={
    gold:  {dark:hexRgb('#5a3f12'),mid:hexRgb('#b8902f'),bright:hexRgb('#f2d98a')},
    blood: {dark:hexRgb('#4a1414'),mid:hexRgb('#b03a30'),bright:hexRgb('#ff5a4a')},
    bile:  {dark:hexRgb('#24380e'),mid:hexRgb('#5e8a22'),bright:hexRgb('#9ad24a')},
    violet:{dark:hexRgb('#2e1a44'),mid:hexRgb('#6a3aa0'),bright:hexRgb('#c89cff')}
  };
  var ACC=ACCENTS.gold;
  var LIQUIDS={
    blood:  {dark:hexRgb('#33070a'),mid:hexRgb('#8c1c20'),bright:hexRgb('#e8483c')},
    mana:   {dark:hexRgb('#0a1630'),mid:hexRgb('#214d90'),bright:hexRgb('#5e9cf0')},
    essence:{dark:hexRgb('#1c0e34'),mid:hexRgb('#4e2488'),bright:hexRgb('#b888f0')},
    ferveur:{dark:hexRgb('#332408'),mid:hexRgb('#a87824'),bright:hexRgb('#f0c85a')}
  };
  /* familles d'unités */
  var FAM={
    flesh: {c:hexRgb('#c25a48'),d:hexRgb('#3a120e'),lab:'FLESH', shape:'bar'},
    order: {c:hexRgb('#d6b25a'),d:hexRgb('#4a3814'),lab:'ORDER', shape:'cross'},
    bone:  {c:hexRgb('#c8b894'),d:hexRgb('#473a2c'),lab:'BONE',  shape:'diamond'},
    arcane:{c:hexRgb('#bd7aa6'),d:hexRgb('#33182c'),lab:'ARCANE',shape:'star'},
    abyss: {c:hexRgb('#b06a86'),d:hexRgb('#2a1220'),lab:'ABYSS', shape:'disc'}
  };
  /* afflictions (couleur famille d'effet) */
  var AFFL={
    burn:  {c:hexRgb('#f08a3a'), bmp:["00010000","00011000","00111100","01111100","01111110","11101110","01111100","00111000"]},
    poison:{c:hexRgb('#8fd06a'), bmp:["00011000","00011000","00111100","00111100","01111110","01111110","01111110","00111100"]},
    bleed: {c:hexRgb('#e0584c'), bmp:["00011000","00011000","00111100","00111100","01111110","01100110","01111110","00111100"]},
    rot:   {c:hexRgb('#9a8a52'), bmp:["01000010","00100100","10111101","01111110","00111100","10111101","00100100","01000010"]}
  };

  function setAccent(name){ if(ACCENTS[name]) ACC=ACCENTS[name]; }

  /* ============================================================
     Buffer pixel
     ============================================================ */
  function Buf(w,h){ this.w=w; this.h=h; this.d=new Uint8ClampedArray(w*h*4); }
  Buf.prototype.set=function(x,y,c,a){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; this.d[i]=c[0];this.d[i+1]=c[1];this.d[i+2]=c[2];this.d[i+3]=(a==null?255:a); };
  Buf.prototype.blendOver=function(x,y,c,a){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; var ba=this.d[i+3]/255; var na=a+ba*(1-a); if(na<=0)return; for(var k=0;k<3;k++)this.d[i+k]=(c[k]*a+this.d[i+k]*ba*(1-a))/na; this.d[i+3]=na*255; };
  Buf.prototype.add=function(x,y,c,k){ x|=0;y|=0; if(x<0||y<0||x>=this.w||y>=this.h)return; var i=(y*this.w+x)*4; if(this.d[i+3]===0)this.d[i+3]=255; this.d[i]=Math.min(255,this.d[i]+c[0]*k); this.d[i+1]=Math.min(255,this.d[i+1]+c[1]*k); this.d[i+2]=Math.min(255,this.d[i+2]+c[2]*k); };
  Buf.prototype.toCanvas=function(cv){ var ctx=cv.getContext('2d'); var id=ctx.createImageData(this.w,this.h); id.data.set(this.d); ctx.putImageData(id,0,0); };

  /* ============================================================
     Texte binarisé
     ============================================================ */
  var _tc={};
  function textMask(txt){
    if(_tc[txt])return _tc[txt];
    var sp=6*R, o=document.createElement('canvas'); o.width=Math.max(1,txt.length*sp+2*R); o.height=10*R;
    var oc=o.getContext('2d'); oc.imageSmoothingEnabled=false; oc.textBaseline='top';
    oc.font=(8*R)+'px "Courier New",monospace'; oc.fillStyle='#fff';
    var cx=1*R; for(var i=0;i<txt.length;i++){ oc.fillText(txt[i],cx,1*R); cx+=sp; }
    var d=oc.getImageData(0,0,o.width,o.height).data, pix=[], mnx=99999,mxx=0,mny=99999,mxy=0;
    for(var y=0;y<o.height;y++)for(var x=0;x<o.width;x++){ if(d[(y*o.width+x)*4+3]>110){ pix.push([x,y]); if(x<mnx)mnx=x;if(x>mxx)mxx=x;if(y<mny)mny=y;if(y>mxy)mxy=y; } }
    var m={ w:(mxx-mnx+1)||1, h:(mxy-mny+1)||1, pix:pix.map(function(p){return [p[0]-mnx,p[1]-mny];}) };
    _tc[txt]=m; return m;
  }
  function measure(txt){ var m=textMask(txt); return {w:m.w,h:m.h}; }
  function labelPts(label,cx,cyTop){ var m=textMask(label); var ox=Math.round(cx-m.w/2), oy=Math.round(cyTop); var a=[]; for(var i=0;i<m.pix.length;i++)a.push([ox+m.pix[i][0],oy+m.pix[i][1]]); return {pts:a,w:m.w,h:m.h,ox:ox,oy:oy}; }
  function leftPts(label,x,y){ var m=textMask(label); var a=[]; for(var i=0;i<m.pix.length;i++)a.push([x+m.pix[i][0],y+m.pix[i][1]]); return {pts:a,w:m.w,h:m.h}; }
  function stampText(buf,label,x,y,color,sh){ var m=textMask(label); var i,px,py; if(sh){ for(i=0;i<m.pix.length;i++){ px=x+m.pix[i][0]; py=y+m.pix[i][1]; buf.set(px+1,py+1,sh); } } for(i=0;i<m.pix.length;i++)buf.set(x+m.pix[i][0],y+m.pix[i][1],color); }
  function goldText(buf,pts,glow,t,phase){
    if(!pts.length)return;
    var base=hexRgb(GOLD.hi),hot=hexRgb(GOLD.glow),shd=hexRgb(GOLD.deep);
    var g=glow*(0.8+0.2*Math.sin(t*5+phase));
    var occ={}; for(var i=0;i<pts.length;i++)occ[pts[i][0]+'_'+pts[i][1]]=1;
    for(i=0;i<pts.length;i++){ var px=pts[i][0],py=pts[i][1]; if(!occ[(px+1)+'_'+(py+1)])buf.set(px+1,py+1,shd); }
    if(g>0.02)for(i=0;i<pts.length;i++){ var hx=pts[i][0],hy=pts[i][1]; buf.add(hx-1,hy,ACC.mid,g*0.5); buf.add(hx+1,hy,ACC.mid,g*0.5); buf.add(hx,hy-1,ACC.mid,g*0.5); buf.add(hx,hy+1,ACC.mid,g*0.5); }
    for(i=0;i<pts.length;i++){ var c=g>0.02?mix(mix(base,hot,0.5),ACC.bright,g):base; buf.set(pts[i][0],pts[i][1],c); }
  }

  /* ============================================================
     Bitmaps
     ============================================================ */
  function blit(buf,bmp,x,y,color,sc){ sc=sc||R; for(var r=0;r<bmp.length;r++){ var row=bmp[r]; for(var c=0;c<row.length;c++){ if(row[c]==='1'){ for(var sy=0;sy<sc;sy++)for(var sx=0;sx<sc;sx++)buf.set(x+c*sc+sx,y+r*sc+sy,color); } } } }
  var ICON={
    heart:["0110110","1111111","1111111","1111111","0111110","0011100","0001000"],
    sword:["0000010","0000110","0001110","0011100","0111000","1110010","1100110","0001100","0011000"],
    clock:["0011100","0100010","1001010","1001010","1000110","0100010","0011100"],
    gear: ["00100100","01111110","11111111","11100111","11100111","11111111","01111110","00100100"],
    sigil:["00010000","00111000","01010100","11010110","01010100","00111000","00010000"],
    chev: ["10000","11000","11100","11000","10000"]
  };

  /* ============================================================
     Remplissages & métal
     ============================================================ */
  function stripeFill(buf,x0,y0,x1,y1,a,b,sz){
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){ var band=Math.floor((x+y)/sz)%2; buf.set(x,y,band?a:b); }
  }
  function panelFill(buf,x0,y0,x1,y1,press){
    var cx=(x0+x1)/2, cy=(y0+y1)/2, maxd=Math.max(1,Math.hypot((x1-x0)/2,(y1-y0)/2));
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){
      var vy=(y-y0)/Math.max(1,(y1-y0));
      var col=mix(BG.top,BG.bot,vy);
      var d=Math.hypot(x-cx,y-cy)/maxd;
      col=mix(col,BG.vig,clamp(d-0.45)*0.55);
      col=mix(col,(BAYER[y&3][x&3]>7?BG.top:BG.bot),0.045);
      var gd=Math.min(x-x0,x1-x,y-y0,y1-y);
      if(gd<11*R)col=mix(col,GRIME_C,(1-gd/(11*R))*0.5*GRIME);
      if(press>0)col=mix(col,BG.vig,press*0.18);
      buf.set(x,y,col);
    }
  }
  function metalBorder(buf,x0,y0,x1,y1,M,th,press,seed){
    var deep=hexRgb(M.deep),base=hexRgb(M.base),hi=hexRgb(M.hi),sh=hexRgb(M.sh);
    var hlF=1-press*0.6, x,y;
    for(y=y0;y<=y1;y++)for(x=x0;x<=x1;x++){
      var dT=y-y0,dB=y1-y,dL=x-x0,dR=x1-x,dmin=Math.min(dT,dB,dL,dR);
      if(dmin>=th)continue;
      var col;
      if(dmin<R)col=deep;
      else if(dmin>=th-R)col=mix(ACC.dark,ACC.bright,0.55);
      else{ var lit=(dmin===dT||dmin===dL),f=(dmin-R)/Math.max(1,th-2*R); col=lit?mix(mix(base,hi,1-f),base,1-hlF):mix(mix(base,sh,1-f),VERDIGRIS,0.24*GRIME); }
      buf.set(x,y,col);
    }
    for(y=y0;y<=y1;y++)for(x=x0;x<=x1;x++){ var dm=Math.min(y-y0,y1-y,x-x0,x1-x); if(dm<R||dm>=th)continue; if(hash2(hgi(x)>>1,hgi(y)>>1,seed+7)>0.9-0.04*GRIME)buf.blendOver(x,y,GRIME_DARK,0.5*GRIME); }
    buf.set(x0,y0,deep,0);buf.set(x1,y0,deep,0);buf.set(x0,y1,deep,0);buf.set(x1,y1,deep,0);
  }
  function rivet(buf,x,y,M){
    var deep=hexRgb(M.deep),hi=hexRgb(M.hi),base=hexRgb(M.base),rr=R*1.1;
    for(var oy=-rr;oy<=rr;oy++)for(var ox=-rr;ox<=rr;ox++){ var d=Math.hypot(ox,oy); if(d>rr+0.3)continue; buf.set(x+ox,y+oy,d>rr-0.6?deep:mix(base,hi,1-d/rr)); }
    buf.set(x,y,hi); buf.set(x-1,y-1,hexRgb(M.glow));
    for(var k=1;k<=2*R;k++)buf.blendOver(x,y+rr+k,GRIME_DARK,0.4*GRIME*(1-k/(2*R)));
  }
  function dropShadow(buf,W,yb){ for(var dy=0;dy<3*R;dy++){ var base=(0.5-dy*0.14/R); for(var x=3*R;x<W-3*R;x++){ var edge=Math.abs(x-W/2)/(W/2); buf.blendOver(x,yb+dy,[0,0,0],base*(1-edge*0.55)); } } }

  function pillFill(buf,x0,y0,x1,y1,color){
    var h=y1-y0, r=h/2, cyl=(y0+y1)/2;
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){
      var inside=true;
      if(x<x0+r){ inside=Math.hypot(x-(x0+r),y-cyl)<=r+0.2; }
      else if(x>x1-r){ inside=Math.hypot(x-(x1-r),y-cyl)<=r+0.2; }
      if(inside)buf.set(x,y,color);
    }
  }

  function veins(buf,x0,y0,x1,y1,seed,t,grow){
    var starts=[[x0+7*R,y0+7*R,0.8],[x1-7*R,y0+7*R,2.4],[x0+7*R,y1-7*R,5.5],[x1-7*R,y1-7*R,3.9]];
    for(var s=0;s<4;s++){ var rnd=mulberry32((seed*7+s*131)|0);
      var baseLen=(12+((rnd()*14)|0))*R, len=Math.round(baseLen*(0.6+0.4*grow*orgPulse(t,seed+s)));
      var x=starts[s][0],y=starts[s][1],dir=starts[s][2];
      for(var i=0;i<len;i++){
        buf.blendOver(Math.round(x),Math.round(y),VEIN,0.75); buf.blendOver(Math.round(x),Math.round(y)+1,[0,0,0],0.28);
        if(i%(4*R)===2*R)buf.add(Math.round(x),Math.round(y),VEIN_HOT,0.45*orgPulse(t,seed+s+i));
        dir+=(rnd()-0.5)*0.9/R;
        var nearX=Math.min(x-x0,x1-x),nearY=Math.min(y-y0,y1-y);
        if(Math.min(nearX,nearY)>13*R)dir+=(nearX<nearY?(x<(x0+x1)/2?0.5:-0.5):(y<(y0+y1)/2?0.5:-0.5))/R;
        x+=Math.cos(dir);y+=Math.sin(dir);
        if(x<x0+2*R||x>x1-2*R||y<y0+2*R||y>y1-2*R)break;
      }
    }
  }
  function metalRing(buf,cx,cy,Rc,M,seed){
    var deep=hexRgb(M.deep),base=hexRgb(M.base),hi=hexRgb(M.hi),sh=hexRgb(M.sh),mid=hexRgb(M.mid);
    var rOut=Rc,rIn=Rc-3*R;
    for(var y=Math.floor(cy-Rc-1);y<=Math.ceil(cy+Rc+1);y++)for(var x=Math.floor(cx-Rc-1);x<=Math.ceil(cx+Rc+1);x++){
      var dx=x-cx,dy=y-cy,d=Math.sqrt(dx*dx+dy*dy); if(d<rIn-0.5||d>rOut+0.5)continue;
      var lit=(-dx/d*0.4-dy/d*0.55),col;
      if(d>=rOut-R*0.6||d<=rIn+R*0.6)col=deep; else col=lit>0?mix(mid,hi,lit):mix(mix(base,sh,-lit),VERDIGRIS,0.26*GRIME);
      if(hash2(hgi(x)>>1,hgi(y)>>1,(seed||0)+7)>0.9)col=mix(col,GRIME_DARK,0.5*GRIME);
      buf.set(x,y,col);
    }
    var rr=Rc-1.5*R;
    rivet(buf,Math.round(cx),Math.round(cy-rr),M); rivet(buf,Math.round(cx),Math.round(cy+rr),M);
    rivet(buf,Math.round(cx-rr),Math.round(cy),M); rivet(buf,Math.round(cx+rr),Math.round(cy),M);
  }
  function cornerPiece(buf,ox,oy,fx,fy,t){
    var P=[[1,1,1,1,1,2,0,0],[1,3,3,4,3,2,2,0],[1,3,4,5,4,3,2,2],[1,4,5,3,3,4,3,2],[1,3,4,3,1,3,4,3],[2,3,3,4,3,1,3,4],[0,2,2,3,4,3,1,3],[0,0,2,2,3,4,3,1]];
    var deep=hexRgb(GOLD.deep),base=hexRgb(GOLD.base),hi=hexRgb(GOLD.hi),mid=hexRgb(GOLD.mid),sh=hexRgb(GOLD.sh);
    var pal=[null,deep,sh,base,mid,hi];
    for(var yy=0;yy<8;yy++)for(var xx=0;xx<8;xx++){ var v=P[yy][xx]; if(!v)continue; var c=pal[v]; var X=ox+(fx?7-xx:xx)*R,Y=oy+(fy?7-yy:yy)*R; if(v>=2&&hash2(hgi(X)>>1,hgi(Y)>>1,9)>0.88)c=mix(c,GRIME_DARK,0.5*GRIME); for(var by=0;by<R;by++)for(var bx=0;bx<R;bx++)buf.set(X+bx,Y+by,c); }
    var gx=ox+(fx?2:5)*R,gy=oy+(fy?2:5)*R,g=orgPulse(t,(ox+oy)*0.3);
    for(var gy2=0;gy2<R;gy2++)for(var gx2=0;gx2<R;gx2++){ buf.set(gx+gx2,gy+gy2,mix(ACC.dark,ACC.bright,g)); buf.add(gx+gx2,gy+gy2,ACC.mid,g*0.5); }
  }

  /* ============================================================
     ŒIL (porté)
     ============================================================ */
  function drawEyeAt(buf,cx,cy,r,open,glow,t,seed,opts){
    opts=opts||{};
    var squash=opts.squash||0.7, skew=opts.skew||0, pupil=opts.pupil||'round', inject=opts.inject||0;
    var scl=opts.scl||[176,164,136], gaze=opts.gaze||null;
    var sclD=[scl[0]*0.42,scl[1]*0.40,scl[2]*0.34], lidC=[20,13,9];
    if(inject>0){ scl=mix(scl,[162,46,40],inject*0.55); sclD=mix(sclD,[64,14,14],inject*0.6); }
    var bt=(t*0.7+seed*3)%6, blink=bt>5.7?(1-Math.abs(bt-5.85)/0.15):0;
    var op=clamp(open*(1-clamp(blink))), lidHalf=Math.max(0.4*R,r*squash*op), rs=Math.ceil(r)+1, x,y;
    for(y=-rs;y<=rs;y++)for(x=-rs;x<=rs;x++){
      var ly=y-skew*x, ex=x/r, ey=ly/(r*squash);
      if(ex*ex+ey*ey>1)continue;
      if(Math.abs(ly)>lidHalf+0.7*R)continue;
      var X=Math.round(cx+x),Y=Math.round(cy+y);
      if(Math.abs(ly)>lidHalf){ buf.set(X,Y,lidC); continue; }
      buf.set(X,Y,mix(scl,sclD,clamp(Math.abs(ex)*0.55+Math.abs(ly)/Math.max(0.5*R,lidHalf)*0.45)));
    }
    if(op>0.4){ var cnt=2+Math.round(inject*4),rnd=mulberry32((seed*13)|0);
      for(var v=0;v<cnt;v++){ var a=rnd()*6.28,vx=cx+Math.cos(a)*r*0.92,vy=cy+Math.sin(a)*r*squash*0.92;
        for(var k=0;k<4;k++){ var lyy=(vy-cy)-skew*(vx-cx); if(Math.abs(lyy)<=lidHalf)buf.blendOver(Math.round(vx),Math.round(vy),VEIN_HOT,0.4+inject*0.3); vx+=(cx-vx)*0.22; vy+=(cy-vy)*0.22; } } }
    var gx,gy;
    if(gaze){ var dx=gaze[0]-cx,dy=gaze[1]-cy,dl=Math.hypot(dx,dy)||1,mo=r*0.32; gx=dx/dl*mo; gy=dy/dl*mo*squash; }
    else{ gx=Math.sin(t*0.6+seed)*r*0.3; gy=Math.cos(t*0.43+seed*1.7)*r*squash*0.5; }
    var ir=r*0.5;
    for(y=-Math.ceil(ir);y<=Math.ceil(ir);y++)for(x=-Math.ceil(ir);x<=Math.ceil(ir);x++){
      var d=Math.hypot(x,y); if(d>ir)continue;
      var ax=gx+x,ay=gy+y, ly2=ay-skew*ax;
      if(Math.abs(ly2)>lidHalf)continue;
      var dd=d/ir, c2=mix(mix(ACC.mid,ACC.bright,glow),ACC.dark,dd), isPup;
      if(pupil==='slit_v')isPup=Math.abs(x)<ir*0.24*(1-0.35*Math.abs(y)/ir);
      else if(pupil==='slit_h')isPup=Math.abs(y)<ir*0.24*(1-0.35*Math.abs(x)/ir);
      else isPup=dd<0.5;
      if(isPup)c2=[5,4,8]; else if(dd>0.9)c2=mix(c2,[0,0,0],0.6);
      buf.set(Math.round(cx+ax),Math.round(cy+ay),c2);
    }
    if(op>0.5){ var sx=cx+gx-ir*0.3,sy=cy+gy-ir*0.35,lys=(sy-cy)-skew*(sx-cx); if(Math.abs(lys)<=lidHalf)buf.add(Math.round(sx),Math.round(sy),[255,255,255],0.45*op); }
    for(x=-rs;x<=rs;x++){ var ex5=x/r; if(Math.abs(ex5)>1)continue; var lh=Math.sqrt(Math.max(0,1-ex5*ex5))*r*squash; if(lh>=lidHalf-0.6*R){ buf.set(Math.round(cx+x),Math.round(cy-lidHalf+skew*x),lidC); buf.set(Math.round(cx+x),Math.round(cy+lidHalf+skew*x),lidC); } }
    if(op>0.3)buf.add(Math.round(cx),Math.round(cy),ACC.mid,0.18*op*orgPulse(t,seed));
  }

  /* ============================================================
     ORBE + nageuse (porté)
     ============================================================ */
  function drawOrb(buf,W,H,level,liquid,seed,t){
    var cx=W/2-0.5, cy=H/2-0.5, Rc=Math.min(W,H)/2-1, rIn=Rc-3*R;
    var L=liquid, glass0=hexRgb('#09070f'), glass1=hexRgb('#191428');
    var surfaceBase=cy+rIn-2*clamp(level)*rIn;
    function surfAt(X){ return surfaceBase+Math.sin(X*(0.42/R)+t*2.1)*(1.15*R)+Math.sin(X*(0.14/R)-t*1.35)*(0.85*R); }
    for(var y=Math.floor(cy-rIn);y<=Math.ceil(cy+rIn);y++)for(var x=Math.floor(cx-rIn);x<=Math.ceil(cx+rIn);x++){
      var dx=x-cx,dy=y-cy,d=Math.sqrt(dx*dx+dy*dy); if(d>rIn+0.5)continue;
      var nx=dx/rIn,ny=dy/rIn,lightDot=(-nx*0.5-ny*0.6),sphere=clamp(0.5+lightDot*0.55);
      var edge=1-Math.pow(clamp(d/rIn),3)*0.65, surf=surfAt(x), col;
      if(y>=surf){ var depth=clamp((y-surf)/(rIn*2)); col=mix(L.bright,L.dark,clamp(0.12+depth*1.25)); col=mix(col,L.mid,0.28); col=mix(mix(col,[0,0,0],0.45*(1-sphere)),col,0.55); col=[col[0]*edge,col[1]*edge,col[2]*edge]; var murk=hash2(hgi(x)>>1,hgi(y+((t*8)|0))>>1,seed); if(murk>0.82)col=mix(col,L.dark,0.4); if(y<surf+1.4*R)col=mix(col,L.bright,0.7); }
      else{ col=mix(glass0,glass1,sphere); col=[col[0]*edge,col[1]*edge,col[2]*edge]; }
      buf.set(x,y,col);
    }
    /* nageuse */
    var ct=((t*0.062+seed*0.37)%1);
    if(ct<0.55){
      var prog=ct/0.55, hx=cx-rIn-5*R+prog*(2*rIn+10*R), hy=cy+rIn*0.22+Math.sin(t*1.3+seed)*rIn*0.2;
      for(var sg=0;sg<13;sg++){
        var bx=hx-sg*2.0*R, by=hy+Math.sin(t*2.2-sg*0.55)*(3.2*R), br=Math.max(1,2.5-sg*0.13)*R;
        for(var oy2=-Math.ceil(br);oy2<=Math.ceil(br);oy2++)for(var ox2=-Math.ceil(br);ox2<=Math.ceil(br);ox2++){
          if(ox2*ox2+oy2*oy2>br*br)continue; var X=Math.round(bx+ox2),Y=Math.round(by+oy2);
          if(Math.hypot(X-cx,Y-cy)>rIn-1)continue; if(Y>=surfAt(X))buf.blendOver(X,Y,[4,2,6],0.55);
        }
      }
      var ehx=Math.round(hx),ehy=Math.round(hy);
      if(ehy>=surfAt(ehx)&&Math.hypot(ehx-cx,ehy-cy)<rIn-1){ for(var ey0=-R;ey0<=0;ey0++)for(var ex0=-R;ex0<=R;ex0++){ if(ex0*ex0+ey0*ey0<=R*R)buf.set(ehx+ex0,ehy+ey0,ACC.bright); } buf.add(ehx,ehy,ACC.bright,0.7); }
    }
    /* fêlures */
    var rnd=mulberry32((seed*17)|0),ox=cx+(rnd()-0.5)*rIn*0.7,oy=cy-rIn*0.45;
    for(var c2=0;c2<2;c2++){ var a=rnd()*6.28,fx=ox,fy=oy; for(var k=0;k<rIn*0.7;k++){ if(fy<surfaceBase-1)buf.add(Math.round(fx),Math.round(fy),[190,194,210],0.22); a+=(rnd()-0.5)*0.6/R; fx+=Math.cos(a); fy+=Math.sin(a); if(Math.hypot(fx-cx,fy-cy)>rIn-1)break; } }
    /* reflet */
    var sx=cx-rIn*0.36,sy=cy-rIn*0.42,sa=rIn*0.42,sb=rIn*0.26;
    for(var yy=Math.floor(sy-sb);yy<=Math.ceil(sy+sb);yy++)for(var xx=Math.floor(sx-sa);xx<=Math.ceil(sx+sa);xx++){ var ex=(xx-sx)/sa,ey=(yy-sy)/sb,e=ex*ex+ey*ey; if(e>1)continue; buf.add(xx,yy,[255,255,255],(1-e)*0.3); }
    buf.add(Math.round(sx-1),Math.round(sy-1),[255,255,255],0.5);
    var rb=mulberry32((seed*5+1)|0);
    for(var b=0;b<4;b++){ var bx2=cx+(rb()-0.5)*rIn*1.1,phase=rb()*6.28,sp=0.4+rb()*0.5,by2=cy+rIn-((t*sp+phase)%2)/2*2*clamp(level)*rIn; if(by2>surfaceBase+2&&Math.abs(bx2-cx)<rIn-2)buf.add(Math.round(bx2),Math.round(by2),L.bright,0.5); }
    metalRing(buf,cx,cy,Rc,GOLD,seed);
  }

  /* ============================================================
     BOUTON + nuée d'yeux (porté)
     ============================================================ */
  var DROP=4*R,TH=3*R;
  function genEyes(W,hslab,seed,label){
    var rnd=mulberry32((seed*9301+7)|0);
    var L=labelPts(label,W/2,Math.round((hslab-7*R)/2));
    var tx0=L.ox-2*R,tx1=L.ox+L.w+1*R,ty0=L.oy-2*R,ty1=L.oy+L.h+1*R;
    var n=Math.max(2,Math.min(9,Math.round((W-2*TH)/(20*R)))), eyes=[], tries=0;
    while(eyes.length<n&&tries<n*14){ tries++;
      var r=(3+Math.floor(rnd()*5))*R;
      var ex=TH+r+rnd()*(W-2*(TH+r));
      var ey=TH+r*0.7+rnd()*(hslab-2*TH-r*1.4);
      if(ex>tx0-r&&ex<tx1+r&&ey>ty0-r&&ey<ty1+r)continue;
      var ok=true; for(var j=0;j<eyes.length;j++){ if(Math.hypot(ex-eyes[j].ex,ey-eyes[j].ey)<(r+eyes[j].r)*0.78){ ok=false; break; } }
      if(!ok)continue;
      var pr=rnd();
      eyes.push({ex:ex,ey:ey,r:r,squash:0.55+rnd()*0.32,skew:(rnd()-0.5)*0.5,
        pupil:pr<0.62?'slit_v':(pr<0.82?'round':'slit_h'),
        inject:rnd()<0.45?0.3+rnd()*0.55:0,
        scl:[168+(rnd()*22-11),148+(rnd()*30-15),118+(rnd()*34)],phase:rnd()*10});
    }
    return eyes;
  }
  function drawButton(buf,W,H,press,eyeOpen,glow,seed,label,disabled,eyes,mx,my,t){
    var hslab=H-DROP, slabY=Math.round(press*(DROP-R));
    dropShadow(buf,W,hslab);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    panelFill(buf,x0+TH,y0+TH,x1-TH,y1-TH,press);
    if(disabled)for(var yy=y0+TH;yy<=y1-TH;yy++)for(var xx=x0+TH;xx<=x1-TH;xx++)buf.blendOver(xx,yy,[18,16,22],0.4);
    if(!disabled&&eyes&&eyeOpen>0.02){
      for(var i=0;i<eyes.length;i++){ var e=eyes[i];
        var gx=mx+Math.sin(t*1.1+e.phase)*1.6*R, gy=my+Math.cos(t*0.9+e.phase)*1.6*R;
        drawEyeAt(buf,Math.round(e.ex),Math.round(slabY+e.ey),e.r,eyeOpen,glow,t,seed+e.phase*7,
          {gaze:[gx,gy],squash:e.squash,skew:e.skew,pupil:e.pupil,inject:e.inject,scl:e.scl});
      }
    }
    metalBorder(buf,x0,y0,x1,y1,GOLD,TH,press+(disabled?0.5:0),seed);
    var rv=4*R; rivet(buf,x0+rv,y0+rv,GOLD); rivet(buf,x1-rv,y0+rv,GOLD); rivet(buf,x0+rv,y1-rv,GOLD); rivet(buf,x1-rv,y1-rv,GOLD);
    if(disabled){ // liseré scellé pointillé
      for(var dx=x0+rv+2*R;dx<x1-rv-2*R;dx+=3*R){ buf.set(dx,y0+1,hexRgb('#241c14')); buf.set(dx,y1-1,hexRgb('#241c14')); }
    }
    var Lb=labelPts(label,W/2,slabY+Math.round((hslab-7*R)/2));
    goldText(buf,Lb.pts,disabled?0:glow*0.5,t,seed);
    if(disabled)for(var i2=0;i2<Lb.pts.length;i2++)buf.blendOver(Lb.pts[i2][0],Lb.pts[i2][1],[38,34,28],0.5);
  }

  /* bouton d'économie : plus petit, label + coût gemme */
  function drawEcoBtn(buf,W,H,press,glow,seed,label,cost,disabled,t){
    var hslab=H-DROP, slabY=Math.round(press*(DROP-R));
    dropShadow(buf,W,hslab);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    panelFill(buf,x0+2*R,y0+2*R,x1-2*R,y1-2*R,press);
    if(disabled)for(var yy=y0+2*R;yy<=y1-2*R;yy++)for(var xx=x0+2*R;xx<=x1-2*R;xx++)buf.blendOver(xx,yy,[18,16,22],0.45);
    metalBorder(buf,x0,y0,x1,y1,GOLD,2*R,press+(disabled?0.4:0),seed);
    rivet(buf,x0+3*R,y0+3*R,GOLD); rivet(buf,x0+3*R,y1-3*R,GOLD);
    var cy=slabY+Math.round((hslab-7*R)/2);
    var lab=labelPts(label,(W-(cost!=null?14*R:0))/2,cy);
    goldText(buf,lab.pts,disabled?0:glow*0.45,t,seed);
    if(disabled)for(var i=0;i<lab.pts.length;i++)buf.blendOver(lab.pts[i][0],lab.pts[i][1],[38,34,28],0.5);
    if(cost!=null){
      var gx=x1-12*R, gy=slabY+hslab/2;
      drawDiamond(buf,gx,gy,3*R, disabled?mix(ACC.dark,[0,0,0],0.3):ACC.bright, disabled?[60,50,30]:ACC.mid);
      stampText(buf, String(cost), gx-7*R, gy-3.5*R, disabled?hexRgb('#5b4d44'):hexRgb('#e8dcc0'), GOLD.deep);
    }
  }

  function drawDiamond(buf,cx,cy,r,fill,edge){
    for(var y=-r;y<=r;y++)for(var x=-r;x<=r;x++){ if(Math.abs(x)+Math.abs(y)<=r){ var on=(Math.abs(x)+Math.abs(y)>=r-0.9); buf.set(Math.round(cx+x),Math.round(cy+y), on?edge:fill); } }
    buf.add(Math.round(cx-r*0.3),Math.round(cy-r*0.3),[255,255,255],0.4);
  }

  /* bouton-icône carré */
  function drawIconBtn(buf,W,H,press,glow,seed,kind,t){
    var hslab=H-DROP, slabY=Math.round(press*(DROP-R));
    dropShadow(buf,W,hslab);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    panelFill(buf,x0+2*R,y0+2*R,x1-2*R,y1-2*R,press);
    metalBorder(buf,x0,y0,x1,y1,GOLD,2*R,press,seed);
    rivet(buf,x0+3*R,y0+3*R,GOLD); rivet(buf,x1-3*R,y0+3*R,GOLD); rivet(buf,x0+3*R,y1-3*R,GOLD); rivet(buf,x1-3*R,y1-3*R,GOLD);
    var cx=W/2, cy=slabY+hslab/2, col=mix(hexRgb(GOLD.hi),ACC.bright,glow*0.6), r=hslab*0.28;
    if(kind==='sigil'){ // glyphe instable
      var amp=(0.3+glow*0.9+press*0.5)*R, pts=glyphPts(2,cx,cy,r), mut=[];
      for(var i=0;i<pts.length;i++)mut.push([pts[i][0]+Math.round(Math.sin(t*3+i*0.7+seed)*amp),pts[i][1]+Math.round(Math.cos(t*2.6+i*0.9+seed)*amp)]);
      goldText(buf,mut,glow+0.3,t,seed);
    } else if(kind==='left'||kind==='right'){
      var dir=kind==='left'?-1:1;
      for(var k=0;k<=r;k++){ var w=r-k; for(var j=-1;j<=1;j++){ var X=Math.round(cx+dir*(k-r/2)+j*0), Y; for(Y=Math.round(cy-w);Y<=Math.round(cy+w);Y++){} } }
      // chevron propre
      for(var s=-r;s<=r;s++){ var xx=Math.round(cx - dir*r*0.4 + dir*Math.abs(s)*0.85); buf.set(xx,Math.round(cy+s),col); buf.set(xx-dir,Math.round(cy+s),mix(col,GOLD.deep,0.4)); }
    } else if(kind==='back'){
      for(var s2=-r;s2<=r;s2++){ var xx2=Math.round(cx - r*0.4 + Math.abs(s2)*0.85); buf.set(xx2,Math.round(cy+s2),col); buf.set(xx2-1,Math.round(cy+s2),mix(col,GOLD.deep,0.4)); }
      for(var bx=0;bx<r*1.3;bx++)buf.set(Math.round(cx-r*0.4+bx),Math.round(cy),col);
    } else if(kind==='gear'){
      blit(buf,ICON.gear,Math.round(cx-4*R),Math.round(cy-4*R),col,R);
    }
  }

  /* ============================================================
     SIGIL (porté)
     ============================================================ */
  function drawSigil(buf,W,H,press,glow,seed,t,kind){
    var hslab=H-DROP, slabY=Math.round(press*(DROP-R));
    dropShadow(buf,W,hslab);
    var x0=0,y0=slabY,x1=W-1,y1=slabY+hslab-1;
    panelFill(buf,x0+TH,y0+TH,x1-TH,y1-TH,press);
    metalBorder(buf,x0,y0,x1,y1,GOLD,TH,press,seed);
    var cx=Math.round(W/2),cy=slabY+Math.round(hslab/2),r=Math.min(W,hslab)/2-5*R;
    var pts=glyphPts(kind,cx,cy,r),amp=(0.35+glow*0.95+press*0.6)*R, mut=[];
    for(var i=0;i<pts.length;i++)mut.push([pts[i][0]+Math.round(Math.sin(t*3+i*0.7+seed)*amp),pts[i][1]+Math.round(Math.cos(t*2.6+i*0.9+seed)*amp)]);
    goldText(buf,mut,glow,t,seed);
  }
  function glyphPts(kind,cx,cy,r){ var a=[],k,st=1/R;
    if(kind===0){ for(k=0;k<28*R;k++){ var an=k/(28*R)*6.283; a.push([Math.round(cx+Math.cos(an)*r),Math.round(cy+Math.sin(an)*r*0.8)]); } for(var yy=-r;yy<=r;yy+=st)a.push([cx,Math.round(cy+yy)]); for(var xx=-r;xx<=r;xx+=st)a.push([Math.round(cx+xx),cy]); a.push([cx,cy]); }
    else if(kind===1){ for(k=-r;k<=r;k+=st){ a.push([Math.round(cx+k),Math.round(cy-r+Math.abs(k))]); a.push([Math.round(cx+k),Math.round(cy+r-Math.abs(k))]); } }
    else if(kind===2){ for(k=0;k<5;k++){ var ang=k/5*6.283-1.57; a.push([Math.round(cx+Math.cos(ang)*r),Math.round(cy+Math.sin(ang)*r)]); var ang2=(k+0.5)/5*6.283-1.57; a.push([Math.round(cx+Math.cos(ang2)*r*0.45),Math.round(cy+Math.sin(ang2)*r*0.45)]); } a.push([cx,cy]); }
    else{ for(k=-r;k<=r;k+=st){ a.push([Math.round(cx+k),cy]); a.push([cx,Math.round(cy+k)]); a.push([Math.round(cx+k),Math.round(cy+k)]); a.push([Math.round(cx+k),Math.round(cy-k)]); } }
    return a;
  }

  /* ============================================================
     JAUGE DE VIE + faim + segments d'altération + alarme
     ============================================================ */
  function drawHealthGauge(buf,W,H,val,segs,accName,t){
    var acc=LIQUIDS[accName]||LIQUIDS.blood, deep=hexRgb(GOLD.deep);
    var TH2=2*R, barH=16*R, x0=TH2,y0=TH2,x1=W-1-TH2,y1=barH-1-TH2, innerW=x1-x0+1;
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)buf.set(x,y,mix(hexRgb('#09070d'),hexRgb('#181420'),(BAYER[y&3][x&3]/15)*0.4));
    var low=val<0.25, breath=Math.sin(t*2.0)*(0.5*R), spasm=low?Math.sin(t*9+1)*(1.5*R):0;
    var segTotal=0; for(var i=0;i<(segs||[]).length;i++)segTotal+=segs[i].frac;
    var fwf=innerW*clamp(val)+breath+spasm, pulse=low?(0.55+0.45*Math.sin(t*7)):1;
    for(var y2=y0;y2<=y1;y2++){
      var frontX=x0+fwf+Math.sin(y2*(0.9/R)+t*3.0)*(1.0*R);
      for(var x2=x0;x2<=x1;x2++){
        if(x2>frontX)break;
        var dith=BAYER[y2&3][x2&3]/15, col=mix(acc.dark,acc.mid,0.4+dith*0.34);
        // segments d'altération : peignent depuis le front vers la gauche
        var fromFront=(frontX-x2)/innerW;
        var segAcc=0;
        for(var k=0;k<(segs||[]).length;k++){ if(fromFront<segAcc+segs[k].frac && fromFront>=segAcc){ col=mix(segs[k].color, col, 0.35+dith*0.2); } segAcc+=segs[k].frac; }
        if(y2<y0+R)col=mix(col,acc.bright,0.4); else if(y2>y1-R)col=mix(col,deep,0.45);
        var sline=Math.sin(x2*(0.5/R)-t*4)+Math.cos(y2*(0.9/R)); if(sline>1.4)col=mix(col,acc.bright,0.32);
        if(low)col=mix(col,acc.bright,(pulse-0.55)*0.5);
        buf.set(x2,y2,col);
      }
      var fx=Math.round(frontX); if(fx>=x0&&fx<=x1){ buf.set(fx,y2,mix(acc.bright,acc.mid,0.2)); buf.add(fx+1,y2,acc.mid,0.45*pulse); buf.add(fx+2,y2,acc.mid,0.16*pulse); }
    }
    metalBorder(buf,0,0,W-1,barH-1,GOLD,TH2,0,50);
    /* rangée d'icônes d'afflictions actives */
    if(segs&&segs.length){ var ix=2*R, iy=barH+3*R; for(var s=0;s<segs.length;s++){ if(segs[s].bmp){ blit(buf,segs[s].bmp,ix,iy,segs[s].color,R); ix+=10*R; } } }
  }

  /* jauge simple (Essence / Ferveur) */
  function drawBar(buf,W,H,val,accName,t){
    var acc=LIQUIDS[accName]||LIQUIDS.blood,deep=hexRgb(GOLD.deep);
    var TH2=2*R,x0=TH2,y0=TH2,x1=W-1-TH2,y1=H-1-TH2,innerW=x1-x0+1;
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++)buf.set(x,y,mix(hexRgb('#09070d'),hexRgb('#181420'),(BAYER[y&3][x&3]/15)*0.4));
    var low=val<0.25, breath=Math.sin(t*2.0)*(0.5*R), spasm=low?Math.sin(t*9+1)*(1.5*R):0;
    var fwf=innerW*clamp(val)+breath+spasm, pulse=low?(0.55+0.45*Math.sin(t*7)):1;
    for(var y2=y0;y2<=y1;y2++){
      var frontX=x0+fwf+Math.sin(y2*(0.9/R)+t*3.0)*(1.0*R);
      for(var x2=x0;x2<=x1;x2++){ if(x2>frontX)break; var dith=BAYER[y2&3][x2&3]/15,col=mix(acc.dark,acc.mid,0.4+dith*0.34); if(y2<y0+R)col=mix(acc.mid,acc.bright,0.5); else if(y2>y1-R)col=mix(acc.dark,deep,0.45); var s=Math.sin(x2*(0.5/R)-t*4)+Math.cos(y2*(0.9/R)); if(s>1.4)col=mix(col,acc.bright,0.32); if(low)col=mix(col,acc.bright,(pulse-0.55)*0.5); buf.set(x2,y2,col); }
      var fx=Math.round(frontX); if(fx>=x0&&fx<=x1){ buf.set(fx,y2,mix(acc.bright,acc.mid,0.2)); buf.add(fx+1,y2,acc.mid,0.45*pulse); }
    }
    metalBorder(buf,0,0,W-1,H-1,GOLD,TH2,0,50);
  }

  /* ============================================================
     PLAQUE HUD
     ============================================================ */
  function drawHudPlate(buf,W,H,t,segments){
    panelFill(buf,2*R,2*R,W-3*R,H-3*R,0);
    metalBorder(buf,0,0,W-1,H-1,GOLD,2*R,0,71);
    rivet(buf,4*R,4*R,GOLD); rivet(buf,W-4*R,4*R,GOLD); rivet(buf,4*R,H-4*R,GOLD); rivet(buf,W-4*R,H-4*R,GOLD);
    var x=8*R, cy=Math.round(H/2-3.5*R);
    for(var i=0;i<segments.length;i++){
      var seg=segments[i];
      stampText(buf,seg.label,x,cy,hexRgb('#6a5a4a'),GOLD.deep); x+=measure(seg.label).w+3*R;
      var lab=leftPts(seg.val,x,cy); goldText(buf,lab.pts,0.3,t,i); x+=lab.w+9*R;
      if(i<segments.length-1){ for(var dy=-3*R;dy<=3*R;dy++)buf.set(x-5*R,cy+3.5*R+dy,mix(hexRgb('#2a2218'),hexRgb('#4a3a22'),0.5)); }
    }
  }

  /* ============================================================
     CADRE 9-SLICE (porté) + variantes
     ============================================================ */
  function drawPanel(buf,W,H,t,title){
    var B=4*R;
    panelFill(buf,B,B,W-B-1,H-B-1,0);
    for(var y=B+1;y<H-B-1;y++)for(var x=B+1;x<W-B-1;x++){ var m=Math.sin(x*(0.13/R)+t*0.6)+Math.sin(y*(0.17/R)-t*0.5)+Math.sin((x+y)*(0.07/R)+t*0.3); if(m>1.7)buf.blendOver(x,y,[6,4,10],0.16*(m-1.7)); }
    veins(buf,B,B,W-B-1,H-B-1,77,t,1);
    var ec=((t*0.085+0.3)%1), eo=ec<0.14?Math.sin(ec/0.14*Math.PI):0;
    if(eo>0.01)drawEyeAt(buf,Math.round(W*0.72),Math.round(H*0.58),6*R,clamp(eo),0.55,t,909,{});
    metalBorder(buf,0,0,W-1,H-1,GOLD,B,0,60);
    cornerPiece(buf,0,0,false,false,t); cornerPiece(buf,W-8*R,0,true,false,t); cornerPiece(buf,0,H-8*R,false,true,t); cornerPiece(buf,W-8*R,H-8*R,true,true,t);
    if(title){ var t1=labelPts(title,W/2,11*R); goldText(buf,t1.pts,0.4+0.14*orgPulse(t,2),t,3); }
  }

  /* tooltip = mini panneau 9-slice + lignes */
  function drawTooltip(buf,W,H,t,lines){
    var B=3*R;
    panelFill(buf,B,B,W-B-1,H-B-1,0);
    veins(buf,B,B,W-B-1,H-B-1,42,t,0.6);
    metalBorder(buf,0,0,W-1,H-1,GOLD,B,0,62);
    cornerPiece(buf,0,0,false,false,t); cornerPiece(buf,W-8*R,0,true,false,t); cornerPiece(buf,0,H-8*R,false,true,t); cornerPiece(buf,W-8*R,H-8*R,true,true,t);
    var y=8*R;
    for(var i=0;i<lines.length;i++){ var ln=lines[i];
      if(ln.gold){ var lp=leftPts(ln.txt,7*R,y); goldText(buf,lp.pts,0.3,t,i); }
      else stampText(buf,ln.txt,7*R,y,ln.color||hexRgb('#b8a98c'),GOLD.deep);
      y+=(ln.gap||10)*R;
    }
  }

  /* bannière de résultat */
  function drawBanner(buf,W,H,word,kind,t){
    var col=kind==='defeat'?hexRgb('#b33833'):hexRgb('#d6b25a'), glowC=kind==='defeat'?hexRgb('#ff5a4a'):ACC.bright;
    var my=Math.round(H/2);
    for(var ry=-1;ry<=1;ry+=2){ var yy=my+ry*(H/2-3*R); for(var x=4*R;x<W-4*R;x++){ var a=1-Math.abs(x-W/2)/(W/2-4*R); buf.set(x,yy,mix(hexRgb(GOLD.deep),hexRgb(GOLD.hi),0.5*a)); buf.set(x,yy+ry,mix(hexRgb(GOLD.deep),hexRgb(GOLD.base),0.35*a)); } }
    // mot agrandi (binarisé puis 2×)
    var m=textMask(word), oxs=Math.round((W-m.w*2)/2), oys=Math.round((H-m.h*2)/2);
    var puls=0.7+0.3*Math.sin(t*3);
    for(var i=0;i<m.pix.length;i++){ var px=oxs+m.pix[i][0]*2, py=oys+m.pix[i][1]*2;
      for(var sy=0;sy<2;sy++)for(var sx=0;sx<2;sx++){ buf.set(px+sx+1,py+sy+1,hexRgb(GOLD.deep)); } }
    for(i=0;i<m.pix.length;i++){ var px2=oxs+m.pix[i][0]*2, py2=oys+m.pix[i][1]*2;
      for(var sy2=0;sy2<2;sy2++)for(var sx2=0;sx2<2;sx2++){ buf.set(px2+sx2,py2+sy2,mix(col,glowC,0.25*puls)); } }
  }

  /* liste scrollable (cadre + lignes clippées + scrollbar) */
  function drawScrollList(buf,W,H,t,rows,scroll){
    var B=4*R;
    panelFill(buf,B,B,W-B-1,H-B-1,0);
    metalBorder(buf,0,0,W-1,H-1,GOLD,B,0,64);
    cornerPiece(buf,0,0,false,false,t); cornerPiece(buf,W-8*R,0,true,false,t); cornerPiece(buf,0,H-8*R,false,true,t); cornerPiece(buf,W-8*R,H-8*R,true,true,t);
    var clipX0=B+3*R, clipX1=W-B-9*R, rh=13*R, y=B+4*R-scroll;
    for(var i=0;i<rows.length;i++){
      var ry=y+i*rh;
      if(ry>=B+1 && ry+rh<=H-B-1){
        if(rows[i].sel){ for(var yy=ry;yy<ry+rh-2*R;yy++)for(var xx=clipX0;xx<=clipX1;xx++)buf.blendOver(xx,yy,ACC.dark,0.35); }
        stampText(buf,rows[i].txt,clipX0+2*R,ry+2*R,rows[i].sel?ACC.bright:hexRgb('#a8997e'),GOLD.deep);
      }
    }
    // scrollbar
    drawScrollbar(buf,W-B-6*R,B+2*R,6*R,H-2*B-4*R,scroll/Math.max(1,(rows.length*rh-(H-2*B))),0.4);
  }

  function drawScrollbar(buf,x,y,w,h,pos,thumbFrac){
    for(var yy=y;yy<y+h;yy++)for(var xx=x;xx<x+w;xx++)buf.set(xx,yy,mix(hexRgb('#0a0810'),hexRgb('#161020'),(BAYER[yy&3][xx&3]/15)*0.5));
    var th=Math.max(8*R,h*thumbFrac), ty=y+(h-th)*clamp(pos);
    metalBorder(buf,x,Math.round(ty),x+w-1,Math.round(ty+th-1),GOLD,2*R,0,80);
    panelFill(buf,x+2*R,Math.round(ty)+2*R,x+w-3*R,Math.round(ty+th)-3*R,0);
  }

  /* ============================================================
     CASE DU PLATEAU (6 états)
     ============================================================ */
  function drawSlot(buf,W,H,state,unit,t){
    var x0=0,y0=0,x1=W-1,y1=H-1, bc, bg=hexRgb('#100a13');
    if(state==='locked'){ bg=hexRgb('#0a070d'); bc=hexRgb('#221c28'); }
    else if(state==='neighbor'){ bc=hexRgb('#a12924'); }
    else if(state==='hover'){ bc=ACC.bright; }
    else if(state==='drop'){ bc=hexRgb('#6bc766'); }
    else if(state==='occupied'){ bc=mix(hexRgb('#524759'),ACC.mid,0.3); }
    else bc=hexRgb('#524759');
    panelFill(buf,2*R,2*R,x1-2*R,y1-2*R,0);
    // bordure d'état (épaisse, biseautée légère)
    for(var y=y0;y<=y1;y++)for(var x=x0;x<=x1;x++){ var dm=Math.min(x-x0,x1-x,y-y0,y1-y); if(dm<2*R){ var c=dm<R?mix(bc,[0,0,0],0.5):bc; buf.set(x,y,c); } }
    if(state==='locked'){
      // pointillé scellé + glyphe +
      for(var d=4*R;d<W-4*R;d+=3*R){ buf.set(d,2*R,hexRgb('#2a232c')); buf.set(d,H-1-2*R,hexRgb('#2a232c')); buf.set(2*R,d,hexRgb('#2a232c')); buf.set(W-1-2*R,d,hexRgb('#2a232c')); }
      var cc=mix(hexRgb('#2a232c'),hexRgb('#3a3140'),0.5+0.5*orgPulse(t,5));
      for(var k=-3*R;k<=3*R;k++){ buf.set(Math.round(W/2)+k,Math.round(H/2),cc); buf.set(Math.round(W/2),Math.round(H/2)+k,cc); }
    } else if(state==='drop'){
      // chevron ▼ vert
      var g2=mix(hexRgb('#3a6b3a'),hexRgb('#8fff8f'),0.5+0.5*Math.sin(t*5));
      for(var s=0;s<=4*R;s++){ var w=4*R-s; for(var j=-w;j<=w;j++)buf.set(Math.round(W/2)+j,Math.round(H/2-3*R)+s,g2); }
    } else if(state==='occupied'||state==='neighbor'){
      var f=FAM[unit.fam];
      stripeFill(buf,8*R,9*R,W-9*R,H-9*R,f.d,hexRgb('#08050a'),3*R);
      // liseré sprite
      for(var yy=9*R;yy<=H-9*R;yy++)for(var xx=8*R;xx<=W-9*R;xx++){ var dm2=Math.min(xx-8*R,(W-9*R)-xx,yy-9*R,(H-9*R)-yy); if(dm2<R)buf.set(xx,yy,mix(f.c,[0,0,0],0.2)); }
      drawTypePip(buf,9*R,8*R,unit.fam,t);
      // pips de niveau
      if(unit.level){ for(var lv=0;lv<unit.level;lv++)drawDiamond(buf,W-8*R-lv*5*R,8*R,2*R,ACC.bright,ACC.mid); }
      if(state==='occupied'){ rivet(buf,3*R,3*R,GOLD); rivet(buf,W-3*R,3*R,GOLD); rivet(buf,3*R,H-3*R,GOLD); rivet(buf,W-3*R,H-3*R,GOLD); }
    }
    if(state==='hover'||state==='neighbor'||state==='drop'){ // halo léger
      var hc=state==='neighbor'?hexRgb('#a12924'):(state==='drop'?hexRgb('#6bc766'):ACC.bright);
      for(var e=0;e<W;e++){ buf.add(e,1,hc,0.15); buf.add(e,H-2,hc,0.15); }
    }
  }

  /* ============================================================
     CARTE DE BOUTIQUE
     ============================================================ */
  function drawShopCard(buf,W,H,state,unit,t){
    var afford=(state==='afford'||state==='hover'), sold=state==='sold';
    var frameM= afford?GOLD:{deep:'#0c0a08',sh:'#1a160f',base:'#2a2418',mid:'#352c1c',hi:'#473a22',glow:'#5a4a28'};
    panelFill(buf,3*R,3*R,W-4*R,H-4*R,state==='hover'?-0.15:0);
    if(sold){ for(var y=3*R;y<H-3*R;y++)for(var x=3*R;x<W-3*R;x++)buf.blendOver(x,y,[8,6,10],0.55); }
    metalBorder(buf,0,0,W-1,H-1,frameM,3*R,0,unit.seed||33);
    if(afford){ rivet(buf,5*R,5*R,GOLD); rivet(buf,W-5*R,5*R,GOLD); rivet(buf,5*R,H-5*R,GOLD); rivet(buf,W-5*R,H-5*R,GOLD); }
    if(sold){ var bp=labelPts('SOLD',W/2,H/2-4*R); for(var i=0;i<bp.pts.length;i++)buf.set(bp.pts[i][0],bp.pts[i][1],hexRgb('#3a2f2a')); return; }
    var f=FAM[unit.fam];
    // mini portrait
    stripeFill(buf,8*R,8*R,W-9*R,H*0.5,f.d,hexRgb('#08050a'),3*R);
    if(state==='hover')for(var yy=8*R;yy<=H*0.5;yy++)for(var xx=8*R;xx<=W-9*R;xx++){ var dm=Math.min(xx-8*R,(W-9*R)-xx,yy-8*R,(H*0.5)-yy); if(dm<R)buf.set(xx,yy,f.c); }
    // mini-icônes afflictions
    var ax=8*R, ay=Math.round(H*0.5)+3*R;
    for(var k=0;k<(unit.affl||[]).length;k++){ var a=AFFL[unit.affl[k]]; if(a){ blit(buf,a.bmp,ax,ay,afford?a.c:mix(a.c,[20,20,20],0.5),R); ax+=10*R; } }
    // nom
    var nm=unit.name.toUpperCase();
    stampText(buf,nm,8*R,Math.round(H*0.65),afford?hexRgb('#cdbca0'):hexRgb('#6a5a4a'),GOLD.deep);
    // coût
    var gx=W-12*R, gy=H-9*R;
    drawDiamond(buf,gx,gy,3*R, afford?ACC.bright:mix(ACC.dark,[0,0,0],0.3), afford?ACC.mid:[60,50,30]);
    stampText(buf,String(unit.cost),gx-7*R,gy-3.5*R, afford?hexRgb('#e8dcc0'):hexRgb('#5b4d44'),GOLD.deep);
  }

  /* emplacement de relique possédée */
  function drawRelicSlot(buf,W,H,state,glyphFam,t){
    panelFill(buf,2*R,2*R,W-3*R,H-3*R,0);
    metalBorder(buf,0,0,W-1,H-1,GOLD,2*R,0,90);
    rivet(buf,4*R,4*R,GOLD); rivet(buf,W-4*R,4*R,GOLD); rivet(buf,4*R,H-4*R,GOLD); rivet(buf,W-4*R,H-4*R,GOLD);
    var f=FAM[glyphFam]||FAM.abyss, cx=W/2, cy=H/2, g=state==='hover'?(0.6+0.4*orgPulse(t,3)):0.3;
    // icône sertie (losange facetté famille)
    drawDiamond(buf,cx,cy,5*R, mix(f.d,f.c,0.4), mix(f.c,ACC.bright,g*0.5));
    buf.add(Math.round(cx-1),Math.round(cy-1),[255,255,255],0.4*g+0.2);
    if(state==='hover'){ for(var e=0;e<W;e++){ buf.add(e,1,ACC.bright,0.18); buf.add(e,H-2,ACC.bright,0.18); } }
  }

  /* ============================================================
     ATOMES
     ============================================================ */
  function drawTypePip(buf,x,y,fam,t){
    var f=FAM[fam], r=4*R, cx=x+r, cy=y+r, c=f.c, e=mix(f.c,[0,0,0],0.4);
    if(f.shape==='bar'){ for(var yy=-1*R;yy<=1*R;yy++)for(var xx=-r;xx<=r;xx++)buf.set(cx+xx,cy+yy,Math.abs(xx)>r-R?e:c); }
    else if(f.shape==='cross'){ for(var k=-r;k<=r;k++){ buf.set(cx+k,cy,Math.abs(k)>r-R?e:c); buf.set(cx,cy+k,Math.abs(k)>r-R?e:c); buf.set(cx+k,cy-1,c); buf.set(cx-1,cy+k,c); } }
    else if(f.shape==='diamond'){ drawDiamond(buf,cx,cy,r,c,e); }
    else if(f.shape==='star'){ for(var s=0;s<5;s++){ var a1=s/5*6.283-1.57; for(var rr=0;rr<=r;rr++)buf.set(Math.round(cx+Math.cos(a1)*rr),Math.round(cy+Math.sin(a1)*rr),rr>r-R?e:c); } buf.set(cx,cy,c); }
    else{ for(var yy2=-r;yy2<=r;yy2++)for(var xx2=-r;xx2<=r;xx2++){ var d=Math.hypot(xx2,yy2); if(d<=r)buf.set(cx+xx2,cy+yy2,d>r-R?e:c); } }
    buf.add(Math.round(cx-r*0.3),Math.round(cy-r*0.3),[255,255,255],0.25);
  }

  function drawKwChip(buf,W,H,affKey,label,value,t,active){
    var fam=AFFL[affKey], col=fam?fam.c:hexRgb('#9a8a72');
    var y0=2*R,y1=H-3*R;
    if(active){ pillFill(buf,2*R,y0,W-3*R,y1,mix(col,[0,0,0],0.4)); pillFill(buf,4*R,y0+2*R,W-5*R,y1-2*R,mix(col,hexRgb('#0a0608'),0.3)); }
    else{ pillFill(buf,2*R,y0,W-3*R,y1,mix(col,[0,0,0],0.55)); pillFill(buf,4*R,y0+2*R,W-5*R,y1-2*R,hexRgb('#0d0a0e')); }
    var tx=8*R, cy=Math.round((y0+y1)/2);
    if(fam){ blit(buf,fam.bmp,tx,cy-4*R,col,R); tx+=11*R; }
    stampText(buf,label,tx,cy-3.5*R, active?hexRgb('#1a1008'):mix(col,hexRgb('#fff'),0.35), null);
    tx+=measure(label).w+3*R;
    if(value!=null){ stampText(buf,String(value),W-11*R,cy-3.5*R, active?hexRgb('#1a1008'):hexRgb('#e8dcc0'), GOLD.deep); }
  }

  function drawLevelPips(buf,W,H,n,t){
    for(var i=0;i<n;i++){ var cx=6*R+i*9*R, cy=H/2; drawDiamond(buf,cx,cy,3*R, mix(ACC.mid,ACC.bright,0.5+0.5*orgPulse(t,i)), ACC.dark); }
  }

  function drawGem(buf,W,H,on,t){
    var cx=W/2, cy=H/2, Rc=Math.min(W,H)/2-2*R;
    metalRing(buf,cx,cy,Rc,GOLD,7);
    var r=Rc-4*R, g=on?(0.55+0.45*orgPulse(t,2)):0;
    if(on){ // gemme facettée éveillée
      for(var y=-r;y<=r;y++)for(var x=-r;x<=r;x++){ if(Math.abs(x)+Math.abs(y)<=r){ var on2=(Math.abs(x)+Math.abs(y)>=r-0.9); var c=on2?mix(ACC.dark,ACC.mid,0.5):mix(ACC.mid,ACC.bright,g*(1-(Math.abs(x)+Math.abs(y))/r)); buf.set(Math.round(cx+x),Math.round(cy+y),c); } }
      buf.add(Math.round(cx-r*0.3),Math.round(cy-r*0.3),[255,255,255],0.6);
      buf.add(Math.round(cx),Math.round(cy),ACC.bright,g*0.5);
    } else {
      for(var y2=-r;y2<=r;y2++)for(var x2=-r;x2<=r;x2++){ if(Math.abs(x2)+Math.abs(y2)<=r){ var on3=(Math.abs(x2)+Math.abs(y2)>=r-0.9); buf.set(Math.round(cx+x2),Math.round(cy+y2), on3?hexRgb('#241c14'):hexRgb('#120d08')); } }
    }
  }

  /* échelle de rareté R1→R5 */
  function drawRarityScale(buf,W,H,current,t){
    var n=5, cw=Math.floor(W/n), fw=cw-4*R, fh=H-12*R;
    for(var i=0;i<n;i++){
      var cur=(i+1)===current, x0=i*cw+2*R, y0=2*R, x1=x0+fw, y1=y0+fh;
      var M=cur?GOLD:{deep:'#0c0a08',sh:'#1a160f',base:'#2a2418',mid:'#352c1c',hi:'#473a22',glow:'#5a4a28'};
      panelFill(buf,x0+2*R,y0+2*R,x1-2*R,y1-2*R,cur?-0.2:0);
      if(cur){ for(var yy=y0+2*R;yy<=y1-2*R;yy++)for(var xx=x0+2*R;xx<=x1-2*R;xx++)buf.add(xx,yy,ACC.mid,0.12*orgPulse(t,i)); }
      metalBorder(buf,x0,y0,x1,y1,M,2*R,0,100+i);
      // label R1..
      stampText(buf,'R'+(i+1),x0+Math.round(fw/2-5*R),y1+3*R, cur?ACC.bright:hexRgb('#5b4d44'),GOLD.deep);
      // pips étoiles
      var px=x0+3*R, py=y1-7*R;
      for(var s=0;s<=i;s++){ drawDiamond(buf,px+s*3*R,py,1.4*R, cur?ACC.bright:hexRgb('#4a3f2a'), GOLD.deep); }
    }
  }

  /* ============================================================
     CARTE MONSTRE (composé riche)
     ============================================================ */
  function drawMonsterCard(buf,W,H,u,t,gilded){
    var B=4*R;
    panelFill(buf,B,B,W-B-1,H-B-1,0);
    veins(buf,B,B,W-B-1,H-B-1,55,t,0.7);
    var f=FAM[u.fam];
    metalBorder(buf,0,0,W-1,H-1,GOLD,B,0,55);
    cornerPiece(buf,0,0,false,false,t); cornerPiece(buf,W-8*R,0,true,false,t); cornerPiece(buf,0,H-8*R,false,true,t); cornerPiece(buf,W-8*R,H-8*R,true,true,t);
    var y=9*R;
    // nom + coût
    var np=leftPts(u.name.toUpperCase(),9*R,y); goldText(buf,np.pts,0.4,t,1);
    var gx=W-13*R, gy=y+3*R; drawDiamond(buf,gx,gy,3.5*R,ACC.bright,ACC.mid); stampText(buf,String(u.cost),gx-8*R,gy-3.5*R,hexRgb('#e8dcc0'),GOLD.deep);
    y+=12*R;
    // portrait
    var py0=y, py1=y+H*0.34;
    stripeFill(buf,10*R,py0,W-11*R,py1,f.d,hexRgb('#08050a'),3*R);
    for(var yy=py0;yy<=py1;yy++)for(var xx=10*R;xx<=W-11*R;xx++){ var dm=Math.min(xx-10*R,(W-11*R)-xx,yy-py0,py1-yy); if(dm<R*1.5)buf.set(xx,yy,mix(f.c,gilded?ACC.bright:f.c,0.4)); }
    stampText(buf,'[ RIG ]',Math.round(W/2-12*R),Math.round((py0+py1)/2-3*R),mix(f.c,[255,255,255],0.3),null);
    y=py1+5*R;
    // type · famille · rang
    drawTypePip(buf,9*R,y-1*R,u.fam,t);
    stampText(buf,f.lab,19*R,y, f.c, GOLD.deep);
    var sx=W-9*R-u.rank*4*R;
    for(var s=0;s<u.rank;s++)drawDiamond(buf,sx+s*4*R,y+3*R,1.6*R,ACC.bright,GOLD.deep);
    y+=11*R;
    // chips
    var cx2=9*R;
    for(var c=0;c<u.chips.length;c++){ var ch=u.chips[c], cwid=(measure(ch.label).w+(ch.affl?11*R:0)+14*R); 
      drawKwChipInline(buf,cx2,y,cwid,9*R,ch.affl,ch.label); cx2+=cwid+3*R; }
    y+=13*R;
    // divider
    for(var x=9*R;x<W-9*R;x++){ var a=1-Math.abs(x-W/2)/((W-18*R)/2); buf.set(x,y,mix(hexRgb(GOLD.deep),hexRgb(GOLD.hi),0.5*a)); }
    drawDiamond(buf,W/2,y,2*R,ACC.bright,ACC.mid);
    y+=7*R;
    // stats
    blit(buf,ICON.heart,9*R,y,hexRgb('#c25a48'),R); stampText(buf,String(u.hp),18*R,y,hexRgb('#cdbca0'),GOLD.deep);
    blit(buf,ICON.sword,Math.round(W*0.40),y-R,hexRgb('#b8a98c'),R); stampText(buf,String(u.dmg),Math.round(W*0.40)+9*R,y,hexRgb('#cdbca0'),GOLD.deep);
    blit(buf,ICON.clock,Math.round(W*0.70),y,hexRgb('#9aa0b0'),R); stampText(buf,u.cd+'s',Math.round(W*0.70)+9*R,y,hexRgb('#cdbca0'),GOLD.deep);
    y+=11*R;
    for(var x2=9*R;x2<W-9*R;x2++){ var a2=1-Math.abs(x2-W/2)/((W-18*R)/2); buf.set(x2,y,mix(hexRgb(GOLD.deep),hexRgb(GOLD.hi),0.4*a2)); }
    y+=6*R;
    // capacité
    var ab=u.ability;
    drawDiamond(buf,11*R,y+3*R,2.5*R,ACC.bright,ACC.mid);
    if(ab.affl)blit(buf,AFFL[ab.affl].bmp,16*R,y,AFFL[ab.affl].c,R);
    var apx=ab.affl?27*R:16*R;
    stampText(buf,ab.name,apx,y, ACC.bright, GOLD.deep);
    stampText(buf,ab.val,W-9*R-measure(ab.val).w,y,hexRgb('#9a8a72'),GOLD.deep);
    y+=10*R;
    stampText(buf,ab.prose,11*R,y,hexRgb('#8a7d66'),null);
    y+=12*R;
    // flavor
    if(y<H-12*R){ stampText(buf,u.flavor,9*R,y,mix(hexRgb('#7a6a58'),f.c,0.2),null); }
  }
  function drawKwChipInline(buf,x,y,w,h,affKey,label){
    var fam=AFFL[affKey], col=fam?fam.c:hexRgb('#9a8a72');
    pillFill(buf,x,y,x+w,y+h,mix(col,[0,0,0],0.55)); pillFill(buf,x+2*R,y+2*R,x+w-2*R,y+h-2*R,hexRgb('#0d0a0e'));
    var tx=x+6*R, cy=y+Math.round(h/2);
    if(fam){ blit(buf,fam.bmp,tx,cy-4*R,col,R); tx+=10*R; }
    stampText(buf,label,tx,cy-3.5*R,mix(col,hexRgb('#fff'),0.4),null);
  }

  /* carte de relique (1 parmi 3) */
  function drawRelicCard(buf,W,H,state,relic,t){
    var sel=state==='selected', hov=state==='hover';
    var B=4*R;
    panelFill(buf,B,B,W-B-1,H-B-1,sel?-0.2:0);
    veins(buf,B,B,W-B-1,H-B-1,33,t,sel?1:0.5);
    var M=sel?GOLD:(hov?{deep:'#1a1208',sh:'#2a1e0c',base:'#4a3a1c',mid:'#6a5228',hi:'#8a6a34',glow:'#a07a3a'}:GOLD);
    metalBorder(buf,0,0,W-1,H-1,M,B,0,40);
    cornerPiece(buf,0,0,false,false,t); cornerPiece(buf,W-8*R,0,true,false,t); cornerPiece(buf,0,H-8*R,false,true,t); cornerPiece(buf,W-8*R,H-8*R,true,true,t);
    var f=FAM[relic.fam], cx=W/2, y=14*R;
    // icône bakée (grand losange facetté)
    var g=sel?(0.6+0.4*orgPulse(t,1)):(hov?0.4:0.2);
    drawDiamond(buf,cx,y+8*R,9*R, mix(f.d,f.c,0.45), mix(f.c,ACC.bright,g*0.6));
    buf.add(Math.round(cx-3*R),Math.round(cy_relic(y)-3*R),[255,255,255],0.4*g+0.2);
    y+=22*R;
    var np=labelPts(relic.name.toUpperCase(),cx,y); goldText(buf,np.pts,sel?0.6:0.35,t,2);
    y+=11*R;
    for(var x=10*R;x<W-10*R;x++){ var a=1-Math.abs(x-cx)/((W-20*R)/2); buf.set(x,y,mix(hexRgb(GOLD.deep),hexRgb(GOLD.hi),0.5*a)); }
    y+=6*R;
    var ep=labelPts(relic.effect,cx,y); goldText(buf,ep.pts,0.3,t,3);
    y+=12*R;
    var fp=labelPts(relic.flavor,cx,y); for(var i=0;i<fp.pts.length;i++)buf.set(fp.pts[i][0],fp.pts[i][1],hexRgb('#8a7d66'));
  }
  function cy_relic(y){ return y+8*R; }

  /* ligne de codex */
  function drawCodexRow(buf,W,H,state,entry,known,t){
    var sel=state==='selected', hov=state==='hover';
    panelFill(buf,1*R,1*R,W-2*R,H-2*R,0);
    var bc=sel?ACC.mid:(hov?mix(ACC.dark,ACC.mid,0.4):hexRgb('#1c1610'));
    for(var y=0;y<H;y++)for(var x=0;x<W;x++){ var dm=Math.min(x,W-1-x,y,H-1-y); if(dm<R)buf.set(x,y,bc); }
    if(sel||hov)for(var yy=2*R;yy<H-2*R;yy++)for(var xx=2*R;xx<W-2*R;xx++)buf.blendOver(xx,yy,ACC.dark,sel?0.3:0.16);
    // vignette
    var f=FAM[entry.fam]||FAM.bone;
    if(known){ stripeFill(buf,4*R,4*R,4*R+H-9*R,H-5*R,f.d,hexRgb('#08050a'),3*R); for(var yy2=4*R;yy2<=H-5*R;yy2++)for(var xx2=4*R;xx2<=4*R+H-9*R;xx2++){ var dm2=Math.min(xx2-4*R,(4*R+H-9*R)-xx2,yy2-4*R,(H-5*R)-yy2); if(dm2<R)buf.set(xx2,yy2,f.c); } }
    else{ panelFill(buf,4*R,4*R,4*R+H-9*R,H-5*R,0); for(var yy3=4*R;yy3<=H-5*R;yy3++)for(var xx3=4*R;xx3<=4*R+H-9*R;xx3++){ var dm3=Math.min(xx3-4*R,(4*R+H-9*R)-xx3,yy3-4*R,(H-5*R)-yy3); if(dm3<R)buf.set(xx3,yy3,hexRgb('#2a2228')); } stampText(buf,'?',Math.round(4*R+(H-9*R)/2-2*R),Math.round(H/2-4*R),hexRgb('#5b4d44'),null); }
    var tx=H+2*R, cy=Math.round(H/2);
    if(known){ stampText(buf,entry.name.toUpperCase(),tx,cy-6*R,sel?ACC.bright:hexRgb('#c7b899'),GOLD.deep); stampText(buf,f.lab+'  R'+entry.rank,tx,cy+2*R,hexRgb('#6a5a4a'),null); }
    else{ stampText(buf,'??????',tx,cy-6*R,hexRgb('#6a5a4a'),null); stampText(buf,'CRYPTIC',tx,cy+2*R,hexRgb('#4a3f36'),null); }
  }

  /* onglet */
  function drawTab(buf,W,H,active,label,t){
    var x0=0,y0=0,x1=W-1,y1=H-1;
    if(active){ panelFill(buf,3*R,3*R,x1-3*R,y1,-0.1); metalBorder(buf,0,0,x1,y1+4*R,GOLD,3*R,0,50); for(var xx=3*R;xx<x1-3*R;xx++)buf.add(xx,4*R,ACC.mid,0.1*orgPulse(t,1)); rivet(buf,5*R,5*R,GOLD); rivet(buf,x1-5*R,5*R,GOLD); var lp=labelPts(label,W/2,Math.round(H/2-3*R)); goldText(buf,lp.pts,0.4,t,2); }
    else{ for(var y=0;y<H;y++)for(var x=0;x<W;x++)buf.set(x,y,mix(hexRgb('#100c14'),hexRgb('#0a0710'),y/H)); for(var x2=0;x2<W;x2++){ buf.set(x2,0,hexRgb('#1c1620')); } stampText(buf,label,Math.round(W/2-measure(label).w/2),Math.round(H/2-3.5*R),hexRgb('#6a5a4a'),null); }
  }

  /* item de menu */
  function drawMenuItem(buf,W,H,state,label,t){
    var cy=Math.round(H/2-3.5*R);
    if(state==='disabled'){ var lp=leftPts(label,Math.round(W/2-measure(label).w/2),cy); for(var i=0;i<lp.pts.length;i++)buf.set(lp.pts[i][0],lp.pts[i][1],hexRgb('#3f352f')); stampText(buf,'( SEALED )',W-22*R,cy,hexRgb('#4a3036'),null); }
    else if(state==='hover'){ var lp2=labelPts(label,W/2,cy); goldText(buf,lp2.pts,0.7,t,1); var off=Math.round(2*R+Math.sin(t*4)*R); blit(buf,ICON.chev,Math.round(W/2-lp2.w/2-12*R-off),cy,ACC.bright,R); blit(buf,flipH(ICON.chev),Math.round(W/2+lp2.w/2+6*R+off),cy,ACC.bright,R); }
    else{ stampText(buf,label,Math.round(W/2-measure(label).w/2),cy,hexRgb('#9a8a72'),null); }
  }
  function flipH(bmp){ return bmp.map(function(r){ return r.split('').reverse().join(''); }); }

  /* puce de filtre */
  function drawFilterChip(buf,W,H,active,label,t){
    var y0=2*R,y1=H-3*R;
    if(active){ pillFill(buf,2*R,y0,W-3*R,y1,mix(ACC.dark,ACC.mid,0.5)); pillFill(buf,4*R,y0+2*R,W-5*R,y1-2*R,mix(ACC.mid,ACC.bright,0.4+0.2*orgPulse(t,1))); stampText(buf,label,Math.round(W/2-measure(label).w/2),Math.round((y0+y1)/2-3.5*R),hexRgb('#1a1008'),null); }
    else{ pillFill(buf,2*R,y0,W-3*R,y1,hexRgb('#2a2418')); pillFill(buf,4*R,y0+2*R,W-5*R,y1-2*R,hexRgb('#0d0a0e')); stampText(buf,label,Math.round(W/2-measure(label).w/2),Math.round((y0+y1)/2-3.5*R),hexRgb('#9a8a72'),null); }
  }

  /* bouton de tri / cycle */
  function drawSortBtn(buf,W,H,press,glow,label,t){
    var hslab=H-DROP, slabY=Math.round(press*(DROP-R));
    dropShadow(buf,W,hslab);
    panelFill(buf,2*R,slabY+2*R,W-3*R,slabY+hslab-3*R,press);
    metalBorder(buf,0,slabY,W-1,slabY+hslab-1,GOLD,2*R,press,72);
    var cy=slabY+Math.round((hslab-7*R)/2);
    stampText(buf,label,6*R,cy,mix(hexRgb('#b8a98c'),ACC.bright,glow*0.5),GOLD.deep);
    // chevron ▾
    var chx=W-11*R, chy=cy+1*R, c=mix(hexRgb(GOLD.hi),ACC.bright,glow);
    for(var s=0;s<=3*R;s++){ var w=3*R-s; for(var j=-w;j<=w;j++)buf.set(chx+j,chy+s,c); }
  }

  /* séparateur (porté) */
  function drawDivider(buf,W,H,t){
    var deep=hexRgb(GOLD.deep),hi=hexRgb(GOLD.hi),base=hexRgb(GOLD.base),my=Math.floor(H/2);
    for(var x=0;x<W;x++){ var a=1-Math.abs(x-W/2)/(W/2); buf.set(x,my,mix(deep,hi,0.55*a)); buf.set(x,my+1,mix(deep,base,0.4*a)); if(hash2(hgi(x),my,3)>0.9)buf.blendOver(x,my,GRIME_DARK,0.5*GRIME); }
    var trav=((t*0.32)%1.4-0.2)*W;
    for(var dx=-6*R;dx<=6*R;dx++){ var X=Math.round(trav+dx),fall=Math.max(0,1-Math.abs(dx)/(6*R)); if(X>0&&X<W){ buf.add(X,my,ACC.bright,fall*0.7); buf.add(X,my+1,ACC.mid,fall*0.4); } }
    var cx=Math.floor(W/2);
    for(var k=-3*R;k<=3*R;k++){ var w=3*R-Math.abs(k); for(var j=-w;j<=w;j++)buf.set(cx+j,my+k,(Math.abs(j)===w||Math.abs(k)===3*R)?deep:mix(base,hi,0.5+0.3*orgPulse(t,1))); }
    buf.add(cx-1,my-1,ACC.mid,0.4*orgPulse(t,1));
  }

  /* œil-sceau seul */
  function drawEye(buf,W,H,open,glow,t,seed){ var cx=W/2-0.5,cy=H/2-0.5,Rc=Math.min(W,H)/2-2*R; metalRing(buf,cx,cy,Rc,GOLD,seed); drawEyeAt(buf,cx,cy,Rc-3*R,open,glow,t,seed,{}); }

  /* ============================================================
     SYSTÈME DE WIDGETS
     ============================================================ */
  var widgets=[];
  function mkCanvas(wL,hL){ var w=wL*R,h=hL*R,cv=document.createElement('canvas'); cv.width=w; cv.height=h; cv.style.width=(w*SCALE)+'px'; cv.style.height=(h*SCALE)+'px'; cv.style.display='block'; cv.style.imageRendering='pixelated'; cv.style.background='transparent'; return cv; }
  var CAP="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:10px;letter-spacing:.03em;color:#7a7361;margin-top:8px;text-align:center;white-space:nowrap;text-transform:lowercase;";
  function elN(tag,style,txt){ var e=document.createElement(tag); if(style)e.style.cssText=style; if(txt!=null)e.textContent=txt; return e; }
  function cell(host,wL,hL,caption,clickable){ var box=elN('div','display:flex;flex-direction:column;align-items:center;flex:none;'); var cv=mkCanvas(wL,hL); if(clickable)cv.style.cursor='pointer'; box.appendChild(cv); if(caption!=null)box.appendChild(elN('div',CAP,caption)); host.appendChild(box); return cv; }

  function W2(cv,drawFn,opts){ opts=opts||{}; var w={cv:cv, st:opts.st||{}, drawFn:drawFn, interactive:!!opts.interactive, ease:opts.ease||null, vis:true, dim:[cv.width,cv.height]}; w.draw=function(t){ var b=new Buf(w.dim[0],w.dim[1]); drawFn(b,w.dim[0],w.dim[1],w.st,t); b.toCanvas(cv); }; widgets.push(w); return w; }

  function bindHover(cv,st){ cv.addEventListener('mouseenter',function(){st.hover=1;}); cv.addEventListener('mouseleave',function(){st.hover=0;st.active=0;}); cv.addEventListener('mousedown',function(){st.active=1;}); window.addEventListener('mouseup',function(){st.active=0;}); }
  function bindTrack(cv,st,W,H){ function tr(e){ var r=cv.getBoundingClientRect(); st.mx=(e.clientX-r.left)/r.width*W; st.my=(e.clientY-r.top)/r.height*H; } cv.addEventListener('mousemove',tr); cv.addEventListener('mouseenter',tr); }

  function easeBtn(st){ var pg=st.active?0.95:(st.hover?0.5:0), pp=st.active?1:0, peo=st.hover?1:0; st.glow=elerp(st.glow||0,pg,0.22); st.press=elerp(st.press||0,pp,0.3); st.eyeOpen=elerp(st.eyeOpen||0,peo,0.16); }
  function easeSmall(st){ var pg=st.active?0.95:(st.hover?0.55:0), pp=st.active?1:0; st.glow=elerp(st.glow||0,pg,0.22); st.press=elerp(st.press||0,pp,0.3); }
  function easeEye(st){ var po=st.on?1:(st.hover?0.55:0.06),pgl=st.on?1:(st.hover?0.4:0.08); st.open=elerp(st.open||0.05,po,0.18); st.glow=elerp(st.glow||0,pgl,0.2); }

  /* ============================================================
     DONNÉES D'EXEMPLE
     ============================================================ */
  var ASHMAW={ name:'Ash-Maw', fam:'abyss', cost:5, rank:5, hp:70, dmg:6, cd:'6.0',
    chips:[{label:'CARRY'},{affl:'burn',label:'BURN'},{label:'CHIM'}],
    ability:{name:'EMBERSTEP', affl:'burn', val:'6 dps · 3s', prose:'Each strike sets the ground alight.'},
    flavor:'"It breathes, and the Pit exhales."' };
  var SHOPU=[
    {name:'Witch', fam:'arcane', cost:3, affl:['poison'], seed:11},
    {name:'Templar', fam:'order', cost:5, affl:[], seed:12},
    {name:'Emberling', fam:'abyss', cost:5, affl:['burn'], seed:13}
  ];
  var RELICS=[
    {name:'Bloodstone', fam:'flesh', effect:'+15% lifesteal', flavor:'"It drinks first."'},
    {name:'Patient Knot', fam:'order', effect:'+1 bleed / taunt', flavor:'"It waits."'},
    {name:'Drowned Coin', fam:'abyss', effect:'steal 2 gold / kill', flavor:'"Wrong currency."'}
  ];
  var CODEX=[
    {name:'Ash-Maw', fam:'abyss', rank:5, known:true},
    {name:'Witch', fam:'arcane', rank:3, known:true},
    {name:'unknown', fam:'bone', rank:0, known:false}
  ];

  /* ============================================================
     BUILDERS
     ============================================================ */
  var BUILD={};

  /* A1 — CTA primaire */
  BUILD.A1=function(host){
    var lw=140,lh=28, states=[
      {cap:'rest', st:{press:0,glow:0,eyeOpen:0}},
      {cap:'hover', st:{press:0,glow:0.5,eyeOpen:1,mx:lw*R*0.5,my:6*R}},
      {cap:'pressed', st:{press:1,glow:0.95,eyeOpen:1,mx:lw*R*0.5,my:6*R}},
      {cap:'disabled', disabled:true, label:'SEALED'}
    ];
    states.forEach(function(s,i){ var label=s.label||'DESCEND'; var seed=2101+i;
      var cv=cell(host,lw,lh,s.cap); var W=cv.width,H=cv.height, hslab=H-DROP, eyes=s.disabled?null:genEyes(W,hslab,seed,label);
      var st=Object.assign({mx:W/2,my:hslab/2,glow:0,eyeOpen:0,press:0},s.st||{});
      W2(cv,function(b,W,H,st,t){ drawButton(b,W,H,st.press,st.eyeOpen,st.glow,seed,label,!!s.disabled,eyes,st.mx,st.my,t); },{st:st});
    });
    // live
    var lcv=cell(host,176,28,'live — hover me',true); var LW=lcv.width,LH=lcv.height, le=genEyes(LW,LH-DROP,2199,'ENTER THE PIT');
    var lst={hover:0,active:0,press:0,glow:0,eyeOpen:0,mx:LW/2,my:(LH-DROP)/2};
    bindHover(lcv,lst); bindTrack(lcv,lst,LW,LH);
    W2(lcv,function(b,W,H,st,t){ drawButton(b,W,H,st.press,st.eyeOpen,st.glow,2199,'ENTER THE PIT',false,le,st.mx,st.my,t); },{st:lst,interactive:true,ease:easeBtn});
  };

  /* A2 — économie */
  BUILD.A2=function(host){
    var rows=[
      {cap:'rest', label:'REROLL', cost:1, st:{glow:0,press:0}},
      {cap:'hover', label:'REROLL', cost:1, st:{glow:0.5,press:0}},
      {cap:'pressed', label:'REROLL', cost:1, st:{glow:0.9,press:1}},
      {cap:'disabled (no gold)', label:'LEVEL', cost:8, disabled:true}
    ];
    rows.forEach(function(s,i){ var seed=2201+i; var cv=cell(host,72,24,s.cap);
      var st=Object.assign({glow:0,press:0},s.st||{});
      W2(cv,function(b,W,H,st,t){ drawEcoBtn(b,W,H,st.press,st.glow,seed,s.label,s.cost,!!s.disabled,t); },{st:st});
    });
    var lcv=cell(host,72,24,'live',true); var lst={hover:0,active:0,glow:0,press:0}; bindHover(lcv,lst);
    W2(lcv,function(b,W,H,st,t){ drawEcoBtn(b,W,H,st.press,st.glow,2299,'WATCH',null,false,t); },{st:lst,interactive:true,ease:easeSmall});
  };

  /* A3 — bouton-icône */
  BUILD.A3=function(host){
    var kinds=[['sigil','sigil'],['left','‹ prev'],['right','next ›'],['gear','settings']];
    kinds.forEach(function(k,i){ var seed=2301+i;
      var cv=cell(host,24,24,k[1]); var lst={hover:0,active:0,glow:0,press:0}; bindHover(cv,lst);
      W2(cv,function(b,W,H,st,t){ drawIconBtn(b,W,H,st.press,st.glow,seed,k[0],t); },{st:lst,interactive:true,ease:easeSmall});
    });
  };

  /* B1 — onglet */
  BUILD.B1=function(host){
    [['RELICS',true],['BESTIARY',false]].forEach(function(p,i){ var cv=cell(host,78,22,p[1]?'active':'inactive');
      W2(cv,function(b,W,H,st,t){ drawTab(b,W,H,p[1],p[0],t); },{st:{}});
    });
  };

  /* B2 — item de menu */
  BUILD.B2=function(host){
    [['ENTER THE PIT','rest'],['ENTER THE PIT','hover'],['RITES & OFFERINGS','disabled']].forEach(function(p,i){
      var state=p[1]==='hover'?'hover':(p[1]==='disabled'?'disabled':'rest');
      var cv=cell(host,200,16,p[1]);
      W2(cv,function(b,W,H,st,t){ drawMenuItem(b,W,H,state,p[0],t); },{st:{}});
    });
    var lcv=cell(host,200,16,'live',true); var lst={hover:0};
    lcv.addEventListener('mouseenter',function(){lst.hover=1;}); lcv.addEventListener('mouseleave',function(){lst.hover=0;});
    W2(lcv,function(b,W,H,st,t){ drawMenuItem(b,W,H,st.hover?'hover':'rest','THE GRIMOIRE',t); },{st:lst,interactive:true});
  };

  /* B3 — puce filtre */
  BUILD.B3=function(host){
    [['SPREAD',false],['CROSS',false],['CONTROL',true]].forEach(function(p,i){ var cv=cell(host,64,16,p[1]?'active':'inactive');
      W2(cv,function(b,W,H,st,t){ drawFilterChip(b,W,H,p[1],p[0],t); },{st:{}});
    });
    var lcv=cell(host,64,16,'live — click',true); var lst={on:false};
    lcv.addEventListener('click',function(){ lst.on=!lst.on; });
    W2(lcv,function(b,W,H,st,t){ drawFilterChip(b,W,H,st.on,'SWARM',t); },{st:lst,interactive:true});
  };

  /* B4 — tri / cycle */
  BUILD.B4=function(host){
    var cv=cell(host,96,18,'rest'); W2(cv,function(b,W,H,st,t){ drawSortBtn(b,W,H,0,0,'SORT: TYPE',t); },{st:{}});
    var lcv=cell(host,96,18,'live',true); var lst={hover:0,active:0,glow:0,press:0}; bindHover(lcv,lst);
    W2(lcv,function(b,W,H,st,t){ drawSortBtn(b,W,H,st.press,st.glow,'SORT: RANK',t); },{st:lst,interactive:true,ease:easeSmall});
  };

  /* B5 — scrollbar */
  BUILD.B5=function(host){
    [['top',0.0],['mid',0.5]].forEach(function(p,i){ var cv=cell(host,10,80,p[0]);
      W2(cv,function(b,W,H,st,t){ drawScrollbar(b,0,0,W,H,p[1],0.42); },{st:{}});
    });
  };

  /* C1 — case du plateau */
  BUILD.C1=function(host){
    var unit={fam:'abyss',level:2};
    [['empty','empty'],['locked','locked'],['hover','hover'],['drop','drop'],['occupied','occupied'],['neighbor','neighbor']].forEach(function(p){
      var cv=cell(host,38,38,p[0]);
      W2(cv,function(b,W,H,st,t){ drawSlot(b,W,H,p[1],unit,t); },{st:{}});
    });
  };

  /* C2 — carte boutique */
  BUILD.C2=function(host){
    [['afford','buyable'],['toocher','too costly'],['hover','hover'],['sold','sold']].forEach(function(p,i){
      var u=Object.assign({},SHOPU[i%SHOPU.length]); if(p[0]==='toocher')u.cost=9;
      var cv=cell(host,60,56,p[1]);
      W2(cv,function(b,W,H,st,t){ drawShopCard(b,W,H,p[0]==='toocher'?'too':p[0],u,t); },{st:{}});
    });
  };

  /* C3 — relique possédée */
  BUILD.C3=function(host){
    [['rest','rest'],['hover','hover'],['rest','rest']].forEach(function(p,i){
      var fam=['abyss','arcane','order'][i];
      var cv=cell(host,26,26,p[1]);
      W2(cv,function(b,W,H,st,t){ drawRelicSlot(b,W,H,p[0],fam,t); },{st:{}});
    });
  };

  /* D1 — jauge de vie */
  BUILD.D1=function(host){
    [['healthy',0.82,[{frac:0.0,color:AFFL.poison.c}]],
     ['afflicted',0.6,[{frac:0.22,color:AFFL.poison.c,bmp:AFFL.poison.bmp},{frac:0.12,color:AFFL.burn.c,bmp:AFFL.burn.bmp}]],
     ['critical < 25%',0.16,[{frac:0.0,color:AFFL.bleed.c,bmp:AFFL.bleed.bmp}]]
    ].forEach(function(p){ var cv=cell(host,90,30,p[0]);
      W2(cv,function(b,W,H,st,t){ drawHealthGauge(b,W,H,p[1],p[2],'blood',t); },{st:{}});
    });
  };

  /* D2 — orbes */
  BUILD.D2=function(host){
    [['Vitae',LIQUIDS.blood,101,0.78],['Mana',LIQUIDS.mana,102,0.54],['Essence',LIQUIDS.essence,103,0.4]].forEach(function(p){
      var cv=cell(host,64,64,p[0].toLowerCase()+' — drag',true); var st={val:p[3]};
      function setv(e){ var r=cv.getBoundingClientRect(); st.val=clamp(1-(e.clientY-r.top)/r.height); }
      cv.addEventListener('click',setv); cv.addEventListener('mousemove',function(e){ if(e.buttons&1)setv(e); });
      W2(cv,function(b,W,H,st,t){ drawOrb(b,W,H,st.val,p[1],p[2],t); },{st:st,interactive:true});
    });
  };

  /* D3 — plaque HUD */
  BUILD.D3=function(host){
    var cv=cell(host,300,18,'run banner');
    var segs=[{label:'GOLD',val:'12'},{label:'LIVES',val:'4/5'},{label:'WINS',val:'3/10'},{label:'ROUND',val:'4'},{label:'SLOTS',val:'5/9'}];
    W2(cv,function(b,W,H,st,t){ drawHudPlate(b,W,H,t,segs); },{st:{}});
  };

  /* E1 — panneau 9-slice */
  BUILD.E1=function(host){
    var cv=cell(host,200,120,'generic panel (breathes & watches)');
    W2(cv,function(b,W,H,st,t){ drawPanel(b,W,H,t,'GRIMOIRE'); },{st:{}});
  };

  /* E2 — séparateur */
  BUILD.E2=function(host){ var cv=cell(host,240,12,'divider — pulse'); W2(cv,function(b,W,H,st,t){ drawDivider(b,W,H,t); },{st:{}}); };

  /* E3 — bannière */
  BUILD.E3=function(host){
    [['VICTORY','win'],['DEFEAT','defeat']].forEach(function(p){ var cv=cell(host,180,46,p[1]);
      W2(cv,function(b,W,H,st,t){ drawBanner(b,W,H,p[0],p[1],t); },{st:{}});
    });
  };

  /* E4 — tooltip */
  BUILD.E4=function(host){
    var cv=cell(host,150,90,'hover sheet');
    var lines=[{txt:'ASH-MAW',gold:true,gap:12},{txt:'HP 70  DMG 6  CD 6s',color:hexRgb('#9a8a72'),gap:13},{txt:'Emberstep',gold:true,gap:11},{txt:'Each hit ignites.',color:hexRgb('#8a7d66'),gap:10}];
    W2(cv,function(b,W,H,st,t){ drawTooltip(b,W,H,t,lines); },{st:{}});
  };

  /* E5 — liste scrollable */
  BUILD.E5=function(host){
    var rows=[{txt:'ASH-MAW',sel:true},{txt:'WITCH'},{txt:'TEMPLAR'},{txt:'EMBERLING'},{txt:'ROT-HOUND'},{txt:'BANDIT'},{txt:'STORMCALLER'}];
    var cv=cell(host,150,110,'clipped list + scrollbar');
    W2(cv,function(b,W,H,st,t){ drawScrollList(b,W,H,t,rows,8*R); },{st:{}});
  };

  /* F1 — carte monstre */
  BUILD.F1=function(host){
    var cv=cell(host,150,210,'monster card (gilded, rank 5)');
    W2(cv,function(b,W,H,st,t){ drawMonsterCard(b,W,H,ASHMAW,t,true); },{st:{}});
  };

  /* F2 — carte relique */
  BUILD.F2=function(host){
    [['rest',0],['hover',1],['selected',2]].forEach(function(p){ var cv=cell(host,120,150,p[0]);
      W2(cv,function(b,W,H,st,t){ drawRelicCard(b,W,H,p[0],RELICS[p[1]],t); },{st:{}});
    });
  };

  /* F3 — ligne de codex */
  BUILD.F3=function(host){
    [['rest',CODEX[0],true],['selected',CODEX[1],true],['unknown',CODEX[2],false]].forEach(function(p){
      var cv=cell(host,180,26,p[0]);
      W2(cv,function(b,W,H,st,t){ drawCodexRow(b,W,H,p[0]==='selected'?'selected':(p[0]==='unknown'?'rest':'rest'),p[1],p[2],t); },{st:{}});
    });
  };

  /* F4 — échelle de rareté */
  BUILD.F4=function(host){
    var cv=cell(host,200,44,'R1 → R5 (current R4 lit)');
    W2(cv,function(b,W,H,st,t){ drawRarityScale(b,W,H,4,t); },{st:{}});
  };

  /* G1 — chip mot-clé */
  BUILD.G1=function(host){
    [['burn','BURN',6,false],['poison','POISON',null,false],[null,'CARRY',null,false]].forEach(function(p){
      var w=p[1].length*6+(p[0]?14:8)+(p[2]!=null?10:4);
      var cv=cell(host,Math.max(40,w),16,p[0]||'tag');
      W2(cv,function(b,W,H,st,t){ drawKwChip(b,W,H,p[0],p[1],p[2],t,false); },{st:{}});
    });
  };

  /* G2 — pip de type */
  BUILD.G2=function(host){
    ['flesh','order','bone','arcane','abyss'].forEach(function(fam){ var cv=cell(host,14,14,fam);
      W2(cv,function(b,W,H,st,t){ drawTypePip(b,Math.round(W/2-4*R),Math.round(H/2-4*R),fam,t); },{st:{}});
    });
  };

  /* G3 — pips de niveau */
  BUILD.G3=function(host){
    [1,2,3].forEach(function(n){ var cv=cell(host,9*n+4,12,'level '+n);
      W2(cv,function(b,W,H,st,t){ drawLevelPips(b,W,H,n,t); },{st:{}});
    });
  };

  /* G4 — gemme */
  BUILD.G4=function(host){
    [['inert',false],['awake',true]].forEach(function(p){ var cv=cell(host,22,22,p[0]);
      W2(cv,function(b,W,H,st,t){ drawGem(b,W,H,p[1],t); },{st:{}});
    });
    var lcv=cell(host,22,22,'live — click',true); var lst={on:false}; lcv.addEventListener('click',function(){lst.on=!lst.on;});
    W2(lcv,function(b,W,H,st,t){ drawGem(b,W,H,st.on,t); },{st:lst,interactive:true});
  };

  /* ============================================================
     BOOT
     ============================================================ */
  function boot(root,opts){
    opts=opts||{}; setAccent(opts.accent||'gold'); RESTLESS=opts.restless!==false; GRIME=opts.grime!=null?opts.grime:0.85;
    widgets.length=0;
    var hosts=root.querySelectorAll('[data-host]');
    Array.prototype.forEach.call(hosts,function(h){ var b=BUILD[h.getAttribute('data-host')]; if(b){ try{ h.innerHTML=''; b(h); }catch(err){ console.warn('builder',h.getAttribute('data-host'),err); } } });

    // visibilité
    if('IntersectionObserver' in window){
      var io=new IntersectionObserver(function(es){ es.forEach(function(e){ var w=cvMap.get(e.target); if(w)w.vis=e.isIntersecting; }); },{rootMargin:'120px'});
      var cvMap=new Map();
      widgets.forEach(function(w){ cvMap.set(w.cv,w); io.observe(w.cv); });
    }

    // 1er rendu
    widgets.forEach(function(w){ w.draw(0.0); });

    var last=0;
    function loop(now){ requestAnimationFrame(loop); var iv=RESTLESS?42:130; if(now-last<iv)return; last=now; var t=now/1000;
      for(var i=0;i<widgets.length;i++){ var w=widgets[i]; if(!w.vis)continue; if(w.interactive&&w.ease)w.ease(w.st); w.draw(t); }
    }
    requestAnimationFrame(loop);

    return {
      setAccent:function(name){ setAccent(name); widgets.forEach(function(w){ w.vis=true; }); },
      setRestless:function(v){ RESTLESS=v; },
      setGrime:function(v){ GRIME=v; }
    };
  }

  window.PitForge={ boot:boot, _v:1 };
})();
