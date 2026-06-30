# Post-processing — chaîne de canvas, CRT, bloom, aberration chromatique

> Comment rendre toute la scène dans un canvas puis lui appliquer des effets
> plein écran (CRT, bloom, scanlines, distorsion). Référence : **Balatro** (CRT
> tout-en-un) et **Moonring** (passes séparées bloom/CRT/recolour — voir
> `games/moonring.md`).

## 1. Le pattern canvas → shader → écran

Le principe universel d'un post-process LÖVE :

```lua
function love.load()
    -- canvas à la résolution interne (souvent sur-échantillonnée pour l'anti-aliasing)
    G.CANVAS    = love.graphics.newCanvas(W, H)
    G.AA_CANVAS = love.graphics.newCanvas(W, H)
end

function love.draw()
    -- 1) dessiner TOUTE la scène dans G.CANVAS
    love.graphics.setCanvas(G.CANVAS)
    love.graphics.clear()
        draw_scene()          -- fond, plateau, cartes, UI, curseur...
    love.graphics.setCanvas()

    -- 2) re-dessiner G.CANVAS à travers le shader plein écran, dans AA_CANVAS
    love.graphics.setCanvas(G.AA_CANVAS)
        myPostShader:send("time", t)         -- + tous les uniforms
        love.graphics.setShader(myPostShader)
        love.graphics.draw(G.CANVAS, 0, 0)
        love.graphics.setShader()
    love.graphics.setCanvas()

    -- 3) blit final à l'écran, mis à l'échelle (sur-échantillonnage -> anti-aliasing)
    love.graphics.draw(G.AA_CANVAS, 0, 0, 0, 1/G.CANV_SCALE, 1/G.CANV_SCALE)
end
```

Notes LÖVE importantes :
- **Toujours** `setShader()` / `setCanvas()` pour réinitialiser après usage.
- Le sur-échantillonnage (`CANV_SCALE > 1`) : on rend plus grand puis on réduit.
  C'est l'anti-aliasing "gratuit" de Balatro, parfait pour garder un pixel-art net
  sans crénelage sur les rotations.
- Un canvas peut servir de texture d'entrée à un shader (c'est tout l'intérêt).
- Pour du **multi-passes** (ex: extraire le bloom dans un canvas séparé puis le
  recomposer), on chaîne plusieurs canvas. Moonring fait ça (scène → bloom →
  CRT → écran).

---

## 2. Le CRT tout-en-un de Balatro (`resources/shaders/CRT.fs`)

Un seul shader qui fait : distorsion barrel, glitch horizontal optionnel,
aberration chromatique, scanlines, bruit, correction contraste, **bloom**. Code
intégral :

