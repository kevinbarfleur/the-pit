#!/usr/bin/env node
// Exporte les pixels de docs/generation/generateur-abominations.html vers une
// table Lua. Le rendu jeu doit rester aligne sur ce generateur, pas sur un
// redraw manuel dans src/render/.

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const ROOT = path.resolve(__dirname, "..");
const SOURCE = path.join(ROOT, "docs/generation/generateur-abominations.html");
const TARGET = path.join(ROOT, "src/data/abomination_assets.lua");

const GAME_IDS = {
  leviathan: {
    boss: "abom_leviathan_boss",
    generals: ["abom_lev_spawn", "abom_lev_carapace", "abom_lev_floater"],
  },
  regard: {
    boss: "abom_regard_boss",
    generals: ["abom_eye_watcher", "abom_eye_tear", "abom_eye_crawler"],
  },
  ossuaire: {
    boss: "abom_ossuary_boss",
    generals: ["abom_bone_reaper", "abom_bone_crawler", "abom_bone_guard"],
  },
  kraken: {
    boss: "abom_kraken_boss",
    generals: ["abom_krak_strangler", "abom_krak_swimmer", "abom_krak_angler"],
  },
  idole: {
    boss: "abom_idol_boss",
    generals: ["abom_idol_knight", "abom_idol_seraph", "abom_idol_reliquary"],
  },
  ruche: {
    boss: "abom_broodmother_boss",
    generals: ["abom_hive_soldier", "abom_hive_winged", "abom_hive_burrower"],
  },
  brasier: {
    boss: "abom_emberlord_boss",
    generals: ["abom_cinder_hound", "abom_ash_wraith", "abom_magma_brute"],
  },
  floraison: {
    boss: "abom_mycelium_boss",
    generals: ["abom_spore_walker", "abom_cap_beast", "abom_rot_crawler"],
  },
  devoreur: {
    boss: "abom_devourer_boss",
    generals: ["abom_gnasher", "abom_grasper", "abom_void_mote"],
  },
  vermine: {
    boss: "abom_greatworm_boss",
    generals: ["abom_lamprey", "abom_grub", "abom_burrow_tick"],
  },
};

function extractScript(html) {
  const match = html.match(/<script>([\s\S]*?)<\/script>/);
  if (!match) throw new Error("No <script> block found in abomination generator");
  const script = match[1];
  const cut = script.indexOf("/* ===================== INTERFACE");
  if (cut < 0) throw new Error("Unable to find interface marker in generator");
  return script.slice(0, cut);
}

