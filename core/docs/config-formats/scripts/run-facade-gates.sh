#!/usr/bin/env bash
# config-formats facade gate runner (Wave M)
# Usage from repo root:
#   bash core/docs/config-formats/scripts/run-facade-gates.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

GATES=(
  core/tests/nextpas.core.config/test_config_facade_surface
  core/tests/nextpas.core.json/test_json_facade_surface
  core/tests/nextpas.core.json/test_json_edge_cases
  core/tests/nextpas.core.yaml/test_yaml_facade_surface
  core/tests/nextpas.core.toml/test_toml_facade_surface
  core/tests/nextpas.core.csv/test_csv_facade_surface
  core/tests/nextpas.core.ini/test_ini_facade_surface
  core/tests/nextpas.core.xml/test_xml_facade_surface
)

echo "config-formats facade gates (root=$ROOT)"
for g in "${GATES[@]}"; do
  echo "=== FOCUS=$g ==="
  make focused FOCUS="$g"
done
echo "config-formats-facade-gates=pass"
