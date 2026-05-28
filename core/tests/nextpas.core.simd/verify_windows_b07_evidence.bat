@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
set "LOG_PATH="
set "SUMMARY_JSON_PATH="
set "SUMMARY_JSON_VERIFIER=%ROOT%verify_gate_summary_json.py"
set "ALLOW_SIMULATED=0"

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="--allow-simulated" (
  set "ALLOW_SIMULATED=1"
  shift
  goto :parse_args
)
if "%LOG_PATH%"=="" (
  set "LOG_PATH=%~1"
) else if "%SUMMARY_JSON_PATH%"=="" (
  set "SUMMARY_JSON_PATH=%~1"
) else (
  echo [EVIDENCE] Unexpected argument: %~1
  exit /b 2
)
shift
goto :parse_args

:args_done
if "%LOG_PATH%"=="" set "LOG_PATH=%ROOT%logs\windows_b07_gate.log"

if not exist "%LOG_PATH%" (
  echo [EVIDENCE] Missing log: %LOG_PATH%
  exit /b 2
)

if "%SUMMARY_JSON_PATH%"=="" (
  call :extract_b07_value "GateSummaryJson" SUMMARY_JSON_PATH
)
if "%SUMMARY_JSON_PATH%"=="" (
  for %%I in ("%LOG_PATH%") do set "SUMMARY_JSON_PATH=%%~dpIgate_summary.json"
)

set "FAIL=0"
set "METRIC_TOTAL="
set "METRIC_PASSED="
set "METRIC_FAILED="

call :check_fixed "[B07] Windows evidence capture"
call :check_fixed "[B07] Source: collect_windows_b07_evidence.bat"
call :check_fixed "[B07] HostOS: Windows_NT"
call :check_fixed "[B07] CmdVer: Microsoft Windows"
call :check_windows_working_dir
call :check_command_marker
call :check_fixed "[GATE] OK"
call :check_fixed "[B07] GATE_EXIT_CODE=0"
call :check_fixed "[BACKEND-OPS] Building standalone program:"
call :check_fixed "[BACKEND-OPS] Running standalone program:"
call :check_fixed "[SIMD-BOUNDARY] Building standalone program:"
call :check_fixed "[SIMD-BOUNDARY] Running standalone program:"
call :check_fixed "[PUBLIC-SMOKE] Building standalone smoke:"
call :check_fixed "[PUBLIC-SMOKE] Running standalone smoke:"
call :check_fixed "[PASS] Default backend is "
call :check_fixed "[DISPATCH-PREINIT] Building standalone smoke:"
call :check_fixed "[DISPATCH-PREINIT] Running standalone smoke:"
call :check_fixed "[DISPATCH-PREINIT] OK"

findstr /r /c:"^\[B07\] Simulated: yes$" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 (
  if not "%ALLOW_SIMULATED%"=="1" (
    echo [EVIDENCE] Invalid source: simulated evidence requires --allow-simulated
    set "FAIL=1"
  )
)

findstr /r /c:"^\[SIMULATE\]" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 (
  if not "%ALLOW_SIMULATED%"=="1" (
    echo [EVIDENCE] Invalid source: simulated evidence requires --allow-simulated
    set "FAIL=1"
  )
)

echo %LOG_PATH% | findstr /i /c:".simulated." >nul 2>nul
if not errorlevel 1 (
  if not "%ALLOW_SIMULATED%"=="1" (
    echo [EVIDENCE] Invalid source: simulated evidence requires --allow-simulated
    set "FAIL=1"
  )
)

findstr /r /c:"^\[B07\] Source: simulate_windows_b07_evidence\.sh$" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 (
  if not "%ALLOW_SIMULATED%"=="1" (
    echo [EVIDENCE] Invalid source: simulator source marker detected
    set "FAIL=1"
  )
)

call :verify_summary_json_if_present
set "SUMMARY_JSON_RC=%ERRORLEVEL%"
if "%SUMMARY_JSON_RC%"=="10" (
  call :check_fixed "[GATE] 1/6 Build + check SIMD module"
  call :check_publicabi_fallback
  call :check_fixed "[GATE] 2/6 SIMD list suites"
  call :check_fixed "[GATE] 3/6 SIMD AVX2 stable vector suites"
  call :check_fixed "[GATE] 4/6 CPUInfo portable suites"
  call :check_fixed "[GATE] 5/6 CPUInfo x86 suites"
  call :check_fixed "[GATE] 6/6 Filtered run_all check chain"
) else if not "%SUMMARY_JSON_RC%"=="0" (
  set "FAIL=1"
)

call :extract_metric "Total" METRIC_TOTAL
call :extract_metric "Passed" METRIC_PASSED
call :extract_metric "Failed" METRIC_FAILED

if "%METRIC_TOTAL%"=="" (
  echo [EVIDENCE] Missing summary metric: Total
  set "FAIL=1"
)
if "%METRIC_PASSED%"=="" (
  echo [EVIDENCE] Missing summary metric: Passed
  set "FAIL=1"
)
if "%METRIC_FAILED%"=="" (
  echo [EVIDENCE] Missing summary metric: Failed
  set "FAIL=1"
)

if not "%METRIC_FAILED%"=="" if not "%METRIC_FAILED%"=="0" (
  echo [EVIDENCE] Invalid summary: failed=%METRIC_FAILED% ^(expect 0^)
  set "FAIL=1"
)

