#!/usr/bin/env bash
set -eo pipefail

# Log file for tracking all Docker commands
LOG_FILE="${HOME}/labels-shim/docker-commands.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Determine which shim was invoked (docker or docker-buildx)
CMD=$(basename "$0")
REAL_BIN="${CMD}-original"
REAL_PATH="$(command -v "$REAL_BIN" || true)"

if [[ ! -x "$REAL_PATH" ]]; then
  echo "[labels-action] ERROR: cannot find real '$REAL_BIN' binary" >&2
  exit 1
fi

# Decide if we should inject labels (only on build commands)
INJECT=false
if [[ "$CMD" == "docker-buildx" && "$1" == "build" ]]; then
  INJECT=true
elif [[ "$CMD" == "docker" ]]; then
  case "$1" in
    build)      INJECT=true ;;  
    buildx)     [[ "$2" == "build" || "$2" == "b" ]] && INJECT=true ;;  
    builder)    [[ "$2" == "build" ]] && INJECT=true ;;  
    image)      [[ "$2" == "build" ]] && INJECT=true ;;  
  esac
fi

# Save original arguments for exec
ORIGINAL_ARGS=("$@")

# Log every command invocation
echo "$CMD $*" >> "$LOG_FILE"

# If not a build, just exec the real binary
if ! $INJECT; then
  exec "$REAL_PATH" "${ORIGINAL_ARGS[@]}"
fi

# Context Collection Functions 

autodetect_platform() {
  if   [[ -n "${GITHUB_RUN_ID:-}" ]]; then echo "github"
  elif [[ -n "${CI_JOB_ID:-}"     ]]; then echo "gitlab"
  elif [[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]]; then echo "bitbucket"
  elif [[ -n "${AZURE_RUN_ID:-}" || -n "${BUILD_BUILDID:-}" ]]; then echo "azure"
  elif [[ -n "${CIRCLE_BUILD_NUM:-}" ]]; then echo "circleci"
  elif [[ -n "${TRAVIS_JOB_ID:-}" ]]; then echo "travis"
  elif [[ -n "${BUILD_ID:-}"      ]]; then echo "jenkins"
  else                                 echo "local"
  fi
}

