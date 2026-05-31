#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

declare -A allowed_files=(
  ["tests/config/test_config_import_export.pas"]=1
  ["tests/config/test_config_snapshot_clone.pas"]=1
  ["tests/config/test_config_validation.pas"]=1
  ["tests/config/test_context_builder_merge_advanced_option_snapshot_semantics.pas"]=1
  ["tests/config/test_context_builder_server_name_compat_marker.pas"]=1
  ["tests/test_context_builder_server_name_compatibility_warning.pas"]=1
  ["tests/test_context_builder_server_servername_runtime_consistency.pas"]=1
  ["tests/test_data_structures.pas"]=1
  ["tests/test_factory_logic.pas"]=1
  ["tests/test_factory_config_server_name_isolation.pas"]=1
  ["tests/test_factory_server_name_compatibility_warning.pas"]=1
  ["tests/test_factory_server_name_scope_clarification.pas"]=1
  ["tests/test_freepascal_context_server_name_inheritance.pas"]=1
  ["tests/test_freepascal_library_default_config_server_name_clarification.pas"]=1
  ["tests/test_openssl_library_default_config_server_name_clarification.pas"]=1
  ["tests/test_transformation_methods.pas"]=1
  ["tests/test_mbedtls_wolfssl_library_default_config_server_name_clarification.pas"]=1
  ["tests/test_tsslcontextconfig_surface.pas"]=1
)

# Files that test the config surface itself and use deprecated fields as part of
# their coverage but are exempt from the INTENTIONAL_COMPAT marker requirement.
declare -A marker_exempt_files=(
  ["tests/test_tsslcontextconfig_surface.pas"]=1
)

marker='INTENTIONAL_COMPAT:'

for file in "${!allowed_files[@]}"; do
  if [[ -z "${marker_exempt_files[$file]+x}" ]]; then
    if ! rg -n --quiet "$marker" "$file"; then
      echo "[FAIL] missing compatibility label in $file"
      exit 1
    fi
  fi

  if ! rg -n --quiet \
    -e '\.WithSNI\(' \
    -e '\b[A-Za-z_][A-Za-z0-9_]*Config[A-Za-z0-9_]*\.ServerName[[:space:]]*:=' \
    "$file"; then
    echo "[FAIL] allowlisted compatibility file no longer contains deprecated builder/config ServerName surface: $file"
    exit 1
  fi
done

mapfile -t matched_files < <(
  rg -l -g '*.pas' \
    -e '\.WithSNI\(' \
    -e '\b[A-Za-z_][A-Za-z0-9_]*Config[A-Za-z0-9_]*\.ServerName[[:space:]]*:=' \
    tests || true
)

for file in "${matched_files[@]}"; do
  if [[ -z "${allowed_files[$file]+x}" ]]; then
    echo "[FAIL] unexpected deprecated builder/config ServerName surface remains in ordinary test: $file"
    rg -n \
      -e '\.WithSNI\(' \
      -e '\b[A-Za-z_][A-Za-z0-9_]*Config[A-Za-z0-9_]*\.ServerName[[:space:]]*:=' \
      "$file" || true
    exit 1
  fi
done

echo "[PASS] deprecated builder/config ServerName compatibility tests are explicitly labeled and confined"
