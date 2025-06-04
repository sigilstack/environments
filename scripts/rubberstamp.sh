#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI 'gh' is not installed or not in PATH."
  exit 1
fi

say() {
  printf "%s\n" "$1"
}

squelch() {
  "$@" > /dev/null 2>&1
}

# Ensure cleanup of temp files even on error
trap 'rm -f .pr_summary.tmp' EXIT

say "🔍 Checking current and default branches..."
CURRENT_BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
  say "🚫 Refusing to rubberstamp from default branch ($DEFAULT_BRANCH)."
  exit 1
fi

if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
  say "📡 No upstream set for '$CURRENT_BRANCH'. Setting upstream..."
  squelch git push --set-upstream origin "$CURRENT_BRANCH" || {
    say "❌ Failed to push and set upstream for '$CURRENT_BRANCH'."
    exit 1
  }
else
  say "⬆️  Pushing current branch '$CURRENT_BRANCH' to origin..."
  squelch git push || {
    say "❌ Failed to push current branch '$CURRENT_BRANCH' to origin."
    exit 1
  }
fi

say "📥 Fetching latest commits from '$DEFAULT_BRANCH'..."
squelch git fetch origin "$DEFAULT_BRANCH" || {
  say "❌ Failed to fetch from origin/$DEFAULT_BRANCH."
  exit 1
}
say "📝 Generating PR summary from commits since '$DEFAULT_BRANCH'..."
git log origin/"$DEFAULT_BRANCH"..HEAD --pretty=format:"- %s" > .pr_summary.tmp

if [[ ! -s .pr_summary.tmp ]]; then
  say "⚠️  No new commits to summarize. Aborting."
  exit 1
fi

PR_NUM=$(gh pr list --state open --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)
if [[ -z "$PR_NUM" || "$PR_NUM" == "null" ]]; then
  say "🆕 Creating new pull request..."
  squelch gh pr create --fill --body-file .pr_summary.tmp
else
  say "🔁 PR already exists for this branch (#$PR_NUM)."
fi

say "🔀 Attempting to squash and merge the PR..."
squelch gh pr merge --squash || say "⚠️  Merge already in progress or completed"

while [[ "$(gh pr view --json mergedAt --jq .mergedAt 2>/dev/null)" == "null" ]]; do
  say "⏳ Waiting for PR to be merged..."
  sleep 5
done

say "📦 Checking out '$DEFAULT_BRANCH' and pulling latest changes..."
if ! squelch git checkout "$DEFAULT_BRANCH"; then
  say "❌ Failed to checkout '$DEFAULT_BRANCH'."
  exit 1
fi
if ! squelch git pull; then
  say "❌ Failed to pull latest changes from '$DEFAULT_BRANCH'."
  exit 1
fi

if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]]; then
  say "🧹 Deleting remote branch '$CURRENT_BRANCH'..."
  if ! squelch git push origin --delete "$CURRENT_BRANCH"; then
    say "⚠️  Failed to delete remote branch '$CURRENT_BRANCH'."
  fi
fi

say "✅ Cleanup complete."
