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
}
