package gmaps

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gosom/scrapemate"
	"github.com/gosom/scrapemate/adapters/fetchers/stealth"
)

type fetchReviewsParams struct {
	page        scrapemate.BrowserPage
	mapURL      string
	reviewCount int
	sortCode    int // Google RPC sort code; see reviewSortCode().
	maxReviews  int // Hard cap on DOM-scrolled reviews (0 = use default 200).
}

// reviewSortCode maps a user-facing sort name to the Google RPC `1e<N>` value.
// Falls back to "newest" if the name is empty or unrecognised.
func reviewSortCode(name string) int {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "relevant", "most_relevant", "most-relevant":
		return 1
	case "highest", "highest_rating", "highest-rating":
		return 3
	case "lowest", "lowest_rating", "lowest-rating":
		return 4
	default: // "", "newest", "most_recent", anything else
		return 2
	}
}

const reviewSortNewest = "newest"

// applyReviewSort drives the place panel's "Sort" dropdown to the requested
// option. Opens the Reviews tab first if it isn't already active. Returns true
// if a selection was made. Both the RPC review fetch and the DOM fallback
// inherit the page's chosen ordering.
func applyReviewSort(page scrapemate.BrowserPage, name string) bool {
	if page == nil {
		return false
	}

	// Make sure the Reviews tab is active — the sort button only renders there.
	_, _ = page.Eval(`() => {
		try {
			const tabs = document.querySelectorAll('button[role="tab"], button[jsaction]');
			for (const t of tabs) {
				const label = (t.getAttribute('aria-label') || t.textContent || '').trim().toLowerCase();
				if (/^reviews?(\s|$|\()/.test(label) || label.startsWith('reviews for')) {
					t.click();
					return true;
				}
			}
			return false;
		} catch (e) { return false; }
	}`)

	time.Sleep(500 * time.Millisecond)

	// Map sort name -> the menu-item label Google renders in the dropdown.
	var target string

	switch strings.ToLower(strings.TrimSpace(name)) {
	case "relevant", "most_relevant", "most-relevant", "":
		target = "most relevant"
	case "highest", "highest_rating", "highest-rating":
		target = "highest rating"
	case "lowest", "lowest_rating", "lowest-rating":
		target = "lowest rating"
	case reviewSortNewest, "most_recent", "recent":
		target = reviewSortNewest
	default:
		target = reviewSortNewest
	}

	// Open the sort dropdown.
	opened, _ := page.Eval(`() => {
		try {
			const candidates = document.querySelectorAll('button, [role="button"]');
			for (const b of candidates) {
				const t = (b.getAttribute('aria-label') || b.textContent || '').trim().toLowerCase();
				if (t === 'sort' || t.startsWith('sort ') ||
				    t === 'most relevant' || t === 'newest' ||
				    t === 'highest rating' || t === 'lowest rating') {
					b.click();
					return true;
				}
			}
			return false;
		} catch (e) { return false; }
	}`)
	if v, _ := opened.(bool); !v {
		return false
	}

	// Wait a beat for the menu to render.
	time.Sleep(400 * time.Millisecond)

	// Click the target option in the menu.
	picked, _ := page.Eval(fmt.Sprintf(`() => {
		try {
			const target = %q;
			const items = document.querySelectorAll('[role="menuitemradio"], [role="menuitem"], li[role], div[role]');
			for (const it of items) {
				const t = (it.getAttribute('aria-label') || it.textContent || '').trim().toLowerCase();
				if (t === target) { it.click(); return true; }
			}
			return false;
		} catch (e) { return false; }
	}`, target))
	if v, _ := picked.(bool); !v {
		return false
	}

	// Let the sorted list re-render before downstream extraction reads it.
	time.Sleep(800 * time.Millisecond)

	return true
}

type FetchReviewsResponse struct {
	pages [][]byte
}

type fetcher struct {
	httpClient scrapemate.HTTPFetcher
	params     fetchReviewsParams
}

func newReviewFetcher(params fetchReviewsParams) *fetcher {
	netClient := stealth.New("firefox", nil)
	ans := fetcher{
		params:     params,
		httpClient: netClient,
	}

	return &ans
}

