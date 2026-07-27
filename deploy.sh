#!/usr/bin/env bash
# Deploy the Survival Tracker to GitHub Pages.
#
#   ./deploy.sh                 # deploy with an auto timestamp message
#   ./deploy.sh "your message"  # deploy with your own commit message
#
# It copies the source (sw_survival_tracker.html) to the served file
# (index.html), commits both, and pushes to GitHub. GitHub Pages rebuilds
# in ~1 min; hard-refresh (Cmd+Shift+R) to skip the browser cache.

set -euo pipefail

# Always operate on this script's own folder, whatever the current directory.
cd "$(dirname "$0")"

# Keep the served copy in sync with the source of truth.
cp sw_survival_tracker.html index.html

# Stage only the tracker files (junk is handled by .gitignore anyway).
git add sw_survival_tracker.html index.html

if git diff --cached --quiet; then
  echo "Nothing to deploy — index.html already matches the source."
  exit 0
fi

msg="${1:-Update tracker ($(date '+%Y-%m-%d %H:%M'))}"
git commit -m "$msg"
git push

echo ""
echo "✅ Deployed. In ~1 min, hard-refresh (Cmd+Shift+R):"
echo "   https://blairinspace.github.io/survival-tracker-live/"
