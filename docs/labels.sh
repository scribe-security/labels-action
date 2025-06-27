#!/usr/bin/env bash
set -eo pipefail

install_wrapper(){
  BIN="$1"
  REAL="$(command -v "$BIN" || true)"
  [[ -z "$REAL" ]] && { echo "[labels] $BIN not found, skipping" >&2; return; }
  REAL_ORIG="${REAL}-original"
  if [[ ! -x "$REAL_ORIG" ]]; then
    echo "[labels] backing up $REAL → $REAL_ORIG" >&2
    sudo mv "$REAL" "$REAL_ORIG"
  fi
  sudo tee "$REAL" >/dev/null << 'INNER'
#!/usr/bin/env bash
set -eo pipefail

LABEL_ARGS=()
while IFS='=' read -r var val; do
  [[ "\$var" =~ ^GITHUB_ ]] && LABEL_ARGS+=(--label "\$var=\$val")
done < <(printenv)

echo "[labels-wrapper] injecting labels: \${LABEL_ARGS[*]}" >&2
exec "\$0-original" "\$@" "\${LABEL_ARGS[@]}"
INNER
  sudo chmod +x "$REAL"
  echo "[labels] wrapper installed for $BIN" >&2
}

install_wrapper docker
install_wrapper docker-buildx

echo "[labels] done."
