package gmaps

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gosom/scrapemate"

	"github.com/gosom/google-maps-scraper/exiter"
)

type PlaceJobOptions func(*PlaceJob)

type PlaceJob struct {
	scrapemate.Job

	UsageInResults          bool
	ExtractEmail            bool
	ExitMonitor             exiter.Exiter
	ExtractExtraReviews     bool
	RestaurantsOnly         bool
	ReviewSort              string
	MaxReviews              int
	WriterManagedCompletion bool
}

func NewPlaceJob(parentID, langCode, u string, extractEmail, extraExtraReviews bool, opts ...PlaceJobOptions) *PlaceJob {
	const (
		defaultPrio       = scrapemate.PriorityMedium
		defaultMaxRetries = 3
	)

	job := PlaceJob{
		Job: scrapemate.Job{
			ID:         uuid.New().String(),
			ParentID:   parentID,
			Method:     "GET",
			URL:        u,
			URLParams:  map[string]string{"hl": langCode},
			MaxRetries: defaultMaxRetries,
			Priority:   defaultPrio,
		},
	}

	job.UsageInResults = true
	job.ExtractEmail = extractEmail
	job.ExtractExtraReviews = extraExtraReviews

	for _, opt := range opts {
		opt(&job)
	}

	return &job
}

func WithPlaceJobExitMonitor(exitMonitor exiter.Exiter) PlaceJobOptions {
	return func(j *PlaceJob) {
		j.ExitMonitor = exitMonitor
	}
}

func WithPlaceJobWriterManagedCompletion() PlaceJobOptions {
	return func(j *PlaceJob) {
		j.WriterManagedCompletion = true
	}
}

func WithPlaceJobRestaurantsOnly(v bool) PlaceJobOptions {
	return func(j *PlaceJob) {
		j.RestaurantsOnly = v
	}
}

func WithPlaceJobReviewSort(s string) PlaceJobOptions {
	return func(j *PlaceJob) {
		j.ReviewSort = s
	}
}

func WithPlaceJobMaxReviews(n int) PlaceJobOptions {
	return func(j *PlaceJob) {
		j.MaxReviews = n
	}
}

func (j *PlaceJob) ProcessOnFetchError() bool {
	return true
}

// ErrGoogleBlocked indicates Google served a captcha/"unusual traffic" page
// instead of real content. Returning it as the job error makes scrapemate
// retry the job; the jshttp fetcher recycles the browser on any failed job,
// so the retry runs through the NEXT proxy in the pool.
var ErrGoogleBlocked = fmt.Errorf("google block page detected (captcha/unusual traffic)")

// isGoogleBlockPage detects Google's interstitial block pages: the /sorry/
// redirect, the reCAPTCHA form, or the "unusual traffic" notice.
func isGoogleBlockPage(page scrapemate.BrowserPage) bool {
	if page == nil {
		return false
	}

	if strings.Contains(page.URL(), "/sorry/") {
		return true
	}

	res, err := page.Eval(`() => {
		try {
			if (location.pathname.startsWith('/sorry')) return true;
			if (document.querySelector('#captcha-form, form#captcha-form, iframe[src*="recaptcha"]')) return true;
			const t = (document.body && document.body.innerText || '').slice(0, 2000).toLowerCase();
			return t.includes('unusual traffic') || t.includes('automated queries');
		} catch (e) { return false; }
	}`)
	if err != nil {
		return false
	}

	blocked, _ := res.(bool)

	return blocked
}

