#!/usr/bin/env bash
set -euo pipefail

SHIM_DIR="${HOME}/labels-shim"
mkdir -p "$SHIM_DIR"

# 1) Copy the real docker & (if present) docker-buildx
cp "$(command -v docker)" "$SHIM_DIR/docker-original"
chmod +x "$SHIM_DIR/docker-original"

if command -v docker-buildx &>/dev/null; then
  cp "$(command -v docker-buildx)" "$SHIM_DIR/docker-buildx-original"
  chmod +x "$SHIM_DIR/docker-buildx-original"
fi

# 2) Download the wrapper (entrypoint.sh) once
curl -sSfL \
  https://scribe-security.github.io/labels-action/entrypoint.sh \
  -o "$SHIM_DIR/entrypoint.sh"
chmod +x "$SHIM_DIR/entrypoint.sh"

# 3) Install the shim under both names
cp "$SHIM_DIR/entrypoint.sh" "$SHIM_DIR/docker"
chmod +x "$SHIM_DIR/docker"

if [[ -f "$SHIM_DIR/docker-buildx-original" ]]; then
  cp "$SHIM_DIR/entrypoint.sh" "$SHIM_DIR/docker-buildx"
  chmod +x "$SHIM_DIR/docker-buildx"
fi

# 4) Prepend to PATH for the rest of the job
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$SHIM_DIR" >> "$GITHUB_PATH"
else
  echo "export PATH=\"$SHIM_DIR:\$PATH\"" > "$SHIM_DIR/env.sh"
  chmod +x "$SHIM_DIR/env.sh"

  # Try to affect current shell if not piped (i.e., bash labels.sh directly)
  if [[ -n "$BASH_VERSION" && -t 0 ]]; then
    export PATH="$SHIM_DIR:$PATH"
  fi
fi

echo "[labels] shim installed; docker & docker-buildx will now inject labels on build"