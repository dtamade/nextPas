#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_PATH="$REPO_ROOT/rtl/core/system/System.pas"

usage() {
  printf 'Usage: %s <check|sync> <target>\n' "${0##*/}" >&2
}

projection_path() {
  case "$1" in
    linux-x86_64)
      printf '%s\n' "$REPO_ROOT/units/linux-x86_64/System.pas"
      ;;
    *)
      printf '[FAIL] unsupported System projection target: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

[[ $# -eq 2 ]] || {
  usage
  exit 2
}

mode="$1"
target="$2"
installed_path="$(projection_path "$target")"
[[ -s "$CANONICAL_PATH" ]] || {
  printf '[FAIL] canonical System source missing or empty: %s\n' "$CANONICAL_PATH" >&2
  exit 1
}

case "$mode" in
  check)
    if ! cmp -s "$CANONICAL_PATH" "$installed_path"; then
      printf '[FAIL] System projection is stale: target=%s\n' "$target" >&2
      diff -u \
        --label rtl/core/system/System.pas \
        --label "units/$target/System.pas" \
        "$CANONICAL_PATH" "$installed_path" >&2 || true
      exit 1
    fi
    printf 'system-projection-status=ready target=%s\n' "$target"
    ;;
  sync)
    mkdir -p "$(dirname "$installed_path")"
    temporary_path="$(mktemp "${installed_path}.tmp.XXXXXX")"
    trap 'rm -f "${temporary_path:-}"' EXIT
    install -m 0644 "$CANONICAL_PATH" "$temporary_path"
    mv -f "$temporary_path" "$installed_path"
    trap - EXIT
    printf 'system-projection-sync=updated target=%s\n' "$target"
    ;;
  *)
    usage
    printf '[FAIL] unsupported System projection mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
