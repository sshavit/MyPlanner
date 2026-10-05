# Daymark — student planner

A personal coursework planner for EECS 449, built from `jac create mysocial --awetiny` with Jac **0.37.23**. Web, React Native mobile, and CLI clients share one Jac planning service and the same account data.

## Setup and web

Run these commands **inside WSL, from this repository**:

```bash
jac --version                  # this project targets 0.37.23
jac install                    # Python/byLLM and web dependencies
jac run                        # starts the default web app AND backend services
```

Open **http://localhost:8000** in your Windows or WSL browser. Choose **New here? Create an account**, then register. No demo password or preloaded assignments are required. First startup can take longer while Jac downloads its PostgreSQL and build tools; allow network access and keep the terminal running.

`default-app = "web"` and `[scale.gateway] colocate = false` in `jac.toml` make bare `jac run` start the full local fleet. Fleet routing is needed for `/api/feed/user/*` authentication in this compiler version. For explicit development mode use `jac run --dev web`. Restart after server/configuration changes; client edits hot reload.

## Using your planner

- **Assignments:** title, course, due date/time, low/medium/high priority, notes, and completion. Add, edit, complete/reopen, and delete with confirmation.
- **Dashboard:** overdue count, work due over the next seven calendar days, completed/total count, and a deadline-ordered list of overdue/upcoming assignments.
- **Day / Week:** navigate previous/next days or Monday–Sunday weeks. **All** includes distant deadlines.
- **Filters:** combine course, priority, and open/completed/all status. Dashboard counters describe your entire planner; the list obeys filters.
- **Dates:** enter `YYYY-MM-DDTHH:MM` in 24-hour campus local time, for example `2026-10-09T23:59`. The default campus timezone is `America/New_York`, independent of the host computer’s timezone. Set `PLANNER_TIMEZONE` to another IANA timezone **before starting the server** if needed. All clients use this same timezone; dates are campus wall-clock deadlines, not converted to each device’s timezone.
- **Sync:** changes save immediately to the server. Use **Refresh** to see changes made on another client. A network connection is required.

## CLI

Start `jac run` in another terminal and create an account in the web or mobile app first:

```bash
jac run cli -- login alice                 # prompts for your password
jac run cli -- add "Finish planner" --course "EECS 449" --due "2026-10-09T23:59" --priority high --notes "Test web, mobile, and CLI"
jac run cli -- today
jac run cli -- upcoming                    # open work from now through the next 7 calendar days
jac run cli -- all                         # all dates, including completed tasks; shows task IDs
jac run cli -- complete TASK_ID            # copy the full ID printed above
jac run cli -- all --json                  # machine-readable output
jac run cli -- logout
```

`complete` is idempotent: repeating it leaves the task completed. `today` includes overdue tasks from earlier today; older overdue work remains visible on the web dashboard and in `all`.

Use `jac run cli -- --url http://HOST:8000 login alice` or set `PLANNER_URL` to select a server. The CLI saves its token in `~/.daymark.json` with owner-only permissions; `PLANNER_SESSION` selects a different file. `PLANNER_PASSWORD` is available for noninteractive testing; normally use the password prompt. Credentials are tied to the selected server.

## iPhone mobile app with Expo Go (WSL)

`mobile.jac` is a **React Native application**, using the scaffold’s shared `@jac/mobui` components. It supports viewing, adding, and completing tasks, plus editing, filters, and the AI preview. It connects to the same Jac planning service as web and CLI.

### Prerequisites

- Jac 0.37.23 and `jac install` completed in WSL.
- **Expo Go on your iPhone**, compatible with the generated Expo project’s SDK. This installed Jac version generates **Expo SDK 57** (`.jac/mobile-rn/package.json`). If Expo Go reports an SDK mismatch, use a matching Expo Go release/development build; do not randomly change the generated React Native dependencies.
- Phone and computer on the same reachable network; allow Windows firewall access to **8000** (planner) and **8081** (Expo Metro).
- No Android device, Android SDK, or Android license is needed. Expo Go does not require local Xcode. A standalone iOS binary is a separate workflow requiring macOS/Xcode or Expo EAS with Apple signing credentials.

### Run on your iPhone

Terminal 1, from the repository root:

```bash
jac run
```

Terminal 2, also from the repository root:

```bash
# Replace this with your computer's address that the PHONE can reach.
export JAC_RN_DEV_HOST=192.168.1.100
export REACT_NATIVE_PACKAGER_HOSTNAME="$JAC_RN_DEV_HOST"
jac run --dev --platform ios mobile
```

