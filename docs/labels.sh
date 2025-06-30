#!/usr/bin/env bash
set -eo pipefail

# Installer portion
SHIM_DIR="${HOME}/labels-shim"
mkdir -p "$SHIM_DIR"

# copy the real docker
DOCKER_REAL="$(command -v docker)"
cp "$DOCKER_REAL" "$SHIM_DIR/docker-original"
chmod +x "$SHIM_DIR/docker-original"

# copy the real docker-buildx plugin (if present)
if command -v docker-buildx &>/dev/null; then
  BUILDX_REAL="$(command -v docker-buildx)"
  cp "$BUILDX_REAL" "$SHIM_DIR/docker-buildx-original"
  chmod +x "$SHIM_DIR/docker-buildx-original"
fi

# write our wrapper (entrypoint) once and reuse for both docker & buildx
cat > "$SHIM_DIR/entrypoint.sh" <<'EOF'
#!/usr/bin/env bash
set -eo pipefail

CMD_NAME=$(basename "$0")
REAL_PATH="$(command -v "$CMD_NAME")-original"

if [[ ! -x "$REAL_PATH" ]]; then
  echo "[labels] ERROR: real $CMD_NAME not found at $REAL_PATH" >&2
  exit 1
fi

# inject on "docker build …" or "docker buildx build …" or direct docker-buildx calls
if [[ "$CMD_NAME" == "docker-buildx" ]] || \
   ([[ "$CMD_NAME" == "docker" ]] && ([[ "$1" == "build" ]] || ([[ "$1" == "buildx" ]] && [[ "$2" == "build" ]] ))); then

  LABEL_ARGS=()
  while IFS='=' read -r var val; do
    [[ "$var" =~ ^GITHUB_ ]] && LABEL_ARGS+=(--label "${var}=${val}")
  done < <(printenv)

  echo "[labels] injecting labels: ${LABEL_ARGS[*]}" >&2
  exec "$REAL_PATH" "$@" "${LABEL_ARGS[@]}"
else
  exec "$REAL_PATH" "$@"
fi
EOF
chmod +x "$SHIM_DIR/entrypoint.sh"

# install the two shim binaries
cp "$SHIM_DIR/entrypoint.sh" "$SHIM_DIR/docker"
chmod +x "$SHIM_DIR/docker"

if [[ -f "$SHIM_DIR/docker-buildx-original" ]]; then
  cp "$SHIM_DIR/entrypoint.sh" "$SHIM_DIR/docker-buildx"
  chmod +x "$SHIM_DIR/docker-buildx"
fi

# put our shim dir first in PATH for subsequent steps
# in GitHub Actions runs, $GITHUB_PATH is provided for exactly this
echo "$SHIM_DIR" >> "$GITHUB_PATH"
echo "[labels] shim installed; docker & docker-buildx will now include labels"