func (f *fetcher) fetch(ctx context.Context) (FetchReviewsResponse, error) {
	requestIDForSession, err := generateRandomID(21)
	if err != nil {
		return FetchReviewsResponse{}, fmt.Errorf("failed to generate session request ID: %v", err)
	}

	reviewURL, err := f.generateURL(f.params.mapURL, "", 20, requestIDForSession)
	if err != nil {
		return FetchReviewsResponse{}, fmt.Errorf("failed to generate initial URL: %v", err)
	}

	// First, try to fetch using the browser's session (has cookies/authentication)
	if f.params.page != nil {
		ans, err := f.fetchWithBrowser(ctx, reviewURL, requestIDForSession)
		if err == nil && len(ans.pages) > 0 {
			return ans, nil
		}

		log.Printf("Browser-based RPC fetch failed: %v, trying HTTP", err)
	}

	// Fallback to direct HTTP (may fail due to lack of authentication)
	currentPageBody, err := f.fetchReviewPage(ctx, reviewURL)
	if err != nil {
		log.Printf("RPC fetch failed, will try DOM extraction: %v", err)
		return FetchReviewsResponse{}, err
	}

	ans := FetchReviewsResponse{}
	ans.pages = append(ans.pages, currentPageBody)

	nextPageToken := extractNextPageToken(currentPageBody)

	for nextPageToken != "" {
		reviewURL, err = f.generateURL(f.params.mapURL, nextPageToken, 20, requestIDForSession)
		if err != nil {
			log.Printf("Error generating URL for token %s: %v", nextPageToken, err)
			break
		}

		currentPageBody, err = f.fetchReviewPage(ctx, reviewURL)
		if err != nil {
			log.Printf("Error fetching review page with token %s: %v", nextPageToken, err)
			break
		}

		ans.pages = append(ans.pages, currentPageBody)
		nextPageToken = extractNextPageToken(currentPageBody)
	}

	return ans, nil
}

// fetchWithBrowser uses Playwright to fetch the review API with browser cookies
func (f *fetcher) fetchWithBrowser(_ context.Context, initialURL, requestID string) (FetchReviewsResponse, error) {
	ans := FetchReviewsResponse{}
	page := f.params.page

	// Use JavaScript fetch to get the reviews with proper cookies
	jsCode := fmt.Sprintf(`async () => {
		try {
			const response = await fetch('%s', {
				method: 'GET',
				credentials: 'include',
				headers: {
					'Accept': '*/*',
					'Accept-Language': 'en-US,en;q=0.9'
				}
			});
			if (!response.ok) {
				return { error: 'HTTP ' + response.status };
			}
			const text = await response.text();
			return { data: text };
		} catch (e) {
			return { error: e.message };
		}
	}`, initialURL)

	result, err := page.Eval(jsCode)
	if err != nil {
		return ans, fmt.Errorf("browser fetch failed: %w", err)
	}

	resultMap, ok := result.(map[string]interface{})
	if !ok {
		return ans, fmt.Errorf("unexpected result type: %T", result)
	}

	if errMsg, hasError := resultMap["error"]; hasError {
		return ans, fmt.Errorf("fetch error: %v", errMsg)
	}

	data, ok := resultMap["data"].(string)
	if !ok || len(data) < 10 {
		return ans, fmt.Errorf("empty response from browser fetch")
	}

	ans.pages = append(ans.pages, []byte(data))

	// Get additional pages
	nextPageToken := extractNextPageToken([]byte(data))
	for nextPageToken != "" && len(ans.pages) < 50 { // Limit to 50 pages
		nextURL, err := f.generateURL(f.params.mapURL, nextPageToken, 20, requestID)
		if err != nil {
			break
		}

		jsCode = fmt.Sprintf(`async () => {
			try {
				const response = await fetch('%s', {
					method: 'GET',
					credentials: 'include'
				});
				if (!response.ok) {
					return { error: 'HTTP ' + response.status };
				}
				return { data: await response.text() };
			} catch (e) {
				return { error: e.message };
			}
		}`, nextURL)

		result, err = page.Eval(jsCode)
		if err != nil {
			break
		}

		resultMap, ok = result.(map[string]interface{})
		if !ok || resultMap["error"] != nil {
			break
		}

		data, ok = resultMap["data"].(string)
		if !ok || len(data) < 10 {
			break
		}

		ans.pages = append(ans.pages, []byte(data))
		nextPageToken = extractNextPageToken([]byte(data))
	}

	return ans, nil
}

var (
	patternsOnce sync.Once
	patterns     map[string]*regexp.Regexp
)

const hexMatchPattern = `0x[0-9a-fA-F]+:0x[0-9a-fA-F]+` // Hex format place ID

