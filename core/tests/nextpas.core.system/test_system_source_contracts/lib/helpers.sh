# Shared helper functions for source-contract checks.
# Sourced by check_system_source_contracts.sh — do not run directly.

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$CORE_ROOT/$path" ]] || fail "required non-empty file missing: core/$path"
}

require_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$CORE_ROOT/$path" || fail "core/$path missing token: $token"
}

require_repo_file() {
  local path="$1"
  [[ -s "$REPO_ROOT/$path" ]] || fail "required non-empty repo file missing: $path"
}

require_repo_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$REPO_ROOT/$path" || fail "$path missing token: $token"
}

reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$CORE_ROOT/$path"; then
    fail "core/$path must not contain token: $token"
  fi
}

require_repo_reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$REPO_ROOT/$path"; then
    fail "$path must not contain token: $token"
  fi
}

require_repo_reject_regex() {
  local path="$1"
  local regex="$2"
  if rg --quiet -- "$regex" "$REPO_ROOT/$path"; then
    fail "$path must not match regex: $regex"
  fi
}

list_pascal_uses_units() {
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function emit_units(line, parts, i, unit) {
      gsub(/\{[^}]*\}/, "", line)
      sub(/\/\/.*/, "", line)
      gsub(/^[ \t]*uses[ \t]*/, "", line)
      split(line, parts, /[,;]/)
      for (i in parts) {
        unit = trim(parts[i])
        if (unit != "" && unit !~ /^\$/) {
          print unit
        }
      }
    }
    /^[ \t]*uses[ \t]*/ {
      in_uses = 1
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
      next
    }
    in_uses {
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
    }
  ' "$1"
}

require_repo_not_uses_unit() {
  local path="$1"
  local forbidden_unit="$2"
  if list_pascal_uses_units "$REPO_ROOT/$path" | grep -Fxi --quiet "$forbidden_unit"; then
    fail "$path must not directly use unit: $forbidden_unit"
  fi
}
