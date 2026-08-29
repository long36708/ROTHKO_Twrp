#!/usr/bin/env bash
# Freeze an already-synced OrangeFox tree into a pinned manifest so CI builds
# are reproducible.
#
# Why: orangefox_sync.sh always fetches the newest revisions. Upstream moves
# break device-tree source patches and make failures impossible to reproduce.
# A pinned manifest records the exact revision of every project instead.
#
# Usage:
#   manifests/generate-pinned-manifest.sh [branch]      # branch: 12.1 | 14.1
#
# Environment:
#   ORANGEFOX_TOP  synced OrangeFox source root (default: $HOME/fox_<branch>)
#   OFOX_SYNC_DIR  clone of https://gitlab.com/OrangeFox/sync.git (optional;
#                  when present, its revision is recorded next to the manifest)
#
# Run this on the machine that holds the synced source (needs `repo` + `git`).
# The generated XML is then committed to this repository (or to the device
# tree's manifests/ directory) and consumed by .github/workflows.

set -euo pipefail

BRANCH="${1:-14.1}"
case "$BRANCH" in
  12.1 | 14.1) ;;
  *)
    echo "unsupported branch: $BRANCH (expected 12.1 or 14.1)" >&2
    exit 1
    ;;
esac

MANIFESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TOP="${ORANGEFOX_TOP:-$HOME/fox_${BRANCH}}"
OUT="$MANIFESTS_DIR/orangefox-fox_${BRANCH}-pinned.xml"

command -v repo >/dev/null 2>&1 || {
  echo "repo not found in PATH" >&2
  exit 1
}

if [[ ! -f "$TOP/build/envsetup.sh" ]]; then
  cat >&2 <<EOF
OrangeFox source root not found: $TOP

Sync it first. Remember to 'cd' into the sync clone before running the script,
otherwise it cannot locate its patches/ directory:

  git clone https://gitlab.com/OrangeFox/sync.git ~/ofox-sync
  cd ~/ofox-sync
  ./orangefox_sync.sh --branch $BRANCH --path $TOP

Or point at an existing tree: ORANGEFOX_TOP=/path/to/fox_${BRANCH} $0 $BRANCH
EOF
  exit 1
fi

echo "OrangeFox top: $TOP"
cd "$TOP"

# -r pins every project to its currently checked-out revision.
repo manifest -r -o "$OUT"

if [[ ! -s "$OUT" ]]; then
  echo "repo manifest produced no output: $OUT" >&2
  exit 1
fi

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$OUT"
fi

project_count="$(grep -c '<project ' "$OUT" || true)"
if [[ "$project_count" -eq 0 ]]; then
  echo "manifest contains no <project> entries: $OUT" >&2
  exit 1
fi
echo "pinned projects: $project_count"

if [[ -n "${OFOX_SYNC_DIR:-}" && -d "$OFOX_SYNC_DIR" ]]; then
  sync_revision_file="$MANIFESTS_DIR/orangefox-fox_${BRANCH}-sync-revision.txt"
  git -C "$OFOX_SYNC_DIR" rev-parse HEAD >"$sync_revision_file"
  echo "sync revision: $(cat "$sync_revision_file")"
fi

# .gitattributes 的 `* text=auto` 会在提交时把 CRLF 归一化为 LF, 因此仓库里
# 存的、CI 检出的是 LF 内容。必须针对规范化后的内容计算校验和:
# 在 Windows 上直接对 CRLF 工作区文件求哈希, 记录的值会与 Linux 检出不一致,
# CI 的 `sha256sum --check --strict` 就会失败。
normalize_dir="$(mktemp -d)"
trap 'rm -rf "$normalize_dir"' EXIT
tr -d '\r' <"$OUT" >"$normalize_dir/$(basename "$OUT")"
(
  cd "$normalize_dir"
  sha256sum "$(basename "$OUT")" \
    >"$MANIFESTS_DIR/$(basename "$OUT").sha256"
)
rm -rf "$normalize_dir"
trap - EXIT
cat "$MANIFESTS_DIR/$(basename "$OUT").sha256"

cat <<EOF

Pinned manifest written: $OUT
Commit it, and CI will take the reproducible path instead of orangefox_sync.sh.
Regenerate whenever you intentionally move to a newer OrangeFox base.
EOF
