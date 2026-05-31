#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_ID="${FAFAFA_MINIMAL_CI_GATE_RUN_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
COMPILE_UNIT_OUTPUT_DIR="${FAFAFA_MINIMAL_CI_GATE_COMPILE_UNIT_OUTPUT_DIR:-tmp/minimal_ci_gate_compile_units_${RUN_ID}}"
MODULE_UNIT_OUTPUT_DIR="${FAFAFA_MINIMAL_CI_GATE_MODULE_UNIT_OUTPUT_DIR:-tmp/minimal_ci_gate_module_units_${RUN_ID}}"
MODULE_BIN_OUTPUT_DIR="${FAFAFA_MINIMAL_CI_GATE_MODULE_BIN_OUTPUT_DIR:-tmp/minimal_ci_gate_module_bin_${RUN_ID}}"
FPC_EXE="${FAFAFA_FPC_EXE:-fpc}"

DRY_RUN=false
VERBOSE=false
WITH_PHASE2_DRYRUN=true
WITH_COMPILE=true
WITH_MODULES=true
MODULE_SET="PKCS7,PKCS12,CMS,Store,OCSP,TS,CT"
WITH_TLS13_SIGN_PURITY_CHECK=false
WITH_TLS13_SIGN_BENCH=false
FAST_LOCAL=false
TLS13_SIGN_BENCH_ITERATIONS="3"
TLS13_SIGN_BENCH_WARMUP="1"
TLS13_SIGN_BENCH_SCHEME="rsa_pkcs1_sha256"
TLS13_SIGN_BENCH_KEY="tests/certificate/test_certs/signer_key.pem"
TLS13_SIGN_BENCH_TIMEOUT="120"
TLS13_SIGN_BENCH_JSON_OUT=""
WARN_LIMIT="${FAFAFA_WARN_LIMIT:-0}"

usage() {
  cat <<'USAGE'
最小 CI 门禁脚本（Draft）

目标：
  以最低成本覆盖“可编译 + P2 核心回归 + Phase2 基准入口可用性”。

用法：
  scripts/run_minimal_ci_gate.sh [options]

选项：
  --fast-local                       本地快速模式：模块测试与报告输出到 ./tmp（避免污染 git 工作区）
  --modules LIST                     指定模块列表（默认: PKCS7,PKCS12,CMS,Store,OCSP,TS,CT）
  --skip-compile                     跳过 compile_all_modules 阶段
  --skip-modules                     跳过 run_all_module_tests 阶段
  --skip-phase2-dryrun               跳过 Phase2 baseline 脚本 dry-run 检查
  --with-tls13-sign-purity-check     追加运行 TLS13 signer 纯 Pascal 依赖静态检查
  --with-tls13-sign-bench            追加运行 TLS13 CertificateVerify 纯 Pascal 签名基准
  --only-tls13-sign-bench            快速模式：仅运行 TLS13 签名基准（自动启用 skip + with）
  --tls13-sign-bench-iterations N    TLS13 签名基准迭代次数（默认: 3）
  --tls13-sign-bench-warmup N        TLS13 签名基准预热次数（默认: 1）
  --tls13-sign-bench-scheme NAME     基准算法（默认: rsa_pkcs1_sha256）
  --tls13-sign-bench-key PATH        私钥路径（默认: tests/certificate/test_certs/signer_key.pem）
  --tls13-sign-bench-timeout N       基准超时时间（秒，默认: 120）
  --tls13-sign-bench-json-out PATH   基准 JSON 输出路径（可选）
  --verbose                          模块测试启用 verbose
  --dry-run                          仅打印命令，不执行
  --help                             显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast-local)
      FAST_LOCAL=true
      shift
      ;;
    --modules)
      MODULE_SET="$2"
      shift 2
      ;;
    --skip-compile)
      WITH_COMPILE=false
      shift
      ;;
    --skip-modules)
      WITH_MODULES=false
      shift
      ;;
    --skip-phase2-dryrun)
      WITH_PHASE2_DRYRUN=false
      shift
      ;;
    --with-tls13-sign-purity-check)
      WITH_TLS13_SIGN_PURITY_CHECK=true
      shift
      ;;
    --with-tls13-sign-bench)
      WITH_TLS13_SIGN_BENCH=true
      shift
      ;;
    --only-tls13-sign-bench)
      WITH_COMPILE=false
      WITH_MODULES=false
      WITH_PHASE2_DRYRUN=false
      WITH_TLS13_SIGN_PURITY_CHECK=false
      WITH_TLS13_SIGN_BENCH=true
      shift
      ;;
    --tls13-sign-bench-iterations)
      TLS13_SIGN_BENCH_ITERATIONS="$2"
      shift 2
      ;;
    --tls13-sign-bench-warmup)
      TLS13_SIGN_BENCH_WARMUP="$2"
      shift 2
      ;;
    --tls13-sign-bench-scheme)
      TLS13_SIGN_BENCH_SCHEME="$2"
      shift 2
      ;;
    --tls13-sign-bench-key)
      TLS13_SIGN_BENCH_KEY="$2"
      shift 2
      ;;
    --tls13-sign-bench-timeout)
      TLS13_SIGN_BENCH_TIMEOUT="$2"
      shift 2
      ;;
    --tls13-sign-bench-json-out)
      TLS13_SIGN_BENCH_JSON_OUT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$FAST_LOCAL" == "false" ]]; then
  if [[ "${FAFAFA_FAST_LOCAL:-}" == "1" || "${FAFAFA_FAST_LOCAL:-}" == "true" ]]; then
    FAST_LOCAL=true
  fi
