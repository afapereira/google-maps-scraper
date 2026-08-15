# Run the scraper online, 24/7, with a dashboard — low budget

Goal: the Portugal restaurant scrape runs on a cheap cloud server that never sleeps,
survives reboots, and gives you (and Claude) a **web dashboard** to watch progress —
instead of babysitting stop/resume on your PC.

The scraper has this built in. `gmapssaas provision` is a guided wizard that provisions
a server, a Postgres job queue (resumable), and a web admin dashboard with TLS, then
prints a URL + login. You only supply a cloud API token and (for the IP) residential proxies.

---

## Cost summary

| Piece | Choice | Cost |
|---|---|---|
| Server | **Hetzner** CX22 (2 vCPU / 4 GB) or CX32 (4 vCPU / 8 GB) | **~€4–8/mo** |
| Postgres queue | created by the wizard on the same server | $0 |
| Dashboard + TLS | deployed by the wizard | $0 |
| **Residential proxies** (the only unavoidable spend — Google blocks datacenter IPs) | IPRoyal / Webshare | see below |

Proxies — the only unavoidable spend, priced by GB of traffic (verified Aug 2026):
- **Cheapest: DataImpulse ~$1/GB**, pay-as-you-go, traffic never expires, no subscription.
  All of Portugal ≈ 60–150 GB (images off) → **~$60–150 one-time**, then done.
- **Proven fallback: IPRoyal "royal residential" ~$1.75/GB** (non-expiring). Slightly pricier but a
  well-established pool for Google Maps → ~$105–260 for the country.
- Buy a small amount first and test for blocks before committing to a provider.

**Realistic all-in: ~€4/mo server + ~$60–150 ONE-TIME proxies for the whole country.**

Alternative to Hetzner: **DigitalOcean App Platform** (wizard supports it) — pricier, zero server admin.
**Oracle Always-Free** is NOT the deal it was — as of June 2026 the free ARM tier was halved to
2 OCPU / 12 GB (still enough, but finicky quota) — so Hetzner's ~€4 is the cleaner pick.

---

## Self-host vs. managed (why self-host wins for THIS project)

A managed API (Apify) removes all setup, but the deep reviews you want make it far pricier:
- Apify **places**: ~$1.50/1,000 → ~150k places ≈ **~$225** (cheap!).
- Apify **reviews**: ~$0.25–0.40/1,000 reviews. But 150k places × ~25 reviews = ~3.75M reviews →
  **~$1,100–1,500**. (Deep 100-review pulls would be ~$4,000+.)
- Managed total with your review depth: **~$1,350+**.

Self-hosting: **~$110–160 total** (Hetzner ~€4/mo × ~1–2 months + ~$100–150 one-time proxies).
→ Self-host is ~10× cheaper *specifically because* you want millions of reviews, and proxy bandwidth
($1/GB) is far cheaper than per-review managed pricing. Managed only wins if you drop deep reviews.

## Prerequisites (one-time, ~15 min)

1. **A Hetzner Cloud account** → create a project → **Security → API Tokens → Generate** (Read & Write).
   Copy the token. (DigitalOcean: create a personal access token instead.)
