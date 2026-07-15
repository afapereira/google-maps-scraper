# Graph Report - .  (2026-07-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 4937 nodes · 10524 edges · 276 communities (259 shown, 17 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 1740 edges (avg confidence: 0.79)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bcf75734`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- generated-structs.go
- xterm.min.js
- pageImpl
- BeforeEach
- k
- P
- worker_jobs.go
- c
- routeImpl
- locatorAssertionsImpl
- browserContextImpl
- helpers.go
- har_test.go
- i
- d
- PlaywrightDriver
- elementHandleImpl
- Position
- frameImpl
- constructor
- t
- locator_test.go
- store
- Entry
- locatorImpl
- fetch-public-proxies.sh
- Provisioner
- s
- Config
- generated-enums.go
- EventEmitter
- locator_helpers.go
- webSocketRouteImpl
- browser_context_test.go
- h
- connection
- IJob
- channel
- serializeArgument
- Request
- AuthProxy
- CreateSeedJobs
- fromChannel
- dbrunner
- route_test.go
- channelOwner
- element_handle_test.go
- n
- fetch_test.go
- playwrightRuntime
- .Work
- Client
- countingConn
- Worker
- .getMate
- Job
- testServer
- .Len
- requestImpl
- locator_assertions_test.go
- .get
- generated-interfaces.go
- remapMapToStruct
- BrowserNewContextOptions
- renderTemplate
- .Is
- provision.go
- api.go
- AppPlatformProvisioner
- BrowserPage
- artifactImpl
- browser_type_test.go
- Routes
- cryptoext.go
- o
- pageSlot
- .handler
- Locator
- Page
- utils_test.go
- ScraperManager
- .Open
- Runner
- frameLocatorImpl
- input_test.go
- StripNULFromEntry
- newSettings
- apiRequestContextImpl
- .push
- parseProduct
- parseReviews
- .Now
- pipeTransport
- responseImpl
- CentralWriter
- NewCentralWriter
- Provider
- ProvisionState
- a
- reviews.go
- jsFetch
- Locator
- _askForLink
- emailjob.go
- scripts.go
- K
- sqlite.go
- unroute_behavior_test.go
- log.go
- EntryFromJSON
- MockCacher
- ScrapemateApp
- frame_locator_test.go
- .Process
- .Process
- SessionFromContext
- responses.go
- .Run
- SearchJob
- MockHTTPFetcher
- MockProxyRotator
- localUtilsImpl
- resultWriter
- memoryJobRepo
- scrape-full-coverage.py
- network_test.go
- session_slot_internal_test.go
- run-portugal.sh
- defaultSetupMate
- browser_test.go
- frame_test.go
- page_add_locator_handler_test.go
- page_aria_snapshot_test.go
- Service
- DeleteAllFilteredJobsHandler
- GetLoggerFromContext
- csvWriter
- main.go
- scrape.py
- scrape.ts
- ingest-bridge.js
- MockJobProvider
- apiResponseImpl
- rawHeaders
- .Call
- WaitUntilState
- selectorsImpl
- provider
- .Process
- gen-booster-queries.mjs
- page_clock_test.go
- tracing_test.go
- middleware.go
- Exiter
- fakeRuntime
- MockResultWriter
- clockImpl
- convertInputFiles
- tracingImpl
- webSocketImpl
- Store
- manifest.json
- JobDeleteArgs
- resolveGlobToRegex
- worker_test.go
- Prompter
- HTTPServer
- .Run
- MockHTMLParser
- Playwright
- OptionalStorageState
- videoImpl
- console_message_test.go
- locator_get_by_test.go
- .Process
- infra.go
- apiResponseAssertionsImpl
- dialogImpl
- .withElement
- pool.go
- .Process
- event_emitter_test.go
- js_handle_test.go
- route_web_socket_test.go
- .ValidateAPIKey
- runHealthServer
- .Run
- Client
- ProxyPool
- AriaRole
- binding_test.go
- websocket_test.go
- Job
- NewAppState
- .Run
- Uploader
- NewProxy
- routeHandlerEntry
- github.com/gosom/scrapemate
- dialog_test.go
- page_assertions_test.go
- AppState
- xterm-addon-fit.min.js
- hashmap
- run-restaurants-json.sh
- CreateRiverUIHandler
- browser.go
- cdp_session_test.go
- selectors_get_by_test.go
- TestSelectorsShouldWorkWithPath
- Page
- PROVISION
- ratelimit.go
- Response
- main.go
- main.go
- TestAssertionsResponseIsOKPass
- TestDownloadBasic
- GoQueryHTMLParser
- TestSetPayloadsIncludesBrowserPoolConfig
- main.go
- TestPageRequestGC
- apply-scrapemate-patches.sh
- run-restaurants-json.sh
- apply-patch.sh
- generate-api.sh
- update-patch.sh
- generate.sh

## God Nodes (most connected - your core abstractions)
1. `BeforeEach()` - 477 edges
2. `pageImpl` - 163 edges
3. `k` - 105 edges
4. `browserContextImpl` - 87 edges
5. `frameImpl` - 78 edges
6. `locatorImpl` - 73 edges
7. `channelOwner` - 71 edges
8. `d` - 68 edges
9. `constructor()` - 67 edges
10. `Entry` - 63 edges

## Surprising Connections (you probably didn't know these)
- `TwoFactorSetupPageHandler()` --calls--> `GenerateQRCode()`  [INFERRED]
  admin/handlers_2fa.go → cryptoext/cryptoext.go
- `TwoFactorSetupSubmitHandler()` --calls--> `GenerateBackupCodes()`  [INFERRED]
  admin/handlers_2fa.go → cryptoext/cryptoext.go
- `TwoFactorSetupSubmitHandler()` --calls--> `HashBackupCodes()`  [INFERRED]
  admin/handlers_2fa.go → cryptoext/cryptoext.go
- `TwoFactorSetupPageHandler()` --calls--> `Generate()`  [INFERRED]
  admin/handlers_2fa.go → infra/cloudinit/cloudinit.go
- `TwoFactorSetupSubmitHandler()` --calls--> `Generate()`  [INFERRED]
  admin/handlers_2fa.go → infra/cloudinit/cloudinit.go

## Import Cycles
- None detected.

## Communities (276 total, 17 thin omitted)

### Community 0 - "generated-structs.go"
Cohesion: 0.01
Nodes (144): APIRequestContextDeleteOptions, APIRequestContextDisposeOptions, APIRequestContextFetchOptions, APIRequestContextGetOptions, APIRequestContextHeadOptions, APIRequestContextPatchOptions, APIRequestContextPostOptions, APIRequestContextPutOptions (+136 more)

### Community 1 - "xterm.min.js"
Cohesion: 0.02
Nodes (87): addDcsHandler(), addDecoration(), _addLineToZone(), _addMouseDownListeners(), addOscHandler(), _applyScrollModifier(), _areCoordsInSelection(), areSelectionValuesReversed() (+79 more)

### Community 2 - "pageImpl"
Cohesion: 0.02
Nodes (33): Download, FileChooser, Frame, FrameDispatchEventOptions, FrameEvalOnSelectorOptions, FrameFillOptions, FrameFocusOptions, FrameGetAttributeOptions (+25 more)

### Community 3 - "BeforeEach"
Cohesion: 0.07
Nodes (77): BeforeEach(), T, TestCloseShouldRunBeforunloadIfAskedFor(), TestPageAddInitScript(), TestPageAddInitScriptWithPath(), TestPageAddScriptTag(), TestPageAddScriptTagFile(), TestPageAddStyleTag() (+69 more)