// extractPlaceID extracts the place ID from various Google Maps URL formats
func extractPlaceID(mapURL string) (string, error) {
	patternsOnce.Do(func() {
		patterns = make(map[string]*regexp.Regexp)
		// Try multiple patterns for extracting place ID
		avail := []string{
			`!1s([^!]+)`,                             // Standard format: !1s0x...
			`place_id=([^&]+)`,                       // Query parameter format
			`/place/[^/]+/@[^/]+/data=!.*!1s([^!]+)`, // Full place URL
			hexMatchPattern,                          // Hex format place ID
		}

		patterns = make(map[string]*regexp.Regexp)
		for _, p := range avail {
			patterns[p] = regexp.MustCompile(p)
		}
	})

	for pattern, re := range patterns {
		match := re.FindStringSubmatch(mapURL)
		if len(match) >= 2 {
			rawPlaceID, err := url.QueryUnescape(match[1])
			if err != nil {
				rawPlaceID = match[1]
			}

			return rawPlaceID, nil
		}
		// For hex format, match[0] is the full match
		if pattern == hexMatchPattern && len(match) >= 1 {
			return match[0], nil
		}
	}

	return "", fmt.Errorf("could not extract place ID from URL: %s", mapURL)
}

func (f *fetcher) generateURL(mapURL, pageToken string, pageSize int, requestID string) (string, error) {
	rawPlaceID, err := extractPlaceID(mapURL)
	if err != nil {
		return "", err
	}

	encodedPlaceID := url.QueryEscape(rawPlaceID)
	encodedPageToken := url.QueryEscape(pageToken)

	// The pb sort slot is brittle to modify directly — Google rejects most
	// values with HTTP 400. Instead, the page-level "Sort: Newest" click in
	// applyReviewSort() puts the session in newest-mode, and the RPC call
	// then uses that session ordering. Keep the original pb intact.
	pbComponents := []string{
		fmt.Sprintf("!1m6!1s%s", encodedPlaceID),
		"!6m4!4m1!1e1!4m1!1e3",
		fmt.Sprintf("!2m2!1i%d!2s%s", pageSize, encodedPageToken),
		fmt.Sprintf("!5m2!1s%s!7e81", requestID),
		"!8m9!2b1!3b1!5b1!7b1",
		"!12m4!1b1!2b1!4m1!1e1!11m0!13m1!1e1",
	}

	// Use English language for consistent parsing
	fullURL := fmt.Sprintf(
		"https://www.google.com/maps/rpc/listugcposts?authuser=0&hl=en&pb=%s",
		strings.Join(pbComponents, ""),
	)

	return fullURL, nil
}

func (f *fetcher) fetchReviewPage(ctx context.Context, u string) ([]byte, error) {
	job := scrapemate.Job{
		Method: "GET",
		URL:    u,
	}

	resp := f.httpClient.Fetch(ctx, &job)
	if resp.Error != nil {
		return nil, fmt.Errorf("fetch error for %s: %w", u, resp.Error)
	}

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("%s: unexpected status code: %d", u, resp.StatusCode)
	}

	return resp.Body, nil
}

func extractNextPageToken(data []byte) string {
	text := string(data)
	prefix := ")]}'\n"
	text = strings.TrimPrefix(text, prefix)

	var result []interface{}

	err := json.Unmarshal([]byte(text), &result)
	if err != nil {
		return ""
	}

	if len(result) < 2 || result[1] == nil {
		return ""
	}

	token, ok := result[1].(string)
	if !ok {
		return ""
	}

	return token
}

func generateRandomID(length int) (string, error) {
	numBytes := (length*6 + 7) / 8
	if numBytes < 16 {
		numBytes = 16
	}

	b := make([]byte, numBytes)

	_, err := rand.Read(b)
	if err != nil {
		return "", err
	}

	encoded := base64.URLEncoding.WithPadding(base64.NoPadding).EncodeToString(b)
	if len(encoded) >= length {
		return encoded[:length], nil
	}

	return "", errors.New("generated ID is shorter than expected")
}

// DOMReview represents a review extracted from the DOM
type DOMReview struct {
	AuthorName              string
	AuthorURL               string
	ProfilePicture          string
	Rating                  int
	RelativeTimeDescription string
	Text                    string
	Images                  []string
}

// ConvertDOMReviewsToReviews converts DOMReview slice to Review slice
func ConvertDOMReviewsToReviews(domReviews []DOMReview) []Review {
	reviews := make([]Review, 0, len(domReviews))

	for _, dr := range domReviews {
		review := Review{
			Name:           dr.AuthorName,
			ProfilePicture: dr.ProfilePicture,
			Rating:         dr.Rating,
			Description:    dr.Text,
			When:           dr.RelativeTimeDescription,
			Images:         dr.Images,
		}
		if review.Name != "" {
			reviews = append(reviews, review)
		}
	}

	return reviews
}