First run provisions the Expo project in `.jac/mobile-rn/`, compiles Jac into native React Native modules, and starts Metro. Wait for **React Native dev ready** and Metro readiness. The first iOS bundle can take around two minutes. In an interactive terminal, use the displayed Expo Go QR code with the iPhone Camera. Alternatively open `exp://192.168.1.100:8081` on the phone (substitute your address).

Inside Daymark, enter **`http://192.168.1.100:8000`** as the **Server address**, select **Connect**, and sign in with your web account. Use port **8000**, the shared planner fleet, even if the mobile command prints another API port. Add or complete a task on the phone, then select **Refresh** in web to see it.

**WSL networking:** before scanning the QR, open `http://YOUR_COMPUTER_IP:8000` in iPhone Safari and `http://YOUR_COMPUTER_IP:8081/status` (should return `packager-status:running`). If unreachable, configure Windows/WSL mirrored networking or forward those ports from Windows to WSL and allow them through the firewall. The WSL address printed automatically may not be reachable from a phone. Both the Expo server and the planner backend must be reachable; tunneling Metro alone does not expose the planner backend.

**Jac 0.37.23 caveat:** the native development command also attempts an auxiliary backend for the mobile entry. On WSL it can log `iOS native build requested on non-macOS host` while Expo/Metro continues running. The mobile app uses the separately running `jac run` backend above, so it does not need that auxiliary process. Confirm Metro readiness and use the explicit planner server URL. This behavior was observed during verification; the native iOS JavaScript bundle still compiled successfully.

If you need to restart Expo directly after Jac has generated/staged the mobile code, stop Terminal 2, then use **Node.js 22+**:

```bash
cd .jac/mobile-rn
npx expo start --go --lan --max-workers 2
```

This directly serves the staged native code; rerun the Jac development command after changing `.jac` source. On iPhone, opening the Expo Go QR runs the native app; the browser preview below is useful when no phone is available.

### Mobile preview and optional standalone build

```bash
jac run --dev --platform web mobile        # browser preview of the mobile entry
jac build --platform web mobile            # compile the mobile browser bundle
# On macOS with Xcode, if a standalone app is later needed:
jac build --platform ios mobile
```

In the browser preview use `http://localhost:8000` in **Server address**, then the same account. **Change server** clears the active sign-in and lets you select another backend. The default address shown on a fresh mobile install is only a placeholder; replace it with your reachable planner URL.

## AI study coach

Choose **Break into steps ✦** on an assignment. The Jac backend calls `propose_steps(...) by llm(...)` to suggest 3–6 concrete work sessions. Review the preview, then choose **Add these study steps**. Each becomes a normal editable task in the same course with the assignment’s deadline; adjust dates to spread out your work. The model cannot directly modify your tasks. Dismissing the preview saves nothing.

To enable the default model:

```bash
export OPENAI_API_KEY="your-key"
jac run
```

The default is `gpt-4o-mini`. `BYLLM_DEFAULT_MODEL` selects another byLLM-supported provider/model; configure that provider’s credentials on the server. Only the selected assignment’s title, course, due date, and notes are sent to the model. Without configuration, the UI explains how to enable AI; normal planning remains fully usable. Provider errors leave existing tasks untouched. Tests use `MockLLM`, not paid model requests.

## Architecture and persistence

| File | Responsibility |
| --- | --- |
| `jac.toml` | Existing multi-app structure; default web app and fleet routing |
| `web.jac`, `mobile.jac` | Thin web and mobile entry points |
| `core/ui.jac`, `core/theme.jac` | Shared responsive mobUI screen, state, authentication, styling |
| `core/feed.jac` | Jac planning service: profile checks, Task graph nodes, CRUD, views, AI |
| `cli.jac` | Argument parser and authenticated typed service bridge |
| `core/feed.test.jac` | Persistence, isolation, validation, view boundaries, AI tests |
| `desktop.jac` | Retained optional desktop host, now showing Daymark |
| `core/scoring.jac` | Retained original Awetiny scoring service/example |

The original Awetiny service name **feed** is retained, so clients use `/api/feed`. Public bridge endpoints explicitly verify the authenticated profile before any read/write of personal tasks. Tasks connect to the caller’s **private `root`**, never `root.shared`; another account cannot view or mutate them even with a known task ID. Anonymous list requests return an empty planner.

Jac automatically persists graph nodes and account records in its project-scoped PostgreSQL database. Stopping the app, closing the browser, logging out, or restarting does not delete assignments. Keep the project’s `.jac` data/identity metadata and Jac’s PostgreSQL data directory; deleting/resetting these is not a routine restart. Use `jac db` for database inspection/backup workflows. An external PostgreSQL server can be configured through `JAC_DB_URL`.

Generated assets, database metadata, environments, and native projects live under `.jac/` and are ignored by Git. API keys belong in the server environment, never client code or committed files.