normalize_git_url() {
  local url="$1"
  url="${url##+([[:space:]])}"
  url="${url%%+([[:space:]])}"
  if [[ "$url" =~ ^git@github\.com:(.*)$ ]]; then
    url="https://github.com/${BASH_REMATCH[1]}.git"
  elif [[ "$url" =~ ^git@(.*)$ ]]; then
    local a="${BASH_REMATCH[1]#:}"
    url="https://${a}"
  elif [[ "$url" =~ ^https://github\.com/.* ]] && [[ ! "$url" =~ \.git$ ]]; then
    url="${url}.git"
  fi
  echo "$url"
}

collect_pipeline_and_git() {
  local p="$1"
  case "$p" in
    github)
      echo "platform";     echo "github"
      echo "run_id";       echo "${GITHUB_RUN_ID:-}"
      echo "actor";        echo "${GITHUB_ACTOR:-}"
      echo "workflow";     echo "${GITHUB_WORKFLOW:-}"
      echo "job_name";     echo ""
      echo "event";        echo "${GITHUB_EVENT_NAME:-}"
      echo "organization"; echo "${GITHUB_REPOSITORY_OWNER:-}"
      local ref="${GITHUB_REF:-}"
      local branch=""; [[ -n "$ref" ]] && branch="${ref##*/}"
      local url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}.git"
      url="$(normalize_git_url "$url")"
      echo "git_commit"; echo "${GITHUB_SHA:-}"
      echo "git_ref";    echo "$ref"
      echo "git_branch"; echo "$branch"
      echo "git_url";    echo "$url"
      echo "git_tag";    echo ""
      ;;
    gitlab)
      echo "platform";     echo "gitlab"
      echo "run_id";       echo "${CI_JOB_ID:-}"
      echo "actor";        echo "${GITLAB_USER_NAME:-}"
      echo "workflow";     echo "${CI_PIPELINE_NAME:-}"
      echo "job_name";     echo "${CI_JOB_NAME:-}"
      echo "event";        echo "${CI_PIPELINE_SOURCE:-}"
      echo "organization"; echo "${CI_PROJECT_ROOT_NAMESPACE:-}"
      echo "git_url";      echo "${CI_REPOSITORY_URL:-}"
      echo "git_commit";   echo "${CI_COMMIT_SHA:-}"
      echo "git_ref";      echo "${CI_COMMIT_REF_NAME:-}"
      echo "git_branch";   echo "${CI_COMMIT_BRANCH:-}"
      echo "git_tag";      echo "${CI_COMMIT_TAG:-}"
      ;;
    bitbucket)
      echo "platform"; echo "bitbucket"
      echo "run_id";   echo "${BITBUCKET_PIPELINE_UUID:-}"
      echo "actor";    echo "${BITBUCKET_STEP_TRIGGERER_UUID:-}"
      echo "workflow"; echo "${BITBUCKET_PIPELINE_UUID:-}"
      echo "job_name"; echo "${BITBUCKET_STEP_UUID:-}"
      echo "event";    echo ""
      echo "organization"; echo "${BITBUCKET_WORKSPACE:-}"
      local bb_br="${BITBUCKET_BRANCH:-}"
      local bb_tag="${BITBUCKET_TAG:-}"
      local ref=""
      [[ -n "$bb_tag" ]] && ref="refs/tags/$bb_tag" || [[ -n "$bb_br" ]] && ref="refs/heads/$bb_br"
      local url="${BITBUCKET_GIT_HTTP_ORIGIN:-}.git"
      url="$(normalize_git_url "$url")"
      echo "git_commit"; echo "${BITBUCKET_COMMIT:-}"
      echo "git_branch"; echo "$bb_br"
      echo "git_ref";    echo "$ref"
      echo "git_url";    echo "$url"
      echo "git_tag";    echo "$bb_tag"
      ;;
    azure)
      echo "platform"; echo "azure"
      local rid="${AZURE_RUN_ID:-$BUILD_BUILDID}"
      echo "run_id";   echo "$rid"
      echo "actor";    echo "${BUILD_REQUESTEDFORID:-}"
      echo "workflow"; echo "${SYSTEM_DEFINITIONNAME:-}"
      echo "job_name"; echo "${SYSTEM_JOBNAME:-}"
      echo "event";    echo "${BUILD_REASON:-}"
      echo "organization"; echo ""
      echo "git_commit"; echo "${BUILD_SOURCEVERSION:-}"
      echo "git_ref";    echo "${BUILD_SOURCEBRANCH:-}"
      echo "git_branch"; echo "${BUILD_SOURCEBRANCHNAME:-}"
      echo "git_url";    echo "$(normalize_git_url "${BUILD_REPOSITORY_URI:-}")"
      echo "git_tag";    echo ""
      ;;
    circleci)
      echo "platform"; echo "circleci"
      echo "run_id"; echo "${CIRCLE_WORKFLOW_ID:-}"
      echo "actor";    echo "${CIRCLE_PROJECT_USERNAME:-}"
      echo "workflow"; echo "${CIRCLE_WORKFLOW_ID:-}"
      echo "job_name"; echo "${CIRCLE_JOB:-}"
      echo "event";    echo ""
      echo "organization"; echo "${CIRCLE_ORGANIZATION_ID:-}"
      echo "git_commit"; echo "${CIRCLE_SHA1:-}"
      echo "git_ref";    echo "${CIRCLE_REF:-}"
      echo "git_branch"; echo "${CIRCLE_BRANCH:-}"
      echo "git_url";    echo "$(normalize_git_url "${CIRCLE_REPOSITORY_URL:-}")"
      echo "git_tag";    echo "${CIRCLE_TAG:-}"
      ;;
    travis)
      echo "platform"; echo "travis"
      echo "run_id"; echo "${TRAVIS_JOB_ID:-}"
      echo "actor"; echo ""
      echo "workflow"; echo ""
      echo "job_name"; echo ""
      echo "event";    echo ""
      echo "organization"; echo ""
      echo "git_branch"; echo "${TRAVIS_BRANCH:-}"
      echo "git_commit"; echo "${TRAVIS_COMMIT:-}"
      echo "git_ref";    echo "${TRAVIS_REF:-}"
      echo "git_url";    echo ""
      echo "git_tag";    echo "${TRAVIS_TAG:-}"
      ;;
    jenkins)
      echo "platform"; echo "jenkins"
      echo "run_id"; echo "${BUILD_ID:-}"
      echo "actor"; echo ""
      echo "workflow"; echo "${JOB_NAME:-}"
      echo "job_name"; echo "${STAGE_NAME:-}"
      echo "event";    echo ""
      echo "organization"; echo ""
      echo "git_commit"; echo "${GIT_COMMIT:-}"
      echo "git_branch"; echo "${GIT_BRANCH:-}"
      echo "git_ref";    echo "${GIT_BRANCH:-}"
      echo "git_url";    echo "${GIT_URL:-}"
      echo "git_tag";    echo ""
      ;;
    *)
      echo "platform"; echo "local"
      echo "run_id"; echo ""
      echo "actor";   echo "${USER:-unknown}"
      echo "workflow"; echo ""
      echo "job_name"; echo ""
      echo "event";    echo ""
      echo "organization"; echo ""
      if git rev-parse HEAD >/dev/null 2>&1; then
        local url
        url="$(normalize_git_url "$(git remote get-url origin 2>/dev/null || echo "")")"
        echo "git_url";    echo "$url"
        echo "git_commit"; echo "$(git rev-parse HEAD)"
        echo "git_branch"; echo "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        echo "git_ref";    echo "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
        echo "git_tag";    echo "$(git describe --tags --exact-match 2>/dev/null || echo "")"
      else
        echo "git_url";    echo ""
        echo "git_commit"; echo ""
        echo "git_branch"; echo ""
        echo "git_ref";    echo ""
        echo "git_tag";    echo ""
      fi
      ;;
  esac
}