func (j *PlaceJob) Process(_ context.Context, resp *scrapemate.Response) (any, []scrapemate.IJob, error) {
	defer func() {
		resp.Document = nil
		resp.Body = nil
		resp.Meta = nil
	}()

	if resp.Error != nil {
		if j.ExitMonitor != nil {
			j.ExitMonitor.IncrPlacesCompleted(1)
		}

		return nil, nil, resp.Error
	}

	raw, ok := resp.Meta["json"].([]byte)
	if !ok {
		if j.ExitMonitor != nil {
			j.ExitMonitor.IncrPlacesCompleted(1)
		}

		return nil, nil, fmt.Errorf("could not convert to []byte")
	}

	// Re-use the entry parsed in BrowserActions if present; only fall back to
	// re-parsing if the cache key is missing (e.g. resp.Meta was overwritten).
	var (
		entry Entry
		err   error
	)

	if cached, ok := resp.Meta["entry"].(Entry); ok {
		entry = cached
	} else {
		entry, err = EntryFromJSON(raw)
		if err != nil {
			if j.ExitMonitor != nil {
				j.ExitMonitor.IncrPlacesCompleted(1)
			}

			return nil, nil, err
		}
	}

	entry.ID = j.ParentID

	if entry.Link == "" {
		entry.Link = j.GetURL()
	}

	// Restaurant-only mode: drop anything that isn't a food-serving venue.
	// The entry is fully parsed but never reaches the writer.
	if j.RestaurantsOnly && !entry.IsRestaurantLike() {
		log.Printf("[restaurants-only] dropped: %s (%s)", entry.Title, entry.Category)

		if j.ExitMonitor != nil && !j.WriterManagedCompletion {
			j.ExitMonitor.IncrPlacesCompleted(1)
		}

		j.UsageInResults = false

		return nil, nil, nil
	}

	// Handle RPC-based reviews
	allReviewsRaw, ok := resp.Meta["reviews_raw"].(FetchReviewsResponse)
	if ok && len(allReviewsRaw.pages) > 0 {
		entry.AddExtraReviews(allReviewsRaw.pages)
	}

	if chips, ok := resp.Meta["mentioned_in_reviews"].([]MentionedKeyword); ok && len(chips) > 0 {
		entry.MentionedInReviews = chips
	}

	// Handle DOM-based reviews (fallback)
	domReviews, ok := resp.Meta["dom_reviews"].([]DOMReview)
	if ok && len(domReviews) > 0 {
		convertedReviews := ConvertDOMReviewsToReviews(domReviews)
		entry.UserReviewsExtended = append(entry.UserReviewsExtended, convertedReviews...)
	}

	if j.ExtractEmail && entry.IsWebsiteValidForEmail() {
		opts := []EmailExtractJobOptions{}
		if j.ExitMonitor != nil {
			opts = append(opts, WithEmailJobExitMonitor(j.ExitMonitor))
		}

		if j.WriterManagedCompletion {
			opts = append(opts, WithEmailJobWriterManagedCompletion())
		}

		emailJob := NewEmailJob(j.ID, &entry, opts...)

		j.UsageInResults = false

		return nil, []scrapemate.IJob{emailJob}, nil
	} else if j.ExitMonitor != nil && !j.WriterManagedCompletion {
		j.ExitMonitor.IncrPlacesCompleted(1)
	}

	return &entry, nil, err
}

