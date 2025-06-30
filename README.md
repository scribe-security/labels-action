# Labels Action

Wraps `docker build…` and `docker buildx build…` so that **all** `GITHUB_*` env vars
are automatically injected as `--label` flags on every build.

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

