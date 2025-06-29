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

# 4) Create wrapper scripts for docker and docker-buildx
sudo tee "$SHIM_DIR/docker" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker "\$@"
EOF

sudo tee "$SHIM_DIR/docker-buildx" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker-buildx "\$@"
EOF

sudo chmod +x "$SHIM_DIR/docker" "$SHIM_DIR/docker-buildx"

# 5) Prepend shim to system-wide PATH via /etc/profile.d
sudo mkdir -p /etc/profile.d
echo "export PATH=\"$SHIM_DIR:\$PATH\"" | sudo tee /etc/profile.d/labels-shim.sh

echo "[labels] shim installed in PATH; future docker commands will include labels"
