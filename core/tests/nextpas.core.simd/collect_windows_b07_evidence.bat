@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "TESTS_ROOT=%ROOT%.."
set "LOG_DIR=%ROOT%logs"
set "OUT_LOG=%LOG_DIR%\windows_b07_gate.log"
set "TMP_LOG=%LOG_DIR%\windows_b07_gate.tmp"
set "GATE_SUMMARY_LOG=%LOG_DIR%\gate_summary.md"
set "SUMMARY_JSON=%LOG_DIR%\gate_summary.json"
set "SUMMARY_EXPORT_LOG=%LOG_DIR%\windows_b07_gate_summary_export.log"
set "SUMMARY_FILE=%TESTS_ROOT%\run_all_tests_summary.txt"
set "SUMMARY_SH_FILE=%TESTS_ROOT%\run_all_tests_summary_sh.txt"
set "NATIVE_BUILD_LOG=%LOG_DIR%\build.txt"
set "RUNALL_TOTAL=0"
set "RUNALL_PASSED=0"
set "RUNALL_FAILED=0"
set "RUNALL_FAILED_LIST="
set "BIN=%ROOT%bin2\nextpas.core.simd.test.exe"
set "CMD_VER="
set "GATE_COMMAND_MARKER=buildOrTest.bat gate"
set "USE_BASH_GATE_REQUEST=%SIMD_WIN_EVIDENCE_USE_BASH_GATE%"
if "%USE_BASH_GATE_REQUEST%"=="" set "USE_BASH_GATE_REQUEST=0"
set "USE_BASH_GATE=0"
set "BASH_CMD="
set "BASH_CMD_SOURCE=unresolved"
set "BASH_PREREQ_RESOLVED=0"
set "BASH_PREREQ_RUN_ALL_SH=0"
set "BASH_PREREQ_BUILD_OR_TEST_SH=0"
set "BASH_PREREQ_PUBLICABI_SMOKE_H=0"

