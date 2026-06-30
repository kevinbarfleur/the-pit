# Particules — émetteurs maison vs `love.graphics.newParticleSystem`

> Deux approches observées : l'**émetteur maison** minimaliste de Balatro (des
> carrés colorés, ultra léger) et les systèmes **data-driven** plus riches
> (Moonring : `particle_data.lua` 119 Ko de définitions → voir
> `games/moonring.md`). Plus le système **intégré** de LÖVE.

## 1. L'émetteur maison de Balatro (`engine/particles.lua`)

Philosophie : pas de texture, pas de lib. Un `Particles` est un Moveable qui
émet des **petits rectangles** avec direction aléatoire, une enveloppe de scale
(grossit puis rétrécit), une vitesse qui décroît, une rotation, une couleur tirée
d'une palette. C'est ce qui fait les étoiles du fond, la poussière, les confettis.

### Configuration

```lua
local p = Particles(x, y, w, h, {
    timer = 0.5,           -- intervalle d'émission (s) -> 1 particule / 0.5 s
    lifespan = 1,          -- durée de vie (s)
    speed = 1,             -- vitesse de base
    vel_variation = 1,     -- 0..1 aléa de vitesse
    scale = 0.1,           -- taille
    max = 50,              -- nb max de particules vivantes
    pulse_max = 0,         -- >0 : émettre N d'un coup (burst) puis stop
    colours = {G.C.RED, G.C.ORANGE},  -- palette tirée au hasard
    fill = true,           -- émettre dans tout le rect (sinon depuis le centre)
    attach = someMoveable, -- suit un objet (alignment 'cm', bond Strong)
    initialize = true,     -- pré-simule 60 frames pour qu'il soit déjà "plein" à l'apparition
})
```

### Mécanique clé (à reproduire)

À l'émission, chaque particule reçoit (`particles.lua:79`) :
```lua
{ dir = random()*2π,                 -- direction de déplacement
  facing = random()*2π,              -- rotation visuelle
  velocity = speed*(vel_variation*random() + (1-vel_variation))*0.7,
  r_vel = 0.2*(0.5-random()),        -- vitesse de rotation
  age = 0, scale = 0,
  colour = pseudorandom_element(colours),
  offset = {x, y} }                  -- position relative à l'émetteur
```

Chaque frame (`particles.lua:100`) :
```lua
-- enveloppe de scale : grossit jusqu'au milieu de vie, puis rétrécit (triangle)
p.scale = min( 2*min( (age/lifespan)*S, S*((lifespan-age)/lifespan) ), S )
-- déplacement
p.offset.x += p.velocity*sin(p.dir)*dt
p.offset.y += p.velocity*cos(p.dir)*dt
p.facing   += p.r_vel*dt
-- friction : la vitesse décroît exponentiellement
p.velocity  = max(0, p.velocity - p.velocity*0.07*dt)
-- quand scale repasse < 0 -> retirée
```

Rendu (`particles.lua:144`) : un simple `rectangle('fill', ...)` rotaté et
coloré, alpha modulé par `fade_alpha`. **Aucune texture** → coût quasi nul.

```lua
love.graphics.setColor(v.colour[1], v.colour[2], v.colour[3], v.colour[4]*alpha*(1-fade_alpha))
love.graphics.translate(v.offset.x, v.offset.y)
love.graphics.rotate(v.facing)
love.graphics.rectangle('fill', -v.scale/2, -v.scale/2, v.scale, v.scale)
```

> **Pourquoi c'est malin** : l'enveloppe triangulaire de scale fait que les
> particules **apparaissent et disparaissent en fondu de taille** (pas de pop
> brutal). La friction `*0.07` donne un mouvement organique qui s'essouffle.
> `pulse_max` permet un **burst** ponctuel (explosion) avec le même code que
> l'émission continue. `initialize` pré-remplit l'effet pour qu'un fond étoilé
> soit déjà peuplé dès la 1ère frame.

### Version autonome minimale (pour The Pit)