### Community 4 - "k"
Cohesion: 0.06
Nodes (3): k, setgLevel(), w()

### Community 5 - "P"
Cohesion: 0.05
Nodes (6): compositionstart(), handleFocus(), P, register(), selectAll(), selectLines()

### Community 6 - "worker_jobs.go"
Cohesion: 0.07
Nodes (47): Addr, Config, HostKeyCallback, boolStr(), composeYAML(), dockerLoginCmd(), Generate(), GenerateEnvFileContent() (+39 more)

### Community 7 - "c"
Cohesion: 0.04
Nodes (19): addEscHandler(), addLineToLink(), addMarker(), c(), clearAllMarkers(), clearMarkers(), end(), _getEntryIdKey() (+11 more)

### Community 8 - "routeImpl"
Cohesion: 0.06
Nodes (20): Job, Browser, BrowserContext, browserImpl, BrowserType, browserTypeImpl, routeImpl, Page (+12 more)

### Community 9 - "locatorAssertionsImpl"
Cohesion: 0.06
Nodes (19): assertionsBase, expectedTextValue, frameExpectOptions, frameExpectResult, LocatorAssertions, locatorAssertionsImpl, PageAssertions, pageAssertionsImpl (+11 more)

### Community 10 - "browserContextImpl"
Cohesion: 0.06
Nodes (12): browserContextImpl, browserContextRecordIntoHarOptions, BrowserContextWaitForEventOptions, Clock, ExposedFunction, Page, Response, routeHandler (+4 more)

### Community 11 - "helpers.go"
Cohesion: 0.08
Nodes (25): FrameSelectOptionOptions, HarContentPolicy, HarMode, harRecordingMetadata, recordHarInputOptions, recordHarOptions, safeValue, safeValue[T] (+17 more)

### Community 12 - "har_test.go"
Cohesion: 0.08
Nodes (49): T, NewTLSServerRequireClientCert(), TestClientCerts(), T, TestBrowserContextStorageStateRoundTripThroughConvert(), TestBrowserContextStorageStateRoundTripThroughTheFile(), TestBrowserContextStorageStateSetLocalStorage(), TestBrowserContextStorageStateShouldCaptureLocalStorage() (+41 more)

### Community 13 - "i"
Cohesion: 0.06
Nodes (9): _addStyle(), _applyMinimumContrast(), createRow(), getColor(), _getContrastCache(), i(), setColor(), setFont() (+1 more)

### Community 14 - "d"
Cohesion: 0.05
Nodes (3): clearTextureAtlas(), d, hook()

### Community 15 - "PlaywrightDriver"
Cohesion: 0.08
Nodes (35): HTTPClient, httpFetch, PipeReader, PlaywrightDriver, RunOptions, downloadDriver(), getDefaultCacheDirectory(), getDriverCliJs() (+27 more)

### Community 16 - "elementHandleImpl"
Cohesion: 0.05
Nodes (6): elementHandleImpl, FrameExpectNavigationOptions, FrameGotoOptions, fromNullableChannel(), newElementHandle(), Response

### Community 17 - "Position"
Cohesion: 0.06
Nodes (40): ElementHandleCheckOptions, ElementHandleClickOptions, ElementHandleDblclickOptions, ElementHandleHoverOptions, ElementHandleSetCheckedOptions, ElementHandleTapOptions, ElementHandleUncheckOptions, FrameCheckOptions (+32 more)

### Community 18 - "frameImpl"
Cohesion: 0.05
Nodes (6): frameImpl, Page, Response, Set, newFrame(), Float()

### Community 19 - "constructor"
Cohesion: 0.07
Nodes (46): addEncoding(), addProtocol(), _clearLiveRegion(), clearRange(), constructor(), _createAccessibilityTreeNode(), createInstance(), disable() (+38 more)

### Community 20 - "t"
Cohesion: 0.08
Nodes (37): addRefreshCallback(), _cancelCallback(), compositionend(), event(), _finalizeComposition(), _handleAnyTextareaChanges(), _handleSelectionChange(), _innerRefresh() (+29 more)

### Community 21 - "locator_test.go"
Cohesion: 0.09
Nodes (44): T, TestLocatorAllInnerTexts(), TestLocatorAllShouldWork(), TestLocatorAllTextContents(), TestLocatorAndFrameLocatorShouldAcceptLocator(), TestLocatorDescribe(), TestLocatorDescribeChained(), TestLocatorDescribeMultipleCalls() (+36 more)

### Community 22 - "store"
Cohesion: 0.10
Nodes (16): Time, APIKey, AppConfig, IStore, Context, Duration, IStore, Pool (+8 more)

### Community 23 - "Entry"
Cohesion: 0.08
Nodes (30): About, Address, Entry, addOrMergeOption(), collectCategories(), decodeURL(), extractActualURL(), extractReviews() (+22 more)

### Community 24 - "locatorImpl"
Cohesion: 0.11
Nodes (5): locatorImpl, LocatorTypeOptions, assignStructFields(), Page, Bool()

### Community 25 - "fetch-public-proxies.sh"
Cohesion: 0.10
Nodes (36): collect_clarketm(), collect_geonode(), collect_getproxylist(), collect_github_speedx_monosans(), collect_hw630590(), collect_jetkai(), collect_mmpx12(), collect_openproxylist_xyz() (+28 more)

### Community 26 - "Provisioner"
Cohesion: 0.09
Nodes (22): provisioner, Droplet, Provisioner, extractPublicIPv4(), Client, Context, Size, init() (+14 more)

### Community 27 - "s"
Cohesion: 0.06
Nodes (3): addCsiHandler(), registerCsiHandler(), s()

### Community 28 - "Config"
Cohesion: 0.15
Nodes (32): New(), ScrapemateApp, Writer, AppendBrowserCapacityOptions(), Config, jsOptions, ScrapemateApp, T (+24 more)

### Community 29 - "generated-enums.go"
Cohesion: 0.07
Nodes (35): BrowserContextRouteFromHAROptions, BrowserContextUnrouteAllOptions, Contrast, ElementHandleWaitForSelectorOptions, ElementState, FrameWaitForLoadStateOptions, FrameWaitForSelectorOptions, HarNotFound (+27 more)

### Community 30 - "EventEmitter"
Cohesion: 0.10
Nodes (18): EventEmitter, eventListener, eventRegister, listener, waiter, Mutex, NewEventEmitter(), Mutex (+10 more)

### Community 31 - "locator_helpers.go"
Cohesion: 0.10
Nodes (16): FrameLocatorOptions, Locator, convertRegexp(), escapeForAttributeSelector(), escapeForTextSelector(), escapeRegexForSelector(), getByAltTextSelector(), getByAttributeTextSelector() (+8 more)

### Community 32 - "webSocketRouteImpl"
Cohesion: 0.10
Nodes (13): serverWebSocketRouteImpl, urlMatcher, WebSocketRoute, webSocketRouteHandler, webSocketRouteImpl, Regexp, newURLMatcher(), newServerWebSocketRoute() (+5 more)

### Community 33 - "browser_context_test.go"
Cohesion: 0.12
Nodes (33): expectPageCookies(), T, TestBrowerContextEventsShouldFireInProperOrder(), TestBrowserContextAddCookies(), TestBrowserContextAddInitScript(), TestBrowserContextAddInitScriptWithPath(), TestBrowserContextClearCookies(), TestBrowserContextClose() (+25 more)

### Community 34 - "h"
Cohesion: 0.10
Nodes (10): _convertViewportColToCharacterIndex(), fire(), getJoinedCharacters(), _getWordAt(), h(), _isCharWordSeparator(), provideLinks(), _reflowSmaller() (+2 more)

