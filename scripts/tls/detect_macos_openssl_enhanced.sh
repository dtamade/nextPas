#!/usr/bin/env bash
# detect_macos_openssl_enhanced.sh
# B64: macOS brew OpenSSL 路径检测增强
# 提供详细的 OpenSSL 环境诊断和配置建议

set -euo pipefail

# ============================================================
# 配置
# ============================================================
VERBOSE=false
JSON_OUTPUT=false
FIX_MODE=false

# 候选路径（按优先级排序）
OPENSSL_CANDIDATES=(
  "/opt/homebrew/opt/openssl@3"      # Apple Silicon Homebrew
  "/usr/local/opt/openssl@3"         # Intel Homebrew
  "/opt/homebrew/opt/openssl@1.1"    # Apple Silicon OpenSSL 1.1
  "/usr/local/opt/openssl@1.1"       # Intel OpenSSL 1.1
  "/opt/local/libexec/openssl3"      # MacPorts
  "/usr/local/ssl"                   # 手动安装
)

# ============================================================
# 帮助
# ============================================================
usage() {
  cat <<EOF
macOS OpenSSL 路径检测增强工具

用法: $0 [OPTIONS]

选项:
  --verbose       显示详细诊断信息
  --json          JSON 格式输出
  --fix           尝试自动修复（生成 shell 配置）
  -h, --help      显示帮助

示例:
  $0                    # 基本检测
  $0 --verbose          # 详细诊断
  $0 --json             # JSON 输出
  $0 --fix              # 生成修复脚本
EOF
  exit 0
}

# ============================================================
# 参数解析
# ============================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --fix) FIX_MODE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# ============================================================
# 检测函数
# ============================================================

# 检测系统架构
detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    arm64) echo "apple_silicon" ;;
    x86_64) echo "intel" ;;
    *) echo "unknown" ;;
  esac
}

