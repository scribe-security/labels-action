# labels-action

Wraps `docker build` and `docker buildx build` to automatically inject two labels on every build:

- CONTEXT: JSON of pipeline & Git metadata (across CI platforms)

- your CI’s run‐ID (e.g. `GITHUB_RUN_ID`)

Env vars containing `_TOKEN`, `_PASSWORD` or` _SECRET` are excluded.


## Installation

### 1. Via Action

```yaml
- name: Install labels shim
  uses: scribe-security/labels-action@main
```

### 2. Via Curl
```yaml
- name: Install labels via curl
  run: |
    curl -sSfL https://scribe-security.github.io/labels-action/labels.sh | bash
```

## Usage

Immediately after installing the shim:

```yaml
- name: Build & push image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.run_number }}
```
Any manual --label flags are preserved alongside the injected ones.

## Troubleshooting

### No labels

Check that which docker points under $HOME/labels-shim

Confirm the shim log:

```bash
[labels-action] shim installed; docker build/buildx will now include labels
```
### Binary not found
  
Ensure you install the shim after any login steps so docker is on your $PATH.

