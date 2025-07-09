# labels-action

Wraps `docker build` and `docker buildx build` to automatically inject four Docker labels on every build:

* **CONTEXT**: JSON of pipeline & Git metadata (across CI platforms)
* **CI run ID**: your CI’s run‐ID variable (e.g. `GITHUB_RUN_ID`, `CI_JOB_ID`)
* **Baseimage**: JSON object containing the Dockerfile name, the last `FROM` line, and the base image string
* **DockerCommands**: JSON array listing every `docker` invocation (`build`, `push`, etc.) during the job

Env vars containing `_TOKEN`, `_PASSWORD` or `_SECRET` are excluded.

---

## Installation

### 1. Via Action (GitHub)

```yaml
- name: Install labels shim
  uses: scribe-security/labels-action@main
```

This uses GitHub’s `$GITHUB_PATH` to set up the shim automatically.

### 2. Via Curl (Non-GitHub CI)

```bash
curl -sSfL https://scribe-security.github.io/labels-action/labels.sh -o install-labels.sh
bash install-labels.sh
# Activate the shim in your current shell:
source "$HOME/labels-shim/env.sh"
```

> **Note:** Sourcing `env.sh` is **required** in GitLab, Jenkins, Bitbucket, etc., so that your shell uses the shimmed `docker` binary.

---

## Usage

After installation, any `docker build` or `docker buildx build` will include the injected labels. For example:

```yaml
- name: Build & push image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.run_number }}
```

Manual `--label` flags are preserved alongside the injected ones.

---

## Supported Commands

The shim injects labels for these forms of build commands:

* `docker build`
* `docker buildx build`
* `docker buildx b`
* `docker builder build`
* `docker image build`

---

## Troubleshooting

### No labels appear?

1. Verify that `docker` points to the shim:

   ```bash
   which docker  # should return $HOME/labels-shim/docker
   ```
2. Check the install log for:

   ```bash
   [labels-action] shim installed; docker & docker-buildx will now inject labels
   ```
3. On non-GitHub CI, ensure you ran:

   ```bash
   source "$HOME/labels-shim/env.sh"
   ```

### Docker not found?

If a Docker login or setup step alters your `PATH`, install the shim **after** those steps so it remains first in `PATH`.
