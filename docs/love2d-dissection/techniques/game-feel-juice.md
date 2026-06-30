# Game feel & juice — ressorts, easing, squash-stretch, screenshake

> Le "juice" est ce qui transforme une logique correcte en jeu *satisfaisant*.
> Ce doc rassemble les patterns réutilisables observés dans Balatro (le maître du
> mouvement de carte) et Dice Have No Eyes (le maître de l'effet d'écran). Tout
> est transposable tel quel à The Pit.

## Principe directeur : séparer la cible du visible

La règle d'or de Balatro : **ne jamais dessiner la valeur logique directement.**
Chaque objet a deux transforms :

- **`T`** (Transform) = la **cible** : où l'objet *devrait* être (résultat de la
  logique : "cette carte va en position 3 de la main").
- **`VT`** (Visible Transform) = ce qui est **réellement dessiné** ; il **rattrape
  `T` en douceur** chaque frame.

On écrit `T.x = 5`. On ne touche jamais `VT`. Le moteur fait glisser `VT` vers
`T`. Résultat : **rien ne se téléporte jamais**. Une carte qui change de place
glisse ; une fenêtre qui s'ouvre grandit ; un objet retiré rétrécit.

---

## 1. Le ressort-amortisseur (l'easing de Balatro)

Extrait de `engine/moveable.lua` (Balatro). C'est un intégrateur de vitesse avec
lissage exponentiel — un ressort critiquement amorti, pas un simple `lerp`.

> **Détail crucial — l'inertie est indépendante du framerate.** Balatro ne fixe
> PAS `exp_times` à une constante : il le recalcule chaque frame
> (`game.lua:2618`) :
> ```lua
> G.exp_times.xy    = math.exp(-50  * dt)   -- ≈ 0.435 à 60 fps
> G.exp_times.scale = math.exp(-60  * dt)   -- ≈ 0.368  (le scale rattrape un peu plus vite)
> G.exp_times.r     = math.exp(-190 * dt)   -- ≈ 0.042  (la rotation se cale quasi instant)
> G.exp_times.max_vel = 70 * dt
> ```
> La formule `inertie = exp(-rate*dt)` garantit le **même ressenti à 30, 60 ou
> 144 fps**. Plus le `rate` est grand, plus l'objet rattrape vite sa cible.

```lua
-- exp_times.xy = math.exp(-50*dt) (recalculé chaque frame), max_vel = 70*dt
function Moveable:move_xy(dt)
    if (self.T.x ~= self.VT.x or math.abs(self.velocity.x) > 0.01) or
       (self.T.y ~= self.VT.y or math.abs(self.velocity.y) > 0.01) then
        -- nouvelle vitesse = inertie*ancienne + (1-inertie)*(distance restante)*raideur*dt
        self.velocity.x = G.exp_times.xy*self.velocity.x + (1-G.exp_times.xy)*(self.T.x - self.VT.x)*35*dt
        self.velocity.y = G.exp_times.xy*self.velocity.y + (1-G.exp_times.xy)*(self.T.y - self.VT.y)*35*dt
        -- clamp de la vitesse max (évite les sauts)
        if self.velocity.x^2 + self.velocity.y^2 > G.exp_times.max_vel^2 then
            local v = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
            self.velocity.x = G.exp_times.max_vel*self.velocity.x/v
            self.velocity.y = G.exp_times.max_vel*self.velocity.y/v
        end
        self.VT.x = self.VT.x + self.velocity.x
        self.VT.y = self.VT.y + self.velocity.y
        -- snap quand on est assez proche (évite les micro-oscillations infinies)
        if math.abs(self.VT.x - self.T.x) < 0.01 and math.abs(self.velocity.x) < 0.01 then
            self.VT.x = self.T.x; self.velocity.x = 0
        end
        if math.abs(self.VT.y - self.T.y) < 0.01 and math.abs(self.velocity.y) < 0.01 then
            self.VT.y = self.T.y; self.velocity.y = 0
        end
    end
end
```

### Version minimale réutilisable (à coller dans The Pit)

```lua
-- un "ressort" générique : approche `target` avec inertie
local Spring = {}
Spring.__index = Spring
function Spring.new(value)
    return setmetatable({ value = value, target = value, vel = 0 }, Spring)
end
function Spring:update(dt, stiffness, rate, max_vel)
    stiffness = stiffness or 35; rate = rate or 50; max_vel = max_vel or 1e9
    local inertia = math.exp(-rate * dt)   -- indépendant du framerate (clé !)
    self.vel = inertia*self.vel + (1-inertia)*(self.target - self.value)*stiffness*dt
    if math.abs(self.vel) > max_vel then self.vel = max_vel*(self.vel>0 and 1 or -1) end
    self.value = self.value + self.vel
    if math.abs(self.value - self.target) < 0.001 and math.abs(self.vel) < 0.001 then
        self.value = self.target; self.vel = 0
    end
end
-- usage : pos = Spring.new(x0); pos.target = x_final; pos:update(dt); draw at pos.value
```