# 检测 Homebrew 路径
detect_homebrew() {
  if command -v brew &>/dev/null; then
    brew --prefix 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# 检测 OpenSSL 安装
detect_openssl_installation() {
  local candidate lib_path include_path version_file
  local found_path=""
  local found_version=""

  for candidate in "${OPENSSL_CANDIDATES[@]}"; do
    lib_path="$candidate/lib"
    include_path="$candidate/include/openssl"

    # 检查库文件
    if [[ -f "$lib_path/libcrypto.dylib" || -f "$lib_path/libcrypto.a" ]]; then
      # 检查头文件
      if [[ -f "$include_path/ssl.h" ]]; then
        found_path="$candidate"

        # 获取版本
        if [[ -x "$candidate/bin/openssl" ]]; then
          found_version=$("$candidate/bin/openssl" version 2>/dev/null | head -1 || echo "unknown")
        fi
        break
      fi
    fi
  done

  echo "$found_path|$found_version"
}

# 检测系统 OpenSSL（LibreSSL）
detect_system_openssl() {
  if [[ -x /usr/bin/openssl ]]; then
    /usr/bin/openssl version 2>/dev/null | head -1 || echo "unknown"
  else
    echo "not found"
  fi
}

# 检测环境变量
check_env_vars() {
  local issues=()

  if [[ -z "${DYLD_LIBRARY_PATH:-}" ]]; then
    issues+=("DYLD_LIBRARY_PATH not set")
  fi

  if [[ -z "${PKG_CONFIG_PATH:-}" ]]; then
    issues+=("PKG_CONFIG_PATH not set")
  fi

  if [[ -z "${OPENSSL_ROOT:-}" ]]; then
    issues+=("OPENSSL_ROOT not set")
  fi

  echo "${issues[*]:-none}"
}

# 检测 FPC 配置
check_fpc_config() {
  if command -v fpc &>/dev/null; then
    fpc -iV 2>/dev/null || echo "unknown"
  else
    echo "not found"
  fi
}

# ============================================================
# 主检测流程
# ============================================================
main() {
  local arch homebrew_prefix openssl_info openssl_path openssl_version
  local system_openssl env_issues fpc_version
  local status="ok"
  local recommendations=()

  # 收集信息
  arch=$(detect_arch)
  homebrew_prefix=$(detect_homebrew)
  openssl_info=$(detect_openssl_installation)
  openssl_path=$(echo "$openssl_info" | cut -d'|' -f1)
  openssl_version=$(echo "$openssl_info" | cut -d'|' -f2)
  system_openssl=$(detect_system_openssl)
  env_issues=$(check_env_vars)
  fpc_version=$(check_fpc_config)

  # 判断状态
  if [[ -z "$openssl_path" ]]; then
    status="error"
    recommendations+=("Install OpenSSL: brew install openssl@3")
  elif [[ "$env_issues" != "none" ]]; then
    status="warning"
    recommendations+=("Set environment variables for OpenSSL")
  fi

  # JSON 输出
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    cat <<EOF
{
  "status": "$status",
  "arch": "$arch",
  "homebrew_prefix": "$homebrew_prefix",
  "openssl_path": "$openssl_path",
  "openssl_version": "$openssl_version",
  "system_openssl": "$system_openssl",
  "env_issues": "$env_issues",
  "fpc_version": "$fpc_version"
}
EOF
    return
  fi

  # 文本输出
  echo "========================================"
  echo "macOS OpenSSL 环境诊断"
  echo "========================================"
  echo ""
  echo "系统信息:"
  echo "  架构: $arch"
  echo "  Homebrew: ${homebrew_prefix:-not found}"
  echo "  FPC: $fpc_version"
  echo ""
  echo "OpenSSL 检测:"
  echo "  系统 OpenSSL: $system_openssl"
  if [[ -n "$openssl_path" ]]; then
    echo "  Homebrew OpenSSL: $openssl_version"
    echo "  路径: $openssl_path"
  else
    echo "  Homebrew OpenSSL: 未安装"
  fi
  echo ""
  echo "环境变量:"
  echo "  DYLD_LIBRARY_PATH: ${DYLD_LIBRARY_PATH:-<not set>}"
  echo "  PKG_CONFIG_PATH: ${PKG_CONFIG_PATH:-<not set>}"
  echo "  OPENSSL_ROOT: ${OPENSSL_ROOT:-<not set>}"
  echo ""

  # 详细诊断
  if [[ "$VERBOSE" == "true" && -n "$openssl_path" ]]; then
    echo "详细检查:"
    echo "  libcrypto.dylib: $(ls -la "$openssl_path/lib/libcrypto.dylib" 2>/dev/null || echo 'missing')"
    echo "  libssl.dylib: $(ls -la "$openssl_path/lib/libssl.dylib" 2>/dev/null || echo 'missing')"
    echo "  ssl.h: $(ls -la "$openssl_path/include/openssl/ssl.h" 2>/dev/null || echo 'missing')"
    echo ""
  fi

  # 状态和建议
  echo "========================================"
  case "$status" in
    ok)
      echo "状态: ✅ 正常"
      ;;
    warning)
      echo "状态: ⚠️ 需要配置"
      ;;
    error)
      echo "状态: ❌ 需要安装"
      ;;
  esac
  echo "========================================"

  if [[ ${#recommendations[@]} -gt 0 ]]; then
    echo ""
    echo "建议操作:"
    for rec in "${recommendations[@]}"; do
      echo "  - $rec"
    done
  fi

  # 修复模式
  if [[ "$FIX_MODE" == "true" && -n "$openssl_path" ]]; then
    echo ""
    echo "========================================"
    echo "修复脚本（添加到 ~/.zshrc 或 ~/.bashrc）:"
    echo "========================================"
    cat <<EOF

# fafafa.ssl OpenSSL 配置
export OPENSSL_ROOT="$openssl_path"
export DYLD_LIBRARY_PATH="\$OPENSSL_ROOT/lib:\${DYLD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="\$OPENSSL_ROOT/lib/pkgconfig:\${PKG_CONFIG_PATH:-}"
export PATH="\$OPENSSL_ROOT/bin:\$PATH"

EOF
  fi

  # 返回状态码
  case "$status" in
    ok) return 0 ;;
    warning) return 0 ;;
    error) return 1 ;;
  esac
}

main