## Validation

```bash
jac check
JAC_TEST_JOBS=0 jac test
jac build --platform web mobile
jac browse open http://localhost:8000
jac browse snapshot
jac browse close
```

The endpoint tests use temporary isolated project stores and two accounts. They exercise create/edit/delete, invalid dates and inputs, completion/reopen, course/priority/status filters, day/week boundaries, overdue/upcoming counts, persistence after reopening the service, and rejection of cross-account access. The AI test runs the real typed `by llm()` request/response pipeline with `MockLLM`.

If `jac browse` cannot find a browser, install Chromium or set `JACBROWSER_CHROME` to its executable. On a restricted machine, use a writable `XDG_CACHE_HOME` for Jac’s compiler/toolchain caches. If PostgreSQL cannot be provisioned, allow the initial download or supply `JAC_PG_DIST` / `JAC_DB_URL`; do not delete your data to resolve provisioning errors.

## Scaffold attribution

Adapted from the Awetiny **Tiny JacYac** scaffold, imported from [marsninja/tiny_jacyac](https://github.com/marsninja/tiny_jacyac) at `df87b2c1241e9865acf8eb970418df8c0603ad52`. Its thin app entries, shared mobUI components, authentication flow, Jac graph persistence, typed cross-app bridge, CLI token storage, and optional desktop/scoring examples are preserved and adapted for planning. Original scaffold screenshots remain in `docs/screenshots/`; new captures use the `daymark-` prefix.

## Submission verification and remaining limits

Verified in this WSL environment:

- Workspace `jac check` and four Jac tests (including the retained scoring test).
- Backend task CRUD, validation, per-account isolation, filters, date boundaries, dashboard counts, and persisted tasks after closing/reopening the service.
- Plain root `jac run` starts the web gateway and services with working registration/sign-in.
- Desktop and phone-sized web workflows: create, edit, complete/reopen, delete confirmation, filters, daily/weekly navigation, reload, and AI-not-configured message.
- Separate mobile browser build: reads web-created tasks; adds/completes tasks; retains connection/session on reload.
- CLI login, add, today, upcoming, JSON listing, and completion all passed; a final backend read confirmed the web/mobile/CLI records and completion state in the same account.
- Expo native compilation and Metro iOS bundling: **1,097 modules bundled successfully**. No physical iPhone was available, so Expo Go rendering, device networking, and interaction on the actual phone remain **unverified**.
- AI’s real `by llm()` structured-output path tested using `MockLLM`; accepting proposed steps tested through the backend. A live paid-provider response is **unverified** because no model credentials were supplied.

Native Android work was stopped at the user's request and is not required for this submission. No standalone `.ipa` is included; the iPhone deliverable is the Expo/React Native source and run workflow.

## Assignment checklist

| Requirement | Status | Evidence / limit |
| --- | --- | --- |
| Inspect and preserve Jac/Awetiny structure and patterns | COMPLETE | Existing app entries, mobUI, authentication, service bridge, and graph patterns retained |
| Jac server/backend | COMPLETE | `core/feed.jac`; endpoint tests pass |
| Web frontend | COMPLETE | Browser CRUD, filtering, navigation, and reload checks pass |
| Mobile app | PARTIAL | React Native source, mobile browser workflows, and iOS Expo bundle verified; physical iPhone/Expo Go execution not available here |
| CLI | COMPLETE | Login, add, today/upcoming/all, and completion verified |
| Shared backend/data | COMPLETE | Web, mobile, and CLI records verified in the same authenticated account |
| Persistence between sessions | COMPLETE | Backend close/reopen test and browser reload verified |
| Root `jac run` starts web and server | COMPLETE | Fleet gateway and services started; registration/sign-in tested |
| Required task fields and CRUD | COMPLETE | Title, course, due date/time, priority, notes, status; add/edit/delete/complete/reopen tested |
| Daily and weekly views | COMPLETE | Date boundaries and previous/next navigation tested |
| Course, priority, completion filters | COMPLETE | Backend and browser checks pass |
| Upcoming/overdue dashboard | COMPLETE | Counts and date-window tests pass |
| Practical Jac AI feature | COMPLETE | Typed `by llm()` breakdown tested with MockLLM; review/accept saves ordinary tasks; live provider response unverified |
| Setup, web, iPhone/Expo, CLI, AI documentation | COMPLETE | Commands, prerequisites, configuration, architecture, and limitations documented above |
| Essential final checks | COMPLETE | Six app targets compile; four Jac tests pass; web/mobile-browser/CLI workflows verified |

Nothing is missing from the authored app interfaces. Actual iPhone device validation is the remaining partial item; a signed standalone iOS binary is not part of the Expo Go workflow.