> Réglages : `stiffness` ↑ = rattrape plus vite ; `rate` ↓ = plus de rebond/
> "mou" et de traîne ; `max_vel` borne les grands sauts. Balatro a des `rate`
> différents par axe (xy:50, scale:60, r:190) → la rotation se cale presque
> instantanément tandis que la position garde un peu d'élan, ce qui donne le
> mouvement organique des cartes.

### Rotation et scale séparés

`move_r` ease la rotation, et y injecte la **vitesse horizontale** : une carte
qui glisse vite à droite s'incline légèrement (`des_r = T.r + 0.015*vel.x/dt`).
Détail de feel gratuit (la carte "penche dans le virage").

```lua
function Moveable:move_r(dt, vel)
    local des_r = self.T.r + 0.015*vel.x/dt + (self.juice and self.juice.r*2 or 0)
    self.velocity.r = G.exp_times.r*self.velocity.r + (1-G.exp_times.r)*(des_r - self.VT.r)
    self.VT.r = self.VT.r + self.velocity.r
end
```

---

## 2. `juice_up()` — le squash-stretch amorti (LE geste signature)

Quand une carte se déclenche (Joker qui marque, main jouée, achat), Balatro la
fait "pulser" : elle s'écrase puis rebondit avec une oscillation qui s'éteint.

```lua
function Moveable:juice_up(amount, rot_amt)
    if G.SETTINGS.reduced_motion then return end
    amount = amount or 0.4
    self.juice = {
        scale = 0, scale_amt = amount,
        r = 0, r_amt = rot_amt or pseudorandom_element({0.6*amount, -0.6*amount}),
        start_time = G.TIMERS.REAL,
        end_time = G.TIMERS.REAL + 0.4,
    }
    self.VT.scale = 1 - 0.6*amount   -- écrase INSTANTANÉMENT, puis le sinus rebondit
end

-- mis à jour chaque frame :
function Moveable:move_juice(dt)
    if self.juice and self.juice.end_time >= G.TIMERS.REAL then
        local t = G.TIMERS.REAL - self.juice.start_time
        local life = (self.juice.end_time - G.TIMERS.REAL)/(self.juice.end_time - self.juice.start_time)
        -- oscillation amortie : sin rapide * enveloppe qui décroît (puissance 3 pour le scale)
        self.juice.scale = self.juice.scale_amt * math.sin(50.8*t) * math.max(0, life^3)
        self.juice.r     = self.juice.r_amt     * math.sin(40.8*t) * math.max(0, life^2)
    elseif self.juice then
        self.juice = nil
    end
end
-- au draw, le scale appliqué = VT.scale (qui inclut self.juice.scale via move_scale)
```