### Community 35 - "connection"
Cohesion: 0.11
Nodes (13): Int32, connection, parsedStackTrace, protocolCallback, rootChannelOwner, newRootChannelOwner(), Call, Once (+5 more)

### Community 36 - "IJob"
Cohesion: 0.13
Nodes (15): memoryProvider, HTMLParser, IJob, ScrapeMate, Signal, Stringer, Context, CancelCauseFunc (+7 more)

### Community 37 - "channel"
Cohesion: 0.09
Nodes (10): channel, keyboardImpl, mouseImpl, touchscreenImpl, eventEmitter, newChannel(), newKeyboard(), newMouse() (+2 more)

### Community 38 - "serializeArgument"
Cohesion: 0.08
Nodes (15): Error, FrameWaitForFunctionOptions, JSHandle, jsHandleImpl, parseError(), targetClosedError(), Reader, T (+7 more)

### Community 39 - "Request"
Cohesion: 0.15
Nodes (19): PageExpectRequestFinishedOptions, Request, UUID, apiError, apiScrapeResponse, ctxKey, formData, Server (+11 more)

### Community 40 - "AuthProxy"
Cohesion: 0.13
Nodes (16): Auth, AuthProxy, ProxyType, createHTTPProxyClient(), createSOCKS5ProxyClient(), Client, Conn, Logger (+8 more)

### Community 41 - "CreateSeedJobs"
Cohesion: 0.13
Nodes (25): Deduper, GmapJob, GmapJobOptions, Job, isGoogleMapsURL(), NewGmapJob(), WithDeduper(), WithExitMonitor() (+17 more)

### Community 42 - "fromChannel"
Cohesion: 0.09
Nodes (12): CDPSession, ElementHandle, ElementHandleSetInputFilesOptions, fileChooserImpl, FrameAddScriptTagOptions, FrameAddStyleTagOptions, FrameQuerySelectorOptions, PageAddScriptTagOptions (+4 more)

### Community 43 - "dbrunner"
Cohesion: 0.09
Nodes (20): dbrunner, service, service, Config, Context, DB, ScrapemateApp, openPsqlConn() (+12 more)

### Community 44 - "route_test.go"
Cohesion: 0.11
Nodes (27): M, AfterAll(), AssertToBeGolden(), BeforeAll(), getGoldenFilename(), T, TestMain(), writeGoldenFile() (+19 more)

### Community 45 - "channelOwner"
Cohesion: 0.11
Nodes (13): cdpSessionImpl, channelOwner, dummyObject, streamImpl, writableStream, newCDPSession(), eventEmitter, RWMutex (+5 more)

### Community 46 - "element_handle_test.go"
Cohesion: 0.12
Nodes (30): T, TestElementBoundingBox(), TestElementHandleCheck(), TestElementHandleClick(), TestElementHandleContentFrame(), TestElementHandleDblclick(), TestElementHandleDispatchEvent(), TestElementHandleDispatchEventInitObject() (+22 more)

### Community 47 - "n"
Cohesion: 0.09
Nodes (3): charProperties(), n(), wcwidth()

### Community 48 - "fetch_test.go"
Cohesion: 0.14
Nodes (28): T, TestErrorWhenMaxRedirectsIsLessThanZero(), TestFetchShouldNotThrowWhenFailOnStatusCodeIsFalse(), TestFetchShouldRetryECONNRESET(), TestFetchShouldThrowWhenFailOnStatusCodeIsTrue(), TestFetchShouldWork(), TestShouldAcceptAlreadySerializedDataAsBytesWhenContentTypeIsApplicationJson(), TestShouldDisposeGlobalRequest() (+20 more)

### Community 49 - "playwrightRuntime"
Cohesion: 0.14
Nodes (9): page, playwrightPage, playwrightRuntime, runtimeFactory, sessionSlot, slotRuntime, applyStealth(), newBrowser() (+1 more)

### Community 50 - ".Work"
Cohesion: 0.12
Nodes (21): Warn(), JobListItem, JobListResult, effectiveScrapeTimeout(), GetScrapeWatchdogMetrics(), Duration, InsertOpts, Job (+13 more)

### Community 51 - "Client"
Cohesion: 0.15
Nodes (13): Logger, With(), RawMessage, Client, DashboardStats, JobStatus, decodeJobID(), encodeJobID() (+5 more)

### Community 52 - "countingConn"
Cohesion: 0.09
Nodes (18): init(), NamedValue, Script, countingConn, countingDriver, countingTx, Context, DB (+10 more)

### Community 53 - "Worker"
Cohesion: 0.09
Nodes (9): BrowserContextExpectConsoleMessageOptions, ConsoleMessage, consoleMessageImpl, PageExpectConsoleMessageOptions, PageExpectWorkerOptions, Worker, workerImpl, Page (+1 more)

### Community 54 - ".getMate"
Cohesion: 0.20
Nodes (22): HTTPFetcher, newJSFetcher(), Result, main(), run(), writeCsv(), New(), getMockedServices() (+14 more)

### Community 55 - "Job"
Cohesion: 0.10
Nodes (5): Job, RetryPolicy, Context, Duration, Response

### Community 56 - "testServer"
Cohesion: 0.11
Nodes (9): CloseError, MessageType, ServeMux, testServer, wsConnection, Config, Conn, HandlerFunc (+1 more)

### Community 57 - ".Len"
Cohesion: 0.14
Nodes (19): T, loadReviewsFixture(), Test_extractPlaceID(), Test_parseReviews_Aggregator(), Test_parseReviews_NativeNoTranslation(), Test_parseReviews_NativeWithReply(), Test_parseReviews_NoText(), Rotator (+11 more)

### Community 58 - "requestImpl"
Cohesion: 0.10
Nodes (6): requestImpl, RequestTiming, RouteFallbackOptions, serializedFallbackOverrides, Response, newRequest()

### Community 59 - "locator_assertions_test.go"
Cohesion: 0.14
Nodes (26): T, TestLocatorAssertionsToBeChecked(), TestLocatorAssertionsToBeDisabled(), TestLocatorAssertionsToBeEditable(), TestLocatorAssertionsToBeEmpty(), TestLocatorAssertionsToBeEnabled(), TestLocatorAssertionsToBeFocused(), TestLocatorAssertionsToBeHidden() (+18 more)

### Community 61 - "generated-interfaces.go"
Cohesion: 0.08
Nodes (13): APIRequestContext, Dialog, Keyboard, Locator, Mouse, Page, Response, Touchscreen (+5 more)

### Community 62 - "remapMapToStruct"
Cohesion: 0.10
Nodes (17): ConsoleMessageLocation, RequestSizesResult, ResponseSecurityDetailsResult, ResponseServerAddrResult, testOptionsJSONSerialization, Cookie, StorageState, remapMapToStruct() (+9 more)

### Community 63 - "BrowserNewContextOptions"
Cohesion: 0.14
Nodes (24): APIRequestNewContextOptions, BrowserNewContextOptions, BrowserNewPageOptions, BrowserTypeLaunchOptions, BrowserTypeLaunchPersistentContextOptions, ClientCertificate, ColorScheme, ForcedColors (+16 more)

### Community 64 - "renderTemplate"
Cohesion: 0.12
Nodes (21): AppState, HandlerFunc, init(), LoginPageHandler(), LoginSubmitHandler(), LogoutHandler(), DashboardHandler(), AppState (+13 more)