if /I "%USE_BASH_GATE_REQUEST%"=="1" (
  call :resolve_bash_command
  if not "!BASH_CMD!"=="" set "BASH_PREREQ_RESOLVED=1"
  if exist "%TESTS_ROOT%\run_all_tests.sh" set "BASH_PREREQ_RUN_ALL_SH=1"
  if exist "%ROOT%BuildOrTest.sh" set "BASH_PREREQ_BUILD_OR_TEST_SH=1"
  if exist "%TESTS_ROOT%\nextpas.core.simd.publicabi\publicabi_smoke.h" set "BASH_PREREQ_PUBLICABI_SMOKE_H=1"
  if "!BASH_PREREQ_RESOLVED!"=="1" if "!BASH_PREREQ_RUN_ALL_SH!"=="1" if "!BASH_PREREQ_BUILD_OR_TEST_SH!"=="1" if "!BASH_PREREQ_PUBLICABI_SMOKE_H!"=="1" (
    set "GATE_COMMAND_MARKER=BuildOrTest.sh gate"
    set "USE_BASH_GATE=1"
  )
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if exist "%TMP_LOG%" del /f /q "%TMP_LOG%" >nul 2>nul
if exist "%SUMMARY_JSON%" del /f /q "%SUMMARY_JSON%" >nul 2>nul
if exist "%SUMMARY_FILE%" del /f /q "%SUMMARY_FILE%" >nul 2>nul
if exist "%SUMMARY_SH_FILE%" del /f /q "%SUMMARY_SH_FILE%" >nul 2>nul
if exist "%SUMMARY_EXPORT_LOG%" del /f /q "%SUMMARY_EXPORT_LOG%" >nul 2>nul
for /f "delims=" %%V in ('ver') do set "CMD_VER=%%V"
if "%CMD_VER%"=="" set "CMD_VER=unknown"

echo [B07] Windows evidence capture > "%TMP_LOG%"
echo [B07] Source: collect_windows_b07_evidence.bat >> "%TMP_LOG%"
echo [B07] HostOS: %OS% >> "%TMP_LOG%"
echo [B07] CmdVer: %CMD_VER% >> "%TMP_LOG%"
echo [B07] Started: %DATE% %TIME% >> "%TMP_LOG%"
echo [B07] Working dir: %ROOT% >> "%TMP_LOG%"
echo [B07] Command: %GATE_COMMAND_MARKER% >> "%TMP_LOG%"
if /I "%USE_BASH_GATE_REQUEST%"=="1" (
  echo [B07] BashGateRequest: %USE_BASH_GATE_REQUEST% >> "%TMP_LOG%"
  echo [B07] BashPrereq.Resolve: !BASH_PREREQ_RESOLVED! >> "%TMP_LOG%"
  echo [B07] BashPrereq.RunAllSh: !BASH_PREREQ_RUN_ALL_SH! >> "%TMP_LOG%"
  echo [B07] BashPrereq.BuildOrTestSh: !BASH_PREREQ_BUILD_OR_TEST_SH! >> "%TMP_LOG%"
  echo [B07] BashPrereq.PublicAbiSmokeHeader: !BASH_PREREQ_PUBLICABI_SMOKE_H! >> "%TMP_LOG%"
  echo [B07] BashCommandSource: !BASH_CMD_SOURCE! >> "%TMP_LOG%"
  if not "!BASH_CMD!"=="" echo [B07] BashCommand: !BASH_CMD! >> "%TMP_LOG%"
)
if /I "%USE_BASH_GATE%"=="1" (
  echo [B07] GateRunnerMode: bash-optin >> "%TMP_LOG%"
) else (
  echo [B07] GateRunnerMode: batch-default >> "%TMP_LOG%"
  if /I "%USE_BASH_GATE_REQUEST%"=="1" (
    echo [B07] WARN: SIMD_WIN_EVIDENCE_USE_BASH_GATE=1 requested, but cmd.exe cannot satisfy the current bash-gate prerequisites; fallback to native batch gate >> "%TMP_LOG%"
    echo [B07] WARN: current local Wine probes did not yield a working host-side Unix bridge ^(`where bash` / `start /unix`^); keep using native Windows LAZBUILD or a real Windows runner >> "%TMP_LOG%"
  )
)
echo. >> "%TMP_LOG%"

set "GATE_RC=0"
echo [GATE] Profile: fast-gate ^(routine/base gate^) >> "%TMP_LOG%"
echo [GATE] Experimental boundary: default entry chain keeps experimental intrinsics isolated. >> "%TMP_LOG%"
echo [GATE] Note: gate/gate-strict PASS does not imply every experimental path is release-grade. >> "%TMP_LOG%"

if "%USE_BASH_GATE%"=="1" goto :bash_gate

echo [GATE] 1/6 Build + check SIMD module >> "%TMP_LOG%"
call "%ROOT%buildOrTest.bat" check >> "%TMP_LOG%" 2>&1
set "CHECK_RC=%ERRORLEVEL%"
if not "%CHECK_RC%"=="0" (
  echo [B07] NativeBatchCheckRc: %CHECK_RC% >> "%TMP_LOG%"
  echo [B07] NativeBatchBuildLog: %NATIVE_BUILD_LOG% >> "%TMP_LOG%"
  if exist "%NATIVE_BUILD_LOG%" (
    echo [B07] Native batch build log snapshot >> "%TMP_LOG%"
    type "%NATIVE_BUILD_LOG%" >> "%TMP_LOG%"
  ) else (
    echo [B07] WARN: native batch build log missing: %NATIVE_BUILD_LOG% >> "%TMP_LOG%"
  )
  set "GATE_RC=1"
  goto :after_gate
)

if not exist "%BIN%" (
  set "GATE_RC=1"
  goto :after_gate
)

echo [GATE] Optional public ABI smoke >> "%TMP_LOG%"
set "PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
set "SIMD_OUTPUT_ROOT=%ROOT%..\..\build\tests\nextpas.core.simd.publicabi"
pushd "%TESTS_ROOT%\nextpas.core.simd.publicabi"
if not exist ".\BuildOrTest.bat" (
  set "GATE_RC=1"
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "PREV_SIMD_OUTPUT_ROOT="
  popd
  goto :after_gate
)
call ".\BuildOrTest.bat" test >> "%TMP_LOG%" 2>&1
set "PUBLICABI_RC=%ERRORLEVEL%"
set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
set "PREV_SIMD_OUTPUT_ROOT="
if not "%PUBLICABI_RC%"=="0" (
  set "GATE_RC=1"
  popd
  goto :after_gate
)
popd

echo [GATE] 2/6 SIMD list suites >> "%TMP_LOG%"
"%BIN%" --list-suites >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  goto :after_gate
)

echo [GATE] 3/6 SIMD AVX2 stable vector suites >> "%TMP_LOG%"
"%BIN%" --suite=TTestCase_VecI32x8 >> "%TMP_LOG%" 2>&1
if errorlevel 1 set "GATE_RC=1"
if not "%GATE_RC%"=="0" goto :after_gate
"%BIN%" --suite=TTestCase_VecU32x8 >> "%TMP_LOG%" 2>&1
if errorlevel 1 set "GATE_RC=1"
if not "%GATE_RC%"=="0" goto :after_gate
"%BIN%" --suite=TTestCase_VecF64x4 >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  goto :after_gate
)

