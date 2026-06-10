#!/usr/bin/env node
/**
 * Bridge: google-maps-scraper JSON output → JustNomNom /api/restaurants/ingest
 *
 * Usage:
 *   node ingest-bridge.js results.json [options]
 *
 * Options:
 *   --url <base>      Base URL of the JustNomNom app  (env: INGEST_URL)
 *   --secret <token>  RESTAURANT_INGEST_SECRET value  (env: INGEST_SECRET)
 *   --delay <ms>      Milliseconds between requests   (default: 62000 ≈ 60/hr limit)
 *   --dry-run         Parse + validate only, no HTTP calls
 *   --out <file>      Write per-entry results to JSON (default: ingest-results.json)
 *
 * Example:
 *   INGEST_URL=http://localhost:3000 INGEST_SECRET=mysecret \
 *     node ingest-bridge.js lisbon-restaurants.json --delay 2000
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);

function flag(name) {
  const i = argv.indexOf(name);
  return i !== -1 && i + 1 < argv.length ? argv[i + 1] : null;
}

const inputFile = argv.find((a) => !a.startsWith('--') && argv[argv.indexOf(a) - 1] !== '--url' && argv[argv.indexOf(a) - 1] !== '--secret' && argv[argv.indexOf(a) - 1] !== '--delay' && argv[argv.indexOf(a) - 1] !== '--out');
const BASE_URL  = (flag('--url')    || process.env.INGEST_URL    || '').replace(/\/$/, '');
const SECRET    =  flag('--secret') || process.env.INGEST_SECRET || '';
const DELAY_MS  = parseInt(flag('--delay') ?? '62000', 10);
const DRY_RUN   = argv.includes('--dry-run');
const OUT_FILE  = flag('--out') || 'ingest-results.json';

// ---------------------------------------------------------------------------
// Validate
// ---------------------------------------------------------------------------

if (!inputFile) {
  console.error('Usage: node ingest-bridge.js <results.json> [--url <base>] [--secret <token>] [--delay <ms>] [--dry-run]');
  process.exit(1);
}

if (!DRY_RUN) {
  if (!BASE_URL) {
    console.error('Error: set --url or INGEST_URL (e.g. https://yourapp.vercel.app)');
    process.exit(1);
  }
  if (!SECRET) {
    console.error('Error: set --secret or INGEST_SECRET');
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Load input
// ---------------------------------------------------------------------------

let entries;
try {
  const raw = readFileSync(resolve(inputFile), 'utf8');
  const parsed = JSON.parse(raw);
  entries = Array.isArray(parsed) ? parsed : [parsed];
} catch (e) {
  console.error(`Failed to read/parse ${inputFile}: ${e.message}`);
  process.exit(1);
}

console.log(`\nLoaded ${entries.length} entries from ${inputFile}`);
if (DRY_RUN) console.log('DRY RUN — no HTTP requests will be made');
console.log(`Endpoint : ${BASE_URL}/api/restaurants/ingest`);
console.log(`Delay    : ${DELAY_MS}ms between requests`);
const etaMins = Math.ceil((entries.length * DELAY_MS) / 60_000);
console.log(`ETA      : ~${etaMins} minute${etaMins !== 1 ? 's' : ''}\n`);

// ---------------------------------------------------------------------------
// Ingest loop
// ---------------------------------------------------------------------------

const ENDPOINT = `${BASE_URL}/api/restaurants/ingest`;

const results = [];
const summary = { created: 0, updated: 0, skipped: 0, failed: 0 };

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function postWithRetry(entry, attempt = 1) {
  if (DRY_RUN) {
    const id = entry.place_id || entry.title || '?';
    return { ok: true, status: 200, body: { dry_run: true, id } };
  }

  let res;
  try {
    res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${SECRET}`,
      },
      body: JSON.stringify(entry),
    });
  } catch (e) {
    return { ok: false, status: 0, body: { error: e.message } };
  }

  if (res.status === 429 && attempt <= 3) {
    const wait = DELAY_MS * attempt * 2;
    console.log(`  [429] Rate limited — waiting ${wait / 1000}s before retry ${attempt}/3`);
    await sleep(wait);
    return postWithRetry(entry, attempt + 1);
  }

  let body;
  try {
    body = await res.json();
  } catch {
    body = { error: 'non-json response' };
  }

  return { ok: res.ok, status: res.status, body };
}

for (let i = 0; i < entries.length; i++) {
  const entry = entries[i];
  const label = entry.title || entry.name || `entry[${i}]`;
  const placeId = entry.place_id || '—';

  process.stdout.write(`[${i + 1}/${entries.length}] ${label} (${placeId}) ... `);

  const { ok, status, body } = await postWithRetry(entry);

  let outcome;
  if (ok || DRY_RUN) {
    if (body.created) {
      outcome = 'created';
      summary.created++;
    } else if (body.updated || body.dry_run) {
      outcome = body.dry_run ? 'dry-run' : 'updated';
      summary.updated++;
    } else {
      outcome = 'ok';
      summary.updated++;
    }
    console.log(`✓ ${outcome}`);
  } else {
    outcome = 'failed';
    summary.failed++;
    const reason = body?.error || body?.message || status;
    if (status === 422) {
      outcome = 'skipped';
      summary.failed--;
      summary.skipped++;
      console.log(`⚠ skipped — ${reason}`);
    } else {
      console.log(`✗ ${status} — ${reason}`);
    }
  }

  results.push({
    index: i,
    place_id: placeId,
    title: label,
    outcome,
    status,
    body,
  });

  // Delay between requests (skip after the last one)
  if (i < entries.length - 1 && !DRY_RUN) {
    await sleep(DELAY_MS);
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

console.log('\n── Summary ────────────────────────────');
console.log(`  Created : ${summary.created}`);
console.log(`  Updated : ${summary.updated}`);
console.log(`  Skipped : ${summary.skipped}  (no municipality boundary for coords)`);
console.log(`  Failed  : ${summary.failed}`);
console.log(`  Total   : ${entries.length}`);
console.log('───────────────────────────────────────\n');

writeFileSync(OUT_FILE, JSON.stringify(results, null, 2));
console.log(`Results written to ${OUT_FILE}`);