### Community 65 - ".Is"
Cohesion: 0.26
Nodes (22): GetAppURL(), Provisioner, NewVPSProvisioner(), NewVPSProvisionerWithKey(), initHetzner(), initVPS(), New(), generateTestKeyPair() (+14 more)

### Community 66 - "provision.go"
Cohesion: 0.27
Nodes (12): createNewDB(), Context, Provisioner, initDO(), setupDatabase(), toAbsolutePath(), useExistingDB(), dbStrategy (+4 more)

### Community 67 - "api.go"
Cohesion: 0.18
Nodes (22): containsNotFound(), deleteJobHandler(), getJobHandler(), Client, HandlerFunc, ResponseWriter, Router, healthCheckHandler() (+14 more)

### Community 68 - "AppPlatformProvisioner"
Cohesion: 0.16
Nodes (12): AppRegion, DatabaseEngineOptions, AppPlatformProvisioner, ImageSourceSpec, ImageSourceSpecRegistryType, buildImageSpec(), Client, Context (+4 more)

### Community 69 - "BrowserPage"
Cohesion: 0.15
Nodes (16): clickRejectCookiesIfRequired(), Context, Response, scroll(), waitUntilURLContains(), MentionedKeyword, Context, Job (+8 more)

### Community 70 - "artifactImpl"
Cohesion: 0.10
Nodes (5): artifactImpl, downloadImpl, newArtifact(), Page, newDownload()

### Community 71 - "browser_type_test.go"
Cohesion: 0.16
Nodes (20): remoteServer, T, TestBrowserTypeBrowserName(), TestBrowserTypeConnect(), TestBrowserTypeConnectArtifactPath(), TestBrowserTypeConnectOverCDP(), TestBrowserTypeConnectOverCDPTwice(), TestBrowserTypeConnectShouldBeAbleToReconnectToBrowser() (+12 more)

### Community 72 - "Routes"
Cohesion: 0.20
Nodes (20): AppState, HandlerFunc, pendingBackupCodesKey(), TwoFactorDisableHandler(), TwoFactorPromptPageHandler(), TwoFactorSetupPageHandler(), TwoFactorSetupSubmitHandler(), TwoFactorVerifyPageHandler() (+12 more)

### Community 73 - "cryptoext.go"
Cohesion: 0.11
Nodes (15): centerText(), PrintBanner(), PrintCredentials(), Context, runCreateUser(), Command, GenerateBackupCodes(), GenerateEncryptionKey() (+7 more)

### Community 74 - "o"
Cohesion: 0.12
Nodes (3): getCoords(), getMouseReportCoords(), o()

### Community 75 - "pageSlot"
Cohesion: 0.15
Nodes (15): fakeSlotFactory, pageLease, pageSlot, pageSlotFactory, pageSlotPool, pageSlotPoolConfig, playwrightSlotFactory, Context (+7 more)

### Community 76 - ".handler"
Cohesion: 0.16
Nodes (11): invoker, lambdaAwsRunner, lInput, Client, Config, Context, NewInvoker(), copyDir() (+3 more)

### Community 77 - "Locator"
Cohesion: 0.16
Nodes (4): LocatorOptions, Locator, escapeText(), newLocator()

### Community 78 - "Page"
Cohesion: 0.13
Nodes (6): Locator, Page, Duration, Locator, WaitUntilState, toPlaywrightWaitUntil()

### Community 79 - "utils_test.go"
Cohesion: 0.13
Nodes (12): R, syncSlice, syncSlice[T], testUtils, chromiumVersionLessThan(), getFileLastModifiedTimeMs(), Mutex, Page (+4 more)

### Community 80 - "ScraperManager"
Cohesion: 0.14
Nodes (11): Context, Int64, Pool, RWMutex, NewScraperManager(), T, TestScraperManagerSubmitJobAllowsNonMapsJobs(), TestScraperManagerSubmitJobRequiresManagedSearchJob() (+3 more)

### Community 81 - ".Open"
Cohesion: 0.16
Nodes (13): File, fileRunner, Conn, Config, Context, Reader, ScrapemateApp, New() (+5 more)

### Community 82 - "Runner"
Cohesion: 0.13
Nodes (17): installer, Config, main(), runnerFactory(), Connect(), Context, Pool, Config (+9 more)

### Community 83 - "frameLocatorImpl"
Cohesion: 0.21
Nodes (4): FrameLocator, frameLocatorImpl, Locator, newFrameLocator()

### Community 84 - "input_test.go"
Cohesion: 0.18
Nodes (20): T, TestElementHandleFill(), TestElementHandlePress(), TestElementHandleType(), TestKeyboardDown(), TestKeyboardInsertPress(), TestKeyboardInsertText(), TestKeyboardType() (+12 more)

### Community 85 - "StripNULFromEntry"
Cohesion: 0.26
Nodes (18): LinkSource, cleanAbout(), cleanAddress(), cleanImages(), cleanLinkSource(), cleanLinkSources(), cleanOpenHours(), cleanOwner() (+10 more)

### Community 86 - "newSettings"
Cohesion: 0.19
Nodes (16): OrderedHeaders, proxyFetcher, settings, stealthFetch, chromeHeaders(), edgeHeaders(), firefoxHeaders(), newSettings() (+8 more)

### Community 87 - "apiRequestContextImpl"
Cohesion: 0.21
Nodes (10): apiRequestContextImpl, apiRequestImpl, APIResponse, RouteFulfillOptions, countNonNil(), isJsonContentType(), newAPIRequestContext(), newApiRequestImpl() (+2 more)

### Community 88 - ".push"
Cohesion: 0.13
Nodes (7): getBufferElements(), _mergeRanges(), registerHandler(), _removeIntersectingLinks(), selectionText(), translateBufferLineToString(), translateToString()

### Community 89 - "parseProduct"
Cohesion: 0.13
Nodes (13): BookDetailJob, Product, Context, Job, Response, Document, parseAvailability(), parseCurrency() (+5 more)

### Community 90 - "parseReviews"
Cohesion: 0.42
Nodes (12): ensureLen(), T, newReviewElement(), setNested(), setNestedValue(), TestParseReviewsPublishedAtFallsBackToSecondTimestampPath(), TestParseReviewsPublishedAtFromMicrosecondTimestamp(), TestParseReviewsPublishedAtRejectsInvalidTimestamps() (+4 more)

### Community 91 - ".Now"
Cohesion: 0.15
Nodes (13): contextKey, generateRequestID(), Context, Handler, LoggingMiddleware(), RequestIDFromContext(), setContextRequestID(), Mutex (+5 more)

### Community 92 - "pipeTransport"
Cohesion: 0.15
Nodes (10): jsonPipe, message, pipeTransport, transport, Process, newJsonPipe(), Reader, Writer (+2 more)

### Community 94 - "CentralWriter"
Cohesion: 0.16
Nodes (7): CentralWriter, Context, Mutex, Result, Time, FlushResult, trackedJob

### Community 95 - "NewCentralWriter"
Cohesion: 0.30
Nodes (18): Pool, NewCentralWriter(), pgSave(), T, noopSave(), TestCentralWriter_AddResultAfterFlush(), TestCentralWriter_AddResultThenFlush(), TestCentralWriter_DiscardDropsTrackedJobWithoutSave() (+10 more)

### Community 96 - "Provider"
Cohesion: 0.19
Nodes (12): Provider, Context, Mutex, Once, WaitGroup, NewProvider(), T, TestProviderCloseIsIdempotent() (+4 more)

### Community 97 - "ProvisionState"
Cohesion: 0.13
Nodes (24): BuildAndPushImage(), buildAndPushImage(), run(), DeleteState(), EnsureStateDir(), Time, LoadState(), SaveState() (+16 more)

