#!/usr/bin/env bash
set -eo pipefail

# figure out which shim we were invoked as
CMD=$(basename "$0")
REAL_BIN="${CMD}-original"
REAL_PATH="$(command -v "$REAL_BIN" || true)"

if [[ ! -x "$REAL_PATH" ]]; then
  echo "[labels-action] ERROR: cannot find real '$REAL_BIN' binary" >&2
  exit 1
fi

# decide whether this invocation is a build
INJECT=false
if [[ "$CMD" == "docker-buildx" && "$1" == "build" ]]; then
  INJECT=true
elif [[ "$CMD" == "docker" ]]; then
  case "$1" in
    build) INJECT=true ;;
    buildx)
      [[ "${2:-}" == "build" ]] && INJECT=true
      ;;
  esac
fi

if $INJECT; then
  # collect all GITHUB_* vars into --label args
  LABEL_ARGS=()
  while IFS='=' read -r NAME VALUE; do
    [[ "$NAME" =~ ^GITHUB_ ]] && LABEL_ARGS+=(--label "${NAME}=${VALUE}")
  done < <(printenv)

  echo "[labels-action] injecting labels: ${LABEL_ARGS[*]}" >&2
  exec "$REAL_PATH" "$@" "${LABEL_ARGS[@]}"
else
  exec "$REAL_PATH" "$@"
fi
