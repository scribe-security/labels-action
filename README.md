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


---