```glsl
extern number time;
extern vec2   distortion_fac;   // courbure barrel (ex {1.07, 1.10})
extern vec2   scale_fac;        // léger zoom out pour la courbure (ex {0.99,0.99})
extern number feather_fac;      // largeur du fondu vers le noir au bord
extern number noise_fac;        // intensité du bruit
extern number bloom_fac;        // intensité du bloom
extern number crt_intensity;    // dosage global (slider)
extern number glitch_intensity; // 0 = pas de glitch
extern number scanlines;        // densité des scanlines (≈ hauteur pixel * 0.75)

#define BUFF 0.01
#define BLOOM_AMT 3

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
{
    vec2 orig_tc = tc;
    // recentrer en [-1,1]
    tc = tc*2.0 - vec2(1.0);
    tc *= scale_fac;
    // distorsion barrel (bombé depuis le centre)
    tc += (tc.yx*tc.yx) * tc * (distortion_fac - 1.0);
    // masque : fondu doux vers le noir au bord de l'écran
    number mask = (1.0 - smoothstep(1.0-feather_fac,1.0,abs(tc.x) - BUFF))
                * (1.0 - smoothstep(1.0-feather_fac,1.0,abs(tc.y) - BUFF));
    tc = (tc + vec2(1.0))/2.0;  // dé-recentrer

    // glitch horizontal (décalage par lignes, optionnel)
    number offset_l = 0.;
    number offset_r = 0.;
    if (glitch_intensity > 0.01) {
        number timefac = 3.0*time;
        offset_l = 50.0*(-3.5+sin(timefac*0.512 + tc.y*40.0) + sin(-timefac*0.8233 + tc.y*81.532)
                + sin(timefac*0.333 + tc.y*30.3) + sin(-timefac*0.1112331 + tc.y*13.0));
        offset_r = -50.0*(-3.5+sin(timefac*0.6924 + tc.y*29.0) + sin(-timefac*0.9661 + tc.y*41.532)
                + sin(timefac*0.4423 + tc.y*40.3) + sin(-timefac*0.13321312 + tc.y*11.0));
        if (glitch_intensity > 1.0) {
            offset_l = 50.0*(-1.5+sin(timefac*0.512 + tc.y*4.0) + sin(-timefac*0.8233 + tc.y*1.532)
                + sin(timefac*0.333 + tc.y*3.3) + sin(-timefac*0.1112331 + tc.y*1.0));
            offset_r = -50.0*(-1.5+sin(timefac*0.6924 + tc.y*19.0) + sin(-timefac*0.9661 + tc.y*21.532)
                + sin(timefac*0.4423 + tc.y*20.3) + sin(-timefac*0.13321312 + tc.y*5.0));
        }
        tc.x = tc.x + 0.001*glitch_intensity*clamp(offset_l, clamp(offset_r, -1.0, 0.0), 1.0);
    }

    vec4 crt_tex = Texel(tex, tc);
    float artifact_amplifier = (abs(clamp(offset_l, clamp(offset_r, -1.0, 0.0), 1.0))*glitch_intensity > 0.9 ? 3. : 1.);

    // aberration chromatique horizontale : R et G échantillonnés à des x légèrement décalés
    float crt_amout_adjusted = (max(0., (crt_intensity)/(0.16*0.3)))*artifact_amplifier;
    if (crt_amout_adjusted > 0.0000001) {
        crt_tex.r = crt_tex.r*(1.-crt_amout_adjusted) + crt_amout_adjusted*Texel(tex, tc + vec2( 0.0005*(1.+10.*(artifact_amplifier-1.))*1600./love_ScreenSize.x, 0.)).r;
        crt_tex.g = crt_tex.g*(1.-crt_amout_adjusted) + crt_amout_adjusted*Texel(tex, tc + vec2(-0.0005*(1.+10.*(artifact_amplifier-1.))*1600./love_ScreenSize.x, 0.)).g;
    }
    vec3 rgb_result = crt_tex.rgb*(1.0 - (1.0*crt_intensity*artifact_amplifier));

    if (sin(time + tc.y*200.0) > 0.85) {
        if (offset_l < 0.99 && offset_l > 0.01) rgb_result.r = rgb_result.g*1.5;
        if (offset_r > -0.99 && offset_r < -0.01) rgb_result.g = rgb_result.r*1.5;
    }

    // scanlines : motif RGB déphasé (pas l'image réelle, sinon trop dur)
    vec3 rgb_scanline = vec3(
        clamp(-0.3+2.0*sin(tc.y*scanlines-3.14/4.0) - 0.8*clamp(sin(tc.x*scanlines*4.0), 0.4, 1.0), -1.0, 2.0),
        clamp(-0.3+2.0*cos(tc.y*scanlines) - 0.8*clamp(cos(tc.x*scanlines*4.0), 0.0, 1.0), -1.0, 2.0),
        clamp(-0.3+2.0*cos(tc.y*scanlines-3.14/3.0) - 0.8*clamp(cos(tc.x*scanlines*4.0-3.14/4.0), 0.0, 1.0), -1.0, 2.0));
    rgb_result += crt_tex.rgb * rgb_scanline * crt_intensity * artifact_amplifier;

    // bruit
    number x = (tc.x - mod(tc.x, 0.002)) * (tc.y - mod(tc.y, 0.0013)) * time * 1000.0;
    x = mod(x, 13.0) * mod(x, 123.0);
    number dx = mod(x, 0.11)/0.11;
    rgb_result = (1.0-clamp(noise_fac*artifact_amplifier, 0.0,1.0))*rgb_result + dx * clamp(noise_fac*artifact_amplifier, 0.0,1.0) * vec3(1.0);

    // correction contraste / luminosité
    rgb_result -= vec3(0.55 - 0.02*(artifact_amplifier - 1. - crt_amout_adjusted*bloom_fac*0.7));
    rgb_result = rgb_result*(1.0 + 0.14 + crt_amout_adjusted*(0.012 - bloom_fac*0.12));
    rgb_result += vec3(0.5);
    vec4 final_col = vec4(rgb_result, 1.0);

    // bloom : moyenne pondérée des texels brillants voisins (au-dessus d'un cutoff)
    vec4 col = vec4(0.0);
    float bloom = 0.0;
    if (bloom_fac > 0.00001 && crt_intensity > 0.000001) {
        bloom = 0.03*(max(0., (crt_intensity)/(0.16*0.3)));
        float bloom_dist = 0.0015*float(BLOOM_AMT);
        vec4 samp; float cutoff = 0.6;
        for (int i = -BLOOM_AMT; i <= BLOOM_AMT; ++i)
        for (int j = -BLOOM_AMT; j <= BLOOM_AMT; ++j) {
            samp = Texel(tex, tc + (bloom_dist/float(BLOOM_AMT))*vec2(float(i), float(j)));
            samp.r = max(1./(1.-cutoff)*samp.r - 1./(1.-cutoff) + 1., 0.);  // ne garde que > cutoff
            samp.g = max(1./(1.-cutoff)*samp.g - 1./(1.-cutoff) + 1., 0.);
            samp.b = max(1./(1.-cutoff)*samp.b - 1./(1.-cutoff) + 1., 0.);
            col += min(min(samp.r,samp.g),samp.b) * (2. - float(abs(float(i+j)))/float(BLOOM_AMT+BLOOM_AMT));
        }
        col /= float(BLOOM_AMT*BLOOM_AMT);
        col.a = final_col.a;
    }

    return (final_col*(1. - bloom) + bloom*col)*mask;
}
```

