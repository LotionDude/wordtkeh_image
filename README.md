# Wordtkeh

A self-hosted multilingual word game with playable English and Hebrew Daily
puzzles. Accepted guesses, difficulty and results survive refresh through local
IndexedDB. Daily and Random modes include history, statistics, local backups,
sharing and System/Light/Dark appearance. See the [session API](docs/SESSION_API.md) and
[Daily UI integration](docs/DAILY_UI.md) for the application boundaries.

## Development

Use Node 24 LTS and npm. Dependencies are pinned in `package-lock.json`.

```sh
npm ci
npx playwright install chromium
npm run dev
```

Open the localhost URL printed by Vite. `/en/daily` and `/he/daily` share one
application. Language links retain the current page. The URL wins over stored
preferences; `/` uses the last saved language, or English on first use.

### Test streaks and date rollover locally

```sh
npm run dev:debug
```

Open `http://127.0.0.1:5174/en/daily`. Below the app, **Local test tools** provides
Next day (+1), Next week (+7), a forward date picker, current/longest play and win
streaks, freeze balance/usage/save counts, and the last 14 days' derived timeline.
Values refresh every two seconds or with **Refresh values**. Switching language
changes which language's streaks are inspected.

This mode starts at the configured epoch and uses the separate `wordtkeh-debug`
IndexedDB database. Normal player data is untouched. The simulated date is pinned
through focus refresh and kept in sessionStorage across reloads in the same tab.
Changing dates reloads the application: save private-note drafts first. Accepted
guesses remain saved. Advancing uses calendar dates, including across DST.

Try winning Thursday, advancing through Friday/Saturday without playing, then
skipping Sunday and advancing to Monday. The optional dates keep both streaks;
Sunday consumes a freeze, preserves both streaks without incrementing either. A single valid guess
advances play; advancing the day without finishing resets wins. A fresh sandbox
starts with three freezes and earns one per five participation days, up to five.

Date controls only move forward because rewinding cannot undo already persisted
unfinished/completed sessions. For a fresh test run, click **Reset test data & date**
and confirm. It clears all test games, notes and preferences across languages,
resets derived streaks/freezes, removes the simulated date and opens Daily at the
configured epoch. Only `wordtkeh-debug` is cleared; normal player data is untouched.
Close other debug tabs first. Use one debug tab per test run; the test database is
shared across tabs while their clocks are separate.

Plain `npm run dev` retains normal behavior. Debug tools are dynamically imported
only in development `debug` mode and are absent from production builds/preview.
`npm run test:debug` runs the dedicated Chromium debug-mode workflow.

Settings includes global System, Light and Dark appearance. Each language has
light and dark semantic palettes. System follows live OS/browser changes; the
stored preference remains `system`. Appearance survives reloads and language
switches. Native controls use the resolved color-scheme, and stored appearance
is applied before rendering the shell, with a system-aware loading background.

```sh
npm run lint
npm run typecheck
npm run test
npm run build
npm run test:e2e
npm run format:check
```

Playwright starts a preview of the built `dist` directory; run the build first.
On Linux CI install browsers with `npx playwright install --with-deps chromium`.
`npm run format` formats implementation files without rewriting supplied specs.

## Runtime configuration

`public/config.json` is the canonical production configuration, served at runtime
as `/config.json`. The epoch is **2026-10-01**; change it before launch as needed.
No environment override exists. The complete schema, generated Helm values,
mount path and configuration lifecycle are documented in
[Deployment](docs/DEPLOYMENT.md). Unknown/malformed configuration fails visibly
with retry support rather than silently selecting a fallback epoch.

A fresh HTTP Date response anchors the application clock when available within
10 seconds. The clock advances using monotonic elapsed time; otherwise it uses
browser time. HTTP Date has second precision and is not an anti-cheat guarantee.
The clock is sampled at startup and refreshed from the same origin on Daily-page
focus/visibility resume. A failed refresh falls back to browser time. A running
session keeps its original epoch/timezone even if deployment configuration changes;
reload to apply new configuration. Visible Daily pages reconcile once per minute.
Time conversion is centralized and injectable.

## Architecture

`src/app` composes the UI and adapters. `src/domain` contains pure data types.
`src/data/repositories` defines the application-owned persistence contract;
`src/data/indexeddb` implements it. Components never access Dexie directly.
`src/content/languages` supplies text, direction, keyboard, normalization, theme
and local fixtures. `src/shared/time` owns clock/date conversion. CSS Modules
consume semantic custom properties. No global state or UI framework is used.

