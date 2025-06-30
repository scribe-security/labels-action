#!/usr/bin/env bash
set -eo pipefail

# 1) Create the global shim directory
SHIM_DIR="/usr/local/labels-shim"
sudo mkdir -p "$SHIM_DIR"

# 2) Backup the real docker and docker-buildx binaries
sudo cp "$(command -v docker)" "$SHIM_DIR/docker-original"
sudo chmod +x "$SHIM_DIR/docker-original"
if command -v docker-buildx &>/dev/null; then
  sudo cp "$(command -v docker-buildx)" "$SHIM_DIR/docker-buildx-original"
  sudo chmod +x "$SHIM_DIR/docker-buildx-original"
fi

# 3) Download the entrypoint injector into the shim
sudo curl -sSfL \
  "https://raw.githubusercontent.com/scribe-security/labels-action/main/entrypoint.sh" \
  -o "$SHIM_DIR/entrypoint.sh"
sudo chmod +x "$SHIM_DIR/entrypoint.sh"

# 4) Create wrapper scripts for docker and (standalone) docker-buildx
sudo tee "$SHIM_DIR/docker" >/dev/null <<EOF
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker "\$@"
EOF

sudo tee "$SHIM_DIR/docker-buildx" >/dev/null <<EOF
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker-buildx "\$@"
EOF

sudo chmod +x "$SHIM_DIR/docker" "$SHIM_DIR/docker-buildx"

# 5) Hijack the Docker CLI plugin for buildx
PLUGIN_DIR="/usr/libexec/docker/cli-plugins"
if [ -d "$PLUGIN_DIR" ]; then
  # backup the real plugin
  if [ -x "$PLUGIN_DIR/docker-buildx" ]; then
    sudo cp "$PLUGIN_DIR/docker-buildx" "$SHIM_DIR/docker-buildx-plugin-original"
  fi

  # overwrite it with our shim
  sudo tee "$PLUGIN_DIR/docker-buildx" >/dev/null <<EOF
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker-buildx "\$@"
EOF

  sudo chmod +x "$PLUGIN_DIR/docker-buildx"
fi

# 6) Prepend shim to system-wide PATH via /etc/profile.d
sudo mkdir -p /etc/profile.d
echo "export PATH=\"$SHIM_DIR:\$PATH\"" | sudo tee /etc/profile.d/labels-shim.sh

echo "[labels] shim installed in PATH; future docker commands will include labels"

# 7) If running in GitHub Actions, register our shim so remaining steps pick it up
if [[ -n "${GITHUB_PATH-}" ]]; then
  echo "$SHIM_DIR" >> "$GITHUB_PATH"
  echo "[labels] registered $SHIM_DIR in GITHUB_PATH for subsequent steps"
fi