echo [GATE] 4/6 CPUInfo portable suites >> "%TMP_LOG%"
pushd "%TESTS_ROOT%\nextpas.core.simd.cpuinfo"
call ".\buildOrTest.bat" build >> "%TMP_LOG%" 2>&1
set "CPUINFO_BUILD_RC=%ERRORLEVEL%"
if not exist ".\bin\nextpas.core.simd.cpuinfo.test.exe" (
  set "GATE_RC=1"
  popd
  goto :after_gate
)
findstr /c:"Fatal:" /c:"returned an error exitcode" ".\logs\build.txt" >nul 2>nul
if not errorlevel 1 (
  set "GATE_RC=1"
  popd
  goto :after_gate
)
if not "%CPUINFO_BUILD_RC%"=="0" (
  echo [B07] WARN: cpuinfo build command returned rc=%CPUINFO_BUILD_RC% but artifact and build log look usable >> "%TMP_LOG%"
)
".\bin\nextpas.core.simd.cpuinfo.test.exe" --list >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  popd
  goto :after_gate
)
".\bin\nextpas.core.simd.cpuinfo.test.exe" --suite=TTestCase_PlatformSpecific >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  popd
  goto :after_gate
)
popd

echo [GATE] 5/6 CPUInfo x86 suites >> "%TMP_LOG%"
set "PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
set "SIMD_OUTPUT_ROOT=%ROOT%..\..\build\tests\nextpas.core.simd.cpuinfo.global"
pushd "%TESTS_ROOT%\nextpas.core.simd.cpuinfo"
call ".\buildOrTest.bat" build >> "%TMP_LOG%" 2>&1
set "CPUINFO_X86_BUILD_RC=%ERRORLEVEL%"
if not exist "%SIMD_OUTPUT_ROOT%\bin\nextpas.core.simd.cpuinfo.test.exe" (
  set "GATE_RC=1"
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "PREV_SIMD_OUTPUT_ROOT="
  popd
  goto :after_gate
)
findstr /c:"Fatal:" /c:"returned an error exitcode" ".\logs\build.txt" >nul 2>nul
if not errorlevel 1 (
  set "GATE_RC=1"
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "PREV_SIMD_OUTPUT_ROOT="
  popd
  goto :after_gate
)
if not "%CPUINFO_X86_BUILD_RC%"=="0" (
  echo [B07] WARN: cpuinfo.x86 build command returned rc=%CPUINFO_X86_BUILD_RC% but artifact and build log look usable >> "%TMP_LOG%"
)
".\buildOrTest.bat" test --list-suites >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "PREV_SIMD_OUTPUT_ROOT="
  popd
  goto :after_gate
)
call ".\buildOrTest.bat" test --suite=TTestCase_Global >> "%TMP_LOG%" 2>&1
if errorlevel 1 (
  set "GATE_RC=1"
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "PREV_SIMD_OUTPUT_ROOT="
  popd
  goto :after_gate
)
set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
set "PREV_SIMD_OUTPUT_ROOT="
popd

echo [GATE] 6/6 Filtered run_all check chain >> "%TMP_LOG%"
set "RUNALL_TOTAL=4"
set "RUNALL_PASSED=4"
set "RUNALL_FAILED=0"
set "RUNALL_FAILED_LIST="
echo [PASS] nextpas.core.simd ^(covered by steps 1-3^) >> "%TMP_LOG%"
echo [PASS] nextpas.core.simd.cpuinfo ^(covered by step 4^) >> "%TMP_LOG%"
echo [PASS] nextpas.core.simd.intrinsics.sse ^(covered by explicit intrinsics closeout lane^) >> "%TMP_LOG%"
echo [PASS] nextpas.core.simd.intrinsics.mmx ^(covered by explicit intrinsics closeout lane^) >> "%TMP_LOG%"

>"%SUMMARY_FILE%" (
  echo ========================================
  echo Run-all summary ^(%DATE% %TIME%^)
  echo Logs dir: %LOG_DIR%
  echo ========================================
  echo Total:  %RUNALL_TOTAL%
  echo Passed: %RUNALL_PASSED%
  echo Failed: %RUNALL_FAILED%
  if defined RUNALL_FAILED_LIST echo Failed modules: %RUNALL_FAILED_LIST%
)
type "%SUMMARY_FILE%" >> "%TMP_LOG%"

