-- src/core/dev.lua
-- MODE DÉVELOPPEUR (cheat). UN SEUL master switch : `Dev.ENABLED`. Le passer à `false` AVANT publication
-- désactive TOUTE la surface dev d'un coup — le toggle disparaît du menu et tous les overrides redeviennent
-- inertes (`fullUnlock()` renvoie false quoi qu'il arrive, le fichier persistant est ignoré). Donc :
-- non-cheatable par les joueurs (rien à activer), et trivial à désactiver pour la release (1 ligne).
--
-- `fullUnlock` : toggle runtime (depuis le menu) qui RÉVÈLE tout le codex (reliques + bestiaire) au READ-TIME
-- (Grimoire.isKnown / Bestiary.isSeen le consultent). Il ne touche JAMAIS la vraie progression persistée —
-- l'éteindre rend la vue normale (caché = progression réelle). Persisté à part (dev-only) pour le confort.

local Dev = {
  ENABLED = true,        -- ⚠️ METTRE À false POUR LA RELEASE (coupe tout le mode dev ; non-cheatable).
  _fullUnlock = false,   -- état runtime du toggle.
  file = "dev_fullunlock.txt",
}

-- Tout révéler ? true seulement si le mode dev est actif ET le toggle armé. Utilisé par les codex (read-time).
function Dev.fullUnlock()
  return Dev.ENABLED and Dev._fullUnlock
end

-- Bascule le toggle (no-op hors mode dev) + persiste (dev-only ; silencieux si pas d'IO).
function Dev.toggleFullUnlock()
  if not Dev.ENABLED then return false end
  Dev._fullUnlock = not Dev._fullUnlock
  if love and love.filesystem and love.filesystem.write then
    pcall(love.filesystem.write, Dev.file, Dev._fullUnlock and "1" or "0")
  end
  return Dev._fullUnlock
end

-- Charge l'état persisté du toggle (uniquement si le mode dev est actif -> en release, fichier ignoré).
function Dev.load()
  if not Dev.ENABLED then return end
  if love and love.filesystem and love.filesystem.read then
    local ok, data = pcall(love.filesystem.read, Dev.file)
    if ok and type(data) == "string" and data:match("1") then Dev._fullUnlock = true end
  end
end

return Dev
