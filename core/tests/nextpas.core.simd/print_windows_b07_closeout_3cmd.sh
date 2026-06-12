#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LBatchId="${1:-SIMD-$(date '+%Y%m%d')-152}"

cat <<'EOM' | sed "s/__BATCH_ID__/${LBatchId}/g"
[CLOSEOUT] Current worktree closeout guidance

- Historical Windows/GH closeout shell helpers are not restored in this worktree.
- Do not treat the old GH/main-entry commands below as runnable current truth:
  - `BuildOrTest.sh closeout-release`
  - `BuildOrTest.sh win-evidence-preflight`
  - `BuildOrTest.sh win-evidence-via-gh`
  - `BuildOrTest.sh finalize-win-evidence`
  - `BuildOrTest.sh win-closeout-snippets`
  - `BuildOrTest.sh win-closeout-finalize`

[CLOSEOUT] Current local 3-step path

1) Windows native evidence capture + verify
   tests\nextpas.core.simd\buildOrTest.bat evidence-win-verify

2) Linux/Git Bash/WSL fail-close cross gate
   FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate

3) Freeze confirmation
   FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status

[CLOSEOUT] Useful local diagnostics

- Linux freeze-only status:
  FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status-linux
- Gate/freeze selfcheck:
  bash tests/nextpas.core.simd/BuildOrTest.sh gate-summary-selfcheck
- Reference batch id for notes/manual follow-up:
  __BATCH_ID__
EOM