### Community 98 - "a"
Cohesion: 0.21
Nodes (5): a(), _announceCharacters(), _createSelectionElement(), handleSelectionChanged(), _renderRows()

### Community 99 - "reviews.go"
Cohesion: 0.30
Nodes (12): DOMReview, fetcher, fetchReviewsParams, FetchReviewsResponse, ConvertDOMReviewsToReviews(), extractNextPageToken(), extractPlaceID(), extractReviewsFromPage() (+4 more)

### Community 100 - "jsFetch"
Cohesion: 0.21
Nodes (9): browser, jsFetch, JSFetcherOptions, ProxyRotator, NewPage(), Context, Response, New() (+1 more)

### Community 101 - "Locator"
Cohesion: 0.18
Nodes (16): ElementHandleScreenshotOptions, FrameLocatorLocatorOptions, LocatorFilterOptions, LocatorLocatorOptions, LocatorScreenshotOptions, PageLocatorOptions, PageScreenshotOptions, ScreenshotAnimations (+8 more)

### Community 102 - "_askForLink"
Cohesion: 0.19
Nodes (15): _askForLink(), _checkLinkProviderResult(), _clearCurrentLink(), _createLinkUnderlineEvent(), _fireUnderlineEvent(), _getMouseEventScrollAmount(), _handleHover(), _handleMouseMove() (+7 more)

### Community 104 - "emailjob.go"
Cohesion: 0.18
Nodes (13): EmailExtractJob, EmailExtractJobOptions, docEmailExtractor(), getValidEmail(), Context, Document, Job, Response (+5 more)

### Community 105 - "scripts.go"
Cohesion: 0.24
Nodes (10): Client, Context, generateCaddyfile(), GenerateDBScript(), GenerateDeployScript(), GenerateSetupScript(), WrapScript(), DeployScriptConfig (+2 more)

### Community 106 - "K"
Cohesion: 0.25
Nodes (6): K, SyncMap, SyncMap[K, V], RWMutex, NewSyncMap(), V

### Community 107 - "sqlite.go"
Cohesion: 0.27
Nodes (10): job, repo, scannable, createSchema(), Context, DB, Job, initDatabase() (+2 more)

### Community 108 - "unroute_behavior_test.go"
Cohesion: 0.23
Nodes (15): T, TestContextCloseShouldNotWaitForActiveRouteHandlersOnTheOwnedPages(), TestContextUnrouteAllRemovesAllHandlers(), TestContextUnrouteAllShouldNotWaitForPendingHandlersToComplete(), TestContextUnrouteAllShouldNotWaitForPendingHandlersToCompleteIfBehaviorIsIgnoreErrors(), TestContextUnrouteShouldNotWaitForPendingHandlersToComplete(), TestPageCloseDoesNotWaitForActiveRouteHandlers(), TestPageCloseShouldNotWaitForActiveRouteHandlersOnTheOwningContext() (+7 more)

### Community 109 - "log.go"
Cohesion: 0.17
Nodes (12): AppState, HandlerFunc, TerminalPageHandler(), TerminalWSHandler(), terminalSize, Level, Debug(), DebugContext() (+4 more)

### Community 110 - "EntryFromJSON"
Cohesion: 0.15
Nodes (23): EntryFromJSON(), getHours(), getLinkSource(), getNthElementAndCast(), getOptionValues(), getPopularTimes(), T, postalCodeFromAddress() (+15 more)

### Community 111 - "MockCacher"
Cohesion: 0.24
Nodes (7): MockCacher, MockCacherMockRecorder, Call, Context, Controller, Response, NewMockCacher()

### Community 112 - "ScrapemateApp"
Cohesion: 0.14
Nodes (12): Cacher, JobProvider, New(), main(), run(), main(), run(), CancelCauseFunc (+4 more)

### Community 113 - "frame_locator_test.go"
Cohesion: 0.34
Nodes (14): Page, T, routeAmbiguous(), routeIframe(), TestFrameLocatorContentFrameShouldWork(), TestFrameLocatorFirst(), TestFrameLocatorGetByCoverage(), TestFrameLocatorLast() (+6 more)

### Community 114 - ".Process"
Cohesion: 0.17
Nodes (10): Context, Document, Job, QuoteCollectJob, Response, NewQuoteCollectJob(), parseNextPage(), Document (+2 more)

### Community 115 - ".Process"
Cohesion: 0.17
Nodes (10): Context, Document, Job, QuoteCollectJob, Response, NewQuoteCollectJob(), parseNextPage(), Document (+2 more)

### Community 116 - "SessionFromContext"
Cohesion: 0.36
Nodes (13): buildWorkerViews(), DeleteWorkerHandler(), DownloadSSHKeyHandler(), AppState, HandlerFunc, ProvisionWorkerHandler(), SaveProviderTokenHandler(), WorkersPageHandler() (+5 more)

### Community 117 - "responses.go"
Cohesion: 0.18
Nodes (11): DeleteJobResponse, ErrorResponse, GmapData, HealthCheckResponse, JobStatusResponse, JobSummary, ListJobsRequest, ListJobsResponse (+3 more)

### Community 118 - ".Run"
Cohesion: 0.29
Nodes (10): BoundingBox, Cell, calculateLonStep(), EstimateCellCount(), GenerateCells(), normalizeCellSizeKm(), ParseBoundingBox(), T (+2 more)

### Community 119 - "SearchJob"
Cohesion: 0.23
Nodes (12): MapLocation, MapSearchParams, SearchJob, buildGoogleMapsParams(), Context, Job, Response, NewSearchJob() (+4 more)

### Community 120 - "MockHTTPFetcher"
Cohesion: 0.22
Nodes (8): MockHTTPFetcher, MockHTTPFetcherMockRecorder, mockedServices, Call, Context, Controller, Response, NewMockHTTPFetcher()

### Community 121 - "MockProxyRotator"
Cohesion: 0.24
Nodes (6): MockProxyRotator, MockProxyRotatorMockRecorder, Call, Controller, Response, NewMockProxyRotator()

### Community 122 - "localUtilsImpl"
Cohesion: 0.19
Nodes (5): harLookupOptions, harLookupResult, localUtilsImpl, localUtilsZipOptions, newLocalUtils()

### Community 123 - "resultWriter"
Cohesion: 0.30
Nodes (9): resultWriter, Context, DB, Duration, Result, Time, isJSONBNULByteError(), marshalEntry() (+1 more)

### Community 124 - "memoryJobRepo"
Cohesion: 0.26
Nodes (6): Context, Job, T, TestScrapeJobMarksOKBeforeClosingMate(), fakeMate, memoryJobRepo

### Community 125 - "scrape-full-coverage.py"
Cohesion: 0.23
Nodes (13): _build_docker_cmd(), estimate_cell_count(), load_existing(), main(), merge_into(), place_uid(), Rough cell count estimate (lat × lon, rectangular approximation)., Run one full-bbox pass at cell_km resolution. Returns parsed place list. (+5 more)

### Community 126 - "network_test.go"
Cohesion: 0.27
Nodes (11): T, TestNetworkEventsRequest(), TestNetworkEventsResponse(), TestNetworkEventsShouldFireEventsInProperOrder(), TestRequestContinue(), TestRequestFulfill(), TestRequestShouldFireForNavigationRequests(), TestShouldReportIfRequestWasFromServiceWorker() (+3 more)