IndexedDB version 1 is the complete pre-production baseline. Future schema changes
require tested migrations. Accepted guesses persist immediately through repository
interfaces; corruption is reported and never silently erased. See
[Data model](docs/DATA_MODEL.md) and [Data ownership](docs/DATA_OWNERSHIP.md).

Production word banks are bundled locally. The committed English and Hebrew Daily
schedules are fixed after the one-time pre-launch shuffle; future additions are
append-only. See [Content](content/README.md).

## Static deployment

See [Production deployment](docs/DEPLOYMENT.md) for image build/run, runtime mounts,
Helm, OpenShift Route, Kubernetes Ingress/port-forward and GitLab CD setup.
The portable chart repository is [deploy/helm](deploy/helm/README.md).

For Docker Compose, use [deploy/compose](deploy/compose/README.md). Its included
`config.json` is exported from the Helm chart's defaults. After loading the release
tar, start it from the repository root:

```sh
docker compose -f deploy/compose/compose.yaml up -d --wait
```

Open `http://localhost:8080`. Edit `deploy/compose/config.json` for your deployment,
then recreate with `docker compose -f deploy/compose/compose.yaml up -d --force-recreate --wait`
and reload the browser. The Compose README also covers pulling
`registry.com/tochnitan/wordtkeh:1.0.0` from Artifactory.

`npm run test:e2e` builds an isolated historical-fixture version for regression
journeys. `npm run test:production` targets the actual NGINX image at
`E2E_BASE_URL` (default localhost:8080), with real runtime config and schedules.
`npm run verify:helm` validates all three chart exposure modes using Helm.

### Load the release tar and push to Artifactory

The exported release is `artifacts/wordtkeh-1.0.0-linux-amd64.tar`, with a
matching `.tar.sha256` checksum file. It contains the verified **Linux/amd64**
image already tagged `wordtkeh:1.0.0`. Docker Desktop must use Linux containers.
Copy both files to the machine that can reach your Artifactory registry.
Generated archives are excluded from Git and the Docker build context.

From the directory containing the transferred files, verify and load the image:

```sh
sha256sum --check wordtkeh-1.0.0-linux-amd64.tar.sha256
docker image load --input wordtkeh-1.0.0-linux-amd64.tar
docker image inspect wordtkeh:1.0.0 --format '{{.Id}} {{.Os}}/{{.Architecture}}'
```

On PowerShell, use `Get-FileHash -Algorithm SHA256 ./wordtkeh-1.0.0-linux-amd64.tar`
and compare the hash with the accompanying checksum file instead of `sha256sum`.
Use `docker load` for this image archive; it restores the image configuration and
tag. No source checkout or rebuild is required. See the
[Docker archive documentation](https://docs.docker.com/reference/cli/docker/image/save/).

To start it locally:

```sh
docker run --rm --name wordtkeh -p 8080:8080 --read-only --tmpfs /tmp:rw,noexec,nosuid,size=32m --cap-drop ALL --security-opt no-new-privileges wordtkeh:1.0.0
```

Open `http://localhost:8080`. Runtime config mounts work as described in
[Production deployment](docs/DEPLOYMENT.md#build-and-run).

For **`registry.com/tochnitan/wordtkeh:1.0.0`**, tag and push the loaded image:

```sh
docker login registry.com
docker image tag wordtkeh:1.0.0 registry.com/tochnitan/wordtkeh:1.0.0
docker image push registry.com/tochnitan/wordtkeh:1.0.0
```

At the login prompts, enter your Artifactory username and access token. Do not put
the token into the README or a command-line password argument. Login uses only
the registry hostname; the tag and push include your supplied `/tochnitan/wordtkeh`
path. Your account needs push permission on the target Docker repository. The
hostname must expose Artifactory's Docker endpoint, as shown by **Set Me Up**. See
[JFrog's Docker access methods](https://docs.jfrog.com/artifactory/docs/additional-docker-information).

After pushing, configure Helm to use the same destination:

```yaml
image:
  repository: registry.com/tochnitan/wordtkeh
  tag: "1.0.0"
```

Configure `imagePullSecrets` for a private registry. The tar is a transport archive; loading
and pushing publishes a pullable Docker image to Artifactory.

To recreate the archive from the verified local image:

```sh
docker image tag wordtkeh:phase7-final wordtkeh:1.0.0
docker image save --output artifacts/wordtkeh-1.0.0-linux-amd64.tar wordtkeh:1.0.0
```

Regenerate the SHA-256 sidecar whenever the tar is recreated.
