#!/usr/bin/env bash
# Prints one git tree hash for the current working tree.
#
# The hash covers committed, uncommitted, and untracked files. It leaves out
# files that .gitignore ignores. Two runs on the same files print the same
# hash, so the hash tells whether the code changed between two points.
#
# The tester agent copies this hash into audit.md as its "Tree:" line.
# commit-and-pr compares the hash again before its pre-flight check. When the
# two hashes are equal, the code is the code that the tester passed, and the
# pre-flight check does not run again.
#
# changelog/ is left out. commit-and-pr writes the changelog entry after the
# tester ran, and that entry is not code.
#
# The script does not change the real index or the stash stack. It copies the
# index to a temporary file and stages into the copy only.
#
# Usage: bash .claude/scripts/tree-hash.sh

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

real_index="$(git rev-parse --git-path index)"
tmp_index="$(mktemp)"
trap 'rm -f "$tmp_index"' EXIT

if [ -f "$real_index" ]; then
  cp "$real_index" "$tmp_index"
else
  rm -f "$tmp_index"
fi

export GIT_INDEX_FILE="$tmp_index"
# core.safecrlf=false stops the line-ending warnings on Windows. The hash
# goes to stdout and the warnings would go to stderr, but they add noise.
git -c core.safecrlf=false add -A
git rm -r --cached -q --ignore-unmatch changelog
git write-tree