// extractReviewsFromPage extracts reviews directly from the page DOM.
// `maxReviews` caps the result (0 → default 200). This is the primary path
// when a non-default sort is requested, and the fallback when the RPC fails.
//
//nolint:gocyclo // DOM scroll/extraction handles many page-state edge cases inline; splitting would obscure the scrape flow.
func extractReviewsFromPage(ctx context.Context, page scrapemate.BrowserPage, maxReviews int) ([]DOMReview, error) {
	if maxReviews <= 0 {
		maxReviews = 200
	}

	log.Printf("Attempting DOM-based review extraction (cap=%d)", maxReviews)

	// First, try to click the reviews section to open the reviews panel
	clickedReviews, _ := page.Eval(`() => {
		try {
			// Method 1: Click on the reviews count/link in the place info
			const reviewsButtons = document.querySelectorAll('button[jsaction*="reviewChart"], button[jsaction*="reviews"]');
			for (const btn of reviewsButtons) {
				if (btn.textContent.includes('review') || btn.getAttribute('aria-label')?.includes('review')) {
					btn.click();
					return 'reviews_button';
				}
			}

			// Method 2: Click on the reviews tab
			const tabs = document.querySelectorAll('button[role="tab"]');
			for (const tab of tabs) {
				const label = tab.getAttribute('aria-label') || tab.textContent || '';
				if (label.toLowerCase().includes('review')) {
					tab.click();
					return 'reviews_tab';
				}
			}

			// Method 3: Click the star rating area which often opens reviews
			const ratingArea = document.querySelector('.F7nice, .fontDisplayLarge');
			if (ratingArea) {
				ratingArea.click();
				return 'rating_area';
			}

			// Method 4: Look for "See all reviews" or similar links
			const allLinks = document.querySelectorAll('a, button');
			for (const link of allLinks) {
				const text = link.textContent?.toLowerCase() || '';
				if (text.includes('all review') || text.includes('see review') || text.includes('more review')) {
					link.click();
					return 'all_reviews_link';
				}
			}

			return false;
		} catch (e) {
			console.error('Error clicking reviews:', e);
			return false;
		}
	}`)

	if clickedReviews != nil && clickedReviews != false {
		log.Printf("Clicked reviews via: %v", clickedReviews)
	}

	// Wait for reviews panel to load
	time.Sleep(3 * time.Second)

	var reviews []DOMReview

	// Scroll budget: enough rounds to plausibly reach the maxReviews cap
	// (Google loads ~10 reviews per visible scroll on most layouts).
	maxScrollAttempts := maxReviews/5 + 30
	lastCount := 0
	stuckCount := 0

	for attempt := 0; attempt < maxScrollAttempts; attempt++ {
		select {
		case <-ctx.Done():
			return reviews, ctx.Err()
		default:
		}

		// Extract reviews from the DOM - updated for Dec 2025 Google Maps structure
		reviewsJSON, err := page.Eval(`() => {
			try {
				const reviews = [];

				// Try multiple selectors for review container elements
				// Google Maps uses various class names that change over time
				const reviewSelectors = [
					'.jftiEf',                           // Common review container
					'div[data-review-id]',               // Review with ID attribute
					'.gws-localreviews__google-review',  // Alternative format
					'[data-hveid] .review-dialog-list > div', // Search results reviews
					'.WMbnJf',                           // Another review container
					'.bwb7ce',                           // New review format
				];

				let reviewElements = [];
				for (const selector of reviewSelectors) {
					const elements = document.querySelectorAll(selector);
					if (elements && elements.length > 0) {
						reviewElements = Array.from(elements);
						console.log('Found reviews with selector:', selector, 'count:', elements.length);
						break;
					}
				}

				// If no reviews found with specific selectors, try to find by structure
				if (reviewElements.length === 0) {
					// Look for elements that look like reviews (have rating + text)
					const allDivs = document.querySelectorAll('div[class]');
					for (const div of allDivs) {
						const hasRating = div.querySelector('[aria-label*="star"], [role="img"][aria-label*="star"]');
						const hasText = div.querySelector('span.wiI7pd, span[class*="review"]');
						if (hasRating && hasText && !reviewElements.includes(div)) {
							reviewElements.push(div);
						}
					}
				}

				console.log('Total review elements found:', reviewElements.length);

				for (const element of reviewElements) {
					try {
						// Author name - comprehensive selectors
						const userSelectors = [
							'.d4r55',           // Primary name class
							'.WNxzHc',          // Alternative name
							'.TSUbDb a',        // Link with name
							'.review-author',   // Generic
							'button.al6Kxe',    // Clickable name
							'.bHrnEe',          // Another name container
						];
						let userName = '';
						let userUrl = '';
						for (const sel of userSelectors) {
							const el = element.querySelector(sel);
							if (el) {
								userName = el.textContent?.trim() || '';
								if (el.tagName?.toLowerCase() === 'a') {
									userUrl = el.getAttribute('href') || '';
								}
								if (userName) break;
							}
						}

						// Profile picture - multiple patterns
						const profilePicSelectors = [
							'.NBa7we',
							'img[src*="googleusercontent"]',
							'img[src*="lh3.google"]',
							'.review-author-photo img',
						];
						let profilePic = '';
						for (const sel of profilePicSelectors) {
							const el = element.querySelector(sel);
							if (el) {
								profilePic = el.getAttribute('src') || '';
								if (profilePic) break;
							}
						}

						// Rating - the star widget exposes an aria-label like
						// "5 stars" or "Rated 4 out of 5". Google obfuscates and
						// changes the class names, so scan every aria-labelled
						// descendant for that pattern instead of relying on a
						// fixed selector. Restrict the value to a single 1-5 digit
						// so review counts / dates can't be mistaken for a rating.
						let rating = 0;
						const labelled = element.querySelectorAll('[aria-label]');
						for (const el of labelled) {
							const al = el.getAttribute('aria-label') || '';
							const m = al.match(/(?:^|\brated\s+)?([1-5](?:[.,]\d)?)\s*(?:out of\s*5|stars?|★)/i) ||
								al.match(/([1-5](?:[.,]\d)?)\s*out of\s*5/i);
							if (m) {
								rating = Math.round(parseFloat(m[1].replace(',', '.'))) || 0;
								if (rating > 0) break;
							}
						}

						// Time/date - multiple selectors
						const timeSelectors = ['.rsqaWe', '.DU9Pgb', '.tTVLSc', '.review-date', '.dehysf'];
						let relativeTime = '';
						for (const sel of timeSelectors) {
							const el = element.querySelector(sel);
							if (el) {
								const text = el.textContent?.trim() || '';
								// Look for time-related text (ago, month, year, etc)
								if (text && (text.includes('ago') || text.includes('week') || text.includes('month') ||
								    text.includes('year') || text.includes('day') || text.match(/\d{4}/))) {
									relativeTime = text;
									break;
								}
							}
						}

						// Review text - try to expand and get full text
						const textSelectors = [
							'.wiI7pd',
							'.MyEned span',
							'.review-full-text',
							'.Jtu6Td span',
							'[data-expandable-section] span',
						];
						let text = '';

						// First try to click "More" button to expand text
						const moreButtons = element.querySelectorAll('.w8nwRe, button[aria-label*="More"], button[aria-expanded="false"]');
						for (const btn of moreButtons) {
							try { btn.click(); } catch(e) {}
						}

						for (const sel of textSelectors) {
							const textEl = element.querySelector(sel);
							if (textEl) {
								text = textEl.textContent?.trim() || '';
								if (text && text.length > 5) break;
							}
						}

						// Images
						const imageElements = element.querySelectorAll('.KtCyie img, .Tya61d img, .review-photos img, img[src*="lh3"]');
						const images = [];
						for (const img of imageElements) {
							const src = img.getAttribute('src') || '';
							if (src && !src.includes('data:image') && !src.includes('profile')) {
								images.push(src);
							}
						}

						if (userName && (text || rating > 0)) {
							reviews.push({
								author_name: userName,
								author_url: userUrl,
								profile_picture: profilePic,
								rating: rating,
								relative_time_description: relativeTime,
								text: text,
								images: images
							});
						}
					} catch (e) {
						console.error("Error extracting review:", e);
					}
				}

				return reviews;
			} catch (e) {
				console.error("Error in review extraction:", e);
				return [];
			}
		}`)

		if err != nil {
			log.Printf("Error extracting reviews from DOM: %v", err)
		} else if reviewsJSON != nil {
			rawReviews, ok := reviewsJSON.([]any)
			if ok {
				for _, rawReview := range rawReviews {
					reviewMap, ok := rawReview.(map[string]interface{})
					if !ok {
						continue
					}

					review := DOMReview{}
					if v, ok := reviewMap["author_name"].(string); ok {
						review.AuthorName = v
					}

					if v, ok := reviewMap["author_url"].(string); ok {
						review.AuthorURL = v
					}

					if v, ok := reviewMap["profile_picture"].(string); ok {
						review.ProfilePicture = v
					}

					switch v := reviewMap["rating"].(type) {
					case float64:
						review.Rating = int(v)
					case int:
						review.Rating = v
					case int64:
						review.Rating = int(v)
					case json.Number:
						if n, err := v.Int64(); err == nil {
							review.Rating = int(n)
						}
					}

					if v, ok := reviewMap["relative_time_description"].(string); ok {
						review.RelativeTimeDescription = v
					}

					if v, ok := reviewMap["text"].(string); ok {
						review.Text = v
					}

					if v, ok := reviewMap["images"].([]interface{}); ok {
						for _, img := range v {
							if imgStr, ok := img.(string); ok {
								review.Images = append(review.Images, imgStr)
							}
						}
					}

					// Add if unique (check by author name and text prefix)
					isDuplicate := false

					for _, existing := range reviews {
						if existing.AuthorName == review.AuthorName {
							if existing.Text == review.Text {
								isDuplicate = true
								break
							}

							if len(existing.Text) > 20 && len(review.Text) > 20 &&
								existing.Text[:20] == review.Text[:20] {
								isDuplicate = true
								break
							}
						}
					}

					if !isDuplicate && review.AuthorName != "" {
						reviews = append(reviews, review)
					}
				}
			}
		}

		currentCount := len(reviews)

		// Hit the user-requested cap — stop scrolling early.
		if currentCount >= maxReviews {
			log.Printf("Reached review cap (%d), stopping scroll", maxReviews)
			break
		}

		if currentCount == lastCount {
			stuckCount++
			// The scroll now jumps to the absolute bottom and jiggles up on a
			// stall to re-fire the lazy loader (see below); a genuine end-of-list
			// won't recover past that, so 6 no-change rounds is enough to confirm
			// we're done. (Was 10 — the jiggle makes the extra patience wasteful.)
			if stuckCount > 6 {
				log.Printf("Review count stuck at %d, stopping scroll", currentCount)
				break
			}
		} else {
			stuckCount = 0
			lastCount = currentCount
		}

		// Scroll to load more reviews. Class names rotate, so we first try
		// a known-good review element and walk up to its scrollable ancestor —
		// this works even when Google ships new class names.
		//
		// Jump to the absolute bottom (not an incremental scrollBy, which can
		// lag behind as the list grows and stall the lazy loader). When the
		// count is stuck, first jiggle up so re-hitting the bottom re-fires the
		// intersection observer that requests the next batch.
		jiggle := stuckCount > 0
		scrollJS := fmt.Sprintf(`() => {
			try {
				const jiggle = %t;
				const toBottom = (el) => {
					if (jiggle) { el.scrollTop = Math.max(0, el.scrollHeight - el.clientHeight * 2); }
					el.scrollTop = el.scrollHeight;
				};
				const findScrollable = (el) => {
					for (let n = el; n && n !== document.body; n = n.parentElement) {
						const s = getComputedStyle(n);
						if ((s.overflowY === 'auto' || s.overflowY === 'scroll') &&
						    n.scrollHeight > n.clientHeight + 50) {
							return n;
						}
					}
					return null;
				};

				// Anchor: any visible review tile.
				const anchorSelectors = ['div[data-review-id]', '.jftiEf', '.WMbnJf', '.bwb7ce'];
				for (const sel of anchorSelectors) {
					const anchor = document.querySelector(sel);
					if (!anchor) continue;
					const sc = findScrollable(anchor);
					if (sc) {
						toBottom(sc);
						return 'anchor-scroll';
					}
				}

				// Fallback: legacy class-name selectors.
				const legacy = [
					'.m6QErb.DxyBCb.kA9KIf.dS8AEf',
					'.m6QErb.DxyBCb.kA9KIf',
					'.DxyBCb.kA9KIf',
					'.m6QErb',
					'div[role="feed"]'
				];
				for (const sel of legacy) {
					const el = document.querySelector(sel);
					if (el && el.scrollHeight > el.clientHeight) {
						toBottom(el);
						return 'legacy-scroll';
					}
				}

				window.scrollTo(0, document.body.scrollHeight);
				return 'window-scroll';
			} catch (e) { return 'err'; }
		}`, jiggle)
		_, _ = page.Eval(scrollJS)

		// Give a stalled list a longer beat to stream the next batch in.
		if jiggle {
			time.Sleep(1200 * time.Millisecond)
		} else {
			time.Sleep(700 * time.Millisecond)
		}
	}

	log.Printf("DOM extraction completed: %d reviews found", len(reviews))

	return reviews, nil
}