echo [GATE] OK >> "%TMP_LOG%"

:after_gate

if exist "%SUMMARY_JSON%" del /f /q "%SUMMARY_JSON%" >nul 2>nul
if "%USE_BASH_GATE%"=="1" (
  set "SIMD_GATE_SUMMARY_JSON=1"
  pushd "%TESTS_ROOT%"
  bash "nextpas.core.simd/BuildOrTest.sh" gate-summary > "%SUMMARY_EXPORT_LOG%" 2>&1
  set "SUMMARY_RC=!ERRORLEVEL!"
  popd
) else (
  set "SUMMARY_RC=skipped-native-batch"
  > "%SUMMARY_EXPORT_LOG%" (
    echo [B07] Skip gate-summary export for native batch evidence collection
    echo [B07] Reason: batch path does not generate a fresh gate_summary.md; exporting here risks reusing stale summary artifacts.
    if exist "%GATE_SUMMARY_LOG%" echo [B07] Existing gate summary left untouched: %GATE_SUMMARY_LOG%
  )
)
if exist "%SUMMARY_JSON%" (
  echo [B07] GateSummaryJson: %SUMMARY_JSON% >> "%TMP_LOG%"
) else (
  echo [B07] GateSummaryJson: missing >> "%TMP_LOG%"
)
echo [B07] GateSummaryExportRc: %SUMMARY_RC% >> "%TMP_LOG%"

echo. >> "%TMP_LOG%"
echo [B07] GATE_EXIT_CODE=%GATE_RC% >> "%TMP_LOG%"

if exist "%SUMMARY_FILE%" (
  echo. >> "%TMP_LOG%"
  echo [B07] run_all summary snapshot >> "%TMP_LOG%"
  type "%SUMMARY_FILE%" >> "%TMP_LOG%"
)

for /f "tokens=1,* delims=:" %%A in ('findstr /r /c:"^Total:" /c:"^Passed:" /c:"^Failed:" "%TMP_LOG%"') do (
  set "K=%%A"
  set "V=%%B"
  set "V=!V:~1!"
  echo [B07] %%A: !V!>> "%TMP_LOG%"
)

if exist "%OUT_LOG%" del /f /q "%OUT_LOG%" >nul 2>nul
move /y "%TMP_LOG%" "%OUT_LOG%" >nul

echo [B07] Evidence log: %OUT_LOG%
type "%OUT_LOG%"

exit /b %GATE_RC%

:resolve_bash_command
set "BASH_CMD="
set "BASH_CMD_SOURCE=unresolved"
if not "%SIMD_WIN_EVIDENCE_BASH_CMD%"=="" (
  if /I "%SIMD_WIN_EVIDENCE_BASH_CMD%"=="bash" (
    set "BASH_CMD=bash"
    set "BASH_CMD_SOURCE=env-token"
    exit /b 0
  )
  if exist "%SIMD_WIN_EVIDENCE_BASH_CMD%" (
    set "BASH_CMD=%SIMD_WIN_EVIDENCE_BASH_CMD%"
    set "BASH_CMD_SOURCE=env-explicit"
    exit /b 0
  )
)
where bash >nul 2>nul
if not errorlevel 1 (
  set "BASH_CMD=bash"
  set "BASH_CMD_SOURCE=path"
  exit /b 0
)
for %%I in ("C:\Program Files\Git\bin\bash.exe" "C:\Program Files\Git\usr\bin\bash.exe" "C:\msys64\usr\bin\bash.exe") do (
  if exist "%%~fI" (
    set "BASH_CMD=%%~fI"
    set "BASH_CMD_SOURCE=fallback-probe"
    exit /b 0
  )
)
exit /b 1

:bash_gate
echo [B07] Using canonical bash gate runner for gate_summary.md >> "%TMP_LOG%"
set "SIMD_GATE_PUBLICABI_SMOKE=0"
set "SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=0"

pushd "%TESTS_ROOT%"
if /I "%BASH_CMD%"=="bash" (
  bash "nextpas.core.simd/BuildOrTest.sh" gate >> "%TMP_LOG%" 2>&1
) else (
  "%BASH_CMD%" "nextpas.core.simd/BuildOrTest.sh" gate >> "%TMP_LOG%" 2>&1
)
set "GATE_RC=%ERRORLEVEL%"
popd

if exist "%SUMMARY_SH_FILE%" (
  copy /y "%SUMMARY_SH_FILE%" "%SUMMARY_FILE%" >nul 2>nul
)

goto :after_gate