func (j *PlaceJob) BrowserActions(ctx context.Context, page scrapemate.BrowserPage) scrapemate.Response {
	var resp scrapemate.Response

	pageResponse, err := page.Goto(j.GetURL(), scrapemate.WaitUntilDOMContentLoaded)
	if err != nil {
		resp.Error = err

		return resp
	}

	clickRejectCookiesIfRequired(page)

	const defaultTimeout = 5 * time.Second

	// Ignore WaitForURL errors — Google Maps may redirect slowly especially via proxy
	_ = page.WaitForURL(page.URL(), defaultTimeout)

	// Fail fast on Google block pages: erroring here (instead of burning the
	// 30s JSON-extraction timeout) triggers a retry on a fresh browser+proxy.
	if isGoogleBlockPage(page) {
		resp.Error = ErrGoogleBlocked

		return resp
	}

	resp.URL = pageResponse.URL
	resp.StatusCode = pageResponse.StatusCode
	resp.Headers = pageResponse.Headers

	raw, err := j.extractJSON(page)
	if err != nil {
		// Distinguish a block page from a transient render issue so the retry
		// rotates the proxy with a meaningful error in the logs.
		if isGoogleBlockPage(page) {
			err = ErrGoogleBlocked
		}

		resp.Error = err

		return resp
	}

	if resp.Meta == nil {
		resp.Meta = make(map[string]any)
	}

	resp.Meta["json"] = raw

	// Parse the place entry ONCE here — EntryFromJSON walks deeply nested
	// arrays and is the heaviest call in the hot path. Process re-uses this
	// from resp.Meta["entry"] instead of parsing again.
	peek, perr := EntryFromJSON(raw)
	if perr == nil {
		resp.Meta["entry"] = peek
	}

	// Only run keyword-chip extraction for restaurant-like places with reviews —
	// the click+poll costs up to ~2 s and produces nothing on other categories.
	// Some listings parse ReviewCount as 0 even though they have reviews; fall
	// back to ReviewRating > 0 so those still get keyword/label-chip extraction.
	if perr == nil && peek.IsRestaurantLike() && (peek.ReviewCount > 0 || peek.ReviewRating > 0) {
		if chips := ExtractMentionedInReviews(page); len(chips) > 0 {
			resp.Meta["mentioned_in_reviews"] = chips
		}
	}

	if j.ExtractExtraReviews {
		reviewCount := 0
		reviewRating := 0.0

		if perr == nil {
			reviewCount = peek.ReviewCount
			reviewRating = peek.ReviewRating
		}

		// A parsed count of 0 with a non-zero rating means the count field did
		// not parse (Google's data layout varies); the place still has reviews,
		// so attempt the fetch — the RPC/DOM paths don't rely on the count.
		if reviewCount > 0 || reviewRating > 0 { // download reviews for any place that has them
			// The reviews panel can render lazily or only partially, so a single
			// click+scroll may see an empty list ("review count stuck at 0") or
			// just a handful for a place with thousands. Retry the whole fetch a
			// few times — reloading the page between attempts — and keep the
			// deepest result, so transient empty/shallow renders self-heal within
			// the run instead of leaving reviews missing or undercounted.
			const (
				reviewFetchAttempts = 3
				healthyReviewDepth  = 40 // a partial render yields far fewer than this
			)

			var (
				bestCount = -1
				bestRPC   FetchReviewsResponse
				bestDOM   []DOMReview
				lastErr   error
			)

			for attempt := 1; attempt <= reviewFetchAttempts; attempt++ {
				// On retries, reload the place page so the reviews panel
				// re-renders from scratch. Re-clicking a panel that is stuck on
				// the same session does not recover it — only a fresh page load
				// does (which is why a separate re-scrape succeeds).
				if attempt > 1 {
					if _, gerr := page.Goto(j.GetURL(), scrapemate.WaitUntilDOMContentLoaded); gerr == nil {
						clickRejectCookiesIfRequired(page)
					}
				}

				// Drive the page's Sort dropdown so both RPC and DOM-fallback
				// paths inherit the requested ordering.
				applyReviewSort(page, j.ReviewSort)

				params := fetchReviewsParams{
					page:        page,
					mapURL:      page.URL(),
					reviewCount: reviewCount,
					sortCode:    reviewSortCode(j.ReviewSort),
					maxReviews:  j.MaxReviews,
				}

				// Use the new fallback mechanism that tries RPC first, then DOM
				rpcData, domReviews, err := FetchReviewsWithFallback(ctx, params)
				lastErr = err

				collected := len(domReviews)
				for _, p := range rpcData.pages {
					collected += len(extractReviews(p))
				}

				// Keep the deepest result across attempts so a later, shallower
				// retry can never overwrite a better earlier one.
				if collected > bestCount {
					bestCount = collected
					bestRPC = rpcData
					bestDOM = domReviews
				}

				// Enough when we pulled a healthy share of the advertised count.
				// Cap the expectation at healthyReviewDepth so big-review places
				// aren't retried forever, and use a fraction so a near-complete
				// pull isn't retried over a few missing reviews. When the count
				// did not parse (0), accept any reviews.
				sufficient := collected > 0
				if reviewCount > 0 {
					expected := reviewCount
					if expected > healthyReviewDepth {
						expected = healthyReviewDepth
					}

					sufficient = collected*100 >= expected*80
				}

				if sufficient {
					break
				}

				if attempt < reviewFetchAttempts {
					log.Printf("review extraction shallow (%d reviews, attempt %d/%d), retrying", collected, attempt, reviewFetchAttempts)

					select {
					case <-ctx.Done():
						attempt = reviewFetchAttempts // stop retrying on cancellation
					case <-time.After(1500 * time.Millisecond):
					}
				}
			}

			switch {
			case len(bestRPC.pages) > 0:
				resp.Meta["reviews_raw"] = bestRPC
			case len(bestDOM) > 0:
				resp.Meta["dom_reviews"] = bestDOM
			case lastErr != nil:
				fmt.Printf("Warning: review extraction failed: %v\n", lastErr)
			}
		}
	}

	return resp
}