2. **A machine with Docker** to *run the wizard from* — your Windows PC with Docker Desktop is fine.
   (The wizard runs in a container and talks to Hetzner's API; it does NOT need to run on the server.)
3. **A residential proxy plan** (IPRoyal or Webshare). Get the proxy list / rotating-gateway
   credentials in the form `http://user:pass@host:port` (one per line if a list).

---

## Part A — Provision the server + dashboard (the wizard)

From your PC (PowerShell or Git Bash), in the scraper repo folder, run the provisioner. Two ways:

**A1. Prebuilt image (simplest, if you have access to the SaaS image):**
```bash
# the repo's PROVISION script wraps this; it launches the wizard in Docker
docker run --rm -it \
  -e HOME="$HOME" -e XDG_CACHE_HOME=/tmp/.cache \
  -e GMAPSSAAS_IMAGE="ghcr.io/gosom/google-maps-scraper-saas:latest" \
  -v "$HOME/.gmapssaas:$HOME/.gmapssaas" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/.ssh:$HOME/.ssh:ro" \
  ghcr.io/gosom/google-maps-scraper-saas:latest provision
```

**A2. Build your own image from source** (if the prebuilt SaaS image is gated). The wizard offers
"build and push a new image" — point it at your own `ghcr.io/<your-user>/gmapssaas:latest` with a
GitHub PAT (write:packages). Everything else is identical.

Then follow the prompts:
1. **Where to install?** → `Hetzner Cloud`
2. Paste your **Hetzner API token** → it validates instantly.
3. **Server location** → pick one near Portugal (e.g. `nbg1`/`fsn1` Germany, or `hel1`).
4. **Server type** → the list is **sorted cheapest-first with $/mo shown**. Pick **CX22** (~€4) to start,
   or **CX32** (~€8, 8 GB) if you want more workers.
5. **Database** → `Create a new database` (it builds Postgres on the box).
6. The wizard then, automatically: sets up the VM, runs migrations, generates encryption keys +
   SSH keys, deploys the app, and creates an admin user.
7. At the end it prints:
   ```
   Application URL:  https://<server-ip-or-domain>
   Username:         admin
   Password:         <generated>
   ```
   **Save these.** That URL is your dashboard. (State is saved under `~/.gmapssaas`, so a re-run
   resumes; it's safe to Ctrl-C and re-run.)

> TLS note: with no domain it uses a self-signed cert (browser warning — fine for you/Claude).
> To get a clean `https://` with no warning, point a cheap domain/subdomain's A-record at the
> server IP and re-run with that domain — the wizard provisions a real cert.

---

## Part B — Add a worker, with residential proxies

**Corrected 2026-08-14 after reading the code:** there is no global proxy setting, and the wizard
does not create anything that scrapes. `provision` builds the **app server** (dashboard + Postgres
+ River queue) only. Scraping runs on separate **worker VMs** you add from the dashboard →
**Workers**, and proxies are a field on the add-worker form (`admin/templates/workers.html:96`),
baked into that worker's `/opt/gms-worker/.env` as `PROXIES=` (comma-separated).

So: budget for **2 VMs**, not one. To rotate proxy providers, add a new worker and delete the old.

Without proxies the jobs return captchas/empty results.

Set **Worker Containers to 2–4**, not the form's default of 8 — see the Chrome-bloat gotcha below.

---

## Part C — Seed the Portugal scrape + send results to NomNom

1. In the dashboard → **Jobs → New job**, create scrape jobs from the parish query list
   (`restaurants-by-place.txt`, the same 3,074 parishes we've been using). You can paste queries
   or upload the list. Set per-job: `-extra-reviews`, `review-sort newest`, `max-reviews 100`,
   depth 20, and a modest concurrency (start `c=4` on CX22, `c=6–8` on CX32).
2. **Getting data into the app** — two options:
   - **Export + feed:** let the queue fill, export the results JSON from the dashboard/API, then run
     the existing feeder (`justnomnom/scripts/import-restaurants-from-json.mjs`) pointed at your
     deployed ingest endpoint. Same pipeline we just verified.
   - **Direct webhook (if wired):** point the scraper's result webhook at
     `https://<your-app>/api/restaurants/ingest` with the `RESTAURANT_INGEST_SECRET`. (Confirm the
     SaaS build supports a per-job webhook; if not, use export + feed.)
3. The Postgres queue means work is **resumable** — reboot the server and it picks up where it left off.
   No more "died between sessions."

---

## Part D — How you (and Claude) check on it

- **You:** open the **Application URL** in a browser, log in → the dashboard shows jobs, workers,
  progress, and a live terminal.
- **Claude:** I can monitor it by (a) `WebFetch`/curl to the dashboard or its JSON API, or (b) `ssh`
  into the server (the wizard generated a key under `~/.gmapssaas`) to tail logs and counts. Give me
  the URL + login (or the SSH key path) and I'll watch it and report the same way I do locally —
  minus the babysitting, since it won't die between sessions.

---

## Gotchas / notes

- **Proxies are mandatory** on any cloud host — budget for them; the server itself is the cheap part.
- **Prebuilt SaaS image is PUBLIC** (verified 2026-08-14: anonymous ghcr manifest fetch for
  `gosom/google-maps-scraper-saas:latest` returns HTTP 200). The build-your-own path (A2) is a
  fallback you almost certainly won't need.
- **Sizing:** CX22 (4 GB) runs the app server fine. Workers are the memory-hungry side — the
  scraper reuses one Chrome per worker container without recycling it (a single chrome.exe hit
  **7.3 GB** after 789 places locally), so **2–4 containers on a 4 GB worker, 4–6 on CX32**. The
  add-worker form defaults to 8; that will OOM a CX22.
- **Review depth is not settable via the API.** `ScrapeJobArgs` has no `max_reviews`/`review_sort`;
  the SaaS worker falls back to **200 reviews, newest-first**, vs the local run's 100. Expect ~2×
  the per-place time and proxy bandwidth unless the option is threaded through.
- **Self-signed cert** → browser warning is expected; add a domain for a clean cert if it bugs you.
- Keep `~/.gmapssaas` (the state dir) — it holds keys and lets you re-run/redeploy/teardown.
