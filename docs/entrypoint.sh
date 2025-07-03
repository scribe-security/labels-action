#!/usr/bin/env bash
set -eo pipefail

# --------------------------------------------------------------------
# Helper: detect CI platform
# --------------------------------------------------------------------
autodetect_platform() {
  if [[ -n "${GITHUB_RUN_ID:-}" ]]; then       echo "github"
  elif [[ -n "${CI_JOB_ID:-}" ]]; then         echo "gitlab"
  elif [[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]]; then echo "bitbucket"
  elif [[ -n "${AZURE_RUN_ID:-}" || -n "${BUILD_BUILDID:-}" ]]; then echo "azure"
  elif [[ -n "${CIRCLE_BUILD_NUM:-}" ]]; then  echo "circleci"
  elif [[ -n "${TRAVIS_JOB_ID:-}" ]]; then     echo "travis"
  elif [[ -n "${BUILD_ID:-}" ]]; then          echo "jenkins"
  else                                          echo "local"
  fi
}

# --------------------------------------------------------------------
# Normalize Git URL to https format
# --------------------------------------------------------------------
normalize_git_url() {
  local url="$1"
  # trim
  url="${url##+( )}"
  url="${url%%+( )}"
  if [[ "$url" =~ ^git@github\.com:(.*)$ ]]; then
    url="https://github.com/${BASH_REMATCH[1]}.git"
  elif [[ "$url" =~ ^git@(.*)$ ]]; then
    local after="${BASH_REMATCH[1]#:}"
    url="https://${after}"
  elif [[ "$url" =~ ^https://github\.com/.* ]] && [[ ! "$url" =~ \.git$ ]]; then
    url="${url}.git"
  fi
  echo "$url"
}

# --------------------------------------------------------------------
# Collect pipeline + git info, emit key/value pairs
# --------------------------------------------------------------------
collect_pipeline_and_git() {
  local platform="$1"
  case "$platform" in
    github)
      echo "platform";     echo "github"
      echo "run_id";       echo "${GITHUB_RUN_ID:-}"
      echo "actor";        echo "${GITHUB_ACTOR:-}"
      echo "workflow";     echo "${GITHUB_WORKFLOW:-}"
      echo "job_name";     echo ""
      echo "event";        echo "${GITHUB_EVENT_NAME:-}"
      echo "organization"; echo "${GITHUB_REPOSITORY_OWNER:-}"
      local git_ref="${GITHUB_REF:-}"
      local branch=""
      [[ -n "$git_ref" ]] && branch="${git_ref##*/}"
      local server="${GITHUB_SERVER_URL:-https://github.com}"
      local repo_url=""
      [[ -n "${GITHUB_REPOSITORY:-}" ]] && repo_url="${server}/${GITHUB_REPOSITORY}.git"
      repo_url="$(normalize_git_url "$repo_url")"
      echo "git_commit"; echo "${GITHUB_SHA:-}"
      echo "git_ref";    echo "$git_ref"
      echo "git_branch"; echo "$branch"
      echo "git_url";    echo "$repo_url"
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
      echo "git_url";    echo "${CI_REPOSITORY_URL:-}"
      echo "git_commit"; echo "${CI_COMMIT_SHA:-}"
      echo "git_ref";    echo "${CI_COMMIT_REF_NAME:-}"
      echo "git_branch"; echo "${CI_COMMIT_BRANCH:-}"
      echo "git_tag";    echo "${CI_COMMIT_TAG:-}"
      ;;
    bitbucket)
      echo "platform";     echo "bitbucket"
      echo "run_id";       echo "${BITBUCKET_PIPELINE_UUID:-}"
      echo "actor";        echo "${BITBUCKET_STEP_TRIGGERER_UUID:-}"
      echo "workflow";     echo "${BITBUCKET_PIPELINE_UUID:-}"
      echo "job_name";     echo "${BITBUCKET_STEP_UUID:-}"
      echo "event";        echo ""
      echo "organization"; echo "${BITBUCKET_WORKSPACE:-}"
      local bb_branch="${BITBUCKET_BRANCH:-}"
      local bb_tag="${BITBUCKET_TAG:-}"
      local ref=""
      if [[ -n "$bb_tag" ]]; then ref="refs/tags/$bb_tag"
      elif [[ -n "$bb_branch" ]]; then ref="refs/heads/$bb_branch"; fi
      local origin="${BITBUCKET_GIT_HTTP_ORIGIN:-}.git"
      origin="$(normalize_git_url "$origin")"
      echo "git_commit"; echo "${BITBUCKET_COMMIT:-}"
      echo "git_branch"; echo "$bb_branch"
      echo "git_ref";    echo "$ref"
      echo "git_url";    echo "$origin"
      echo "git_tag";    echo "$bb_tag"
      ;;
    azure)
      echo "platform"; echo "azure"
      local run_id="${AZURE_RUN_ID:-$BUILD_BUILDID}"
      echo "run_id";   echo "$run_id"
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
      echo "platform";     echo "circleci"
      echo "run_id";       echo "${CIRCLE_WORKFLOW_ID:-}"
      echo "actor";        echo "${CIRCLE_PROJECT_USERNAME:-}"
      echo "workflow";     echo "${CIRCLE_WORKFLOW_ID:-}"
      echo "job_name";     echo "${CIRCLE_JOB:-}"
      echo "event";        echo ""
      echo "organization"; echo "${CIRCLE_ORGANIZATION_ID:-}"
      echo "git_commit"; echo "${CIRCLE_SHA1:-}"
      echo "git_ref";    echo "${CIRCLE_REF:-}"
      echo "git_branch"; echo "${CIRCLE_BRANCH:-}"
      echo "git_url";    echo "$(normalize_git_url "${CIRCLE_REPOSITORY_URL:-}")"
      echo "git_tag";    echo "${CIRCLE_TAG:-}"
      ;;
    travis)
      echo "platform";     echo "travis"
      echo "run_id";       echo "${TRAVIS_JOB_ID:-}"
      echo "actor";        echo ""
      echo "workflow";     echo ""
      echo "job_name";     echo ""
      echo "event";        echo ""
      echo "organization"; echo ""
      echo "git_branch"; echo "${TRAVIS_BRANCH:-}"
      echo "git_commit"; echo "${TRAVIS_COMMIT:-}"
      echo "git_ref";    echo "${TRAVIS_REF:-}"
      echo "git_url";    echo ""
      echo "git_tag";    echo "${TRAVIS_TAG:-}"
      ;;
    jenkins)
      echo "platform";     echo "jenkins"
      echo "run_id";       echo "${BUILD_ID:-}"
      echo "actor";        echo ""
      echo "workflow";     echo "${JOB_NAME:-}"
      echo "job_name";     echo "${STAGE_NAME:-}"
      echo "event";        echo ""
      echo "organization"; echo ""
      echo "git_commit"; echo "${GIT_COMMIT:-}"
      echo "git_branch"; echo "${GIT_BRANCH:-}"
      echo "git_ref";    echo "${GIT_BRANCH:-}"
      echo "git_url";    echo "${GIT_URL:-}"
      echo "git_tag";    echo ""
      ;;
    *)
      echo "platform";     echo "local"
      echo "run_id";       echo ""
      echo "actor";        echo "${USER:-unknown_user}"
      echo "workflow";     echo ""
      echo "job_name";     echo ""
      echo "event";        echo ""
      echo "organization"; echo ""
      if git rev-parse HEAD >/dev/null 2>&1; then
        local url; url="$(normalize_git_url "$(git remote get-url origin 2>/dev/null || echo)")"
        echo "git_url";    echo "$
]}]}


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
