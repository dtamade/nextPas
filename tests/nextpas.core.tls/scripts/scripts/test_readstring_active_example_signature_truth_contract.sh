#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
user_guide="docs/guides/USER_GUIDE.md"
migration_guide="docs/guides/MIGRATION_GUIDE.md"
rest_example="examples/04_https_rest_client.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "function ReadString(out AStr: string): Boolean;" \
  "$source_file" \
  "source no longer declares the current ReadString signature"

require_absent "WriteLn('收到: ', LConn.ReadString);" \
  "$api_ref" \
  "API reference still teaches ReadString as a direct string-returning call"
require_fixed "if LConn.ReadString(LReply) then" \
  "$api_ref" \
  "API reference no longer shows the out-parameter ReadString pattern"

require_absent "LResponse := LConn.ReadString;" \
  "$user_guide" \
  "user guide still teaches ReadString as a direct string-returning call in client flow"
require_absent "LRequest := LConn.ReadString;" \
  "$user_guide" \
  "user guide still teaches ReadString as a direct string-returning call in server flow"
require_fixed "if LConn.ReadString(LResponse) then" \
  "$user_guide" \
  "user guide no longer shows the out-parameter ReadString pattern in client flow"
require_fixed "if LConn.ReadString(LRequest) then" \
  "$user_guide" \
  "user guide no longer shows the out-parameter ReadString pattern in server flow"

require_absent "LResponse := LConn.ReadString;" \
  "$migration_guide" \
  "migration guide still teaches ReadString as a direct string-returning call"
require_fixed "if LConn.ReadString(LResponse) then" \
  "$migration_guide" \
  "migration guide no longer shows the out-parameter ReadString pattern"

require_absent "Response := Connection.ReadString;" \
  "$rest_example" \
  "REST client example still prints the stale ReadString return-value usage"
require_fixed "if Connection.ReadString(Response) then" \
  "$rest_example" \
  "REST client example no longer prints the out-parameter ReadString pattern"

echo "[PASS] active ReadString examples match the current out-parameter source truth"