```lua
local Emitter = {}
Emitter.__index = Emitter
function Emitter.new(cfg)
    return setmetatable({ cfg = cfg, parts = {}, acc = 0 }, Emitter)
end
function Emitter:burst(n, x, y)
    for _=1,n do
        self.parts[#self.parts+1] = {
            x=x, y=y, dir=love.math.random()*2*math.pi,
            vel=self.cfg.speed*(0.5+love.math.random()*0.5),
            facing=love.math.random()*2*math.pi, rvel=(love.math.random()-0.5)*4,
            age=0, life=self.cfg.life, col=self.cfg.colours[love.math.random(#self.cfg.colours)],
        }
    end
end
function Emitter:update(dt)
    for i=#self.parts,1,-1 do
        local p = self.parts[i]
        p.age = p.age + dt
        if p.age >= p.life then table.remove(self.parts, i)
        else
            p.x = p.x + math.sin(p.dir)*p.vel*dt
            p.y = p.y + math.cos(p.dir)*p.vel*dt
            p.facing = p.facing + p.rvel*dt
            p.vel = p.vel * (1 - 0.07)          -- friction (approx, dt-indép. faible)
        end
    end
end
function Emitter:draw()
    for _,p in ipairs(self.parts) do
        local k = p.age/p.life
        local s = self.cfg.scale * 2*math.min(k, 1-k)   -- enveloppe triangle
        love.graphics.setColor(p.col[1], p.col[2], p.col[3], (p.col[4] or 1)*(1-k))
        love.graphics.push()
        love.graphics.translate(p.x, p.y); love.graphics.rotate(p.facing)
        love.graphics.rectangle('fill', -s/2, -s/2, s, s)
        love.graphics.pop()
    end
end
-- usage : e = Emitter.new{speed=60, life=0.8, scale=6, colours={{1,0.3,0.2,1}}}
--         e:burst(20, hitx, hity)  -- éclaboussure de dégâts
```

---

## 2. Systèmes data-driven (Moonring)

Pour des effets variés et nombreux (sorts, impacts, ambiance), définir les
effets dans des **tables de données** séparées du code :

```
particle_data.lua    -> dictionnaire {nom_effet = {émission, couleurs, courbes, sprites, ...}}
particle_effect.lua  -> instancie un effet depuis une définition
particle_manager.lua -> pool global : spawn(nom, x, y), update, draw, recyclage
```

Avantage : on ajoute/règle des effets **sans toucher le moteur**, et un designer
peut tuner les courbes. Voir `games/moonring.md` pour la structure réelle d'une
définition. C'est l'approche recommandée si The Pit veut un **bestiaire d'effets**
(poison, brûlure, soin, invocation…) déclarés en data, cohérent avec notre
philosophie DATA/TUNING.

---

## 3. Le système intégré de LÖVE (`love.graphics.newParticleSystem`)

LÖVE fournit un système natif performant (rendu en SpriteBatch). À privilégier
pour de **gros volumes** (fumée, pluie, feu) avec une texture :

```lua
local img = love.graphics.newImage("spark.png")
local ps = love.graphics.newParticleSystem(img, 256)
ps:setParticleLifetime(0.3, 0.9)
ps:setEmissionRate(120)
ps:setSizeVariation(1)
ps:setLinearAcceleration(-30, -60, 30, -120)   -- min/max ax/ay (ex: monte)
ps:setColors(1,1,1,1,  1,0.5,0,1,  1,0,0,0)     -- dégradé sur la durée de vie
ps:setSizes(1.5, 0.2)                            -- grossit -> rétrécit
ps:setSpin(0, 5); ps:setSpread(math.pi*2)
-- update/draw :
function love.update(dt) ps:update(dt) end
function love.draw() love.graphics.draw(ps, x, y) end
ps:emit(20)  -- burst
```

Quand l'utiliser :
- **Émetteur maison (Balatro)** : peu de particules, look vectoriel/carrés, intégré
  au système Moveable (suit un objet, parallaxe, pause). Idéal pour le juice
  ponctuel et l'ambiance discrète.
- **Data-driven (Moonring)** : beaucoup d'effets nommés réutilisables, tunables.
- **`newParticleSystem` natif** : gros volumes texturés, perf maximale.

---

## 4. Recettes d'effets pour The Pit

| Effet | Approche | Réglages |
|-------|----------|----------|
| Éclaboussure de dégâts | burst maison | 15-25 carrés rouges, life 0.4 s, vitesse forte, friction |
| Étincelles de coup critique | burst maison ou natif | jaune/blanc, spin élevé, gravité légère |
| Poussière de plateau au repos | émetteur continu lent | gris sombre, peu, `initialize=true` |
| Fumée / vapeur | natif texturé | grande life, alpha qui fond, accélération vers le haut |
| Confettis de victoire | burst maison | multi-couleurs, gravité, beaucoup |
| Aura de relique/buff | émetteur attaché (`attach`) | suit la carte, couleur = type |

> Régler la **friction** et l'**enveloppe de scale** avant tout : c'est ce qui
> distingue une particule "organique" d'un point qui se téléporte. Et toujours
> faire mourir en **fondu** (alpha + taille), jamais en pop sec.