### Community 127 - "session_slot_internal_test.go"
Cohesion: 0.33
Nodes (11): fakeRuntimeFactory, Context, T, newFakeRuntimeFactoryWithPages(), newJSFetchForTest(), TestGetSlotWaitsAtCapacityInsteadOfCreatingOverflowBrowser(), TestSessionSlotCleanupLeavesSinglePrimaryPage(), TestSessionSlotInitializeIsLazy() (+3 more)

### Community 128 - "run-portugal.sh"
Cohesion: 0.47
Nodes (12): die(), DISABLE_TELEMETRY, log(), need_feed_env(), need_proxies(), need_scraper(), phase_base(), phase_boost() (+4 more)

### Community 129 - "defaultSetupMate"
Cohesion: 0.40
Nodes (8): defaultSetupMate(), Config, Context, Job, Writer, New(), mateRunner, webrunner

### Community 130 - "browser_test.go"
Cohesion: 0.28
Nodes (12): T, TestBrowserClose(), TestBrowserIsConnected(), TestBrowserNewContext(), TestBrowserNewContextWithExtraHTTPHeaders(), TestBrowserNewPage(), TestBrowserNewPageWithExtraHTTPHeaders(), TestBrowserShouldErrorUponSecondCreateNewPage() (+4 more)

### Community 131 - "frame_test.go"
Cohesion: 0.28
Nodes (12): T, TestFrameElement(), TestFrameInnerHTML(), TestFrameParent(), TestFrameSetInputFiles(), TestFrameShouldHandleNestedFrames(), TestFrameWaitForNavigationAnchorLinks(), TestFrameWaitForNavigationShouldRespectTimeout() (+4 more)

### Community 132 - "page_add_locator_handler_test.go"
Cohesion: 0.28
Nodes (12): T, TestPageAddLocatorHandlerShouldRemoveLocatorHandler(), TestPageAddLocatorHandlerShouldThrowWhenHandlerTimesOut(), TestPageAddLocatorHandlerShouldThrowWhenPageCloses(), TestPageAddLocatorHandlerShouldWork(), TestPageAddLocatorHandlerShouldWorkWhenOwnerFrameDetaches(), TestPageAddLocatorHandlerShouldWorkWithACustomCheck(), TestPageAddLocatorHandlerShouldWorkWithForceTrue() (+4 more)

### Community 133 - "page_aria_snapshot_test.go"
Cohesion: 0.44
Nodes (12): checkAndMatchSnapshot(), Locator, T, TestShouldSnapshot(), TestShouldSnapshotComplex(), TestShouldSnapshotList(), TestShouldSnapshotListWithAccessibleName(), TestShouldSnapshotListWithList() (+4 more)

### Community 134 - "Service"
Cohesion: 0.31
Nodes (6): JobRepository, Service, Context, Job, NewService(), New()

### Community 135 - "DeleteAllFilteredJobsHandler"
Cohesion: 0.45
Nodes (11): BatchDeleteJobsHandler(), buildJobsRedirectURL(), buildJobsStateRedirectURL(), DeleteAllFilteredJobsHandler(), DeleteJobHandler(), DownloadJobResultsHandler(), AppState, Context (+3 more)

### Community 136 - "GetLoggerFromContext"
Cohesion: 0.23
Nodes (9): BookCollectJob, contextKey, ContextWithLogger(), GetLoggerFromContext(), Context, Logger, Context, Job (+1 more)

### Community 137 - "csvWriter"
Cohesion: 0.20
Nodes (8): csvWriter, CsvCapable, Result, Context, Once, Result, Writer, interfaceIsSlice()

### Community 138 - "main.go"
Cohesion: 0.32
Nodes (10): apiRequest(), Client, main(), pollJob(), processKeyword(), readStdin(), safeFilename(), submitJob() (+2 more)

### Community 139 - "scrape.py"
Cohesion: 0.26
Nodes (11): api_request(), main(), poll_job(), process_keyword(), Convert a string to a safe filename component., Make an API request and return parsed JSON., Submit a scrape job and return {"job_id": ..., "keyword": ...}., Poll a job until completion, then save results. (+3 more)

### Community 140 - "scrape.ts"
Cohesion: 0.27
Nodes (10): JobStatusResponse, main(), parallelLimit(), pollJob(), processKeyword(), readStdin(), safeFilename(), ScrapeResponse (+2 more)

### Community 141 - "ingest-bridge.js"
Cohesion: 0.18
Nodes (10): argv, BASE_URL, DELAY_MS, DRY_RUN, etaMins, inputFile, postWithRetry(), results (+2 more)

### Community 142 - "MockJobProvider"
Cohesion: 0.29
Nodes (6): MockJobProvider, MockJobProviderMockRecorder, Call, Context, Controller, NewMockJobProvider()

### Community 144 - "rawHeaders"
Cohesion: 0.23
Nodes (3): NameValue, rawHeaders, newRawHeaders()

### Community 145 - ".Call"
Cohesion: 0.23
Nodes (8): BindingCall, BindingCallFunction, bindingCallImpl, BindingSource, Page, newBindingCall(), serializeError(), ExposedFunction

### Community 146 - "WaitUntilState"
Cohesion: 0.17
Nodes (10): FrameSetContentOptions, FrameWaitForURLOptions, PageExpectNavigationOptions, PageGoBackOptions, PageGoForwardOptions, PageGotoOptions, PageReloadOptions, PageSetContentOptions (+2 more)

### Community 147 - "selectorsImpl"
Cohesion: 0.26
Nodes (5): selectorsImpl, selectorsOwnerImpl, RWMutex, newSelectorsImpl(), newSelectorsOwner()

### Community 148 - "provider"
Cohesion: 0.27
Nodes (9): encjob, provider, decodeJob(), Context, DB, Mutex, NewProvider(), WithBatchSize() (+1 more)

### Community 149 - ".Process"
Cohesion: 0.27
Nodes (9): LoginCRSFToken, LoginJob, CheckLogin(), Context, Document, Job, Response, NewLoginCRSFToken() (+1 more)

### Community 150 - "gen-booster-queries.mjs"
Cohesion: 0.17
Nodes (9): args, BASE_TERM, counts, DEFAULT_CATS, logPath, OUT, rl, saturated (+1 more)

### Community 151 - "page_clock_test.go"
Cohesion: 0.45
Nodes (11): beforePageClock(), T, pageClockFixture(), TestPageClockFastForward(), TestPageClockFixedTime(), TestPageClockPopup(), TestPageClockRunFor(), TestPageClockStubTimers() (+3 more)

### Community 152 - "tracing_test.go"
Cohesion: 0.32
Nodes (11): getTraceActions(), T, mapInternalAPIToPublic(), parseTrace(), TestBrowserContextOutputTrace(), TestBrowserContextOutputTraceChunk(), TestBrowserContextShouldNoErrorWhenStoppingWithoutStart(), TestBrowserContextTracingOutputMultipleChunks() (+3 more)

### Community 153 - "middleware.go"
Cohesion: 0.31
Nodes (10): contextKey, CSRFProtection(), CSRFTokenFromContext(), generateCSRFToken(), generateRandomCSRFToken(), Context, Handler, IStore (+2 more)

### Community 154 - "Exiter"
Cohesion: 0.22
Nodes (4): CancelFunc, Exiter, Context, Mutex

### Community 156 - "MockResultWriter"
Cohesion: 0.27
Nodes (7): MockResultWriter, MockResultWriterMockRecorder, Call, Context, Controller, Result, NewMockResultWriter()

### Community 157 - "clockImpl"
Cohesion: 0.29
Nodes (3): clockImpl, parseTicks(), parseTime()

