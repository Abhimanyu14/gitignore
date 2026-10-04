#!/bin/bash

# Enable strict error handling:
# -e: exit immediately on command failure
# -u: treat unset variables as errors
# -o pipefail: catch failures in piped commands
set -euo pipefail

# Capture start timestamp in seconds to calculate execution duration
start_time=$(date +%s)

# Array of workspace directory names to exclude from updating
excludedDirectories=(
  "gitignore"
  "private-files"
  "samples"
)

# Navigate up one level to workspace root
cd ..
ROOT_DIR="$(pwd)"

# Absolute path to canonical master .gitignore source file
GITIGNORE_SRC="${ROOT_DIR}/gitignore/.gitignore"

# Validate that the source file exists before executing
if [ ! -f "$GITIGNORE_SRC" ]; then
  echo "Error: Source gitignore file not found at $GITIGNORE_SRC" >&2
  exit 1
fi

# Core function to process and update an individual repository
update_gitignore() {
  local dir="$1"
  local repo_path="${ROOT_DIR}/${dir}"

  # Subshell block `( ... )` isolates directory context (`cd`) across parallel jobs
  (
    cd "$repo_path" || exit 0

    # Skip directory if not a Git repository
    if [ ! -d ".git" ]; then
      exit 0
    fi

    # Skip repository if unresolved merge conflicts exist
    if git status --porcelain | grep -qE '^(U|AA|DD|AU|UA|DU|UD)'; then
      echo "Skipping $dir: Unresolved merge conflicts present." >&2
      exit 0
    fi

    # Track whether local uncommitted working changes were stashed
    local stashed=false
    if [ -n "$(git status --porcelain)" ]; then
      if git stash save --quiet "temp-gitignore-script-stash" >/dev/null 2>&1; then
        stashed=true
      fi
    fi

    # Identify currently active Git branch
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)

    # Skip updates if repository is in detached HEAD state
    if [ "$branch" = "HEAD" ]; then
      echo "Skipping $dir: Repository is in a detached HEAD state." >&2
      [ "$stashed" = "true" ] && git stash pop --quiet >/dev/null 2>&1 || true
      exit 0
    fi

    # Attempt pulling remote updates for current branch
    if ! git pull origin "$branch" >/dev/null 2>&1; then
      echo "Skipping $dir: Failed to pull remote updates." >&2
      [ "$stashed" = "true" ] && git stash pop --quiet >/dev/null 2>&1 || true
      exit 0
    fi

    # Compare local .gitignore against source template byte-by-byte
    if ! cmp -s .gitignore "$GITIGNORE_SRC"; then
      echo "Updating .gitignore in: $dir"
      cp "$GITIGNORE_SRC" .gitignore
      git add .gitignore >/dev/null 2>&1
      git commit -m "[TECH] updated gitignore" >/dev/null 2>&1
      git push origin "$branch" >/dev/null 2>&1 || echo "Warning: Push failed for $dir" >&2
    fi

    # Restore stashed changes if saved earlier
    if [ "$stashed" = "true" ]; then
      if ! git stash pop --quiet >/dev/null 2>&1; then
        echo "Warning: Stash restoration failed for $dir. Check git stash manually." >&2
      fi
    fi
  )
}

# Export environment variables and function for subshell access
export ROOT_DIR GITIGNORE_SRC
export -f update_gitignore

# Maximum number of concurrent background Git jobs (increase if server/network allows)
MAX_JOBS=10

# Fast helper function to check active background job count
get_job_count() {
  jobs -p | wc -l | tr -d ' '
}

# Iterate through every directory in the workspace root
for dir_path in */; do
  dir="${dir_path%/}" # Strip trailing slash

  # Exclusion check
  skip=false
  for excluded in "${excludedDirectories[@]}"; do
    if [ "$dir" = "$excluded" ]; then
      skip=true
      break
    fi
  done

  if [ "$skip" = "true" ]; then
    continue
  fi

  # Execute update task asynchronously in background
  update_gitignore "$dir" &

  # Fast low-latency throttling (50ms poll instead of 500ms)
  while [ "$(get_job_count)" -ge "$MAX_JOBS" ]; do
    sleep 0.05
  done
done

# Block main script execution until all remaining background jobs finish
wait

# Calculate elapsed execution time
duration=$(($(date +%s) - start_time ))

echo -e "\n.gitignore updated across repositories in ${duration} seconds!"
