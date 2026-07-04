#!/usr/bin/env node
// Saturation-detection + booster-query generator.
//
// Google Maps caps a search at ~120 results. After a base pass over the parish
// list (`restaurants <parish>`), any parish whose search returned at/near that
// cap was undercounted. This script mines the base-pass log for those, and
// emits category-diversified booster queries (`café <parish>`, `petiscos
// <parish>`, …) whose union breaks past the cap on a second pass.
//
// Usage:
//   node gen-booster-queries.mjs <base-pass.log> [options]
//     --threshold N   count at/above N counts as saturated   (default 100)
//     --base WORD     leading base term to strip off a query (default "restaurants")
//     --cats FILE     newline-separated category terms        (default: built-in PT list)
//     --out FILE      output query file                        (default booster-queries.txt)
//
// The base pass MUST run with a high enough -depth to actually scroll to ~120,
// or saturation can't be observed. Parse target line (emitted by GmapJob):
//   `<N> places found for query "<query>"`

import { readFileSync, writeFileSync, createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

const args = process.argv.slice(2);
const logPath = args.find((a) => !a.startsWith('--'));
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i !== -1 && args[i + 1] ? args[i + 1] : def;
};

if (!logPath) {
  console.error('Usage: node gen-booster-queries.mjs <base-pass.log> [--threshold 100] [--base restaurants] [--cats file] [--out booster-queries.txt]');
  process.exit(1);
}

const THRESHOLD = Number(opt('threshold', 100));
const BASE_TERM = opt('base', 'restaurants');
const OUT = opt('out', 'booster-queries.txt');

// Portuguese food-venue terms that surface *different* 120-slices than a plain
// "restaurants" search — cuisines, meal types, and PT-specific venue names.
const DEFAULT_CATS = [
  'café', 'comida', 'pastelaria', 'padaria', 'cervejaria', 'marisqueira',
  'churrasqueira', 'tasca', 'casa de pasto', 'snack-bar', 'petiscos',
  'pizzaria', 'hamburgueria', 'sushi', 'restaurante chinês', 'restaurante indiano',
  'restaurante italiano', 'restaurante japonês', 'kebab', 'gelataria',
  'vegetariano', 'vegano', 'brunch', 'take away',
];
const cats = opt('cats', null)
  ? readFileSync(opt('cats'), 'utf8').split(/\r?\n/).map((s) => s.trim()).filter(Boolean)
  : DEFAULT_CATS;

// --- Mine the log: max count seen per query (retries can emit a query twice) --
const counts = new Map();
const LINE_RE = /^(\d+) places found for query "(.+)"$/;

const rl = createInterface({ input: createReadStream(logPath), crlfDelay: Infinity });
for await (const line of rl) {
  let msg = line;
  try {
    const o = JSON.parse(line);
    if (typeof o.message === 'string') msg = o.message; // scrapemate JSON logs
  } catch {
    // plain text line — use as-is
  }
  const m = msg.match(LINE_RE);
  if (!m) continue;
  const count = Number(m[1]);
  const query = m[2];
  if (!counts.has(query) || counts.get(query) < count) counts.set(query, count);
}

// --- Flag saturated queries, extract the location, emit boosters -------------
const stripBase = (q) => {
  const prefix = `${BASE_TERM} `;
  return q.toLowerCase().startsWith(prefix.toLowerCase()) ? q.slice(prefix.length).trim() : q.trim();
};

const saturated = [...counts.entries()]
  .filter(([, c]) => c >= THRESHOLD)
  .map(([q, c]) => ({ location: stripBase(q), count: c }))
  .filter((x) => x.location);

const out = new Set();
for (const { location } of saturated) {
  for (const cat of cats) out.add(`${cat} ${location}`);
}

writeFileSync(OUT, [...out].join('\n') + (out.size ? '\n' : ''));

const total = counts.size;
console.log(`Parsed ${total} query results from ${logPath}`);
console.log(`Saturated (>= ${THRESHOLD}): ${saturated.length} parishes`);
if (saturated.length) {
  const top = saturated.sort((a, b) => b.count - a.count).slice(0, 10);
  console.log('Top saturated:');
  for (const s of top) console.log(`  ${String(s.count).padStart(3)}  ${s.location}`);
}
console.log(`Wrote ${out.size} booster queries (${saturated.length} parishes x ${cats.length} categories) -> ${OUT}`);