fi

if [[ ! "$TLS13_SIGN_BENCH_ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$TLS13_SIGN_BENCH_ITERATIONS" -le 0 ]]; then
  echo "Invalid --tls13-sign-bench-iterations: $TLS13_SIGN_BENCH_ITERATIONS" >&2
  exit 1
fi

if [[ ! "$TLS13_SIGN_BENCH_WARMUP" =~ ^[0-9]+$ ]] || [[ "$TLS13_SIGN_BENCH_WARMUP" -lt 0 ]]; then
  echo "Invalid --tls13-sign-bench-warmup: $TLS13_SIGN_BENCH_WARMUP" >&2
  exit 1
fi

if [[ ! "$TLS13_SIGN_BENCH_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TLS13_SIGN_BENCH_TIMEOUT" -le 0 ]]; then
  echo "Invalid --tls13-sign-bench-timeout: $TLS13_SIGN_BENCH_TIMEOUT" >&2
  exit 1
fi

run_project_cmd() {
  local cmd_desc="$1"
  shift

  echo "[GATE] $cmd_desc"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi

  (
    cd "$PROJECT_ROOT"
    "$@"
  )
}

echo "========================================"
echo "fafafa.ssl Minimal CI Gate (Draft)"
echo "========================================"
echo "[INFO] run_id: $RUN_ID"
echo "[INFO] compile unit output dir: $COMPILE_UNIT_OUTPUT_DIR"
echo "[INFO] module unit output dir: $MODULE_UNIT_OUTPUT_DIR"
echo "[INFO] module bin output dir: $MODULE_BIN_OUTPUT_DIR"

if [[ "$WITH_COMPILE" == "true" ]]; then
  compile_args=(
    python3 scripts/compile_all_modules.py
    --unit-output-dir "$COMPILE_UNIT_OUTPUT_DIR"
    --fpc-exe "$FPC_EXE"
  )
  compile_desc="cd '$PROJECT_ROOT' && python3 scripts/compile_all_modules.py --unit-output-dir '$COMPILE_UNIT_OUTPUT_DIR' --fpc-exe '$FPC_EXE'"
  if [[ "$WARN_LIMIT" -gt 0 ]]; then
    compile_args+=(--warn-limit "$WARN_LIMIT")
    compile_desc="$compile_desc --warn-limit $WARN_LIMIT"
  fi
  run_project_cmd "$compile_desc" "${compile_args[@]}"
fi