### Côté Lua (Balatro, `game.lua`)

```lua
G.SHADERS['CRT']:send('distortion_fac', {1.0 + 0.07*crt/100, 1.0 + 0.1*crt/100})
G.SHADERS['CRT']:send('scale_fac',      {1.0 - 0.008*crt/100, 1.0 - 0.008*crt/100})
G.SHADERS['CRT']:send('feather_fac', 0.01)
G.SHADERS['CRT']:send('bloom_fac', bloom - 1)
G.SHADERS['CRT']:send('time', 400 + G.TIMERS.REAL)
G.SHADERS['CRT']:send('noise_fac', 0.001*crt/100)
G.SHADERS['CRT']:send('crt_intensity', 0.16*crt/100)
G.SHADERS['CRT']:send('glitch_intensity', 0)
G.SHADERS['CRT']:send('scanlines', G.CANVAS:getPixelHeight()*0.75/G.CANV_SCALE)
love.graphics.setShader(G.SHADERS['CRT'])
love.graphics.draw(G.CANVAS, 0, 0)
```

> **Dosage** : Balatro multiplie l'intensité du slider par 0.3 avant l'envoi
> (`crt = crt*0.3`). L'effet par défaut est **subtil** — c'est ce qui le rend
> classe plutôt que kitsch. Pour The Pit grimdark : courbure barrel quasi nulle,
> scanlines très légères, un soupçon de vignettage (le `mask`) et un bloom doux
> sur les sources lumineuses (sang qui brille, runes). On garde `glitch=0` sauf
> sur un event "corruption".

---

## 3. Bloom en passe séparée (approche Moonring)

Quand on veut un bloom plus marqué qu'un simple voisinage 7×7, on l'isole :

1. **Extraction** : dessiner la scène, puis dans un canvas `bright`, ne garder que
   les pixels au-dessus d'un seuil de luminance (threshold).
2. **Flou** : flouter `bright` (gaussien séparable : passe horizontale puis
   verticale, bien moins coûteux qu'un flou 2D). Souvent en demi-résolution.
3. **Composition** : `final = scene + bloom_strength * blurred_bright` (additif).

Voir `games/moonring.md` pour les `.fs` `bloom.fs` / `old_bloom.fs` complets et
leur enchaînement. Pour The Pit, un bloom séparable demi-résolution sur un canvas
"émissif" (uniquement les éléments qui doivent briller) est le meilleur rapport
qualité/perf.

---

## 4. Pièges & perf

- **Pixel-art + canvas** : utiliser `image:setFilter('nearest','nearest')` sur les
  sprites, mais le canvas final peut être en `linear` si on sur-échantillonne.
  Sinon `nearest` partout pour rester net.
- **Coût du bloom dans le CRT** : la boucle 7×7 = 49 `Texel` par pixel. À pleine
  résolution c'est cher. Balatro l'assume car la résolution interne est maîtrisée.
  Alternative : passe de bloom en demi/quart de résolution.
- **`love_ScreenSize`** est la taille du canvas courant, pas de la fenêtre.
- Réinitialiser `setShader()` et `setColor(1,1,1,1)` entre les passes pour éviter
  les teintes résiduelles.
