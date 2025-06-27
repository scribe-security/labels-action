#!/usr/bin/env bash

set -eo pipefail

CMD_NAME=$(basename "$0")                      
REAL_PATH="$(command -v "$CMD_NAME")-original" 

if [[ ! -x "$REAL_PATH" ]]; then
  echo "[entrypoint] ERROR: real $CMD_NAME not found at $REAL_PATH" >&2
  exit 1
fi

# Only wrap docker build/buildx invocation
if [[ "$CMD_NAME" == "docker-buildx" ]] || \
   ([[ "$CMD_NAME" == "docker" ]] && [[ "$1" == "build" ]]); then

  # Collect all GITHUB_* env vars into --label args
  LABEL_ARGS=()
  while IFS='=' read -r var val; do
    [[ "$var" =~ ^GITHUB_ ]] && LABEL_ARGS+=(--label "${var}=${val}")
  done < <(printenv)

  echo "[entrypoint] injecting labels: ${LABEL_ARGS[*]}" >&2
  exec "$REAL_PATH" "$@" "${LABEL_ARGS[@]}"
else
  # Pass through all other commands unmodified
  exec "$REAL_PATH" "$@"
fi
