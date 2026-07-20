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
echo "==> Asking claude for a commit message suggestion..."
suggested_msg="$(git -C "$REPO" diff --cached | claude -p \
  "Write a concise git commit message (subject line only, imperative mood, no trailing period) for this diff. Output ONLY the commit message, nothing else." \
  2>/dev/null || true)"

if [[ -n "$suggested_msg" ]]; then
  echo "Suggested: $suggested_msg"
fi

read -r -t 3 -p "Commit message [Enter to accept suggestion, auto-accepts in 3s]: " msg || true
echo ""

if [[ -z "$msg" ]]; then
  msg="$suggested_msg"
fi

if [[ -z "$msg" ]]; then
  echo "Aborting commit (empty message)."
  git -C "$REPO" reset HEAD
  exit 1
fi

git -C "$REPO" commit -m "$msg"

echo ""
echo "==> Verifying gh user matches repo owner..."
remote_url="$(git -C "$REPO" remote get-url origin)"
expected_user="$(echo "$remote_url" | sed -E 's#^(https?://|git@)github\.com[:/]##; s#/.*##')"
active_user="$(gh auth status 2>&1 | grep -B1 'Active account: true' | grep 'Logged in' | sed -E 's/.*account ([^ ]+).*/\1/')" || true

if [[ -z "$expected_user" ]]; then
  echo "Warning: could not determine expected gh user from remote URL ($remote_url); skipping check." >&2
elif [[ "$active_user" != "$expected_user" ]]; then
  echo "Active gh user is '$active_user', but this repo belongs to '$expected_user'."
  echo "==> Switching gh account to '$expected_user'..."
  gh auth switch -u "$expected_user"
else
  echo "gh user OK: $active_user"
fi

git -C "$REPO" push
