@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=test"
if not "%~1"=="" shift

set "NORMALIZED_TEST_ARGS="
:collect_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--list-suites" (
  set "NORMALIZED_TEST_ARGS=!NORMALIZED_TEST_ARGS! --list"
) else (
  set "NORMALIZED_TEST_ARGS=!NORMALIZED_TEST_ARGS! %~1"
)
shift
goto :collect_args
:args_done

set "ROOT=%~dp0"
set "OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
if "%OUTPUT_ROOT%"=="" set "OUTPUT_ROOT=%ROOT%"
set "PROG=%ROOT%nextpas.core.simd.cpuinfo.test.lpr"
set "BIN_DIR=%OUTPUT_ROOT%\bin"
set "LIB_DIR=%OUTPUT_ROOT%\lib"
set "BIN=%BIN_DIR%\nextpas.core.simd.cpuinfo.test.exe"
set "LOG_DIR=%OUTPUT_ROOT%\logs"
set "BUILD_LOG=%LOG_DIR%\build.txt"
set "TEST_LOG=%LOG_DIR%\test.txt"
set "MODE=%FAFAFA_BUILD_MODE%"
if "%MODE%"=="" set "MODE=Release"

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%LIB_DIR%" mkdir "%LIB_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

if /I "%ACTION%"=="debug" set "MODE=Debug"
if /I "%ACTION%"=="release" set "MODE=Release"

if /I "%ACTION%"=="clean" goto :clean
if /I "%ACTION%"=="build" goto :build
if /I "%ACTION%"=="check" goto :check
if /I "%ACTION%"=="test" goto :test
if /I "%ACTION%"=="debug" goto :test
if /I "%ACTION%"=="release" goto :test

echo Usage: %~nx0 [clean^|build^|check^|test^|debug^|release] [test-args...]
exit /b 2

:clean
echo [CLEAN] Removing %BIN_DIR%, %LIB_DIR%, %LOG_DIR%
if exist "%BIN_DIR%" rmdir /s /q "%BIN_DIR%"
if exist "%LIB_DIR%" rmdir /s /q "%LIB_DIR%"
if exist "%LOG_DIR%" rmdir /s /q "%LOG_DIR%"
exit /b 0

:build
if /I "%MODE%"=="Debug" (
  set "FPC_MODE_FLAGS=-O1 -g -gl -dDEBUG"
) else (
  set "MODE=Release"
  set "FPC_MODE_FLAGS=-O2 -gl"
)
echo [BUILD] Program: %PROG% (mode=%MODE%, output_root=%OUTPUT_ROOT%)
echo. > "%BUILD_LOG%"
	fpc -B -Mobjfpc -Sc -Si %FPC_MODE_FLAGS% ^
  -Fu"%ROOT%" -Fu"%ROOT%..\..\src" -Fi"%ROOT%..\..\src" ^
  -FE"%BIN_DIR%" -FU"%LIB_DIR%" ^
  -o"%BIN%" "%PROG%" > "%BUILD_LOG%" 2>&1
if errorlevel 1 (
  echo [BUILD] FAILED (see %BUILD_LOG%)
  type "%BUILD_LOG%"
  exit /b 1
)
echo [BUILD] OK
exit /b 0

:check
call :build
if errorlevel 1 exit /b 1
findstr /r /c:"src\\fafafa\.core\.simd\..*Warning:" /c:"src\\fafafa\.core\.simd\..*Hint:" "%BUILD_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [CHECK] Found warnings/hints from SIMD units in build log
  type "%BUILD_LOG%"
  exit /b 1
)
echo [CHECK] OK (no SIMD-unit warnings/hints)
exit /b 0

:test
call :build
if errorlevel 1 exit /b 1
findstr /r /c:"src\\fafafa\.core\.simd\..*Warning:" /c:"src\\fafafa\.core\.simd\..*Hint:" "%BUILD_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [CHECK] Found warnings/hints from SIMD units in build log
  type "%BUILD_LOG%"
  exit /b 1
)

echo [TEST] Running: %BIN%%NORMALIZED_TEST_ARGS%
echo. > "%TEST_LOG%"
"%BIN%" %NORMALIZED_TEST_ARGS% > "%TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [TEST] FAILED (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 1
)
findstr /b /c:"Invalid option" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [TEST] FAILED: unsupported test argument (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 2
)
findstr /r /c:"Number of failures:[ ]*[1-9][0-9]*" /c:"Number of errors:[ ]*[1-9][0-9]*" /c:"Time:.* E:[1-9][0-9]*" /c:"Time:.* F:[1-9][0-9]*" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [TEST] FAILED: test runner reports failures/errors (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 1
)
echo [TEST] OK

findstr /r /c:"^[1-9][0-9]* unfreed memory blocks" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [LEAK] FAILED: heaptrc reports unfreed blocks
  type "%TEST_LOG%"
  exit /b 1
)
echo [LEAK] OK
exit /b 0