# Build JSON context
platform="$(autodetect_platform)"
declare -a pairs=()
while IFS= read -r key && IFS= read -r val; do
  pairs+=("$key" "$val")
done < <(collect_pipeline_and_git "$platform")

json="{"
for ((i=0; i<${#pairs[@]}; i+=2)); do
  k="${pairs[i]}"
  v="${pairs[i+1]}"
  [[ -z "$v" || "$k" =~ (_TOKEN|_PASSWORD|_SECRET) ]] && continue
  v_esc=$(printf '%s' "$v" | sed 's/"/\\"/g')
  json+="\"$k\":\"$v_esc\"," 
done
json="${json%,}}"

# Preload the CI prefix var
case "$platform" in
  github)    prefix_var="GITHUB_RUN_ID";         prefix_val="${GITHUB_RUN_ID:-}" ;;  
  gitlab)    prefix_var="CI_JOB_ID";              prefix_val="${CI_JOB_ID:-}" ;;  
  bitbucket) prefix_var="BITBUCKET_PIPELINE_UUID"; prefix_val="${BITBUCKET_PIPELINE_UUID:-}" ;;  
  azure)     prefix_var="AZURE_RUN_ID";           prefix_val="${AZURE_RUN_ID:-}" ;;  
  circleci)  prefix_var="CIRCLE_WORKFLOW_ID";     prefix_val="${CIRCLE_WORKFLOW_ID:-}" ;;  
  travis)    prefix_var="TRAVIS_JOB_ID";         prefix_val="${TRAVIS_JOB_ID:-}" ;;  
  jenkins)   prefix_var="BUILD_ID";              prefix_val="${BUILD_ID:-}" ;;  
  *)         prefix_var="";                       prefix_val="" ;;  
esac

LABEL_ARGS=(--label "CONTEXT=$json")
if [[ -n "$prefix_var" && -n "$prefix_val" ]]; then
  LABEL_ARGS+=(--label "$prefix_var=$prefix_val")
fi

# Baseimage Extraction 
# Default Dockerfile, override if -f provided
DOCKERFILE="Dockerfile"
for ((i=0; i<${#ORIGINAL_ARGS[@]}; i++)); do
  if [[ "${ORIGINAL_ARGS[i]}" == "-f" ]]; then
    DOCKERFILE="${ORIGINAL_ARGS[i+1]}"
    break
  fi
done

if [[ -f "$DOCKERFILE" ]]; then
  FROM_LINE=$(grep -i '^FROM' "$DOCKERFILE" | tail -n1)
  BASE_IMAGE=$(echo "$FROM_LINE" | awk '{print $2}')
  esc_from=$(printf '%s' "$FROM_LINE" | sed 's/"/\\"/g')
  esc_df=$(printf '%s' "$DOCKERFILE" | sed 's/"/\\"/g')
  esc_base=$(printf '%s' "$BASE_IMAGE" | sed 's/"/\\"/g')
  BASE_JSON="{\"dockerfile\":\"$esc_df\",\"from_line\":\"$esc_from\",\"base_image\":\"$esc_base\"}"
  LABEL_ARGS+=(--label "Baseimage=$BASE_JSON")
fi

# DockerCommands Label
if [[ -f "$LOG_FILE" ]]; then
  CMDS_JSON="["
  while IFS= read -r line; do
    esc_line=${line//"/\\"}
    CMDS_JSON+="\"$esc_line\"," 
done < "$LOG_FILE"
  CMDS_JSON="${CMDS_JSON%,}]"
  LABEL_ARGS+=(--label "DockerCommands=$CMDS_JSON")
fi

# Finally, inject labels and hand off to the real Docker binary
echo "[labels-action] injecting labels: ${LABEL_ARGS[*]}" >&2
exec "$REAL_PATH" "${ORIGINAL_ARGS[@]}" "${LABEL_ARGS[@]}"