if not "%METRIC_TOTAL%"=="" if not "%METRIC_PASSED%"=="" if not "%METRIC_TOTAL%"=="%METRIC_PASSED%" (
  echo [EVIDENCE] Invalid summary: total=%METRIC_TOTAL% passed=%METRIC_PASSED% ^(expect total==passed^)
  set "FAIL=1"
)

if not "%METRIC_TOTAL%"=="" (
  set /a METRIC_TOTAL_NUM=%METRIC_TOTAL% >nul 2>nul
  if errorlevel 1 (
    echo [EVIDENCE] Invalid summary: total is not numeric ^(%METRIC_TOTAL%^)
    set "FAIL=1"
  ) else (
    if !METRIC_TOTAL_NUM! LSS 3 (
      echo [EVIDENCE] Invalid summary: total=!METRIC_TOTAL_NUM! ^(expect >=3^)
      set "FAIL=1"
    )
  )
)

if not "%FAIL%"=="0" (
  echo [EVIDENCE] FAILED: %LOG_PATH%
  exit /b 1
)

echo [EVIDENCE] OK: %LOG_PATH%
exit /b 0

:usage
echo Usage: %~nx0 [evidence-log-path] [gate-summary-json-path] [--allow-simulated]
echo Default log: %ROOT%logs\windows_b07_gate.log
echo --allow-simulated: allow simulated evidence for dryrun/rehearsal only
exit /b 0

:check_fixed
set "PATTERN=%~1"
findstr /l /c:"%PATTERN%" "%LOG_PATH%" >nul 2>nul
if errorlevel 1 (
  echo [EVIDENCE] Missing pattern: %PATTERN%
  set "FAIL=1"
)
exit /b 0

:check_regex
set "PATTERN=%~1"
findstr /r /c:"%PATTERN%" "%LOG_PATH%" >nul 2>nul
if errorlevel 1 (
  echo [EVIDENCE] Missing regex: %PATTERN%
  set "FAIL=1"
)
exit /b 0

:check_command_marker
findstr /l /c:"[B07] Command: buildOrTest.bat gate" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 exit /b 0
findstr /l /c:"[B07] Command: BuildOrTest.sh gate" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 exit /b 0
echo [EVIDENCE] Missing command marker for gate entry
set "FAIL=1"
exit /b 0

:check_windows_working_dir
findstr /l /c:"[B07] Working dir: " "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 exit /b 0
echo [EVIDENCE] Missing B07 value: Working dir
set "FAIL=1"
exit /b 0

:check_publicabi_fallback
findstr /l /c:"[GATE] Optional public ABI smoke" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 exit /b 0
findstr /l /c:"--suite=TTestCase_PublicAbi,TTestCase_SimdConcurrentPublicAbi,TTestCase_SimdConcurrentFramework" "%LOG_PATH%" >nul 2>nul
if not errorlevel 1 exit /b 0
echo [EVIDENCE] Missing public ABI witness ^(expected old gate marker or current public ABI concurrent suite line^)
set "FAIL=1"
exit /b 0

:extract_metric
set "METRIC=%~1"
set "OUTVAR=%~2"
set "VALUE="

for /f "usebackq tokens=1,* delims=:" %%A in ("%LOG_PATH%") do (
  if /I "%%A"=="[B07] !METRIC!" (
    set "VALUE=%%B"
  )
)

if not defined VALUE (
  for /f "usebackq tokens=1,* delims=:" %%A in ("%LOG_PATH%") do (
    if /I "%%A"=="!METRIC!" (
      set "VALUE=%%B"
    )
  )
)

if defined VALUE (
  call :trim_value "!VALUE!" VALUE
  set "VALUE=!VALUE: =!"
)

set "%OUTVAR%=%VALUE%"
exit /b 0

:extract_b07_value
set "B07KEY=%~1"
set "OUTVAR=%~2"
set "VALUE="
for /f "usebackq tokens=1,* delims=:" %%A in ("%LOG_PATH%") do (
  if /I "%%A"=="[B07] !B07KEY!" (
    set "VALUE=%%B"
  )
)
if defined VALUE (
  call :trim_value "!VALUE!" VALUE
)
set "%OUTVAR%=%VALUE%"
exit /b 0

:trim_value
setlocal EnableDelayedExpansion
set "VALUE=%~1"
if not defined VALUE (
  endlocal & set "%~2=" & exit /b 0
)
for /f "tokens=* delims= " %%A in ("!VALUE!") do set "VALUE=%%A"
:trim_value_right
if defined VALUE if "!VALUE:~-1!"==" " (
  set "VALUE=!VALUE:~0,-1!"
  goto :trim_value_right
)
endlocal & set "%~2=%VALUE%"
exit /b 0

:verify_summary_json_if_present
if not exist "%SUMMARY_JSON_PATH%" exit /b 10
if not exist "%SUMMARY_JSON_VERIFIER%" (
  echo [EVIDENCE] Missing gate summary verifier: %SUMMARY_JSON_VERIFIER%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%SUMMARY_JSON_VERIFIER%" --summary-json "%SUMMARY_JSON_PATH%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%SUMMARY_JSON_VERIFIER%" --summary-json "%SUMMARY_JSON_PATH%"
  exit /b %ERRORLEVEL%
)

echo [EVIDENCE] Missing python runtime for gate summary json verification
exit /b 2
