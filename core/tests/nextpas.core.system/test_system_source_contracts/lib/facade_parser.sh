# Pascal interface section parser for facade surface checks.
# Sourced by check_system_source_contracts.sh — do not run directly.
# Requires: CORE_ROOT (set by main script).

list_unit_facade_surface() {
  local unit_path="$1"
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_pascal_line(s) {
      gsub(/\{[^}]*\}/, "", s)
      sub(/\/\/.*/, "", s)
      return trim(s)
    }
    function note_unknown(s) {
      print "[FAIL] unrecognized public interface declaration in " FILENAME ": " s > "/dev/stderr"
      unknown = 1
    }
    BEGIN {
      in_interface = 0
      section = ""
      type_depth = 0
      unknown = 0
    }
    END {
      if (unknown) {
        exit 2
      }
    }
    /^[ \t]*interface[ \t]*$/ {
      in_interface = 1
      next
    }
    /^[ \t]*implementation[ \t]*$/ {
      exit
    }
    !in_interface {
      next
    }
    {
      line = strip_pascal_line($0)
      if (line == "") {
        next
      }
      lower_line = tolower(line)
      if (lower_line ~ /^uses([ \t]|$)/) {
        section = "uses"
        if (line ~ /;/) {
          section = ""
        }
        next
      }
      if (section == "uses") {
        if (line ~ /;/) {
          section = ""
        }
        next
      }
      if (type_depth > 0) {
        if (lower_line ~ /^end[.;]?$/) {
          type_depth--
          if (type_depth < 0) {
            type_depth = 0
          }
        }
        next
      }
      if (lower_line == "const") {
        section = "const"
        next
      }
      if (lower_line == "type") {
        section = "type"
        next
      }
      if (lower_line == "var") {
        section = "var"
        next
      }
      if (lower_line == "threadvar") {
        section = "threadvar"
        next
      }
      if (lower_line == "resourcestring") {
        section = "resourcestring"
        next
      }
      if (match(line, /^generic[ \t]+procedure[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "procedure " parts[1]
        next
      }
      if (match(line, /^generic[ \t]+function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        next
      }
      if (match(line, /^procedure[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "procedure " parts[1]
        next
      }
      if (match(line, /^function[ \t]+([A-Za-z_][A-Za-z0-9_]*)/, parts)) {
        section = ""
        print "function " parts[1]
        next
      }
      if (match(line, /^operator[ \t]*([^ \t(]+)/, parts)) {
        section = ""
        print "operator " parts[1]
        next
      }
      if (section == "const" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "const " parts[1]
        next
      }
      if (section == "type" && match(line, /^generic[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t<]/, parts)) {
        print "type " parts[1]
        if (lower_line ~ /=[ \t]*(packed[ \t]+)?(class|record|object|interface)([ \t(;]|$)/) {
          type_depth = 1
        }
        next
      }
      if (section == "type" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "type " parts[1]
        if (lower_line ~ /=[ \t]*(packed[ \t]+)?(class|record|object|interface)([ \t(;]|$)/) {
          type_depth = 1
        }
        next
      }
      if (section == "var" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t,:]/, parts)) {
        print "var " parts[1]
        next
      }
      if (section == "threadvar" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t,:]/, parts)) {
        print "threadvar " parts[1]
        next
      }
      if (section == "resourcestring" && match(line, /^([A-Za-z_][A-Za-z0-9_]*)[ \t=]/, parts)) {
        print "resourcestring " parts[1]
        next
      }
      note_unknown(line)
    }
  ' "$unit_path"
}

list_root_facade_surface() {
  list_unit_facade_surface "$CORE_ROOT/src/nextpas.core.system.pas"
}

require_facade_surface_allowlist() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf '[FAIL] %s public surface drifted\n' "$label" >&2
    printf '%s\n' '--- expected' >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' '--- actual' >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi
}