if [[ "$WITH_MODULES" == "true" ]]; then
  module_cmd_desc="cd '$PROJECT_ROOT' && FAFAFA_FPC_EXE='$FPC_EXE' FAFAFA_FPC_UNIT_OUTPUT_DIR='$MODULE_UNIT_OUTPUT_DIR' FAFAFA_TEST_BIN_DIR='$MODULE_BIN_OUTPUT_DIR' bash scripts/run_all_module_tests.sh --modules $MODULE_SET"
  module_cmd=(
    env
    "FAFAFA_FPC_EXE=$FPC_EXE"
    "FAFAFA_FPC_UNIT_OUTPUT_DIR=$MODULE_UNIT_OUTPUT_DIR"
    "FAFAFA_TEST_BIN_DIR=$MODULE_BIN_OUTPUT_DIR"
    bash scripts/run_all_module_tests.sh
    --modules "$MODULE_SET"
  )
  if [[ "$FAST_LOCAL" == "true" ]]; then
    module_cmd_desc="$module_cmd_desc --fast-local"
    module_cmd+=(--fast-local)
  fi
  if [[ "$VERBOSE" == "true" ]]; then
    module_cmd_desc="$module_cmd_desc --verbose"
    module_cmd+=(--verbose)
  fi
  run_project_cmd "$module_cmd_desc" "${module_cmd[@]}"
fi

if [[ "$WITH_PHASE2_DRYRUN" == "true" ]]; then
  phase2_cmd_desc="cd '$PROJECT_ROOT' && bash scripts/run_phase2_performance_baseline.sh --dry-run --iterations 200 --tls-iterations 50"
  phase2_cmd=(
    bash scripts/run_phase2_performance_baseline.sh
    --dry-run
    --iterations 200
    --tls-iterations 50
  )
  if [[ "$FAST_LOCAL" == "true" ]]; then
    phase2_cmd_desc="$phase2_cmd_desc --fast-local --run-id '$RUN_ID'"
    phase2_cmd+=(--fast-local --run-id "$RUN_ID")
  fi
  run_project_cmd "$phase2_cmd_desc" "${phase2_cmd[@]}"
fi

if [[ "$WITH_TLS13_SIGN_PURITY_CHECK" == "true" ]]; then
  run_project_cmd \
    "cd '$PROJECT_ROOT' && bash scripts/check_tls13_signer_pure_pascal.sh" \
    bash scripts/check_tls13_signer_pure_pascal.sh
fi

if [[ "$WITH_TLS13_SIGN_BENCH" == "true" ]]; then
  tls13_bench_cmd_desc="cd '$PROJECT_ROOT' && FAFAFA_TLS13_SIGN_BENCH_ITERATIONS='$TLS13_SIGN_BENCH_ITERATIONS' FAFAFA_TLS13_SIGN_BENCH_WARMUP='$TLS13_SIGN_BENCH_WARMUP' FAFAFA_TLS13_SIGN_BENCH_SCHEME='$TLS13_SIGN_BENCH_SCHEME' FAFAFA_TLS13_SIGN_BENCH_KEY='$TLS13_SIGN_BENCH_KEY' FAFAFA_TLS13_SIGN_BENCH_TIMEOUT='$TLS13_SIGN_BENCH_TIMEOUT' FAFAFA_TLS13_SIGN_BENCH_JSON_OUT='$TLS13_SIGN_BENCH_JSON_OUT' bash scripts/run_freepascal_tls13_servercertverify_bench.sh"
  tls13_bench_cmd=(
    env
    "FAFAFA_TLS13_SIGN_BENCH_ITERATIONS=$TLS13_SIGN_BENCH_ITERATIONS"
    "FAFAFA_TLS13_SIGN_BENCH_WARMUP=$TLS13_SIGN_BENCH_WARMUP"
    "FAFAFA_TLS13_SIGN_BENCH_SCHEME=$TLS13_SIGN_BENCH_SCHEME"
    "FAFAFA_TLS13_SIGN_BENCH_KEY=$TLS13_SIGN_BENCH_KEY"
    "FAFAFA_TLS13_SIGN_BENCH_TIMEOUT=$TLS13_SIGN_BENCH_TIMEOUT"
    "FAFAFA_TLS13_SIGN_BENCH_JSON_OUT=$TLS13_SIGN_BENCH_JSON_OUT"
    bash scripts/run_freepascal_tls13_servercertverify_bench.sh
  )
  run_project_cmd "$tls13_bench_cmd_desc" "${tls13_bench_cmd[@]}"
fi

echo "[PASS] minimal CI gate finished"
