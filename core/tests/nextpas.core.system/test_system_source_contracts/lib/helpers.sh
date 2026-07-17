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

require_repo_owner_family_token() {
  local relative_root="$1"
  local owner_base="$2"
  local token="$3"
  local owner_root="$REPO_ROOT/$relative_root"
  local owner_path="$owner_root/${owner_base}.pas"
  local current_path include_name include_path
  local index=0
  local -a owner_files
  local -A seen_files

  [[ -s "$owner_path" ]] || fail "$relative_root/$owner_base owner source missing"
  owner_files=("$owner_path")
  seen_files["$owner_path"]=1

  while (( index < ${#owner_files[@]} )); do
    current_path="${owner_files[$index]}"
    index=$((index + 1))
    while IFS= read -r include_name; do
      case "$include_name" in
        /*|*/*|*..*)
          fail "${current_path#$REPO_ROOT/} has out-of-family include: $include_name"
          ;;
      esac
      include_path="$owner_root/$include_name"
      [[ -s "$include_path" ]] ||
        fail "${current_path#$REPO_ROOT/} includes missing file: $include_name"
      if [[ -z "${seen_files[$include_path]+present}" ]]; then
        owner_files+=("$include_path")
        seen_files["$include_path"]=1
      fi
    done < <(
      awk '
        BEGIN { IGNORECASE = 1 }
        match($0, /\{\$(i|include)[ \t]+([^} \t]+)/, parts) {
          print parts[2]
        }
      ' "$current_path"
    )
  done

  if ! rg -F --quiet -- "$token" "${owner_files[@]}"; then
    fail "$relative_root/$owner_base owner family missing token: $token"
  fi
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