// ExtractMentionedInReviews scrapes the "mentioned in reviews" keyword chips
// (keyword + their review counts) that Google Maps surfaces above the reviews
// list for a place. All chips are captured — dishes (e.g. "octopus") as well as
// topic tags (e.g. "service", "atmosphere", "great value"). Results come back
// sorted by count, descending.
//
// Side effect: opens the Reviews tab on the place panel, since the keyword
// chips are only rendered once that tab is active.
func ExtractMentionedInReviews(page scrapemate.BrowserPage) []MentionedKeyword {
	if page == nil {
		return nil
	}

	// Click the Reviews tab so the chips render.
	_, _ = page.Eval(`() => {
		try {
			const tabs = document.querySelectorAll('button[role="tab"], button[jsaction]');
			for (const t of tabs) {
				const label = (t.getAttribute('aria-label') || t.textContent || '').trim().toLowerCase();
				if (/^reviews?(\s|$|\()/.test(label) || label.startsWith('reviews for')) {
					t.click();
					return true;
				}
			}
			return false;
		} catch (e) { return false; }
	}`)

	const chipExtractor = `() => {
		try {
			const out = [];
			const seen = new Set();
			// Chip aria-labels read: "<keyword>, mentioned in <N> reviews".
			const chipRe = /^(.+?),\s*mentioned in\s+([\d,\.]+)\s+reviews?$/i;

			// Scope to the reviews scroll container if we can find it — saves
			// scanning hundreds of unrelated buttons. Fall back to full DOM
			// if no container matches (chip layout may have shifted).
			let root = document.querySelector('div[role="main"] div[role="region"]') ||
				document.querySelector('div[role="main"]') ||
				document.querySelector('div[role="feed"]') ||
				document;

			const nodes = root.querySelectorAll('button, span[role="button"]');
			for (const n of nodes) {
				const raw = (n.getAttribute('aria-label') || n.textContent || '').trim();
				if (!raw) continue;
				const m = raw.match(chipRe);
				if (!m) continue;
				const label = m[1].trim();
				if (!label || label.length > 40) continue;
				const key = label.toLowerCase();
				if (seen.has(key)) continue;
				seen.add(key);
				const count = parseInt(m[2].replace(/[,.]/g, ''), 10) || 0;
				out.push({ name: key, count: count });
			}
			return out;
		} catch (e) { return []; }
	}`

	// Adaptive polling: try a fast first scan, then back off if empty. Chips
	// usually render in <600 ms on a warm connection; this avoids the 1.5 s
	// fixed grace period and shaves ~1 s off the common path.
	//
	// Backoff sequence (ms): 250, 400, 600, 800, 1000, then 1000 until deadline.
	// Bail after 5 consecutive empties (~4 s) so a place really has no chips —
	// a lower threshold gave up before the panel rendered under concurrency,
	// where pages load slower. Stop once the chip list is stable across two
	// scans (Google sometimes streams chips in over a couple hundred ms).
	const maxEmptyScans = 5
	deadline := time.Now().Add(10 * time.Second)
	delays := []time.Duration{
		250 * time.Millisecond,
		400 * time.Millisecond,
		600 * time.Millisecond,
		800 * time.Millisecond,
		1000 * time.Millisecond,
	}

	var (
		lastCount  int
		stableHits int
		emptyHits  int
		viewedMore bool
		chips      []MentionedKeyword
	)

	for attempt := 0; time.Now().Before(deadline); attempt++ {
		// Initial wait before the first scan — even a fast click needs ~200 ms
		// for the tab to swap.
		if attempt < len(delays) {
			time.Sleep(delays[attempt])
		} else {
			time.Sleep(delays[len(delays)-1])
		}

		// Expand "View N more" exactly once.
		if !viewedMore {
			res, _ := page.Eval(`() => {
				const btns = document.querySelectorAll('button');
				for (const b of btns) {
					const t = (b.getAttribute('aria-label') || b.textContent || '').trim();
					if (/^view\s+\d+\s+more$/i.test(t)) { b.click(); return true; }
				}
				return false;
			}`)
			if v, ok := res.(bool); ok && v {
				viewedMore = true
			}
		}

		raw, err := page.Eval(chipExtractor)
		if err != nil {
			continue
		}

		arr, _ := raw.([]any)
		if len(arr) > 0 {
			cur := parseChips(arr)
			if len(cur) == lastCount {
				stableHits++
			} else {
				stableHits = 0
				lastCount = len(cur)
			}

			chips = cur
			emptyHits = 0

			if stableHits >= 1 {
				break
			}
		} else {
			emptyHits++
			if emptyHits >= maxEmptyScans {
				break
			}
		}
	}

	// Sort by count desc, then name asc for stable output.
	for i := 0; i < len(chips); i++ {
		for j := i + 1; j < len(chips); j++ {
			if chips[j].Count > chips[i].Count ||
				(chips[j].Count == chips[i].Count && chips[j].Name < chips[i].Name) {
				chips[i], chips[j] = chips[j], chips[i]
			}
		}
	}

	return chips
}

