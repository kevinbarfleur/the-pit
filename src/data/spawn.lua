-- src/data/spawn.lua
-- PONT D'ENGEANCE (axe « Mort & Engeance », plan big-update §AXE 3) — porte `window.SPAWN` du générateur de
-- bestiaire (docs/generation/generateur-bestiaire.html) en data Lua PURE. Une unité-invocatrice meurt →
-- l'op `summon` (src/effects/ops.lua) fait jaillir UN sous-être (token) à SA place (décision user : « 1 token,
-- dans la case libérée du parent » = remplacement 1-pour-1, PAS de débordement/multi-spawn).
--
-- Couche DATA : ce fichier ne require RIEN (descripteurs littéraux). La SIM (arena/ops) l'interprète ; le
-- RENDER (arena_draw → creaturegen.cached) lit `family`/`arch` du token pour le visuel + les anims.
--
-- TOKENS TERMINAUX (anti-boucle, garde-fou §6.4) : les 9 tokens sont IMPOSANCE 0 et ne portent AUCUN effet
-- `summon` → un token ne peut JAMAIS ré-invoquer. La chaîne de mort est bornée à profondeur 1 sans gouverneur
-- (la marée vient du NOMBRE d'invocateurs, pas du multi-spawn). Ils ne sont PAS dans le pool de boutique
-- (`Units.pool`) ni dans `Units.order` : on n'en achète/affiche jamais hors combat — ils n'existent que comme
-- engeance. Stats FAIBLES (placeholders à tuner via tools/sim.lua).
--
-- VISUEL (résolu, asset-forge 2026-06-25) : les 9 archétypes `sousetres` du prototype HTML (aGrubling/…/aSwarmling)
-- sont DÉSORMAIS portés dans src/gen/primgen.lua — UNE famille dédiée `sousetres` (pals GRUB + treatPod, fidèle au
-- proto) regroupe les 9 MINI-corps. Chaque token PIN son `arch` par NOM (Primgen.archIndexOf) → rend son PROPRE
-- mini-corps (un boneling = mini-squelette, un mote = petit œil ailé, un slimelet = goutte molle…), tout en restant
-- visuellement SUBORDONNÉ au parent (palette larvaire terne + pousses d'œufs du treatPod). Le rendu (arena_draw →
-- creaturegen.cached) lit ces `family`/`arch` du token sans aucune retouche : le pont passe family/arch tel quel.

-- Les 9 TOKENS (ids EXACTEMENT ceux de window.SPAWN). `type` = colle mécanique (couleur/pôle visuel + amps de
-- type W1 : un token hérite du `type` du parent → un board mono-os qui invoque des `boneling` reste mono-os,
-- cf. plan Q2). `family` = "sousetres" (famille dédiée) ; `arch` = le mini-corps homonyme du token (PIN par nom).
-- rank 1 (cost = rank pour l'invariant headless si jamais référencé) ; imposance 0 (terminal).
local TOKENS = {
  -- token id      type      family (primgen)  arch (=mini-corps homonyme)  hp  dmg  cd   (mini stats, placeholders)
  grubling   = { type = "bone",   family = "sousetres", arch = "grubling",   hp = 14, dmg = 3, cd = 40 },
  spiderling = { type = "flesh",  family = "sousetres", arch = "spiderling", hp = 12, dmg = 4, cd = 34 },
  sporeling  = { type = "arcane", family = "sousetres", arch = "sporeling",  hp = 12, dmg = 2, cd = 36 },
  ratling    = { type = "flesh",  family = "sousetres", arch = "ratling",    hp = 10, dmg = 3, cd = 32 },
  mote       = { type = "arcane", family = "sousetres", arch = "mote",       hp = 10, dmg = 3, cd = 38 },
  slimelet   = { type = "abyss",  family = "sousetres", arch = "slimelet",   hp = 16, dmg = 2, cd = 42 },
  implet     = { type = "abyss",  family = "sousetres", arch = "implet",     hp = 13, dmg = 4, cd = 36 },
  boneling   = { type = "bone",   family = "sousetres", arch = "boneling",   hp = 14, dmg = 3, cd = 40 },
  swarmling  = { type = "order",  family = "sousetres", arch = "swarmling",  hp = 11, dmg = 3, cd = 34 },
}

local Spawn = { tokens = TOKENS }

-- Liste des ids de tokens (ordre fixe -> déterministe pour les tests / le visuel).
Spawn.tokenOrder = { "grubling", "spiderling", "sporeling", "ratling", "mote", "slimelet", "implet", "boneling", "swarmling" }

-- Un token est-il TERMINAL (jamais ré-invoquant) ? Toujours vrai pour les 9 (imposance 0). Sert de garde
-- explicite côté arène (defensive : même si une data future donnait par erreur un `summon` à un token).
function Spawn.isToken(id) return TOKENS[id] ~= nil end

-- Descripteur d'un token (ou nil). Lu par l'arène (stats) et le render (family/arch).
function Spawn.token(id) return TOKENS[id] end

return Spawn
