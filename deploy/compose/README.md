# Docker Compose example

This directory can be copied on its own. `config.json` is exported from the Helm
chart's `config` defaults and mounts read-only at `/usr/share/nginx/html/config.json`.
It uses the same 2026-10-01 epoch and full runtime settings as the chart. Edit this
public JSON for your deployment before starting; it must contain no secrets.

With Docker Compose v2 and Linux containers, load the release tar if needed:

```sh
docker load --input /path/to/wordtkeh-1.0.0-linux-amd64.tar
```

From this directory:

```sh
docker compose up -d --wait
docker compose ps
docker compose logs --tail 50
```

Open `http://localhost:8080`. Default image is the locally loaded `wordtkeh:1.0.0`.
The image supplies its non-root identity; Compose uses a read-only root, dropped
capabilities, no privilege escalation, bounded writable /tmp, HTTP health checks
and graceful shutdown. No application backend or persistent server volume is needed.
Player data stays in each browser. Port 8080 binds on all host interfaces; change
the port mapping to `127.0.0.1:8080:8080` if access should be localhost-only.
The relevant options are documented in the
[Docker Compose service reference](https://docs.docker.com/reference/compose-file/services/).

To use Artifactory instead, create a local `.env` beside compose.yaml:

```dotenv
WORDTKEH_IMAGE=registry.com/tochnitan/wordtkeh:1.0.0
WORDTKEH_PORT=8080
```

Then authenticate, pull and start:

```sh
docker login registry.com
docker compose pull
docker compose up -d --wait
```

Credentials are managed by Docker login; do not put them into config.json or .env.
`WORDTKEH_IMAGE` and `WORDTKEH_PORT` only control Compose, not application config.
For public HTTPS access, use your existing TLS reverse proxy. This container serves
HTTP; clipboard features require HTTPS or localhost.

After editing config.json, recreate the service and reload your browser:

```sh
docker compose up -d --force-recreate --wait
docker compose exec wordtkeh cat /usr/share/nginx/html/config.json
docker compose down
```

Recreation ensures an editor's atomic file replacement is reflected in the mount.
Stopping/removing containers does not erase browser history.

In the application repository, `npm run sync:compose` regenerates this example's
config from `deploy/helm/values.yaml`. `npm run sync:config` also refreshes it after
updating canonical configuration. These commands overwrite local edits to this
example; maintain deployment-specific copies separately. `npm run check:config`
checks that the committed defaults remain identical.