**Recette générique** (squash-stretch sur n'importe quoi) :
```
offset(t) = amplitude * sin(freq * t) * max(0, ((duration - t)/duration))^power
```
- `freq ≈ 40–51` rad/s → ~3-4 oscillations sur 0.4 s.
- `power = 3` (scale) ou `2` (rotation) → l'enveloppe meurt vite et proprement.
- `amount` ≈ 0.4 pour un pop visible, 0.1–0.2 pour un feedback discret.

> **À appliquer dans The Pit** sur : déclenchement de capacité, encaissement de
> dégâts, gain d'or, achat en boutique, level-up. Un `:juice_up(0.3)` au bon
> moment = +80 % de satisfaction pour 0 coût.

---

## 3. Soudure d'objets (Major / Minor) — bouger des groupes gratuitement

Dans Balatro, une carte dans la main est un Moveable **Minor** "soudé" à un
CardArea **Major**. Le Minor copie la transform du Major + un offset. Conséquence :

- on **incline / secoue / déplace** le Major → tous les enfants suivent, avec la
  rotation correctement composée (`move_with_major`).
- on n'écrit jamais la position absolue d'une carte : juste son offset dans la
  zone. La zone gère le layout.

Bonds réglables : `'Strong'` (copie instantanée) ou `'Weak'` (l'enfant ease lui-
même → effet de "traîne" / élastique entre parent et enfant). C'est le bond
`Weak` qui donne l'impression que les cartes "rattrapent" la main avec un léger
retard.

> Pour The Pit : notre plateau 3×3 peut être un Major ; les monstres des Minor.
> Secouer le plateau (impact) ou le faire respirer devient trivial.

---

## 4. Le conteneur qui secoue l'écran (screenshake "gratuit")

Comme chaque Node se dessine **relativement à son conteneur**
(`Node:translate_container`), il suffit de décaler/tourner le conteneur racine
(`G.ROOM`) pour secouer **tout** sans toucher les objets.

Pattern de screenshake (trauma décroissant, indépendant de Balatro mais idéal) :

```lua
-- Dice Have No Eyes et la plupart des jeux "juicy" utilisent un trauma² :
Shake = { trauma = 0, x = 0, y = 0, rot = 0 }
function Shake:add(amount) self.trauma = math.min(1, self.trauma + amount) end
function Shake:update(dt, t)
    local s = self.trauma * self.trauma          -- trauma² = chute non linéaire, plus punchy
    local amp = 16 * s                            -- pixels max
    self.x   = amp * (love.math.noise(t*40, 0)*2 - 1)
    self.y   = amp * (love.math.noise(0, t*40)*2 - 1)
    self.rot = 0.05 * s * (love.math.noise(t*40, t*40)*2 - 1)
    self.trauma = math.max(0, self.trauma - dt*1.5)  -- décroît en ~0.7 s
end
-- au draw, avant de dessiner la scène :
love.graphics.translate(Shake.x, Shake.y)
love.graphics.rotate(Shake.rot)
```

> Pourquoi `trauma²` et du **noise** plutôt que `random()` : le noise donne un
> tremblement *continu* et cohérent (pas un grésillement), et le carré fait que
> les petits chocs sont discrets mais les gros chocs claquent. `add(0.3)` sur un
> coup normal, `add(0.7)` sur un coup critique.

---

## 5. Hitstop (freeze frame) — le punch de l'impact

Geler le jeu 30–120 ms au moment d'un gros impact donne énormément de poids.
Pattern :

```lua
local hitstop = 0
function freeze(duration) hitstop = math.max(hitstop, duration) end
function love.update(dt)
    if hitstop > 0 then
        hitstop = hitstop - dt
        dt = dt * 0.05      -- le jeu tourne au ralenti extrême (quasi figé)
    end
    -- ... update normal avec dt modifié ...
end
-- freeze(0.06) sur un coup, freeze(0.12) sur un kill / critique
```

Souvent combiné : **hitstop + screenshake + juice_up + flash** déclenchés
ensemble sur le même event = la "trinité" du feel d'impact.

---

## 6. Easing tweens (quand on n'a pas besoin d'un ressort)

Pour les animations à durée fixe (fade d'un panneau, montée d'un score), un tween
avec fonction d'easing suffit. Les courbes utiles :

```lua
local ease = {}
function ease.out_quad(t)  return 1 - (1-t)*(1-t) end
function ease.in_out_quad(t) return t<0.5 and 2*t*t or 1-(-2*t+2)^2/2 end
function ease.out_back(t)  local c1=1.70158; local c3=c1+1; return 1+c3*(t-1)^3+c1*(t-1)^2 end -- léger dépassement (rebond)
function ease.out_elastic(t)
    if t==0 or t==1 then return t end
    local c4 = (2*math.pi)/3
    return 2^(-10*t)*math.sin((t*10-0.75)*c4)+1
end
-- valeur = from + (to-from)*ease.out_back(elapsed/duration)
```

Balatro a son propre `ease_value` / `EventManager` (`engine/event.lua`) : une
**file d'événements temporisés** où chaque entrée a un délai, une durée, une
fonction d'easing et un callback. C'est ce qui orchestre les séquences (jouer
une main → chaque carte se déclenche l'une après l'autre avec délais). Pattern :

```lua
-- file d'events : { trigger='after'|'immediate', delay=, func=, blocking= }
-- un manager qui dépile dans l'ordre, en respectant les délais et le "blocking"
-- (un event blocking empêche le suivant tant qu'il n'est pas fini)
```

> Pour The Pit, c'est exactement ce qu'il faut pour **séquencer un tour de
> combat** : event "monstre A attaque" (0.3 s) → "B encaisse + juice + shake"
> (0.2 s) → "C contre-attaque"… avec des délais lisibles, pilotés par la SIM mais
> joués par la présentation.

---

## 7. Checklist "rendre un événement juicy" pour The Pit

Pour chaque événement marquant (capacité, dégâts, mort, achat), empiler :

1. **Mouvement** : poser la nouvelle `T`, laisser le ressort easer (jamais de snap).
2. **Squash-stretch** : `:juice_up(0.2–0.4)` sur l'objet acteur ET la cible.
3. **Screenshake** : `Shake:add(0.2–0.7)` proportionnel à l'ampleur.
4. **Hitstop** : `freeze(0.04–0.12)` sur les gros impacts seulement.
5. **Flash** : court flash blanc/coloré sur la cible (shader `flash` ou overlay).
6. **Particules** : éclaboussure/étincelles brèves (voir `particles.md`).
7. **Son** : SFX avec **pitch croissant** si l'event fait partie d'une chaîne.
8. **Texte** : nombre qui pop et monte (DynaText-like), couleur = type de dégât.

Régler l'intensité selon l'enjeu. Le secret de Balatro/Dice : ce ne sont pas des
effets isolés, c'est leur **superposition synchronisée** sur le même instant.
