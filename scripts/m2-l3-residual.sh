#!/usr/bin/env bash
# M2 L3 residual probe — one command: rebuild -> L3 build -> residual buckets + first opt error.
# This is the per-session progress meter for docs/plans/m2/ROADMAP.md.
#
# Usage:
#   scripts/m2-l3-residual.sh                 # full loop: rebuild stage0 + L3 build + analyze
#   scripts/m2-l3-residual.sh --no-rebuild    # reuse current probe binary, rebuild .ll + analyze
#   scripts/m2-l3-residual.sh --analyze-only  # analyze existing nextpas.ll (seconds)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LL=".nextpas/cache/backend/linux-x86_64/nextpas.ll"
PROBE="./nextpas-m2-l3-probe"
OUT="${M2_RESIDUAL_OUT:-/tmp/m2-l3-residual}"
HISTORY=".nextpas/m2-residual-history.tsv"
mkdir -p "$OUT"

do_rebuild=1; do_build=1
for a in "$@"; do case "$a" in
  --no-rebuild)   do_rebuild=0 ;;
  --analyze-only) do_rebuild=0; do_build=0 ;;
  *) echo "unknown arg: $a" >&2; exit 2 ;;
esac; done

if (( do_rebuild )); then
  echo "[1/4] rebuild stage0 ..."
  ./scripts/rebuild-compiler.sh >"$OUT/rebuild.log" 2>&1 \
    || { echo "rebuild=FAIL  log=$OUT/rebuild.log"; exit 1; }
  /bin/cp -f build/stage0-bootstrap/nextpas "$PROBE"
fi

if (( do_build )); then
  echo "[2/4] L3 build (full stage0 driver -> LLVM) ..."
  [[ -x "$PROBE" ]] || { echo "missing probe binary $PROBE (run without --no-rebuild first)"; exit 1; }
  rm -f "$LL"
  "$PROBE" build tools/stage0/nextpas.pas \
    --target linux-x86_64 \
    --toolchain-binding linux-x86_64-to-linux-x86_64-llvm \
    --workspace "$PWD" --out-dir "$OUT/out" >"$OUT/build.log" 2>&1
  rc=$?
  [[ -f "$LL" ]] || { echo "build=FAIL (no $LL emitted)  log=$OUT/build.log"; exit 1; }
  (( rc != 0 )) && echo "  build exit=$rc (expected while L3 is open)  log=$OUT/build.log"
fi

[[ -f "$LL" ]] || { echo "no $LL — run once without --analyze-only"; exit 1; }

echo "[3/4] residual analysis of $LL ..."
sym='[A-Za-z$._][A-Za-z0-9$._]*'
grep -oE "^define[^@]*@$sym"  "$LL" | sed 's/.*@//' | sort -u >"$OUT/defined.txt"
grep -oE "^declare[^@]*@$sym" "$LL" | sed 's/.*@//' | sort -u >"$OUT/declared.txt"
grep -oE "^@$sym *=" "$LL" | sed -e 's/^@//' -e 's/ *=$//' | sort -u >"$OUT/globals.txt"
grep -oE "(call|invoke)[^@]*@$sym\(" "$LL" | sed -e 's/.*@//' -e 's/($//' | sort >"$OUT/calls_all.txt"
# Non-call uses count too (vmt/imt table entries, store operands: "ptr @X") —
# opt rejects them exactly like undefined callees (B5e imt blind spot).
grep -oE "ptr @$sym" "$LL" | sed 's/ptr @//' | sort >"$OUT/ptrrefs_all.txt"
sort "$OUT/calls_all.txt" "$OUT/ptrrefs_all.txt" >"$OUT/uses_all.txt"
sort -u "$OUT/uses_all.txt" >"$OUT/calls_uniq.txt"
sort -u "$OUT/defined.txt" "$OUT/declared.txt" "$OUT/globals.txt" >"$OUT/resolved.txt"
comm -23 "$OUT/calls_uniq.txt" "$OUT/resolved.txt" >"$OUT/undefined_uniq.txt"
grep -Fxf "$OUT/undefined_uniq.txt" "$OUT/uses_all.txt" >"$OUT/undefined_all.txt" 2>/dev/null || : >"$OUT/undefined_all.txt"

N_DEF=$(wc -l <"$OUT/defined.txt")
N_DECL=$(wc -l <"$OUT/declared.txt")
U_UNIQ=$(wc -l <"$OUT/undefined_uniq.txt")
U_TOT=$(wc -l <"$OUT/undefined_all.txt")

sort "$OUT/undefined_all.txt" | uniq -c | sort -rn >"$OUT/undefined_ranked.txt"

# Bucket taxonomy from docs/plans/m2/wave0-ledger.md (classification frozen there).
awk '
function bucket(s) {
  if (s ~ /^(SizeOf|High|Low|Length|Ord|Chr|Succ|Pred|Abs|Odd|Assigned|Trunc|Round|Inc|Dec)(\$|$)/) return "intrinsic";
  if (s ~ /^(atomic_|Interlocked|InterLocked|(Init|Done|Enter|Leave|TryEnter)CriticalSection)/)      return "atomic";
  if (s ~ /^(SameText|SameStr|Trim|TrimLeft|TrimRight|ParamStr|ParamCount|ExpandFileName|ExtractFile|IntToStr|StrToInt|TryStrToInt|Format|UpperCase|LowerCase|CompareText|StringReplace|IncludeTrailing)/) return "sysutils-string";
  if (s ~ /\./)                                                       return "method-object";
  if (s ~ /^[A-Z][A-Z0-9_]+$/)                                        return "const-upper";
  if (s ~ /^(np_|platform_|fpc_|FPC_)/)                               return "runtime-decl";
  if (s ~ /^\$/ || s == "Result" || s == "Self" || s ~ /^[AFGL][A-Z][a-z0-9]/) return "var-param";
  return "project-helper";
}
{ b = bucket($2); cnt[b] += $1; uniq[b]++ }
END { for (b in cnt) printf "%-16s uniq=%-5d total=%d\n", b, uniq[b], cnt[b] }
' "$OUT/undefined_ranked.txt" | sort -t= -k3 -rn >"$OUT/buckets.txt"

echo "[4/4] opt -O2 first error ..."
OPT_STATE="SKIP(no-opt-in-PATH)"
if command -v opt >/dev/null 2>&1; then
  if opt -O2 -o /dev/null "$LL" 2>"$OUT/opt.err"; then OPT_STATE="PASS"; else OPT_STATE="FAIL"; fi
fi

mkdir -p "$(dirname "$HISTORY")"
printf '%s\t%s\t%s\t%s\n' "$(date +%F-%H%M)" "$U_UNIQ" "$U_TOT" "$OPT_STATE" >>"$HISTORY"

echo
echo "================ M2 L3 residual ================"
echo "undefined: uniq=$U_UNIQ  total=$U_TOT   (define=$N_DEF declare=$N_DECL)"
echo
echo "-- buckets (fix wholesale, descending total; taxonomy: wave0-ledger) --"
cat "$OUT/buckets.txt"
echo
echo "-- top offenders --"
head -12 "$OUT/undefined_ranked.txt"
echo
echo "-- opt -O2: $OPT_STATE --"
[[ "$OPT_STATE" == "FAIL" ]] && head -3 "$OUT/opt.err"
echo
echo "-- history ($HISTORY) --"
tail -5 "$HISTORY"
echo
echo "details: $OUT/  (undefined_uniq.txt / undefined_ranked.txt / buckets.txt)"
