#!/usr/bin/env bash
set -euo pipefail

SHIM_DIR="/usr/local/labels-shim"

# 1) Create the shim dir
sudo mkdir -p "$SHIM_DIR"

# 2) Back up the real `docker` binary
REAL_DOCKER="$(command -v docker)"
sudo cp "$REAL_DOCKER" "$SHIM_DIR/docker-original"
sudo chmod +x "$SHIM_DIR/docker-original"

# 3) Write our one-and-only `docker` wrapper
sudo tee "$SHIM_DIR/docker" >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail

CMD=\$1; shift

# Build up --label arguments from every GITHUB_* env var
collect_labels() {
  local LABELS=()
  while IFS='=' read -r NAME VAL; do
    [[ "\$NAME" == GITHUB_* ]] && LABELS+=(--label "\$NAME=\$VAL")
  done < <(printenv)
  echo "\${LABELS[@]}"
}

case "\$CMD" in
  # docker build …
  build)
    LABEL_ARGS=(\$(collect_labels))
    exec "$SHIM_DIR/docker-original" build "\$@" "\${LABEL_ARGS[@]}"
    ;;

  # docker buildx build …
  buildx)
    SUB=\$1; shift
    if [[ "\$SUB" == "build" ]]; then
      LABEL_ARGS=(\$(collect_labels))
      exec "$SHIM_DIR/docker-original" buildx build "\$@" "\${LABEL_ARGS[@]}"
    else
      # pass through other buildx subcommands
      exec "$SHIM_DIR/docker-original" buildx "\$SUB" "\$@"
    fi
    ;;

  # everything else (run, pull, push…)
  *)
    exec "$SHIM_DIR/docker-original" "\$CMD" "\$@"
    ;;
esac
EOF

sudo chmod +x "$SHIM_DIR/docker"

# 4) Inject our shim into PATH for GitHub Actions
if [[ -n "${GITHUB_PATH-}" ]]; then
  # For CI (non-login shells)
  echo "$SHIM_DIR" >> "$GITHUB_PATH"
else
  # For local installs (login shells)
  echo "export PATH=\"$SHIM_DIR:\$PATH\"" | sudo tee /etc/profile.d/labels-shim.sh
fi

echo "[labels] shim installed; docker build/buildx will now include all GITHUB_* labels"
