# Scraper online setup — actionable checklist

Companion to [DEPLOY-ONLINE.md](DEPLOY-ONLINE.md) (the "why"). This is the "what to do", verified
against the code in this repo on 2026-08-14.

## Where things stand

- Local run: **13 of 308 chunks done** (`restaurants/out/*.done`), stopped mid-chunk-013 on
  2026-07-24. That's ~4% of Portugal after a month of stop/resume — the reason to go online.
- `~/.gmapssaas` holds only a `known_hosts` file → **never provisioned**. Clean slate.
- Docker Desktop is installed but **the engine is not running**. Go 1.26.4 present.
- The prebuilt image `ghcr.io/gosom/google-maps-scraper-saas:latest` is **publicly pullable**
  (anonymous ghcr manifest fetch returns 200) — you do NOT need the build-your-own path.

## Architecture (this is not one server)

`provision` builds the **app server**: admin dashboard + Postgres + River job queue. It does not
scrape. Scraping happens on **worker VMs** you add afterwards from the dashboard, each provisioned
via cloud-init with its own `.env`. So the real cost is **2 VMs minimum**, ~€8/mo, not €4.

    provision wizard  →  app server (dashboard + queue)  →  add worker VM(s)  →  workers pull jobs

## What only YOU can do

| # | Item | Notes |
|---|---|---|
| 1 | **Start Docker Desktop** | The wizard runs in a container. Currently not running. |
| 2 | **Hetzner Cloud account** → project → Security → API Tokens → **Read & Write** | Needed twice: once by the wizard, once pasted into the dashboard so it can spawn workers. Same token is fine. |
| 3 | **Residential proxy plan + payment** | DataImpulse ~$1/GB or IPRoyal ~$1.75/GB. Buy a small amount and test before committing. |
| 4 | **Save the printed dashboard URL + admin password** | Shown once at the end of the wizard. |

Everything below this line I can drive for you once you hand over the URL + login (or the SSH key
under `~/.gmapssaas`).

## Step 1 — Run the wizard

The repo's `PROVISION` script is POSIX sh (`id -u`, `/var/run/docker.sock`), so run it from **Git
Bash**, not PowerShell:

```bash
cd /c/Users/andre/Downloads/google-maps-scraper && ./PROVISION
```

If the `--user $(id -u):$(id -g)` line misbehaves on Windows, run the container directly instead:

```bash
docker run --rm -it -e HOME="$HOME" -e XDG_CACHE_HOME=/tmp/.cache -e GMAPSSAAS_IMAGE="ghcr.io/gosom/google-maps-scraper-saas:latest" -v "$HOME/.gmapssaas:$HOME/.gmapssaas" -v /var/run/docker.sock:/var/run/docker.sock -v "$HOME/.ssh:$HOME/.ssh:ro" ghcr.io/gosom/google-maps-scraper-saas:latest provision
```

Setting `GMAPSSAAS_IMAGE` skips the build-and-push prompt entirely (`provision.go:81`).

Prompts, in order: **Hetzner Cloud** → paste token → location (`nbg1`/`fsn1`/`hel1`) → server type
(list is sorted cheapest-first; **CX22** is fine for the app server) → **Create a new database**.
It then provisions, migrates, generates keys, deploys, and prints the URL + admin password.

State lives in `~/.gmapssaas` — Ctrl-C is safe, a re-run resumes.

## Step 2 — Add a worker (this is where proxies go)

Log into the dashboard → **Workers**:

1. Paste the Hetzner token into the provider-token box and save.
2. **Add worker** — the form fields are provider / name / region / size / **Worker Containers** /
   Max Jobs Per Cycle / Fast Mode / **Proxies (comma-separated)**.
3. Proxies go in as `http://user:pass@host:port, http://user:pass@host:port` — they are baked into
   the worker's `/opt/gms-worker/.env` as `PROXIES=`.

> **Set Worker Containers to 2–4, not the default 8.** The default will OOM a 4 GB box. This repo's
> own history: the scraper reuses one Chrome per worker without recycling it, and a single
> `chrome.exe` reached **7.3 GB** after 789 places. That's why the local run sits at `-c 2`.
> CX32 (8 GB) can take 4–6.

There is no global proxy setting — proxies are per-worker, at creation time. To change providers,
add a new worker and delete the old one.

## Step 3 — Seed the 3,074 parishes via the API

Don't paste queries by hand. Create an API key in the dashboard, then POST each parish to
`/api/v1/scrape`:

```bash
curl -sS -X POST "https://$APP_HOST/api/v1/scrape" -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' -d '{"keyword":"restaurantes em Alvalade Lisboa","lang":"pt","max_depth":20,"extra_reviews":true}'
```

Returns `202 {"job_id":"...","status":"pending"}`. Poll `/api/v1/jobs/{id}`, list with
`/api/v1/jobs?state=running`, download results per job.

**Known gap:** `ScrapeJobArgs` (`rqueue/rqueue.go:87`) exposes keyword, lang, max_depth, email,
geo_coordinates, zoom, radius, fast_mode, extra_reviews, timeout — but **not** `max_reviews` or
`review_sort`. The SaaS worker never calls `WithMaxReviews`/`WithReviewSort` (`rqueue/rqueue.go:206-224`).
The defaults it falls back to are **200 reviews, sorted newest** (`gmaps/reviews.go:474`, `reviewSortCode`
falls through to newest). That is 2× the review depth of the local run (`-max-reviews 100`), so
expect roughly 2× the per-place time and proxy bandwidth. If you want 100, it needs a small patch to
thread the option through — say the word.

## Step 4 — Ingest into NomNom

Export job results, then feed them through the verified pipeline:
`nomnom/scripts/import-restaurants-from-json.mjs`. Ingest is idempotent (re-runs update, not
duplicate) and was verified end-to-end on 30 real places on 2026-07-22.

## Cost

| | |
|---|---|
| App server CX22 | ~€4/mo |
| Worker CX22 (or CX32 ~€8) | ~€4–8/mo |
| Proxies | ~$60–150 one-time for the country at $1/GB |
| **Total** | **~€8–12/mo + ~$100 one-time** |

Compare: Apify managed with this review depth is ~$1,350+.
