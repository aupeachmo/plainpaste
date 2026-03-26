#!/bin/bash
set -euo pipefail

# Get the latest semver tag, sorted properly
latest=$(git tag --list 'v*' --sort=-v:refname | head -n1)

if [ -z "$latest" ]; then
  next="v0.0.1"
else
  # Strip the leading v
  version="${latest#v}"

  IFS='.' read -r major minor patch <<< "$version"
  patch=$((patch + 1))
  next="v${major}.${minor}.${patch}"
fi

echo "Current: ${latest:-none}"
echo "Next:    $next"
echo ""
read -p "Tag and push $next? [y/N] " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  git tag "$next"
  git push origin "$next"
  echo "✅  $next pushed — release will build automatically"
else
  echo "Cancelled."
fi