function fnv1a(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

function runGenerator() {
  const html = fs.readFileSync(SOURCE, "utf8");
  const setup = extractScript(html);
  const runner = `${setup}
  function gen(archName,palArr,treat,seed,gridN,base){
    var rnd=mulberry32(seed>>>0);
    var p=palArr[Math.floor(rnd()*palArr.length)];
    var g=makeGrid(gridN,gridN);
    var A=ARCH[archName](g,rnd,p);
    treat(g,rnd,p,A);
    outline(g,p.out);
    return {g:g,A:A,p:p,prof:PROF[archName]||{},fl:!!A.float,base:base};
  }
  var GAME_IDS = ${JSON.stringify(GAME_IDS)};
  var OUT = { species: [], generalToSpecies: {} };
  for (var bi=0; bi<BOSSES.length; bi++) {
    var sp = BOSSES[bi];
    var ids = GAME_IDS[sp.key];
    if (!ids) throw new Error("Missing game ids for " + sp.key);
    var master = (${fnv1a.toString()})("the-pit-abomination:" + sp.key) >>> 0;
    var entry = {
      key: sp.key,
      name: sp.name,
      accent: sp.accent,
      masterSeed: master,
      boss: null,
      generals: []
    };
    var bossCard = gen(sp.boss, sp.pals, sp.treat, master, 96, 90);
    entry.boss = {
      id: ids.boss,
      arch: sp.boss,
      seed: master,
      w: bossCard.g.w,
      h: bossCard.g.h,
      base: bossCard.base,
      float: bossCard.fl,
      data: bossCard.g.data
    };
    for (var gi=0; gi<sp.generals.length; gi++) {
      var seed = (master + (gi + 1) * 0x9E3779B9) >>> 0;
      var card = gen(sp.generals[gi], sp.pals, sp.treat, seed, 48, 45);
      var genEntry = {
        id: ids.generals[gi],
        arch: sp.generals[gi],
        name: sp.gnames[gi],
        seed: seed,
        w: card.g.w,
        h: card.g.h,
        base: card.base,
        float: card.fl,
        data: card.g.data
      };
      entry.generals.push(genEntry);
      OUT.generalToSpecies[genEntry.id] = sp.key;
    }
    OUT.species.push(entry);
  }
  globalThis.__ABOMINATION_EXPORT__ = OUT;
})();`;

  const context = { console };
  vm.runInNewContext(runner, context, { filename: SOURCE });
  return context.__ABOMINATION_EXPORT__;
}

const CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

function encodeAsset(asset) {
  const seen = new Map();
  const palette = {};
  const rows = [];
  for (const col of asset.data) {
    if (col && !seen.has(col)) {
      const ch = CHARS[seen.size];
      if (!ch) throw new Error(`Too many colors in ${asset.id}`);
      seen.set(col, ch);
      palette[ch] = col;
    }
  }
  for (let y = 0; y < asset.h; y++) {
    let row = "";
    for (let x = 0; x < asset.w; x++) {
      const col = asset.data[y * asset.w + x];
      row += col ? seen.get(col) : ".";
    }
    rows.push(row);
  }
  return { ...asset, palette, rows, data: undefined };
}

function hexNumber(s) {
  return `0x${s.replace("#", "").toLowerCase()}`;
}

function q(s) {
  return JSON.stringify(String(s));
}

function writeAsset(lines, asset, indent) {
  const pad = " ".repeat(indent);
  lines.push(`${pad}{`);
  lines.push(`${pad}  id = ${q(asset.id)},`);
  lines.push(`${pad}  arch = ${q(asset.arch)},`);
  lines.push(`${pad}  name = ${q(asset.name || "")},`);
  lines.push(`${pad}  seed = ${asset.seed >>> 0},`);
  lines.push(`${pad}  w = ${asset.w}, h = ${asset.h}, base = ${asset.base}, float = ${asset.float ? "true" : "false"},`);
  lines.push(`${pad}  palette = {`);
  for (const ch of Object.keys(asset.palette)) {
    lines.push(`${pad}    [${q(ch)}] = ${hexNumber(asset.palette[ch])},`);
  }
  lines.push(`${pad}  },`);
  lines.push(`${pad}  rows = {`);
  for (const row of asset.rows) lines.push(`${pad}    ${q(row)},`);
  lines.push(`${pad}  },`);
  lines.push(`${pad}},`);
}

function emitLua(out) {
  const lines = [];
  lines.push("-- src/data/abomination_assets.lua");
  lines.push("-- GENERATED FILE. Source: docs/generation/generateur-abominations.html");
  lines.push("-- Regenerate with: node tools/export_abomination_assets.js");
  lines.push("");
  lines.push("return {");
  lines.push("  source = \"docs/generation/generateur-abominations.html\",");
  lines.push("  species = {");
  for (const sp of out.species) {
    const boss = encodeAsset(sp.boss);
    const generals = sp.generals.map(encodeAsset);
    lines.push(`    [${q(sp.key)}] = {`);
    lines.push(`      key = ${q(sp.key)}, name = ${q(sp.name)}, accent = ${q(sp.accent)}, masterSeed = ${sp.masterSeed >>> 0},`);
    lines.push("      boss =");
    writeAsset(lines, boss, 8);
    lines.push("      generals = {");
    for (const gen of generals) {
      lines.push(`        [${q(gen.id)}] =`);
      writeAsset(lines, gen, 10);
    }
    lines.push("      },");
    lines.push("    },");
  }
  lines.push("  },");
  lines.push("  generalToSpecies = {");
  for (const [id, key] of Object.entries(out.generalToSpecies).sort()) {
    lines.push(`    [${q(id)}] = ${q(key)},`);
  }
  lines.push("  },");
  lines.push("}");
  lines.push("");
  return lines.join("\n");
}

const out = runGenerator();
fs.writeFileSync(TARGET, emitLua(out));
console.log(`wrote ${path.relative(ROOT, TARGET)} from ${path.relative(ROOT, SOURCE)}`);