func parseChips(arr []any) []MentionedKeyword {
	out := make([]MentionedKeyword, 0, len(arr))
	seen := make(map[string]struct{}, len(arr))

	for _, v := range arr {
		m, ok := v.(map[string]any)
		if !ok {
			continue
		}

		name, _ := m["name"].(string)
		name = strings.TrimSpace(name)

		if name == "" {
			continue
		}

		if _, dup := seen[name]; dup {
			continue
		}

		seen[name] = struct{}{}

		var count int

		switch c := m["count"].(type) {
		case float64:
			count = int(c)
		case int:
			count = c
		case int64:
			count = int(c)
		case json.Number:
			if n, err := c.Int64(); err == nil {
				count = int(n)
			}
		case string:
			if n, err := strconv.Atoi(strings.TrimSpace(c)); err == nil {
				count = n
			}
		}

		out = append(out, MentionedKeyword{Name: name, Count: count})
	}

	return out
}

// FetchReviewsWithFallback attempts RPC-based extraction first, then falls back to DOM.
// When a non-default sort is requested, the RPC path is skipped entirely — the
// RPC endpoint hardcodes "most relevant" regardless of page state, so honoring
// the user's sort requires the DOM scroll path.
func FetchReviewsWithFallback(ctx context.Context, params fetchReviewsParams) (FetchReviewsResponse, []DOMReview, error) {
	// sortCode 0 (uninitialised) or 1 (most_relevant) = use RPC.
	// Anything else: DOM only, because RPC ignores sort.
	if params.sortCode != 0 && params.sortCode != 1 {
		// If DOM extraction is unavailable or fails, fall through to RPC as a last resort.
		if params.page != nil {
			domReviews, domErr := extractReviewsFromPage(ctx, params.page, params.maxReviews)
			if domErr == nil && len(domReviews) > 0 {
				log.Printf("DOM extraction (sort=%d) successful: %d reviews", params.sortCode, len(domReviews))
				return FetchReviewsResponse{}, domReviews, nil
			}

			if domErr != nil {
				log.Printf("DOM extraction (sort=%d) failed: %v", params.sortCode, domErr)
			}
		}
	}

	fetcher := newReviewFetcher(params)

	// Try RPC-based extraction first
	rpcResponse, err := fetcher.fetch(ctx)
	if err == nil && len(rpcResponse.pages) > 0 {
		// Validate that we actually got reviews
		totalReviews := 0

		for _, page := range rpcResponse.pages {
			reviews := extractReviews(page)
			totalReviews += len(reviews)
		}

		if totalReviews > 0 {
			log.Printf("RPC extraction successful: %d review pages, ~%d reviews", len(rpcResponse.pages), totalReviews)
			return rpcResponse, nil, nil
		}

		log.Printf("RPC returned empty reviews, trying DOM extraction")
	}

	// Fallback to DOM-based extraction
	if params.page != nil {
		domReviews, domErr := extractReviewsFromPage(ctx, params.page, params.maxReviews)
		if domErr == nil && len(domReviews) > 0 {
			log.Printf("DOM extraction successful: %d reviews", len(domReviews))
			return FetchReviewsResponse{}, domReviews, nil
		}

		if domErr != nil {
			log.Printf("DOM extraction failed: %v", domErr)
		}
	}

	// Return whatever we have
	if err != nil {
		return FetchReviewsResponse{}, nil, fmt.Errorf("all review extraction methods failed: %v", err)
	}

	// Reaching here means RPC yielded no reviews (a non-zero count would have
	// returned above) and DOM was empty too. Return an empty response rather
	// than rpcResponse, whose pages may be non-empty but contain zero reviews —
	// callers treat non-empty pages as "has reviews" and would stop retrying.
	return FetchReviewsResponse{}, nil, nil
}
