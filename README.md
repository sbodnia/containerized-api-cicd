# containerized-api-cicd
Dockerized service with a multi-stage build, non-root runtime, GitHub Actions pipeline and automated deploy to server

**Lint → Test → Build → Scan → Deploy**.

The application source is pulled in as a pinned Git submodule (`upstream/`, [benc-uk/nodejs-demoapp](https://github.com/benc-uk/nodejs-demoapp)), so this repository contains only the packaging and pipeline code.

![CI](https://github.com/<your-login>/containerized-api-cicd/actions/workflows/ci.yml/badge.svg)

## What's inside

| Path | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build: dependencies → runtime on `node:22-alpine` |
| `.dockerignore` | Keeps the build context small and free of secrets |
| `upstream/` | Git submodule pinned to a specific commit of the demo app |
| `.github/workflows/ci.yml` | CI/CD pipeline |

## Quick start

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/sbodnia/containerized-api-cicd
cd containerized-api-cicd
```

Build the image (the upstream source is passed as a named build context):

```bash
docker build \
  --build-context upstream=./upstream \
  --build-arg UPSTREAM_SHA=$(git -C upstream rev-parse HEAD) \
  -t demoapp .
```

Run it:

```bash
docker run --rm --init -p 3000:3000 demoapp
```

Open <http://localhost:3000>. Stop with `Ctrl+C` in the same terminal, or `docker stop <id>` from another one.

## Docker image

- **Base:** `node:22-alpine`, pinned by digest so builds are reproducible.
- **Multi-stage:** production dependencies are installed in a separate stage (`npm ci --omit=dev`), and only the result is copied into the runtime image.
- **Non-root:** the process runs as UID 1000 (`node`).
- **Init process:** `tini` is PID 1, so `docker stop` terminates the app immediately.
- **Labels:** OCI labels record the source repository and the upstream commit (`org.opencontainers.image.revision`).
- **Healthcheck:** an HTTP request to `/` every 30 seconds.
- **Size:** reduced from 424 MB (Debian slim base) to 289 MB by switching to Alpine and pruning unneeded files from dependencies.

## CI/CD pipeline

Defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

| Stage | What it does |
|---|---|
| **Lint** | `hadolint` on the Dockerfile; `prettier --check` on the application |
| **Test** | Starts the app from source and runs the HTTP test suite (`httpyac`) |
| **Build** | Builds the image with Buildx and GitHub Actions cache; pushes to GHCR on `main` |
| **Scan** | Trivy scan of the pushed image; results are written as a table to the job summary |
| **Deploy** | Currently a demo step that writes a summary; to be replaced with a real deployment |

Pull requests run Lint and Test. Build, Scan and Deploy run on pushes to `main`.

Concurrency is set per branch, so a new push cancels the in-progress run of the same branch.

## Decisions

- **Submodule instead of copying the source.** The application is someone else's project. Pinning a submodule keeps its code out of this repository and makes the exact version explicit.
- **Named build context instead of `git clone` inside Docker.** The clone happens on the host, so the image build does not depend on network access to GitHub or on certificates inside the build container.
- **Alpine with digest pinning.** Smaller image, and the base cannot change silently between builds.
- **Scan without failing the job (report mode).** Findings are shown in the job summary first; the gate can be switched to enforcing once the baseline is known.
- **Squash merges into `main`.** Keeps the history readable: one commit per change.

## Known limitations

- The current deploy stage is a placeholder. A real target (VPS over SSH, DigitalOcean, or ECS) needs secrets and an environment configured in the repository settings.
- Test stage runs the application from source, not from the built image. Testing the image itself would catch differences introduced by the Alpine base or the production install.
- The application uses an in-memory session store; this is fine for a demo but not for production.

## Acknowledgements

The application is [nodejs-demoapp](https://github.com/benc-uk/nodejs-demoapp) by [Ben Coleman (@benc-uk)](https://github.com/benc-uk). Thank you for publishing it as an open project: it made a good base for practicing containers and CI/CD. All application code belongs to its author; see the license in `upstream/` for terms.

The packaging and pipeline code in this repository is available for everyone, really, guys.