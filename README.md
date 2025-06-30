# labels-action

A GitHub Action that installs a shim wrapping `docker` (and `docker-buildx`) so that every build
automatically gets labeled with all `GITHUB_*` environment variables.

## How It Works

1. **Shim installation**  
   Copies the real `docker` and (if present) `docker-buildx` binaries into `$HOME/labels-shim`,  
   then writes wrapper scripts named `docker` and `docker-buildx` that:

   - Detect `build` or `buildx build` invocations  
   - Collect all `GITHUB_*` variables into `--label NAME=VALUE` flags  
   - Execute the original binary with your Docker arguments plus the label flags

2. **PATH injection**  
   Prepends `$HOME/labels-shim` to `$PATH` in your job so that any subsequent `docker build…`  
   uses the shim instead of the real binary.

## Usage in a Workflow

```yaml
- name: Checkout
  uses: actions/checkout@v4

- name: Install labels shim
  uses: scribe-security/labels-action@main

- name: Build & push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: |
      ghcr.io/${{ github.repository_owner }}/my-image:latest
      ghcr.io/${{ github.repository_owner }}/my-image:${{ github.run_number }}
