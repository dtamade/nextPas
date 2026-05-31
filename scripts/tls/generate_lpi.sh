#!/bin/bash
#
# generate_lpi.sh - Generate .lpi files for all test Pascal files
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

generate_lpi() {
    local pas_file="$1"
    local dir=$(dirname "$pas_file")
    local name=$(basename "$pas_file" .pas)
    local lpi_file="$dir/$name.lpi"
    local rel_src="../src"
    local rel_framework="framework"

    # Calculate relative path to src and framework
    if [[ "$dir" == *"/integration"* ]] || [[ "$dir" == *"/security"* ]] || [[ "$dir" == *"/http"* ]]; then
        rel_src="../../src"
        rel_framework="../framework"
    fi

    cat > "$lpi_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<CONFIG>
  <ProjectOptions>
    <Version Value="12"/>
    <General>
      <Flags>
        <MainUnitHasCreateFormStatements Value="False"/>
        <MainUnitHasTitleStatement Value="False"/>
        <MainUnitHasScaledStatement Value="False"/>
      </Flags>
      <SessionStorage Value="InProjectDir"/>
      <Title Value="$name"/>
      <UseAppBundle Value="False"/>
      <ResourceType Value="res"/>
    </General>
    <BuildModes>
      <Item Name="Default" Default="True"/>
    </BuildModes>
    <PublishOptions>
      <Version Value="2"/>
      <UseFileFilters Value="True"/>
    </PublishOptions>
    <RunParams>
      <FormatVersion Value="2"/>
    </RunParams>
    <Units>
      <Unit>
        <Filename Value="$name.pas"/>
        <IsPartOfProject Value="True"/>
      </Unit>
    </Units>
  </ProjectOptions>
  <CompilerOptions>
    <Version Value="11"/>
    <Target>
      <Filename Value="bin/$name"/>
    </Target>
    <SearchPaths>
      <IncludeFiles Value="\$(ProjOutDir)"/>
      <OtherUnitFiles Value="$rel_src;$rel_framework"/>
      <UnitOutputDirectory Value="lib/\$(TargetCPU)-\$(TargetOS)"/>
    </SearchPaths>
    <CodeGeneration>
      <TargetCPU Value="x86_64"/>
      <TargetOS Value="linux"/>
      <Optimizations>
        <OptimizationLevel Value="2"/>
      </Optimizations>
    </CodeGeneration>
    <Linking>
      <Debugging>
        <DebugInfoType Value="dsDwarf3"/>
      </Debugging>
    </Linking>
  </CompilerOptions>
</CONFIG>
EOF
    echo "生成: $lpi_file"
}

# Generate for tests/*.pas
echo "=== 生成 tests/*.pas 的 .lpi 文件 ==="
for pas in "$PROJECT_DIR"/tests/*.pas; do
    [ -f "$pas" ] && generate_lpi "$pas"
done

# Generate for tests/integration/*.pas
echo ""
echo "=== 生成 tests/integration/*.pas 的 .lpi 文件 ==="
for pas in "$PROJECT_DIR"/tests/integration/*.pas; do
    [ -f "$pas" ] && generate_lpi "$pas"
done

# Generate for tests/security/*.pas
echo ""
echo "=== 生成 tests/security/*.pas 的 .lpi 文件 ==="
for pas in "$PROJECT_DIR"/tests/security/*.pas; do
    [ -f "$pas" ] && generate_lpi "$pas"
done

# Generate for tests/http/*.pas
echo ""
echo "=== 生成 tests/http/*.pas 的 .lpi 文件 ==="
for pas in "$PROJECT_DIR"/tests/http/*.pas; do
    [ -f "$pas" ] && generate_lpi "$pas"
done

echo ""
echo "完成!"
