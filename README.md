# labels-action

A GitHub Action that wraps `docker` and `docker buildx` to automatically inject all `GITHUB_*` environment variables (including job and step metadata) as Docker labels on every build.

---

## Quick Start

### 1. Using as a GitHub Action

Include **labels-action** as the very first step in your workflow job, before any Docker commands:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Installs the shim so all docker/docker-buildx commands pick up labels
      - name: Install labels-action shim
        uses: scribe-security/labels-action@v1

      # Now build and push your image as usual
      - name: Build & push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            myorg/myapp:latest
            myorg/myapp:${{ github.run_number }}
```

### 2. Using via `curl | sh`

If you need to install in any Linux pipeline (or local environment) without GitHub Actions, run:

```bash
curl -sSfL https://scribe-security.github.io/labels-action/labels.sh | sh
# From this shell, any `docker build` or `docker buildx build` will include labels
docker build -t myorg/myapp:latest .
```

The installer downloads the label-injecting entrypoint, sets up `docker` and `docker-buildx` shims in your `$PATH`, and emits a confirmation log.

---

## How It Works

1. **Shim installation**: Copies the provided `entrypoint.sh` into a private shim directory and prepends it to `$PATH` (in Actions via `$GITHUB_PATH`, or system-wide via `/etc/profile.d` for the curl installer).
2. **Entrypoint**: When you run `docker build` (or `docker buildx build`), the shim reads all `GITHUB_*` variables and translates them into `--label key=value` arguments.
3. **Execution**: The real Docker binary is invoked unmodified, so all normal behavior (output, errors, build cache) is preserved.

---

## Releases & Versioning

Releases are tagged semantically (e.g. `v1.0.0`) and you can pin your workflow to major versions:

```yaml
uses: scribe-security/labels-action@v1  # will pick up any v1.x.x release
```

---

## Feedback & Contributions

Open an issue or pull request in this repository to suggest improvements or report problems. We welcome your feedback!
