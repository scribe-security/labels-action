#!/usr/bin/env bash
set -eo pipefail

# 1) Create a private shim directory
SHIM_DIR="/usr/local/labels-shim"
sudo mkdir -p "$SHIM_DIR"

# 2) Download the entrypoint (or assume it's bundled)
curl -sSfL "https://raw.githubusercontent.com/scribe-security/labels-action/main/entrypoint.sh" \
  -o "$SHIM_DIR/entrypoint.sh"
sudo chmod +x "$SHIM_DIR/entrypoint.sh"

# 3) Install shims for docker & docker-buildx
sudo tee "$SHIM_DIR/docker" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker "$@"
EOF
sudo tee "$SHIM_DIR/docker-buildx" >/dev/null <<'EOF'
#!/usr/bin/env bash
exec "$SHIM_DIR/entrypoint.sh" docker-buildx "$@"
EOF
sudo chmod +x "$SHIM_DIR/docker" "$SHIM_DIR/docker-buildx"

# 4) Prepend to PATH system-wide
echo "export PATH=\"$SHIM_DIR:\$PATH\"" | sudo tee /etc/profile.d/labels-shim.sh

echo "[labels] shim installed in PATH; future docker commands will include labels"
