-- src/data/creatures.lua
-- Définitions data-only des créatures, portées du bestiaire PixiJS.
-- Convention de nommage des parts : head, torso, armBack, armFront, weapon, legs, tail.
-- Une part manquante est silencieusement ignorée par le moteur (pas de crash).
-- Ajouter une créature = pure data : découper la grille, nommer, écrire le rig.

local Rig = require("src.core.rig")

local C = {}

-- ─────────────────────────────── MARAUDER ───────────────────────────────
C.marauder = {
  name = "MARAUDER",
  parts = {
    head = { grid = {
      " KKKKKK ",
      "KIRrRrIK",
      "KIRRrRIK",
      "KIIIIIIK",
      "KIaKKaIK",
      "KIIIIIIK",
      "KdPPPPdK",
      " KKKKKK ",
    }, pivot = { x = 4, y = 7 } },
    torso = { grid = {
      "  KKKK  ",
      " KIIIIK ",
      "KIYYYYIK",
      "KIYIIYIK",
      "KIIIIIIK",
      "KILLLLIK",
      " KKKKKK ",
    }, pivot = { x = 3, y = 6 } },
    armBack = { grid = { "KIK", "KIK", "KIK", "KIK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    armFront = { grid = { "KIK", "KIK", "KIK", "KIK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    weapon = { grid = {
      "  KK ",
      "  KL ",
      "  KL ",
      " KKKK",
      "KIIIK",
      "KIIIK",
      " KKK ",
    }, pivot = { x = 2, y = 0 } },
    legs = { grid = {
      "KIIK KIIK",
      "KLLK KLLK",
      "KLLK KLLK",
      "KnLK KnLK",
      "KKKK KKKK",
    }, pivot = { x = 4, y = 0 } },
  },
  rig = {
    { part = "legs", at = { 0, -5 } },
    { part = "armBack", at = { -2, -10 } },
    { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } },
    { part = "armFront", parent = "torso", at = { 6, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  },
  idlePose = { armFront = 0, weapon = -math.pi / 2 },
}

-- ─────────────────────────────── SQUELETTE ───────────────────────────────
C.skeleton = {
  name = "SQUELETTE",
  parts = {
    head = { grid = {
      " KKKKKKK ",
      "KSSSSSSSK",
      "KSKsSsKSK",
      "KSSSKSSSK",
      "KSsKsKsSK",
      "KsKsKsKsK",
      " KKKKKKK ",
    }, pivot = { x = 4, y = 6 } },
    torso = { grid = {
      " KKKKKK ",
      "KSSKKSSK",
      "KSKSSKSK",
      "KSSKKSSK",
      "KSKSSKSK",
      "KSSSSSSK",
      " KKKKKK ",
    }, pivot = { x = 3, y = 6 } },
    armBack = { grid = { "KSK", "KSK", "KSK", "KSK", "KSK", "KKK" }, pivot = { x = 1, y = 0 } },
    armFront = { grid = { "KSK", "KSK", "KSK", "KSK", "KSK", "KKK" }, pivot = { x = 1, y = 0 } },
    weapon = { grid = {
      "  K  ",
      " KLK ",
      "KKKKK",
      " KIK ",
      " KIK ",
      " KIK ",
      " KIK ",
      "  K  ",
    }, pivot = { x = 2, y = 0 } },
    legs = { grid = {
      "KSK KSK",
      "KSK KSK",
      "KSK KSK",
      "KSK KSK",
      "KKK KKK",
    }, pivot = { x = 3, y = 0 } },
  },
  rig = {
    { part = "legs", at = { 0, -5 } },
    { part = "armBack", at = { -2, -10 } },
    { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } },
    { part = "armFront", parent = "torso", at = { 6, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 5 } },
  },
  idlePose = { armFront = 0, weapon = -math.pi / 2 },
}
-- Custom : tremblement permanent des os (jitter pseudo-aléatoire par part).
C.skeleton.animations = {
  idle = function(char, t)
    local res = Rig.defaultIdle(char, t)
    local ph = char.idlePhase
    for name, part in pairs(char.parts) do
      local f = name:byte(1) * 0.013 -- fréquence différente par nom -> désynchro
      part.rot = part.rot + math.sin(t * 0.5 + f + ph) * 0.015
    end
    return res
  end,
}

-- ─────────────────────────────── TEMPLIER ───────────────────────────────
C.templar = {
  name = "TEMPLIER",
  parts = {
    head = { grid = {
      " KKKKKK ",
      "KIIYTYII",
      "KIIIIIII",
      "KIaaaaaI",
      "KIaKKaaI",
      "KIIIIIII",
      " KKKKKK ",
    }, pivot = { x = 4, y = 6 } },
    torso = { grid = {
      " KKKKKKK ",
      "KIIYTYIIK",
      "KIIYYYIIK",
      "KIYTTTYIK",
      "KIYYYYYIK",
      "KIIIIIIIK",
      "KIaIaIaIK",
      " KKKKKKK ",
    }, pivot = { x = 4, y = 7 } },
    armFront = { grid = { "KIK", "KIK", "KIK", "KIK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    armBack = { grid = { "KIK", "KIK", "KIK", "KIK", "KKK" }, pivot = { x = 1, y = 0 } },
    weapon = { grid = {
      " KK  ",
      " KL  ",
      " KL  ",
      " KK  ",
      "KKKKK",
      "KIYTI",
      "KIYTI",
      "KKKKK",
    }, pivot = { x = 1, y = 0 } },
    legs = { grid = {
      "KIIK KIIK",
      "KIIK KIIK",
      "KIIK KIIK",
      "KnIK KIaK",
      "KKKK KKKK",
    }, pivot = { x = 4, y = 0 } },
  },
  rig = {
    { part = "legs", at = { 0, -5 } },
    { part = "armBack", at = { -3, -11 } },
    { part = "torso", at = { 0, -5 } },
    { part = "armFront", parent = "torso", at = { 7, 2 } },
    { part = "head", parent = "torso", at = { 4, 0 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  },
  idlePose = { armFront = -1.4, armBack = 0.5, weapon = -math.pi / 2 },
}

-- ─────────────────────────────── BANDIT ───────────────────────────────
C.bandit = {
  name = "BANDIT",
  parts = {
    head = { grid = {
      " KKKKKK ",
      "KaaaaaaK",
      "KaaaaaaK",
      "KaXKpKpX",
      "KaXpPpPX",
      " KppppK ",
      "  KppK  ",
      "  KKKK  ",
    }, pivot = { x = 4, y = 7 } },
    torso = { grid = {
      "  KKKK  ",
      " KLLLLK ",
      "KLnnLLnK",
      "KLnnnnLK",
      "KLLLLLLK",
      "KLnnnnLK",
      " KKKKKK ",
    }, pivot = { x = 3, y = 6 } },
    armBack = { grid = { "KLK", "KLK", "KLK", "KLK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    armFront = { grid = { "KLK", "KLK", "KLK", "KLK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    weapon = { grid = {
      " KK ",
      "KLLK",
      "KKKK",
      " KIK",
      " KIK",
      " KIK",
      " KK ",
    }, pivot = { x = 2, y = 0 } },
    legs = { grid = {
      "KLLK KLLK",
      "KLLK KLLK",
      "KnLK KnLK",
      "KnKK KKnK",
      "KKKK KKKK",
    }, pivot = { x = 4, y = 0 } },
  },
  rig = {
    { part = "legs", at = { 0, -5 } },
    { part = "armBack", at = { -2, -10 } },
    { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } },
    { part = "armFront", parent = "torso", at = { 6, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  },
  idlePose = { armFront = -0.3, weapon = -math.pi / 2 },
}

-- ─────────────────────────────── SORCIÈRE ───────────────────────────────
-- Pas de jambes : la robe (torso) descend jusqu'au sol.
C.witch = {
  name = "SORCIERE",
  parts = {
    head = { grid = {
      "     KK    ",
      "    KvvK   ",
      "   KvVvVK  ",
      "  KvVHRVvK ",
      " KvVVVVVvK ",
      "KKvVVVvKKK ",
      "  KPPPPK   ",
      " KPCKpKCK  ",
      " KPPPPPPK  ",
      " KdddddK   ",
      "  KKKKK    ",
    }, pivot = { x = 4, y = 10 } },
    torso = { grid = {
      "  KKKKKK  ",
      " KXVVVVXK ",
      "KXVVVVVVXK",
      "KXVvvvvVXK",
      "KXVVVVVVXK",
      "KXvVvVvVXK",
      "KXVVVVVVXK",
      "KXxxxxxxXK",
      " KXxxxxXK ",
      " KKKKKKKK ",
    }, pivot = { x = 4, y = 9 } },
    armBack = { grid = { "KXK", "KXK", "KXK", "KVK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    armFront = { grid = { "KXK", "KXK", "KXK", "KVK", "KKK", "KPK", "KKK" }, pivot = { x = 1, y = 0 } },
    weapon = { grid = {
      "  KK ",
      "  KL ",
      "  KK ",
      " KSSK",
      "KSSSK",
      " KKK ",
    }, pivot = { x = 2, y = 0 } },
  },
  rig = {
    { part = "armBack", at = { -2, -7 } },
    { part = "torso", at = { 0, 0 } },
    { part = "head", parent = "torso", at = { 4, 0 } },
    { part = "armFront", parent = "torso", at = { 7, 1 } },
    { part = "weapon", parent = "armFront", at = { 1, 6 } },
  },
  idlePose = { armFront = 0, weapon = -math.pi },
}
-- Custom : le bâton vibre, la robe oscille latéralement.
C.witch.animations = {
  idle = function(char, t)
    Rig.defaultIdle(char, t)
    local ph = char.idlePhase
    if char.parts.weapon then
      char.parts.weapon.rot = char.parts.weapon.rot + math.sin(t * 0.06 + ph) * 0.04
    end
    if char.parts.torso then
      char.parts.torso.rot = math.sin(t * 0.03 + ph) * 0.015
    end
    return { rootDx = 0, rootDy = math.sin(t * 0.04 + ph) * 1 }
  end,
}

-- ─────────────────────────────── DÉMON ───────────────────────────────
-- Pas d'arme : armFront sert de griffe (l'attaque par défaut l'abat).
C.demon = {
  name = "DEMON",
  parts = {
    head = { grid = {
      "KK     KK",
      "KDK   KDK",
      "KDDK KDDK",
      "KDDDDDDDD",
      "KDoTKToDK",
      "KDDoooDDK",
      "KdoTToodK",
      "KDDoooDDK",
      " KKKKKKK ",
    }, pivot = { x = 4, y = 8 } },
    torso = { grid = {
      " KKKKKK ",
      "KDDrrDDK",
      "KDrrrrDK",
      "KDoooooK",
      "KDDDDDDK",
      "KDoooDDK",
      " KKKKKK ",
    }, pivot = { x = 3, y = 6 } },
    armFront = { grid = { "KDK", "KDK", "KDK", "KDK", "KKK", "KoK", "KoK", "KKK" }, pivot = { x = 1, y = 0 } },
    armBack = { grid = { "KDK", "KDK", "KDK", "KDK", "KKK", "KoK", "KKK" }, pivot = { x = 1, y = 0 } },
    legs = { grid = {
      "KDDK KDDK",
      "KDDK KDDK",
      "KDoK KDoK",
      "KooK KooK",
      "KKKK KKKK",
    }, pivot = { x = 4, y = 0 } },
  },
  rig = {
    { part = "legs", at = { 0, -5 } },
    { part = "armBack", at = { -2, -10 } },
    { part = "torso", at = { 0, -5 } },
    { part = "head", parent = "torso", at = { 3, 0 } },
    { part = "armFront", parent = "torso", at = { 6, 1 } },
  },
  idlePose = { armFront = 0, armBack = 0 },
}

return C
