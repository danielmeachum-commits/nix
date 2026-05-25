#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user — the script will sudo where needed." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")" && pwd)"
HOST="$(hostname)"

echo "==> Building for host: $HOST"
sudo nixos-rebuild switch --flake "$REPO#$HOST"

echo ""
git -C "$REPO" add -A
git -C "$REPO" diff --cached --stat

if git -C "$REPO" diff --cached --quiet; then
  echo "No changes to commit."
  exit 0
fi

echo ""
read -r -p "Commit message: " msg

if [[ -z "$msg" ]]; then
  echo "Aborting commit (empty message)."
  git -C "$REPO" reset HEAD
  exit 1
fi

git -C "$REPO" commit -m "$msg"
git -C "$REPO" push
