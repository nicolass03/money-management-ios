# money-management-ios — agent notes

## Stack

- **App name:** spendfly (display name + in-app branding; Xcode target/project folder remains `MoneyManagement`).
- **SwiftUI** app, iOS **17+**, committed `MoneyManagement.xcodeproj` (generated from `project.yml` via XcodeGen).
- **Auth:** [supabase-swift](https://github.com/supabase/supabase-swift) — direct `signIn(email:password:)`, not the Next.js `/api/auth/login` proxy.
- **Config:** `Config/Secrets.xcconfig` (gitignored) → `Info.plist` keys `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_URL`.
- **xcconfig URLs:** must use `https:/$()/host.supabase.co` or `http:/$()/127.0.0.1:8080` — `//` starts an xcconfig comment.
- **Rust API:** `APIClient` sends `Authorization: Bearer <Session.accessToken>` to `{API_URL}/api/v1/*`. Shared state in `AppDependencies` (`DataStore` + settings/money-context).

## Caching

- In-memory **`DataStore`** (`Core/Cache/DataStore.swift`) caches API responses per resource key; invalidated keys refetch on next `load()`.
- **`InvalidationMap`** (`Core/Cache/InvalidationMap.swift`) mirrors web `src/lib/query/invalidation.ts` — call `deps.invalidateAfter(.expenseChange)` etc. after mutations.
- **`load(force: true)`** on ViewModels clears cache and refetches everything; pull-to-refresh uses this.
- **`scenePhase == .active`** in `MainTabView` calls `invalidateAll()` + reloads the active tab (app open / return from background — catches daily cron).
- During an active session, switching tabs uses warm cache (no network if data unchanged).
- Settings save invalidates all settings-related keys; dismiss reloads the visible tab.

## Local API dev

- **Simulator:** `API_URL = http:/$()/127.0.0.1:8080` in `Secrets.xcconfig`; run `money-management-api` with `cargo run`.
- **Physical device:** use your Mac's LAN IP instead of `127.0.0.1` (e.g. `http:/$()/192.168.1.10:8080`).
- `Info.plist` sets `NSAllowsLocalNetworking` for HTTP localhost.
- 401 responses trigger automatic sign-out via `APIClient`.

## Architecture

- `AppDependencies` — created in `MainTabView`, holds `APIService`, `DataStore`, and exposes `settings` / `moneyContext` / `displayCurrency` / `rates`.
- Per-tab `@Observable` ViewModels call `APIService` and domain helpers in `Core/Domain/`.
- **Expenses tab** init: `settings` + `money-context`, then parallel `GET /expenses/period-view`, `GET /expenses/upcoming-payable`. No full expense/recurring/planned/budgets/tags fetch on the main tab. `primarySchedule` comes from embedded `GET /settings` response. Per-section **inline skeletons** (`Skeleton.swift`) replace `SectionLoadingMask` on hero and list; shell renders immediately. Tags fetch on expense-form open only.
- **Budgets, income, projections** tabs use the same pattern — page shell + section skeletons; no `LoadingOverlay` on those tabs (`LoadingIndicator` / `LoadingOverlay` kept for auth, settings, sub-routes).
- **Foreground sync:** on `scenePhase == .active`, `AppDependencies.syncOnForeground()` fetches `/settings`, compares `cacheRevision` to `lastSeenCacheRevision`, and only `invalidateAll()` + reloads the active tab when it changed (unchanged data is served from cache — no blanket refetch on every resume).
- Pay-period and calendar period **lists and hero totals** use **`GET /expenses/period-view`** without `includeProjected` (actual spend only). Web passes `includeProjected=true` for planned recurring/planned rows in pay period. **Pay-period only:** hero + two stat cards under total spent — extra spent (manual expenses; red when over `extraSpendLimitConverted`) and planned used %. Limit set in settings (`extraExpenseLimit` + currency). **Early pay** is a pushed sub-screen (`ExpensesRoute.earlyPay`) from the quick-action grid, not an inline expand.
- **Projections tab:** `ProjectionDisplayLogic.visibleRows` shows the **current pay period first**, then up to **10 future periods** (sorted by `payDate`). Past periods are omitted. Header cumulative free uses the last visible row. API horizon is `PROJECTION_MONTHS_FORWARD` (12 months) so monthly schedules can fill all 10 future slots.
- Amounts are integer minor units in API/domain; IDs are UUID strings (parity with web/API). Form inputs use **`AmountTextField`** (`DesignSystem/FormFields.swift`) with decimal keyboard — users type major units (`45.00`, `1,500.00`); `MoneyFormatter.parseToMinorUnits` / `formatMinorUnitsAsInput` mirror web `parseDollarsToCents` / `formatCentsAsDollarsInput` (strip `$`/`,` thousand separators; COP uses whole numbers).
- **Expenses period list:** tap a mutable expense row to open the edit-amount sheet; long-press context menu still offers edit amount + delete.

## Design system

Match the web app terminal aesthetic ([money-management `globals.css`](../money-management/src/app/globals.css)):

- JetBrains Mono bundled in `MoneyManagement/Resources/Fonts/`
- Semantic colors via `AppColors.Palette` + `@Environment(\.appPalette)`
- Dark default; theme cycles dark → light → system (`UserDefaults` key `theme`)
- Zero corner radius on cards, inputs, buttons; scanline overlay on screens
- Shared UI: `TerminalRow`, `TerminalBadge`, `FormSheet`, `MoneyLabel`, `TerminalSegmentedControl`
- Scrolling: use `TerminalScrollView` (hides scroll indicators app-wide); do not use raw `ScrollView`.
- Loading: `LoadingIndicator` (page + inline variants), `TerminalSpinner`, `LoadingOverlay`, `SectionLoadingMask`, `Skeleton` / `CardListSkeleton` / `ExpensePeriodListSkeleton` / `ProjectionsListSkeleton` — parity with web skeleton loading on main tabs
- `DataStore` fetch tasks run on `@MainActor`; `invalidate` / `invalidateAll` cancel in-flight tasks so foreground refresh does not surface stale cancellation errors (`LoadGeneration` guards in tab ViewModels).

## Xcode / build

- **App icon:** `MoneyManagement/Resources/Assets.xcassets/AppIcon.appiconset/` — single `AppIcon.png` (1024×1024) referenced in `Contents.json`. Do not use a top-level `Resources/` folder at repo root; `project.yml` only bundles `MoneyManagement/Resources/Assets.xcassets`.
- Full **Xcode.app** required — Command Line Tools alone cannot run `xcodebuild` or Simulator.
- If `xcode-select` points at CLT: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (or set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for one-off builds).
- **"No supported iOS devices"** on Run means no simulator destination is selected — choose **iPhone 17** (or similar) under the toolbar destination menu, not "Any iOS Device".
- After changing `project.yml` or adding Swift files under `MoneyManagement/`: `xcodegen generate` (do not hand-edit `project.pbxproj`).
- `Config/Secrets.xcconfig` must exist locally; copy from `Secrets.xcconfig.example`.

## Navigation (authenticated)

- **Main shell:** `MainTabView` — custom `TerminalTabBar` (4 tabs) + floating `FloatingSettingsButton` top-trailing (sheet).
- **Tabs** (default `expenses`): expenses, budgets, income, projections. Settings is **not** a tab.
- **Expenses tab:** `NavigationStack` with push routes for recurring (`ExpensesRoute.recurring`) and one-time/planned (`ExpensesRoute.planned`). CRUD via sheets. Pushed sub-screens (`RecurringExpensesView`, `PlannedExpensesView`, `EarlyPayView`) must own their `@Observable` view models via `@State` in the view's `init` — do **not** construct view models inline in `.navigationDestination`, or parent `ExpensesView` re-renders recreate them and cancel `.task` loads (blank list, no error).
- **Settings sheet:** currency, primary pay schedule, projection prefs (API-backed), theme, logout.

## Auth session

- `AuthService` sets `emitLocalSessionAsInitialSession: true` on `SupabaseClientOptions.AuthOptions` (supabase-swift v2.37+). Avoids the legacy “refresh before initial session” warning and matches the v3 default.
- `SessionStore` listens to `authStateChanges` only (no sync `currentSession` read on init). Expired stored sessions stay in `session` but `isAuthenticated` is false until `tokenRefreshed`; `isBootstrapping` shows `LoadingIndicator` during initial auth resolution and background refresh.
- `RememberedEmailStore` uses key `money-mgmt-remembered-email` (parity with web localStorage).

## Test user

Same seeded Supabase user as the web app (see root `money-management/AGENTS.md`).
