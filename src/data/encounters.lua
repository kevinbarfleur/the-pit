-- src/data/encounters.lua
-- Équipes adverses pré-construites (l'IA de seed du cold-start, cf. design async §1.7).
-- Chaque unité : un id + une case (col,row) ; col 0..2 (front = plus grand col, proche du
-- centre), row 0..2 (haut/milieu/bas). La phase de combat les convertit en positions miroir.
-- À terme ces compos seront remplacées par des SNAPSHOTS de vrais joueurs ; en attendant,
-- elles amorcent la boucle. On les fait monter en danger pour donner une courbe.

return {
  {
    key = "fallen_patrol", -- nom affiché : src/i18n/en.lua (encounter.fallen_patrol.name)
    units = {
      { id = "skeleton", col = 1, row = 1 },
      { id = "bandit", col = 2, row = 0 },
      { id = "marauder", col = 2, row = 2 },
    },
  },
  {
    key = "drowned_choir",
    units = {
      { id = "witch", col = 1, row = 1 },
      { id = "templar", col = 2, row = 1 },
      { id = "skeleton", col = 2, row = 0 },
      { id = "skeleton", col = 2, row = 2 },
    },
  },
  {
    key = "brood",
    units = {
      { id = "demon", col = 2, row = 1 },
      { id = "witch", col = 1, row = 0 },
      { id = "bandit", col = 1, row = 2 },
      { id = "marauder", col = 2, row = 0 },
      { id = "skeleton", col = 2, row = 2 },
    },
  },
  -- ── Escalade tardive (décision courbe 2026-06-21, cf. the-pit-balance-diagnosis). Les grants rendent le
  -- board joueur PRÉVISIBLE (3->9 sur rounds 1-7) : on fait suivre l'ennemi cold-start en TAILLE puis en
  -- NIVEAU (champ `level`, appliqué via LEVEL_MULT dans buildRightComp + un bump de round au-delà de la table).
  -- Les unités peuvent porter `level` (2-3) pour une pression de fin de Puits. pickEncounter grimpe l'index. ──
  {
    key = "gorge_pack", -- 6 : mur frontal + bruisers + un carry poison derrière
    units = {
      { id = "templar", col = 2, row = 1 },
      { id = "marauder", col = 2, row = 0 }, { id = "demon", col = 2, row = 2 },
      { id = "bandit", col = 1, row = 0 }, { id = "skeleton", col = 1, row = 2 },
      { id = "witch", col = 0, row = 1 },
    },
  },
  {
    key = "drowned_legion", -- 7 : taunt en façade, horde de DoT mixtes derrière
    units = {
      { id = "gravewarden", col = 2, row = 1 },
      { id = "demon", col = 2, row = 0 }, { id = "marauder", col = 2, row = 2 },
      { id = "corruptor", col = 1, row = 0 }, { id = "razorkin", col = 1, row = 2 },
      { id = "witch", col = 0, row = 0 }, { id = "emberling", col = 0, row = 2 },
    },
  },
  {
    key = "pit_sovereign", -- 9 : board plein, noyau front leveled (le mur de fin de Puits)
    units = {
      { id = "gravewarden", col = 2, row = 1, level = 2 },
      { id = "templar", col = 2, row = 0, level = 2 }, { id = "demon", col = 2, row = 2 },
      { id = "corruptor", col = 1, row = 0 }, { id = "emberling", col = 1, row = 1 }, { id = "razorkin", col = 1, row = 2 },
      { id = "witch", col = 0, row = 0 }, { id = "rot_hound", col = 0, row = 1 }, { id = "stormcaller", col = 0, row = 2 },
    },
  },
}
