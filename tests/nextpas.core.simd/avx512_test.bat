@echo off
REM AVX-512 验证 + 基准测试 (Windows)
REM 用法: avx512_test.bat [fpc路径]
REM
REM 在有 AVX-512 的机器上运行此脚本验证正确性和性能

setlocal enabledelayedexpansion

set FPC=%1
if "%FPC%"=="" set FPC=fpc

set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..\..
set OUT_DIR=%SCRIPT_DIR%bin2

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo === AVX-512 Test Suite ===
%FPC% -iV 2>nul
echo.

REM Compile
echo [1/4] Compiling correctness test...
%FPC% -O3 -B -Fi"%ROOT_DIR%\src" -Fu"%ROOT_DIR%\src" ^
  -FE"%OUT_DIR%" -o"%OUT_DIR%\avx512_verify.exe" ^
  "%SCRIPT_DIR%nextpas.core.simd.avx512_verify.pas"
if errorlevel 1 (
  echo [ERROR] Compilation failed!
  exit /b 1
)

echo [2/4] Compiling benchmark...
%FPC% -O3 -B -Fi"%ROOT_DIR%\src" -Fu"%ROOT_DIR%\src" ^
  -FE"%OUT_DIR%" -o"%OUT_DIR%\avx512_bench.exe" ^
  "%SCRIPT_DIR%nextpas.core.simd.avx512_bench.pas"
if errorlevel 1 (
  echo [ERROR] Compilation failed!
  exit /b 1
)

echo.
echo [3/4] Running correctness test...
"%OUT_DIR%\avx512_verify.exe"
if errorlevel 1 (
  echo [ERROR] Correctness test FAILED!
  exit /b 1
)

echo.
echo [4/4] Running benchmark...
"%OUT_DIR%\avx512_bench.exe"

echo.
echo === All done ===
pause