func (j *PlaceJob) getRaw(ctx context.Context, page scrapemate.BrowserPage) (any, error) {
	for {
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("timeout while getting raw data: %w", ctx.Err())
		default:
			raw, err := page.Eval(js)
			if err != nil {
				// Continue retrying on error
				<-time.After(time.Millisecond * 200)
				continue
			}

			// Check for valid non-null result.
			// JS null may arrive as nil, and empty strings are not useful here.
			if raw == nil {
				<-time.After(time.Millisecond * 200)
				continue
			}

			// If it's a string, make sure it's not empty
			if str, ok := raw.(string); ok {
				if str == "" {
					<-time.After(time.Millisecond * 200)
					continue
				}
			}

			return raw, nil
		}
	}
}

func (j *PlaceJob) extractJSON(page scrapemate.BrowserPage) ([]byte, error) {
	const maxRetries = 2

	for attempt := range maxRetries {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		rawI, err := j.getRaw(ctx, page)

		cancel()

		if err != nil {
			// On timeout, try reloading the page
			if attempt < maxRetries-1 {
				if reloadErr := page.Reload(scrapemate.WaitUntilDOMContentLoaded); reloadErr == nil {
					continue
				}
			}

			return nil, err
		}

		if rawI == nil {
			if attempt < maxRetries-1 {
				if reloadErr := page.Reload(scrapemate.WaitUntilDOMContentLoaded); reloadErr == nil {
					continue
				}
			}

			return nil, fmt.Errorf("APP_INITIALIZATION_STATE data not found")
		}

		raw, ok := rawI.(string)
		if !ok {
			return nil, fmt.Errorf("could not convert to string, got type %T", rawI)
		}

		const prefix = `)]}'`

		raw = strings.TrimSpace(strings.TrimPrefix(raw, prefix))

		return []byte(raw), nil
	}

	return nil, fmt.Errorf("APP_INITIALIZATION_STATE data not found after retries")
}

func (j *PlaceJob) getReviewCount(data []byte) int {
	tmpEntry, err := EntryFromJSON(data, true)
	if err != nil {
		return 0
	}

	return tmpEntry.ReviewCount
}

func (j *PlaceJob) UseInResults() bool {
	return j.UsageInResults
}

const js = `
(function() {
	if (!window.APP_INITIALIZATION_STATE || !window.APP_INITIALIZATION_STATE[3]) {
		return null;
	}
	const appState = window.APP_INITIALIZATION_STATE[3];
	
	// Search all properties of appState for arrays containing JSON strings
	for (const key of Object.keys(appState)) {
		const arr = appState[key];
		if (Array.isArray(arr)) {
			// Check indices 6 and 5 (where place data typically is)
			for (const idx of [6, 5]) {
				const item = arr[idx];
				if (typeof item === 'string' && item.startsWith(")]}'")) {
					return item;
				}
			}
		}
	}
	return null;
})()
`
