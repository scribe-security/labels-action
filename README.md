# cli-wrapper

A minimal Docker image and GitHub Actions examples that build & push `cli-wrapper` on Linux and Windows, with automatic CI metadata labels injected via `labels-action`.

---

### Files

* **Dockerfile** – Alpine base, sample entrypoint
* **Dockerfile.windows** – .NET restore + publish
* **Dockerfile.bad** – used for fail-test workflow
* **docs/labels.sh** – installs a `docker` shim that injects labels
* **docs/entrypoint.sh** – logic for platform detection + label injection

---

### How Label Injection Works

When the `docker` or `docker-buildx` command is wrapped by `entrypoint.sh`, it:

1. Detects the CI platform (GitHub, GitLab, Jenkins, Bitbucket, etc.)
2. Collects git + pipeline context
3. Injects two labels:

   ```bash
   CONTEXT=<JSON>          # Full pipeline + git metadata
   <CI_ID_VAR>=<value>     # e.g., GITHUB_RUN_ID=123456, CI_JOB_ID=98765
   ```

Secrets (e.g. `_TOKEN`, `_PASSWORD`, `_SECRET`) are filtered out automatically.

---

### Quick Start: GitHub Actions

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: scribe-security/labels-action@main

  - uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}

  - name: Build & push Linux
    uses: docker/build-push-action@v5
    with:
      context: .
      file: Dockerfile
      platforms: linux/amd64
      push: true
      tags: |
        ghcr.io/${{ github.repository_owner }}/cli-wrapper:latest
        ghcr.io/${{ github.repository_owner }}/cli-wrapper:${{ github.run_number }}
```

---

### Usage in GitLab, Jenkins, Bitbucket, etc.

For non-GitHub CI platforms, use `labels.sh` via `curl`:

```bash
curl -sSfL https://scribe-security.github.io/labels-action/labels.sh -o install-labels.sh
bash install-labels.sh
source "$HOME/labels-shim/env.sh"   # Required: enables shim in current shell
```

This wraps `docker` and `docker-buildx` with the same label logic.

Without `source "$HOME/labels-shim/env.sh"`, your CI won't use the shim and labels won't be injected.

---

### Supported Docker Forms

The shim auto-injects labels for:

* `docker build`
* `docker buildx build`
* `docker buildx b`
* `docker builder build`
* `docker image build`

---

### CI Platforms Supported

* GitHub Actions
* GitLab CI
* Bitbucket Pipelines
* Azure DevOps
* CircleCI
* Travis CI
* Jenkins
* Local dev

All metadata is auto-collected; labels include `platform`, `git_url`, `git_commit`, and the CI-specific ID (`GITHUB_RUN_ID`, `CI_JOB_ID`, etc.).
