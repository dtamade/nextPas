#!/usr/bin/env bash
# path-mixuse-audit.sh — PathDir / FsPathDir / PathJoin call-site inventory (ci/docs)
# Does NOT change path semantics. Exit 1 only if dual-track test anchors vanish.
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUT_MD="${1:-$REPO_ROOT/core/docs/path/MIXUSE-AUDIT.md}"

CORE_SRC="$REPO_ROOT/core/src"
COMPILER="$REPO_ROOT/compiler"
TEST_PATH_LPR="$REPO_ROOT/core/tests/nextpas.core.path/test_path/test_path.lpr"
TEST_FS_LPR="$REPO_ROOT/core/tests/nextpas.core.fs/test_fs/test_fs.lpr"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
fail=0
warn=0

ok() { printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# Collect pas files under core/src and compiler (exclude build artifacts)
mapfile -t PAS_FILES < <(
  find "$CORE_SRC" -name '*.pas' -type f 2>/dev/null
  if [[ -d "$COMPILER" ]]; then
    find "$COMPILER" -name '*.pas' -type f 2>/dev/null
  fi
)

rel() {
  local p="$1"
  echo "${p#"$REPO_ROOT"/}"
}

# --- E: anchors (fail-closed) ---
printf "\n${BOLD}E: dual-track test anchors${NC}\n"
if [[ -f "$TEST_PATH_LPR" ]] && grep -q "PathDir('file.txt')" "$TEST_PATH_LPR" && \
   grep -E "PathDir\('file\.txt'\)[[:space:]]*=[[:space:]]*''" "$TEST_PATH_LPR" >/dev/null 2>&1; then
  ok "test_path: PathDir('file.txt') = ''"
else
  fail_check "test_path missing bare PathDir('') anchor"
fi
if [[ -f "$TEST_FS_LPR" ]] && grep -q "FsPathDir('file.txt')" "$TEST_FS_LPR" && \
   ( grep -E "FsPathDir\('file\.txt'\).*'\.'" "$TEST_FS_LPR" >/dev/null 2>&1 || \
     grep -E "CheckEqual\('\.'[[:space:]]*,[[:space:]]*FsPathDir\('file\.txt'\)" "$TEST_FS_LPR" >/dev/null 2>&1 ); then
  ok "test_fs: FsPathDir('file.txt') = '.'"
else
  fail_check "test_fs missing bare FsPathDir('.') anchor"
fi

# --- A: FsPathDir sites ---
printf "\n${BOLD}A: FsPathDir call sites${NC}\n"
FSPATHDIR_HITS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && FSPATHDIR_HITS+=("$line")
done < <(
  for f in "${PAS_FILES[@]}"; do
    # skip definitions only loosely: still list all
    grep -nE '\bFsPathDir\s*\(' "$f" 2>/dev/null | while IFS= read -r hit; do
      echo "$(rel "$f"):${hit}"
    done || true
  done
)
if ((${#FSPATHDIR_HITS[@]} == 0)); then
  ok "no FsPathDir( calls (unexpected if path.pas gone)"
else
  ok "FsPathDir sites: ${#FSPATHDIR_HITS[@]}"
  for h in "${FSPATHDIR_HITS[@]}"; do printf "  %s\n" "$h"; done
fi

# --- B: PathDir sites (exclude function PathDir definitions lines roughly) ---
printf "\n${BOLD}B: PathDir call sites${NC}\n"
PATHDIR_HITS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && PATHDIR_HITS+=("$line")
done < <(
  for f in "${PAS_FILES[@]}"; do
    grep -nE '\bPathDir\s*\(' "$f" 2>/dev/null | while IFS= read -r hit; do
      # skip pure declarations: function PathDir(
      if echo "$hit" | grep -qE 'function[[:space:]]+PathDir'; then
        continue
      fi
      echo "$(rel "$f"):${hit}"
    done || true
  done
)
ok "PathDir sites: ${#PATHDIR_HITS[@]}"
for h in "${PATHDIR_HITS[@]}"; do printf "  %s\n" "$h"; done

# --- C: same unit uses both path and fs ---
printf "\n${BOLD}C: units uses both nextpas.core.path and nextpas.core.fs${NC}\n"
BOTH_USES=()
for f in "${PAS_FILES[@]}"; do
  # crude: whole file text for uses of both (include implementation uses)
  if grep -qE 'nextpas\.core\.path\b' "$f" 2>/dev/null && \
     grep -qE 'nextpas\.core\.fs\b' "$f" 2>/dev/null; then
    # fs.util / fs.dir alone: require core.fs or core.fs,
    if grep -qE 'nextpas\.core\.fs([.;,]|$)' "$f" || grep -qE 'nextpas\.core\.fs\s*,' "$f"; then
      BOTH_USES+=("$(rel "$f")")
    fi
  fi
done
# refine: path + (fs as unit not only fs.path via path.pas)
BOTH_USES_UNIQ=()
while IFS= read -r u; do
  [[ -n "$u" ]] && BOTH_USES_UNIQ+=("$u")
done < <(printf '%s\n' "${BOTH_USES[@]:-}" | sort -u)
if ((${#BOTH_USES_UNIQ[@]} == 0)); then
  ok "no co-use of path + fs facades"
else
  for u in "${BOTH_USES_UNIQ[@]}"; do
    warn_check "co-use path+fs: $u"
  done
fi

# --- D: PathJoin style inventory ---
printf "\n${BOLD}D: PathJoin style inventory${NC}\n"
N_JOIN2=$(grep -rhnE '\bPathJoin2\s*\(' "$CORE_SRC" "$COMPILER" --include='*.pas' 2>/dev/null | wc -l | tr -d ' ')
N_FSPJOIN=$(grep -rhnE '\bFsPathJoin\s*\(' "$CORE_SRC" "$COMPILER" --include='*.pas' 2>/dev/null | wc -l | tr -d ' ')
N_JOIN_ARR=$(grep -rhnE '\bPathJoin\s*\(\s*\[' "$CORE_SRC" "$COMPILER" --include='*.pas' 2>/dev/null | wc -l | tr -d ' ')
N_JOIN_BIN=$(grep -rhnE '\bPathJoin\s*\([^\[].*,' "$CORE_SRC" "$COMPILER" --include='*.pas' 2>/dev/null | wc -l | tr -d ' ')
ok "PathJoin2( calls≈$N_JOIN2  FsPathJoin(≈$N_FSPJOIN  PathJoin([≈$N_JOIN_ARR  PathJoin(a,b)≈$N_JOIN_BIN"

# --- Write markdown report ---
{
  echo "# Path mix-use audit"
  echo
  echo "**Generated**: $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "**Script**: \`scripts/path-mixuse-audit.sh\`"
  echo "**Scope**: \`core/src/**/*.pas\`, \`compiler/**/*.pas\`"
  echo "**Semantics**: unchanged (PathDir facade vs FsPathDir Go)."
  echo
  echo "## Dual-track anchors (fail-closed)"
  echo
  echo "| Anchor | Location | Expected |"
  echo "|--------|----------|----------|"
  echo "| bare PathDir | test_path | \`PathDir('file.txt') = ''\` |"
  echo "| bare FsPathDir | test_fs | \`FsPathDir('file.txt') = '.'\` |"
  echo
  if [[ "$fail" -eq 0 ]]; then
    echo "Status: **PASS** (anchors present)."
  else
    echo "Status: **FAIL** (anchors missing)."
  fi
  echo
  echo "## A. FsPathDir sites (${#FSPATHDIR_HITS[@]})"
  echo
  echo '```'
  printf '%s\n' "${FSPATHDIR_HITS[@]:-(none)}"
  echo '```'
  echo
  echo "## B. PathDir call sites (${#PATHDIR_HITS[@]})"
  echo
  echo '```'
  printf '%s\n' "${PATHDIR_HITS[@]:-(none)}"
  echo '```'
  echo
  echo "## C. Co-use nextpas.core.path + nextpas.core.fs (${#BOTH_USES_UNIQ[@]}) — warn"
  echo
  if ((${#BOTH_USES_UNIQ[@]} == 0)); then
    echo "_None._"
  else
    for u in "${BOTH_USES_UNIQ[@]}"; do
      echo "- \`$u\`"
    done
  fi
  echo
  echo "## D. PathJoin style counts"
  echo
  echo "| Form | Approx count |"
  echo "|------|--------------|"
  echo "| PathJoin2( | $N_JOIN2 |"
  echo "| FsPathJoin( | $N_FSPJOIN |"
  echo "| PathJoin([ | $N_JOIN_ARR |"
  echo "| PathJoin(a,b) style | $N_JOIN_BIN |"
  echo
  echo "## Conclusion"
  echo
  echo "- \`path.PathDir\` and \`fs.PathDir\` both squeeze bare-name dir to empty; risk is **FsPathDir** vs **PathDir**, not path vs fs PathDir."
  echo "- Call sites using \`fs.PathDir\` / \`PathDir\` on lock/file paths (tls/http/git) are typically non-bare → **low risk**."
  echo "- Co-use of path+fs units is **warn-only**; review when adding new joins."
  echo "- **No confirmed production bug** from this static pass (U4)."
  echo
  echo "## Re-run"
  echo
  echo '```bash'
  echo 'bash scripts/path-mixuse-audit.sh'
  echo 'bash scripts/path-contract-check.sh'
  echo '```'
} > "$OUT_MD"

printf "\n${BOLD}Wrote${NC} %s\n" "$(rel "$OUT_MD")"

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "anchors_fail=%d  co_use_warn≈%d\n" "$fail" "$warn"
if [[ "$fail" -gt 0 ]]; then
  printf "${RED}${BOLD}path-mixuse-audit: FAIL${NC}\n"
  exit 1
fi
printf "${GREEN}${BOLD}path-mixuse-audit: OK${NC}\n"
exit 0