### Community 158 - "convertInputFiles"
Cohesion: 0.31
Nodes (9): fileItem, InputFile, inputFiles, convertInputFiles(), getFileLastModifiedMs(), listFiles(), normalizeFilePayloads(), resolvePathsAndDirectoryForInputFiles() (+1 more)

### Community 160 - "webSocketImpl"
Cohesion: 0.25
Nodes (3): WebSocketExpectEventOptions, webSocketImpl, newWebsocket()

### Community 161 - "Store"
Cohesion: 0.31
Nodes (6): Context, Duration, Pool, Store, Result, New()

### Community 162 - "manifest.json"
Cohesion: 0.18
Nodes (10): activeTab, background, index.js, background, scripts, content_scripts, manifest_version, name (+2 more)

### Community 163 - "JobDeleteArgs"
Cohesion: 0.22
Nodes (7): JobDeleteArgs, JobDeleteWorker, Context, InsertOpts, Job, Pool, WorkerDefaults

### Community 164 - "resolveGlobToRegex"
Cohesion: 0.31
Nodes (9): constructURLBasedOnBaseURL(), globMustToRegex(), Regexp, resolveGlobBase(), resolveGlobToRegex(), T, Test_globMustToRegex(), TestURLMatches() (+1 more)

### Community 165 - "worker_test.go"
Cohesion: 0.33
Nodes (10): T, TestConsoleMessageWorker(), TestConsoleMessageWorkerNil(), TestWorkerShouldClearUponCrossProcessNavigation(), TestWorkerShouldEmitCreatedAndDestroyedEvents(), TestWorkerShouldEvaluate(), TestWorkerShouldHaveJSHandlesForConsoleLogs(), TestWorkerShouldReportConsoleLogs() (+2 more)

### Community 166 - "Prompter"
Cohesion: 0.38
Nodes (6): Option, Reader, T, NewPrompter(), Select(), Prompter

### Community 167 - "HTTPServer"
Cohesion: 0.33
Nodes (7): Context, Handler, New(), setupDefaults(), WithAddr(), HTTPServer, Option

### Community 168 - ".Run"
Cohesion: 0.33
Nodes (7): Lead, convertToLead(), Client, Context, Result, New(), leadsDBWriter

### Community 169 - "MockHTMLParser"
Cohesion: 0.31
Nodes (6): MockHTMLParser, MockHTMLParserMockRecorder, Call, Context, Controller, NewMockHTMLParser()

### Community 170 - "Playwright"
Cohesion: 0.27
Nodes (6): APIRequest, DeviceDescriptor, Playwright, Selectors, Size, newPlaywright()

### Community 171 - "OptionalStorageState"
Cohesion: 0.22
Nodes (7): OptionalCookie, OptionalStorageState, Origin, Cookie, StorageState, Cookie, StorageState

### Community 172 - "videoImpl"
Cohesion: 0.33
Nodes (4): videoImpl, Once, Page, newVideo()

### Community 173 - "console_message_test.go"
Cohesion: 0.33
Nodes (9): T, TestConsoleShouldEmitSameLogTwice(), TestConsoleShouldHaveLocationForConsoleAPICalls(), TestConsoleShouldNotFailForWindowObjects(), TestConsoleShouldTriggerCorrectLog(), TestConsoleShouldUseTextForStr(), TestConsoleShouldWork(), TestConsoleShouldWorkForDifferentConsoleAPICalls() (+1 more)

### Community 174 - "locator_get_by_test.go"
Cohesion: 0.36
Nodes (9): T, TestGetByAltText(), TestGetByLabel(), TestGetByPlaceholder(), TestGetByRole(), TestGetByTestId(), TestGetByTestIdEscapeId(), TestGetByText() (+1 more)

### Community 175 - ".Process"
Cohesion: 0.50
Nodes (7): NewPlaceJob(), WithPlaceJobExitMonitor(), WithPlaceJobMaxReviews(), WithPlaceJobRestaurantsOnly(), WithPlaceJobReviewSort(), WithPlaceJobWriterManagedCompletion(), PlaceJobOptions

### Community 176 - "infra.go"
Cohesion: 0.22
Nodes (9): shouldBuildAndPush(), DatabaseInfo, DeployConfig, DockerImageBuilder, HetznerConfig, PlanetScaleConfig, Provisioner, RegistryConfig (+1 more)

### Community 177 - "apiResponseAssertionsImpl"
Cohesion: 0.36
Nodes (5): APIResponseAssertions, apiResponseAssertionsImpl, isTexualMimeType(), newAPIResponseAssertions(), subString()

### Community 178 - "dialogImpl"
Cohesion: 0.28
Nodes (3): dialogImpl, Page, newDialog()

### Community 180 - "pool.go"
Cohesion: 0.44
Nodes (8): ConnectOption, ConnectOptions, Duration, WithMaxConnIdleTime(), WithMaxConnLifetime(), WithMaxConns(), WithMinConns(), WithPingTimeout()

### Community 181 - ".Process"
Cohesion: 0.33
Nodes (6): testJob, testJobWithError, testJobWithNext, Context, Job, Response

### Community 182 - "event_emitter_test.go"
Cohesion: 0.39
Nodes (8): T, TestEventEmitterListenerCount(), TestEventEmitterOn(), TestEventEmitterOnce(), TestEventEmitterOnLessArgsAcceptingReceiver(), TestEventEmitterRemove(), TestEventEmitterRemoveEmpty(), TestEventEmitterRemoveKeepExisting()

### Community 183 - "js_handle_test.go"
Cohesion: 0.39
Nodes (8): T, TestEvaluate(), TestEvaluateTransferTypedArrays(), TestJSHandleEvaluate(), TestJSHandleEvaluateHandle(), TestJSHandleGetProperties(), TestJSHandleGetProperty(), TestJSHandleTypeParsing()

### Community 184 - "route_web_socket_test.go"
Cohesion: 0.56
Nodes (8): assertSlicesEqual(), Page, T, setupWS(), TestRouteWebSocketShouldWorkWithoutServer(), TestRouteWebSocketShouldWorkWithServer(), TestShouldPatterMatch(), TestShouldWorkWithWSClose()

### Community 185 - ".ValidateAPIKey"
Cohesion: 0.29
Nodes (6): Context, IStore, Pool, store, New(), Sha256Hash()

### Community 186 - "runHealthServer"
Cohesion: 0.29
Nodes (4): formatDuration(), Context, Duration, runHealthServer()

### Community 187 - ".Run"
Cohesion: 0.29
Nodes (6): asSlice(), Context, Result, Writer, newWriter(), exampleWriter

### Community 188 - "Client"
Cohesion: 0.39
Nodes (4): Context, Response, New(), Client

### Community 189 - "ProxyPool"
Cohesion: 0.36
Nodes (6): playwrightRuntimeFactory, proxyConfig, ProxyPool, Mutex, NewProxyPool(), parseProxy()

### Community 190 - "AriaRole"
Cohesion: 0.46
Nodes (4): AriaRole, LocatorGetByRoleOptions, getAriaRole(), getByRoleSelector()

### Community 191 - "binding_test.go"
Cohesion: 0.43
Nodes (7): T, TestBrowserContextExposeBinding(), TestBrowserContextExposeBindingHandleShouldWork(), TestBrowserContextExposeBindingPanic(), TestBrowserContextExposeFunction(), TestPageBindingsNoRace(), TestPageExposeBindingPanic()

