#!/usr/bin/env bash
set -eo pipefail

if [ $# -lt 1 ]; then
  echo "[labels-action] ERROR: missing shim name argument" >&2
  exit 1
fi

# The first argument is the shim name: "docker" or "docker-buildx"
CMD_NAME="$1"
shift

# Find the real binary (docker-original or docker-buildx-original)
REAL_BIN="$(command -v "${CMD_NAME}-original" || true)"
if [[ ! -x "$REAL_BIN" ]]; then
  echo "[labels-action] ERROR: real '$CMD_NAME' binary not found at '${CMD_NAME}-original'" >&2
  exit 1
fi

# Decide whether to inject on build/buildx build
INJECT=false
if [[ "$CMD_NAME" == "docker-buildx" ]]; then
  [[ "${1:-}" == "build" ]] && INJECT=true
elif [[ "$CMD_NAME" == "docker" ]]; then
  case "$1" in
    build) INJECT=true ;;
    buildx)
      [[ "${2:-}" == "build" ]] && INJECT=true
      ;;
  esac
fi

if $INJECT; then
  # Collect all GITHUB_* vars into --label args
  LABEL_ARGS=()
  while IFS='=' read -r NAME VALUE; do
    [[ "$NAME" =~ ^GITHUB_ ]] && LABEL_ARGS+=(--label "${NAME}=${VALUE}")
  done < <(printenv)

  echo "[labels-action] injecting labels: ${LABEL_ARGS[*]}" >&2
  exec "$REAL_BIN" "$@" "${LABEL_ARGS[@]}"
else
  exec "$REAL_BIN" "$@"
fi
