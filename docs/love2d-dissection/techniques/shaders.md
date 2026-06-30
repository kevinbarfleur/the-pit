# Catalogue de shaders LÖVE (multi-jeux)

> Document de référence pour reproduire les effets GLSL des jeux disséqués.
> Tout le code est recopié verbatim des sources extraites. Les shaders propres à
> un jeu pixel-art (eau, outline, neige de Mudborne ; CRT/recolour de Moonring ;
> juice de Dice) sont **dans leurs docs de jeu respectifs** ; ce fichier
> centralise le **primer LÖVE** et **l'intégralité des shaders de Balatro**
> (les plus réutilisables pour des cartes), plus un **index transversal** des
> familles d'effets.

## Sommaire
- [Primer : comment marchent les shaders LÖVE](#primer)
- [Balatro — bloc partagé (dissolve, HSL/RGB, tilt 3D)](#balatro-bloc-partage)
- [Balatro — shaders d'édition (foil, holo, polychrome…)](#balatro-editions)
- [Balatro — background (fond animé)](#balatro-background)
- [Balatro — CRT (post-process plein écran)](#balatro-crt)
- [Balatro — flame, splash, flash, gold_seal…](#balatro-divers)
- [Index transversal des familles d'effets](#index-transversal)

---

## Primer

### Le modèle de shader LÖVE (`love.graphics.newShader`)

LÖVE compile un pixel shader (fragment) et/ou un vertex shader depuis une chaîne
ou un fichier GLSL. La signature attendue :

```glsl
// PIXEL (fragment) : appelé par pixel dessiné
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    // color          = la couleur de love.graphics.setColor (teinte du draw)
    // tex            = la texture en cours de dessin
    // texture_coords = UV [0..1] dans la texture/quad
    // screen_coords  = position pixel à l'écran
    return Texel(tex, texture_coords) * color;   // Texel = texture2D
}

// VERTEX (optionnel) : appelé par sommet
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection * vertex_position;
}
```

Le même fichier peut contenir les deux : LÖVE définit `VERTEX` quand il compile
la passe vertex et `PIXEL` pour la passe pixel. D'où le motif `#ifdef VERTEX … #endif`.

### Mots-clés et pièges LÖVE

- `Texel(tex, uv)` = `texture2D`. `love_ScreenSize` (vec4) = taille du canvas.
- `number` est un **alias LÖVE de `float`** (pratique). `vec2/3/4` standards.
- Uniforms : déclarés `extern <type> <name>;` (LÖVE) — équivalent de `uniform`.
  Envoyés côté Lua par `myShader:send('name', value)`.
  - number → `:send('x', 1.5)` ; vec2 → `:send('v', {1,2})` ; vec4 → `{r,g,b,a}` ;
    bool → `:send('flag', true)` ; texture → `:send('tex', img)`.
- **Précision mobile** : le préambule
  ```glsl
  #if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
      #define MY_HIGHP_OR_MEDIUMP highp
  #else
      #define MY_HIGHP_OR_MEDIUMP mediump
  #endif
  ```
  sert à forcer `highp` quand disponible (desktop) et retomber sur `mediump`
  (vieux GPU mobiles). Sur desktop on peut l'ignorer, mais le garder rend le
  shader portable. The Pit est desktop → on peut simplifier en `float`.

### Appliquer un shader (côté Lua)

```lua
local sh = love.graphics.newShader("shaders/foil.fs")  -- ou newShader(codeString)
sh:send("time", t)
love.graphics.setShader(sh)
love.graphics.draw(image, x, y)
love.graphics.setShader()   -- toujours réinitialiser
```

Pour un **post-process plein écran** : on dessine la scène dans un `Canvas`,
puis on dessine ce canvas à l'écran avec le shader actif (voir
[`post-processing.md`](post-processing.md)).

---

## Balatro : bloc partagé {#balatro-bloc-partage}

Les 14 shaders de **carte** de Balatro partagent le même en-tête et les mêmes
fonctions utilitaires. **On ne le recopie qu'une fois ici** ; dans les sections
suivantes, seul le corps `effect()` unique est donné.

### Uniforms communs

```glsl
extern MY_HIGHP_OR_MEDIUMP vec2  <name>;        // params animés propres au shader (ex: foil, holo)
extern MY_HIGHP_OR_MEDIUMP number dissolve;     // 0→1 progression dissolution/burn
extern MY_HIGHP_OR_MEDIUMP number time;         // temps animé (désynchronisé par ID de carte)
extern MY_HIGHP_OR_MEDIUMP vec4  texture_details; // (posX, posY, largeurPx, hauteurPx) du quad dans l'atlas
extern MY_HIGHP_OR_MEDIUMP vec2  image_details;   // dimensions de l'atlas
extern bool shadow;                              // passe d'ombre (rend en noir, alpha *0.3)
extern MY_HIGHP_OR_MEDIUMP vec4  burn_colour_1;  // couleur flamme 1 de dissolution
extern MY_HIGHP_OR_MEDIUMP vec4  burn_colour_2;  // couleur flamme 2
// pour le tilt 3D au survol :
extern MY_HIGHP_OR_MEDIUMP vec2  mouse_screen_pos;
extern MY_HIGHP_OR_MEDIUMP float hovering;
extern MY_HIGHP_OR_MEDIUMP float screen_scale;
```

### `dissolve_mask` — la dissolution/burn universelle

Appelée à la fin de presque tous les shaders de carte. Elle découpe le sprite
selon un champ de bruit animé et dessine un liseré de "flamme" (burn_colour) sur
le front de dissolution. Sert pour : apparition de carte, destruction, achat,
défausse.

```glsl
vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv)
{
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.,0.,0.) : tex.xyz, shadow ? tex.a*0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve*dissolve*(3.-2.*dissolve))*1.02 - 0.01; // smoothstep remappé -0.1→1.1

    float t = time * 10.0 + 2003.;
    vec2 floored_uv = (floor((uv*texture_details.ba)))/max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    vec2 field_part1 = uv_scaled_centered + 50.*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.*vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.*vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.+ (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92) ))/2.;
    vec2 borders = vec2(0.2, 0.8);

    float res = (.5 + .5* cos( (adjusted_dissolve) / 82.612 + ( field + -.5 ) *3.14))
    - (floored_uv.x > borders.y ? (floored_uv.x - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y > borders.y ? (floored_uv.y - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.x < borders.x ? (borders.x - floored_uv.x)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y < borders.x ? (borders.x - floored_uv.y)*(5. + 5.*dissolve) : 0.)*(dissolve);

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8*(0.5-abs(adjusted_dissolve-0.5)) && res > adjusted_dissolve) {
        if (!shadow && res < adjusted_dissolve + 0.5*(0.5-abs(adjusted_dissolve-0.5)) && res > adjusted_dissolve) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(shadow ? vec3(0.,0.,0.) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a*0.3: tex.a) : .0);
}
```

### Conversion HSL ↔ RGB (pour décaler la teinte)

Utilisée par holo, polychrome, negative, debuff, played pour faire tourner la
teinte sans casser la luminosité.

```glsl
number hue(number s, number t, number h) {
    number hs = mod(h, 1.)*6.;
    if (hs < 1.) return (t-s) * hs + s;
    if (hs < 3.) return t;
    if (hs < 4.) return (t-s) * (4.-hs) + s;
    return s;
}
vec4 RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    number t = (c.z < .5) ? c.y*c.z + c.z : -c.y*c.z + (c.y+c.z);
    number s = 2.0 * c.z - t;
    return vec4(hue(s,t,c.x + 1./3.), hue(s,t,c.x), hue(s,t,c.x - 1./3.), c.w);
}
vec4 HSL(vec4 c) {
    number low = min(c.r, min(c.g, c.b));
    number high = max(c.r, max(c.g, c.b));
    number delta = high - low;
    number sum = high+low;
    vec4 hsl = vec4(.0, .0, .5 * sum, c.a);
    if (delta == .0) return hsl;
    hsl.y = (hsl.z < .5) ? delta / sum : delta / (2.0 - sum);
    if (high == c.r)      hsl.x = (c.g - c.b) / delta;
    else if (high == c.g) hsl.x = (c.b - c.r) / delta + 2.0;
    else                  hsl.x = (c.r - c.g) / delta + 4.0;
    hsl.x = mod(hsl.x / 6., 1.);
    return hsl;
}
```

### Le vertex shader de tilt 3D (survol)

Partagé par tous les shaders de carte. Perturbe la composante **w** du sommet →
fausse perspective sans matrice 3D.

```glsl
#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.) {
        return transform_projection * vertex_position;
    }
    float mid_dist = length(vertex_position.xy - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
    float scale = 0.2*(-0.03 - 0.3*max(0., 0.3-mid_dist))
                *hovering*(length(mouse_offset)*length(mouse_offset))/(2. -mid_dist);
    return transform_projection * vertex_position + vec4(0,0,0,scale);
}
#endif
```

> **Reproduire le tilt** : envoyer `hovering` (0..1, monte au survol), la
> position souris en pixels écran, et `screen_scale`. Mettre les 4 sommets du
> quad de la carte → le `+vec4(0,0,0,scale)` les "penche". Combiner avec une
> passe d'ombre décalée pour l'effet "carte qui se soulève".

---

## Balatro : shaders d'édition {#balatro-editions}

> Le `uv` local est recalculé pareil partout :
> `vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;`

### `foil.fs` — reflet métallique froid (bleu/cyan)

Champ d'interférence sinusoïdal radial + bandes diagonales, qui pousse le canal
bleu. Corps `effect()` :

```glsl
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    vec2 adjusted_uv = uv - vec2(0.5, 0.5);
    adjusted_uv.x = adjusted_uv.x*texture_details.b/texture_details.a;

    number low  = min(tex.r, min(tex.g, tex.b));
    number high = max(tex.r, max(tex.g, tex.b));
    number delta = min(high, max(0.5, 1. - low));

    number fac  = max(min(2.*sin((length(90.*adjusted_uv) + foil.r*2.) + 3.*(1.+0.8*cos(length(113.1121*adjusted_uv) - foil.r*3.121))) - 1. - max(5.-length(90.*adjusted_uv), 0.), 1.), 0.);
    vec2   rotater = vec2(cos(foil.r*0.1221), sin(foil.r*0.3512));
    number angle = dot(rotater, adjusted_uv)/(length(rotater)*length(adjusted_uv));
    number fac2 = max(min(5.*cos(foil.g*0.3 + angle*3.14*(2.2+0.9*sin(foil.r*1.65 + 0.2*foil.g))) - 4. - max(2.-length(20.*adjusted_uv), 0.), 1.), 0.);
    number fac3 = 0.3*max(min(2.*sin(foil.r*5. + uv.x*3. + 3.*(1.+0.5*cos(foil.r*7.))) - 1., 1.), -1.);
    number fac4 = 0.3*max(min(2.*sin(foil.r*6.66 + uv.y*3.8 + 3.*(1.+0.5*cos(foil.r*3.414))) - 1., 1.), -1.);

    number maxfac = max(max(fac, max(fac2, max(fac3, max(fac4, 0.0)))) + 2.2*(fac+fac2+fac3+fac4), 0.);

    tex.r = tex.r-delta + delta*maxfac*0.3;
    tex.g = tex.g-delta + delta*maxfac*0.3;
    tex.b = tex.b + delta*maxfac*1.9;          // pousse le bleu = aspect métal froid
    tex.a = min(tex.a, 0.3*tex.a + 0.9*min(0.5, maxfac*0.1));
    return dissolve_mask(tex, texture_coords, uv);
}
```
Côté Lua, `foil` est un `vec2 {r, g}` animé dans le temps (r ≈ phase qui défile).

### `holo.fs` — holographique arc-en-ciel (grille diffractive)

Décale la **teinte** selon un champ de bruit + une grille de diffraction
(`gridsize`). Corps unique :

```glsl
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    vec4 hsl = HSL(0.5*tex + 0.5*vec4(0.,0.,1.,tex.a));

    float t = holo.y*7.221 + time;
    vec2 floored_uv = (floor((uv*texture_details.ba)))/texture_details.ba;
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 250.;

    vec2 field_part1 = uv_scaled_centered + 50.*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.*vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.*vec2(sin(-t / 87.53218), sin(-t / 49.0000));
    float field = (1.+ (cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) + cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92) ))/2.;
    float res = (.5 + .5* cos( (holo.x) * 2.612 + ( field + -.5 ) *3.14));

    number low = min(tex.r, min(tex.g, tex.b));
    number high = max(tex.r, max(tex.g, tex.b));
    number delta = 0.2+0.3*(high- low) + 0.1*high;

    number gridsize = 0.79;
    number fac = 0.5*max(max(max(0., 7.*abs(cos(uv.x*gridsize*20.))-6.),max(0., 7.*cos(uv.y*gridsize*45. + uv.x*gridsize*20.)-6.)), max(0., 7.*cos(uv.y*gridsize*45. - uv.x*gridsize*20.)-6.));

    hsl.x = hsl.x + res + fac;     // décale la teinte
    hsl.y = hsl.y*1.3;
    hsl.z = hsl.z*0.6+0.4;
    tex = (1.-delta)*tex + delta*RGB(hsl)*vec4(0.9,0.8,1.2,tex.a);
    if (tex[3] < 0.7) tex[3] = tex[3]/3.;
    return dissolve_mask(tex*colour, texture_coords, uv);
}
```

### `polychrome.fs` — chromatique saturé (le "rainbow" lisse)

Même idée que holo mais sans la grille : décalage de teinte continu et très
saturé.

```glsl
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    number low = min(tex.r, min(tex.g, tex.b));
    number high = max(tex.r, max(tex.g, tex.b));
    number delta = high - low;
    number saturation_fac = 1. - max(0., 0.05*(1.1-delta));
    vec4 hsl = HSL(vec4(tex.r*saturation_fac, tex.g*saturation_fac, tex.b, tex.a));

    float t = polychrome.y*2.221 + time;
    vec2 floored_uv = (floor((uv*texture_details.ba)))/texture_details.ba;
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 50.;
    vec2 field_part1 = uv_scaled_centered + 50.*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.*vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.*vec2(sin(-t / 87.53218), sin(-t / 49.0000));
    float field = (1.+ (cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) + cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92) ))/2.;
    float res = (.5 + .5* cos( (polychrome.x) * 2.612 + ( field + -.5 ) *3.14));
    hsl.x = hsl.x + res + polychrome.y*0.04;
    hsl.y = min(0.6, hsl.y+0.5);
    tex.rgb = RGB(hsl).rgb;
    if (tex[3] < 0.7) tex[3] = tex[3]/3.;
    return dissolve_mask(tex*colour, texture_coords, uv);
}
```

### `negative.fs` — négatif sombre (inverse luminosité + teinte)

```glsl
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    vec4 SAT = HSL(tex);
    if (negative.g > 0.0 || negative.g < 0.0) SAT.b = (1.-SAT.b);  // inverse la luminosité
    SAT.r = -SAT.r+0.2;                                            // décale la teinte
    tex = RGB(SAT) + 0.8*vec4(79./255., 99./255.,103./255.,0.);    // teinte gris-bleu
    if (tex[3] < 0.7) tex[3] = tex[3]/3.;
    return dissolve_mask(tex*colour, texture_coords, uv);
}
```

### `debuff.fs` — carte désactivée (désaturée + croix rouge diagonale)

```glsl
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    vec4 SAT = HSL(tex*0.8 + 0.2*vec4(1., 0., 0., tex.a));
    SAT.g = 0.5;
    number width = 0.0;
    if (debuff.g > 0.0 || debuff.g < 0.0) width = 0.1;
    bool test = false;
    if ((uv.x+uv.y > 1. - width && uv.x+uv.y < 1. + width) || ((1.-uv.x)+uv.y > 1. - width && (1.-uv.x)+uv.y < 1. + width)) {
        test = true; SAT.r = 1.; SAT.g = 0.7; SAT.b = 0.8*SAT.b;   // la croix
    } else { SAT.g = SAT.g*0.5; SAT.b = SAT.b*0.7; }
    tex = RGB(SAT);
    if (!test) tex.a = tex.a*0.3;
    return dissolve_mask(tex*colour, texture_coords, uv);
}
```

### `played.fs` — carte jouée (désaturée, semi-transparente)

```glsl
vec4 SAT = HSL(tex);
SAT.g = SAT.g*0.5 + 0.000001*played.r;
SAT.b = SAT.b*0.8;
tex = RGB(SAT);
tex.a = tex.a*0.5;
return dissolve_mask(tex*colour, texture_coords, uv);
```

### `voucher.fs` / `booster.fs` / `negative_shine.fs` — variantes de "shine"

Les trois partagent la même structure : 4-5 facteurs sinusoïdaux (`fac…fac5`)
combinés en `maxfac`, teinte de base poussée vers le bleu-violet
(`tex.rgb*0.5 + vec3(0.4,0.4,0.8)`), puis modulation par canal. Exemple
`voucher.fs` :

```glsl
number low = min(tex.r, min(tex.g, tex.b));
number high = max(tex.r, max(tex.g, tex.b));
number delta = high-low;
number fac  = 0.8 + 0.9*sin(13.*uv.x+5.32*uv.y + voucher.r*12. + cos(voucher.r*5.3 + uv.y*4.2 - uv.x*4.));
number fac2 = 0.5 + 0.5*sin(10.*uv.x+2.32*uv.y + voucher.r*5.  - cos(voucher.r*2.3 + uv.x*8.2));
number fac3 = 0.5 + 0.5*sin(12.*uv.x+6.32*uv.y + voucher.r*6.111 + sin(voucher.r*5.3 + uv.y*3.2));
number fac4 = 0.5 + 0.5*sin(4.*uv.x+2.32*uv.y + voucher.r*8.111 + sin(voucher.r*1.3 + uv.y*13.2));
number fac5 = sin(0.5*16.*uv.x+5.32*uv.y + voucher.r*12. + cos(voucher.r*5.3 + uv.y*4.2 - uv.x*4.));
number maxfac = 0.6*max(max(fac, max(fac2, max(fac3,0.0))) + (fac+fac2+fac3*fac4), 0.);
tex.rgb = tex.rgb*0.5 + vec3(0.4, 0.4, 0.8);
tex.r = tex.r-delta + delta*maxfac*(0.7 + fac5*0.07) - 0.1;
tex.g = tex.g-delta + delta*maxfac*(0.7 - fac5*0.17) - 0.1;
tex.b = tex.b-delta + delta*maxfac*0.7 - 0.1;
tex.a = tex.a*(0.8*max(min(1., max(0.,0.3*max(low*0.2, delta)+ min(max(maxfac*0.1,0.), 0.4)) ), 0.) + 0.15*maxfac*(0.1+delta));
return dissolve_mask(tex*colour, texture_coords, uv);
```
(`booster` = mêmes constantes ; `negative_shine` = facteurs un peu plus forts.)

### `hologram.fs` — overlay holo translucide avec glow + glitch horizontal

Différent : calcule un **glow** (somme de l'alpha sur 9×9 échantillons voisins),
un **décalage horizontal glitch** (`offset_l/offset_r` sinusoïdaux), recolore
les bords transparents en cyan. Voir le fichier source ; structure :
```glsl
// 1) glow = moyenne d'alpha des texels voisins (halo)
// 2) offset horizontal par lignes (glitch) -> texture_coords.x += ...
// 3) si pixel transparent -> couleur cyan ; sinon teinte légère
// 4) dissolve_mask
```

### `gold_seal.fs` — sceau doré brillant (overlay simple, sans dissolve)

```glsl
extern vec4 gold_seal;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    number low  = min(pixel.r, min(pixel.g, pixel.b));
    number high = max(pixel.r, max(pixel.g, pixel.b));
    number delta = high*0.5;
    number fac = 0.3+sin((texture_coords.x*450. + sin(gold_seal.r*6.)*180.)-700.*gold_seal.r) - sin((texture_coords.x*190. + texture_coords.y*30.)+1080.3*gold_seal.r);
    pixel.r = max(pixel.r, (1. - pixel.r)*delta*fac + pixel.r);
    pixel.g = max(pixel.g, (1. - pixel.g)*delta*fac + pixel.g);
    pixel.b = max(pixel.b, (1. - pixel.b)*delta*fac + pixel.b);
    return pixel;
}
```

### `skew.fs` / `vortex.fs` — uniquement un vertex shader

`skew.fs` ne contient *que* le bloc vertex de tilt 3D (pas de modif de couleur).
`vortex.fs` ajoute `extern float vortex_amt;` + le bloc vertex : il déforme la
géométrie pour l'animation de transition "tout est aspiré" (le shader est piloté
par `G.vortex_time`).

---

## Balatro : background (fond animé) {#balatro-background}

Appliqué à un rectangle plein écran. **Aucune texture** : 100 % procédural.
Swirl polaire + 5 itérations de repli d'UV ("paint") + mélange de 3 couleurs.

```glsl
extern MY_HIGHP_OR_MEDIUMP number time;
extern MY_HIGHP_OR_MEDIUMP number spin_time;
extern MY_HIGHP_OR_MEDIUMP vec4 colour_1;   // 3 couleurs de la palette du fond
extern MY_HIGHP_OR_MEDIUMP vec4 colour_2;
extern MY_HIGHP_OR_MEDIUMP vec4 colour_3;
extern MY_HIGHP_OR_MEDIUMP number contrast;
extern MY_HIGHP_OR_MEDIUMP number spin_amount;
#define PIXEL_SIZE_FAC 700.
#define SPIN_EASE 0.5

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    number pixel_size = length(love_ScreenSize.xy)/PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy) - vec2(0.12, 0.);
    number uv_len = length(uv);

    // swirl central dépendant du temps
    number speed = (spin_time*SPIN_EASE*0.2) + 302.2;
    number new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
    vec2 mid = (love_ScreenSize.xy/length(love_ScreenSize.xy))/2.;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

    // effet "peinture" : 5 itérations de repli
    uv *= 30.;
    speed = time*(2.);
    vec2 uv2 = vec2(uv.x+uv.y);
    for (int i=0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121), sin(uv2.x - 0.113*speed));
        uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
    }

    // mélange des 3 couleurs selon la "quantité de peinture"
    number contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
    number paint_res = min(2., max(0., length(uv)*(0.035)*contrast_mod));
    number c1p = max(0., 1. - contrast_mod*abs(1.-paint_res));
    number c2p = max(0., 1. - contrast_mod*abs(paint_res));
    number c3p = 1. - min(1., c1p + c2p);
    vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a));
    return ret_col;
}
```

> **Reproduire** : dessiner un rectangle plein écran avec ce shader, envoyer
> `time`, `spin_time` (temps), 3 couleurs de palette, `contrast≈3`,
> `spin_amount≈0`. Le `floor()` initial pixellise volontairement le fond
> (cohérent avec le pixel-art). Pour The Pit grimdark : 3 teintes sombres
> (rouge sang, gris-vert, noir) → fond organique vivant gratuit.

---

## Balatro : CRT (post-process plein écran) {#balatro-crt}

Le shader final appliqué au canvas entier. Fait, dans l'ordre : distorsion
barrel, glitch horizontal optionnel, **aberration chromatique**, scanlines,
bruit, correction contraste/luminosité, **bloom** (boucle 7×7). Voir
[`post-processing.md`](post-processing.md) pour le code intégral et la chaîne de
canvas. Uniforms : `distortion_fac, scale_fac, feather_fac, noise_fac,
bloom_fac, crt_intensity, glitch_intensity, scanlines, time`.

---

## Balatro : flame / splash / flash {#balatro-divers}

### `flame.fs` — flamme procédurale (Jokers "on fire", etc.)

Pixellise (`PIXEL_SIZE_FAC 60`), construit un champ de fumée par 5 itérations,
le fait monter dans le temps, et colore selon `colour_1/colour_2`. Piloté par
`amount` (intensité) et `id` (désync par entité). Code complet dans la source ;
c'est la référence pour un **feu pixel-art animé sans spritesheet**.

### `splash.fs` — éclaboussure/tourbillon de transition

Variante de `background` orientée transition : swirl + fumée, flash blanc final
piloté par `mid_flash`. Utilisé pour les écrans de victoire/défaite.

### `flash.fs` — flash blanc radial temporisé

Très court : un flash blanc qui part du centre selon `time` et `mid_flash`.

```glsl
extern number time; extern number mid_flash;
#define PIXEL_SIZE_FAC 700.
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    number pixel_size = length(love_ScreenSize.xy)/PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
    float mid_white = min(1.,(time > 2.5 ? max(0., sqrt(time - 2.5) - 60.*length(uv)) : 0.)
                        + (time > 11. ? max(0., (time-11.)*(time-11.) - 5.*length(uv)) : 0.));
    return vec4(1., 1., 1., mid_flash*mid_white);
}
```

---

## Index transversal des familles d'effets {#index-transversal}

Où trouver chaque famille d'effet dans cette bibliothèque :

| Effet recherché | Meilleure source | Fichier |
|-----------------|------------------|---------|
| Reflet foil / holo / arc-en-ciel sur carte | **Balatro** | ci-dessus (`foil/holo/polychrome`) |
| Dissolution / burn d'apparition-destruction | **Balatro** | `dissolve_mask` ci-dessus |
| Tilt 3D de carte au survol | **Balatro** | bloc vertex ci-dessus |
| Fond animé procédural (sans texture) | **Balatro** | `background` ci-dessus |
| CRT / scanlines / aberration chromatique | **Balatro** + **Moonring** | `post-processing.md`, `games/moonring.md` |
| Bloom | **Moonring** (passe dédiée) + **Balatro** (dans CRT) | `games/moonring.md`, `post-processing.md` |
| Recolour / palette swap | **Moonring** | `games/moonring.md` (`recolour.fs`) |
| Eau / fluide animé | **Mudborne** | `games/mudborne.md` (`sh_fluid.frag`) |
| Outline / contour de sprite | **Mudborne** | `games/mudborne.md` (`sh_outline.frag`) |
| Éclairage jour/nuit, ombres | **Mudborne** | `games/mudborne.md` (`sh_night`, `sh_shadows`) |
| Neige / météo | **Mudborne** | `games/mudborne.md` (`sh_snow.frag`) |
| Bloom/blur/bulge/chromatic en juice | **Dice Have No Eyes** | `games/dice-have-no-eyes.md` (`src/shaders/`) |
| Flamme / feu pixel-art procédural | **Balatro** | `flame.fs` ci-dessus |

> Quand l'agent de The Pit (sur Mac) cherche un effet, commencer par ce tableau,
> puis ouvrir le fichier indiqué qui contient le GLSL complet + le "comment
> reproduire".