### Community 192 - "websocket_test.go"
Cohesion: 0.43
Nodes (7): T, TestWebSocketShouldEmitBinaryFrameEvents(), TestWebSocketShouldEmitCloseEvents(), TestWebSocketShouldEmitErrorEvent(), TestWebSocketShouldEmitFrameEvents(), TestWebSocketShouldRejectWaitForEventOnCloseAndError(), TestWebSocketShouldWork()

### Community 193 - "Job"
Cohesion: 0.32
Nodes (6): apiScrapeRequest, Job, Duration, Time, JobData, SelectParams

### Community 194 - "NewAppState"
Cohesion: 0.29
Nodes (6): AppState, Handler, IStore, Store, NewAppState(), StaticFileHandler()

### Community 195 - ".Run"
Cohesion: 0.33
Nodes (5): Encoder, jsonWriter, asSlice(), Context, Result

### Community 196 - "Uploader"
Cohesion: 0.33
Nodes (5): Client, Context, Reader, New(), Uploader

### Community 197 - "NewProxy"
Cohesion: 0.33
Nodes (4): Proxy, NewProxy(), T, TestNewProxy()

### Community 198 - "routeHandlerEntry"
Cohesion: 0.12
Nodes (11): harRouter, Route, routeHandlerEntry, routeHandlerInvocation, Page, newHarRouter(), deserializeNameAndValueToMap(), routeHandler (+3 more)

### Community 199 - "github.com/gosom/scrapemate"
Cohesion: 0.60
Nodes (6): booktoscrapesimple, githbub.com/gosom/scrapemate/quotestoscrapeapp, github.com/gosom/google-maps-scraper, github.com/gosom/scrapemate, github.com/gosom/scrapemate/quotestoscrapelogin, github.com/playwright-community/playwright-go

### Community 201 - "dialog_test.go"
Cohesion: 0.53
Nodes (5): T, TestDialog(), TestDialogAcceptWithText(), TestDialogDismiss(), TestDialogShouldWorkInPopup()

### Community 202 - "page_assertions_test.go"
Cohesion: 0.53
Nodes (5): T, TestPageAssertionsToHaveAccessibleErrorMessage(), TestPageAssertionsToHaveTitle(), TestPageAssertionsToHaveURL(), TestPageAssertionsToHaveURLWithBaseURL()

### Community 203 - "AppState"
Cohesion: 0.40
Nodes (5): Client, IStore, Store, Template, AppState

### Community 205 - "hashmap"
Cohesion: 0.50
Nodes (3): hashmap, Context, RWMutex

### Community 206 - "run-restaurants-json.sh"
Cohesion: 0.60
Nodes (4): DISABLE_TELEMETRY, run_docker(), run_local(), run-restaurants-json.sh script

### Community 207 - "CreateRiverUIHandler"
Cohesion: 0.40
Nodes (4): CreateRiverUIHandler(), Client, Context, Handler

### Community 208 - "browser.go"
Cohesion: 0.40
Nodes (4): Locator, PageResponse, WaitUntilState, Header

### Community 209 - "cdp_session_test.go"
Cohesion: 0.60
Nodes (4): T, TestCDPSessionDetach(), TestCDPSessionOn(), TestCDPSessionSend()

### Community 210 - "selectors_get_by_test.go"
Cohesion: 0.60
Nodes (4): T, TestSelectorsGetByEscaping(), TestSelectorsGetByRoleEscaping(), TestSelectorsIncludeHiddenShouldWork()

### Community 211 - "TestSelectorsShouldWorkWithPath"
Cohesion: 0.60
Nodes (4): T, TestSelectorsRegisterShouldWork(), TestSelectorsShouldUseDataTestIdInStrictErrors(), TestSelectorsShouldWorkWithPath()

### Community 212 - "Page"
Cohesion: 0.50
Nodes (4): BrowserContextExpectPageOptions, BrowserStartTracingOptions, PageExpectPopupOptions, Page

### Community 213 - "PROVISION"
Cohesion: 0.83
Nodes (3): PROVISION script, fail(), info()

### Community 214 - "ratelimit.go"
Cohesion: 0.50
Nodes (3): Time, Result, Store

### Community 215 - "Response"
Cohesion: 0.50
Nodes (3): Response, Duration, Header

### Community 216 - "main.go"
Cohesion: 0.83
Nodes (3): assertErrorToNilf(), main(), startHttpServer()

### Community 217 - "main.go"
Cohesion: 0.83
Nodes (3): assertEqual(), assertErrorToNilf(), main()

### Community 218 - "TestAssertionsResponseIsOKPass"
Cohesion: 0.67
Nodes (3): T, TestAssertionsResponseIsOKPass(), TestAssertionsShouldPrintResponseWithTextContentTypeIfToBeOKFails()

### Community 219 - "TestDownloadBasic"
Cohesion: 0.67
Nodes (3): T, TestDownloadBasic(), TestDownloadCancel()

## Knowledge Gaps
- **210 isolated node(s):** `IStore`, `terminalSize`, `contextKey`, `contextKey`, `ErrorResponse` (+205 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `BeforeEach()` connect `BeforeEach` to `browser_test.go`, `frame_test.go`, `page_add_locator_handler_test.go`, `page_aria_snapshot_test.go`, `har_test.go`, `locator_test.go`, `page_clock_test.go`, `tracing_test.go`, `browser_context_test.go`, `worker_test.go`, `route_test.go`, `console_message_test.go`, `element_handle_test.go`, `locator_get_by_test.go`, `fetch_test.go`, `js_handle_test.go`, `route_web_socket_test.go`, `.Len`, `locator_assertions_test.go`, `binding_test.go`, `websocket_test.go`, `browser_type_test.go`, `dialog_test.go`, `page_assertions_test.go`, `cdp_session_test.go`, `selectors_get_by_test.go`, `TestSelectorsShouldWorkWithPath`, `input_test.go`, `TestAssertionsResponseIsOKPass`, `TestDownloadBasic`, `TestPageRequestGC`, `unroute_behavior_test.go`, `frame_locator_test.go`, `network_test.go`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Why does `channelOwner` connect `channelOwner` to `pageImpl`, `routeImpl`, `browserContextImpl`, `elementHandleImpl`, `.Call`, `frameImpl`, `selectorsImpl`, `tracingImpl`, `webSocketImpl`, `webSocketRouteImpl`, `connection`, `channel`, `serializeArgument`, `Playwright`, `dialogImpl`, `Worker`, `requestImpl`, `artifactImpl`, `apiRequestContextImpl`, `pipeTransport`, `responseImpl`, `localUtilsImpl`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Why does `IJob` connect `IJob` to `GetLoggerFromContext`, `csvWriter`, `MockJobProvider`, `PlaywrightDriver`, `provider`, `.Process`, `Config`, `CreateSeedJobs`, `.Process`, `.Process`, `Job`, `BrowserPage`, `ScraperManager`, `newSettings`, `parseProduct`, `Provider`, `jsFetch`, `emailjob.go`, `.Process`, `.Process`, `SearchJob`, `MockHTTPFetcher`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._
- **Are the 474 inferred relationships involving `BeforeEach()` (e.g. with `TestAssertionsResponseIsOKPass()` and `TestAssertionsShouldPrintResponseWithTextContentTypeIfToBeOKFails()`) actually correct?**
  _`BeforeEach()` has 474 INFERRED edges - model-reasoned connections that need verification._
- **What connects `IStore`, `terminalSize`, `contextKey` to the rest of the system?**
  _210 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `generated-structs.go` be split into smaller, more focused modules?**
  _Cohesion score 0.013984674329501916 - nodes in this community are weakly interconnected._
- **Should `xterm.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.02165889665889666 - nodes in this community are weakly interconnected._