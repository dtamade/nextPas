unit nextpas.core.simd.backend.consistency.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception, nextpas.core.text.conv, nextpas.core.text.format, Math, nextpas.core.simd.base,
  nextpas.core.simd.fixturehelpers, nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar;

// =============================================================================
// SIMD 跨后端一致性测试
// =============================================================================
//
// 目的：
//   验证所有 SIMD 后端对相同输入产生一致的输出结果。
//   这确保了后端实现的正确性，无论使用哪个后端，结果都应该相同。
//
// 测试策略：
//   1. 以 Scalar 后端作为参考实现
//   2. 将每个 SIMD 后端的结果与 Scalar 结果对比
//   3. 对浮点数使用容差比较（考虑精度差异）
//   4. 对整数使用精确比较
//
// =============================================================================

type
  TConsistencyTestResult = record
    TestName: string;
    Backend: TSimdBackend;
    Passed: Boolean;
    ErrorMessage: string;
    MaxDiff: Double;        // 最大差异（浮点）
    DiffLocation: Integer;  // 差异位置（向量索引）
  end;

  TConsistencyTestResults = array of TConsistencyTestResult;

const
  CONSISTENCY_BACKENDS: array[0..8] of TSimdBackend = (
    sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42, sbAVX2, sbAVX512, sbNEON, sbRISCVV
  );

// 运行所有一致性测试
function RunAllConsistencyTests: TConsistencyTestResults;

function GetConsistencyBackendName(aBackend: TSimdBackend): string;
function IsConsistencyTestSkipped(const aResult: TConsistencyTestResult): Boolean;
function FormatConsistencyFailureText(const aResult: TConsistencyTestResult;
  const aDetailIndent: string = '  '): string;

// 打印测试结果摘要
procedure PrintTestSummary(const results: TConsistencyTestResults);

// 单独测试函数（可用于调试）
function TestF32x4Arithmetic(backend: TSimdBackend): TConsistencyTestResult;
function TestF32x4Math(backend: TSimdBackend): TConsistencyTestResult;
function TestF32x4Comparison(backend: TSimdBackend): TConsistencyTestResult;
function TestF32x4Reduction(backend: TSimdBackend): TConsistencyTestResult;
function TestI32x4Arithmetic(backend: TSimdBackend): TConsistencyTestResult;
function TestI32x4Bitwise(backend: TSimdBackend): TConsistencyTestResult;
function TestFacadeMemOps(backend: TSimdBackend): TConsistencyTestResult;

implementation

type
  TConsistencyTestFunc = function(aBackend: TSimdBackend): TConsistencyTestResult;

const
  // 浮点比较容差
  FLOAT_TOLERANCE = 1e-5;

// =============================================================================
// 辅助函数
// =============================================================================

function FloatEqual(a, b: Single; tolerance: Single = FLOAT_TOLERANCE): Boolean;
begin
  if IsNaN(a) and IsNaN(b) then
    Result := True
  else if IsInfinite(a) and IsInfinite(b) then
    Result := (a > 0) = (b > 0)
  else
    Result := Abs(a - b) <= tolerance;
end;

function VecF32x4Equal(const a, b: TVecF32x4; tolerance: Single; out maxDiff: Double; out diffIdx: Integer): Boolean;
var
  i: Integer;
  diff: Double;
begin
  Result := True;
  maxDiff := 0;
  diffIdx := -1;

  for i := 0 to 3 do
  begin
    diff := Abs(a.f[i] - b.f[i]);
    if diff > maxDiff then
    begin
      maxDiff := diff;
      diffIdx := i;
    end;
    if not FloatEqual(a.f[i], b.f[i], tolerance) then
      Result := False;
  end;
end;

function VecI32x4Equal(const a, b: TVecI32x4; out diffIdx: Integer): Boolean;
var
  i: Integer;
begin
  Result := True;
  diffIdx := -1;

  for i := 0 to 3 do
  begin
    if a.i[i] <> b.i[i] then
    begin
      Result := False;
      diffIdx := i;
      Exit;
    end;
  end;
end;

function MakeVecF32x4(v0, v1, v2, v3: Single): TVecF32x4;
begin
  Result.f[0] := v0;
  Result.f[1] := v1;
  Result.f[2] := v2;
  Result.f[3] := v3;
end;

function MakeVecI32x4(v0, v1, v2, v3: Int32): TVecI32x4;
begin
  Result.i[0] := v0;
  Result.i[1] := v1;
  Result.i[2] := v2;
  Result.i[3] := v3;
end;

procedure InitBackendConsistencyResult(out aResult: TConsistencyTestResult;
  const aTestName: string; aBackend: TSimdBackend);
begin
  aResult.TestName := aTestName;
  aResult.Backend := aBackend;
  aResult.Passed := True;
  aResult.ErrorMessage := '';
  aResult.MaxDiff := 0;
  aResult.DiffLocation := -1;
end;

procedure RestoreBackendConsistencyState(const aState: TSimdSavedBackendState);
begin
  if not RestoreSavedBackendStateAndVerify(aState.Backend, @GetActiveBackend) then
    raise Exception.CreateFmt(
      'Backend consistency helper failed to restore previous backend selection (expected=%d, actual=%d)', [Ord(aState.Backend), Ord(GetActiveBackend)]);
end;

function BeginBackendConsistencyTest(const aTestName: string;
  aBackend: TSimdBackend; out aResult: TConsistencyTestResult;
  out aOriginalState: TSimdSavedBackendState): Boolean;
begin
  InitBackendConsistencyResult(aResult, aTestName, aBackend);
  SaveActiveBackendState(aOriginalState);

  if not IsBackendRegistered(aBackend) then
  begin
    aResult.ErrorMessage := 'Backend not registered (skipped)';
    RestoreBackendConsistencyState(aOriginalState);
    Exit(False);
  end;

  // Use TrySetActiveBackend to avoid false positives when SetActiveBackend falls back.
  if not TrySetActiveBackend(aBackend) then
  begin
    aResult.ErrorMessage := 'Backend not available on this CPU/OS (skipped)';
    RestoreBackendConsistencyState(aOriginalState);
    Exit(False);
  end;

  Result := True;
end;

function GetConsistencyBackendName(aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

function IsConsistencyTestSkipped(const aResult: TConsistencyTestResult): Boolean;
begin
  Result := Pos('skipped', LowerCase(aResult.ErrorMessage)) > 0;
end;

function FormatConsistencyFailureText(const aResult: TConsistencyTestResult;
  const aDetailIndent: string): string;
begin
  Result := TextFormat('%s / %s - %s', [GetConsistencyBackendName(aResult.Backend), aResult.TestName, aResult.ErrorMessage]);
  if aResult.MaxDiff > 0 then
    Result := Result + LineEnding + TextFormat('%sMax diff: %g at index %d', [aDetailIndent, aResult.MaxDiff, aResult.DiffLocation]);
end;

// =============================================================================
// F32x4 算术测试
// =============================================================================

function TestF32x4Arithmetic(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a, b, expected, actual: TVecF32x4;
  maxDiff: Double;
  diffIdx: Integer;
begin
  if not BeginBackendConsistencyTest('F32x4 Arithmetic', backend, Result, LOriginalState) then
    Exit;

  try
    // 测试向量
    a := MakeVecF32x4(1.5, -2.0, 3.25, 0.0);
    b := MakeVecF32x4(0.5, 2.0, -1.25, 4.0);

    // 获取 Scalar 参考结果
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;

    // 测试 Add
    expected := dispatch^.CoreVectors.AddF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.AddF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('AddF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Sub
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.SubF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.SubF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('SubF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Mul
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.MulF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.MulF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('MulF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Div（避免除零）
    b := MakeVecF32x4(0.5, 2.0, -1.25, 4.0);
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.DivF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.DivF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('DivF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// F32x4 数学函数测试
// =============================================================================

function TestF32x4Math(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a, b, expected, actual: TVecF32x4;
  maxDiff: Double;
  diffIdx: Integer;
begin
  if not BeginBackendConsistencyTest('F32x4 Math', backend, Result, LOriginalState) then
    Exit;

  try
    // 测试向量（使用正数以支持 Sqrt）
    a := MakeVecF32x4(1.5, 2.0, 3.25, 4.0);
    b := MakeVecF32x4(0.5, 3.0, 1.0, 2.0);

    // 测试 Abs
    a := MakeVecF32x4(-1.5, 2.0, -3.25, 0.0);
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.AbsF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.AbsF32x4(a);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('AbsF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Sqrt
    a := MakeVecF32x4(1.0, 4.0, 9.0, 16.0);
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.SqrtF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.SqrtF32x4(a);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('SqrtF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Min/Max
    a := MakeVecF32x4(1.5, 2.0, 3.25, 4.0);
    b := MakeVecF32x4(2.0, 1.5, 4.0, 3.0);
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.MinF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.MinF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('MinF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.MaxF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.MaxF32x4(a, b);

    if not VecF32x4Equal(expected, actual, FLOAT_TOLERANCE, maxDiff, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('MaxF32x4 mismatch at [%d]', [diffIdx]);
      Result.MaxDiff := maxDiff;
      Result.DiffLocation := diffIdx;
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// F32x4 比较测试
// =============================================================================

function TestF32x4Comparison(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a, b: TVecF32x4;
  expectedMask, actualMask: TMask4;
begin
  if not BeginBackendConsistencyTest('F32x4 Comparison', backend, Result, LOriginalState) then
    Exit;

  try
    a := MakeVecF32x4(1.0, 2.0, 3.0, 4.0);
    b := MakeVecF32x4(1.0, 3.0, 2.0, 4.0);

    // 测试 CmpEq
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedMask := dispatch^.CoreVectors.CmpEqF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualMask := dispatch^.CoreVectors.CmpEqF32x4(a, b);

    if expectedMask <> actualMask then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('CmpEqF32x4 mask mismatch: expected $%x, got $%x', [expectedMask, actualMask]);
      Exit;
    end;

    // 测试 CmpLt
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedMask := dispatch^.CoreVectors.CmpLtF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualMask := dispatch^.CoreVectors.CmpLtF32x4(a, b);

    if expectedMask <> actualMask then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('CmpLtF32x4 mask mismatch: expected $%x, got $%x', [expectedMask, actualMask]);
      Exit;
    end;

    // 测试 CmpGt
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedMask := dispatch^.CoreVectors.CmpGtF32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualMask := dispatch^.CoreVectors.CmpGtF32x4(a, b);

    if expectedMask <> actualMask then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('CmpGtF32x4 mask mismatch: expected $%x, got $%x', [expectedMask, actualMask]);
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// F32x4 归约测试
// =============================================================================

function TestF32x4Reduction(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a: TVecF32x4;
  expectedVal, actualVal: Single;
begin
  if not BeginBackendConsistencyTest('F32x4 Reduction', backend, Result, LOriginalState) then
    Exit;

  try
    a := MakeVecF32x4(1.0, 2.0, 3.0, 4.0);

    // 测试 ReduceAdd
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedVal := dispatch^.CoreVectors.ReduceAddF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualVal := dispatch^.CoreVectors.ReduceAddF32x4(a);

    if not FloatEqual(expectedVal, actualVal) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('ReduceAddF32x4 mismatch: expected %f, got %f', [expectedVal, actualVal]);
      Result.MaxDiff := Abs(expectedVal - actualVal);
      Exit;
    end;

    // 测试 ReduceMin
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedVal := dispatch^.CoreVectors.ReduceMinF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualVal := dispatch^.CoreVectors.ReduceMinF32x4(a);

    if not FloatEqual(expectedVal, actualVal) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('ReduceMinF32x4 mismatch: expected %f, got %f', [expectedVal, actualVal]);
      Result.MaxDiff := Abs(expectedVal - actualVal);
      Exit;
    end;

    // 测试 ReduceMax
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedVal := dispatch^.CoreVectors.ReduceMaxF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualVal := dispatch^.CoreVectors.ReduceMaxF32x4(a);

    if not FloatEqual(expectedVal, actualVal) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('ReduceMaxF32x4 mismatch: expected %f, got %f', [expectedVal, actualVal]);
      Result.MaxDiff := Abs(expectedVal - actualVal);
      Exit;
    end;

    // 测试 ReduceMul
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedVal := dispatch^.CoreVectors.ReduceMulF32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualVal := dispatch^.CoreVectors.ReduceMulF32x4(a);

    if not FloatEqual(expectedVal, actualVal) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('ReduceMulF32x4 mismatch: expected %f, got %f', [expectedVal, actualVal]);
      Result.MaxDiff := Abs(expectedVal - actualVal);
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// I32x4 算术测试
// =============================================================================

function TestI32x4Arithmetic(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a, b, expected, actual: TVecI32x4;
  diffIdx: Integer;
begin
  if not BeginBackendConsistencyTest('I32x4 Arithmetic', backend, Result, LOriginalState) then
    Exit;

  try
    a := MakeVecI32x4(10, -20, 30, 0);
    b := MakeVecI32x4(5, 10, -15, 25);

    // 测试 Add
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.AddI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.AddI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('AddI32x4 mismatch at [%d]: expected %d, got %d', [diffIdx, expected.i[diffIdx], actual.i[diffIdx]]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Sub
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.SubI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.SubI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('SubI32x4 mismatch at [%d]: expected %d, got %d', [diffIdx, expected.i[diffIdx], actual.i[diffIdx]]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Mul
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.MulI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.MulI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('MulI32x4 mismatch at [%d]: expected %d, got %d', [diffIdx, expected.i[diffIdx], actual.i[diffIdx]]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// I32x4 位运算测试
// =============================================================================

function TestI32x4Bitwise(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  a, b, expected, actual: TVecI32x4;
  diffIdx: Integer;
begin
  if not BeginBackendConsistencyTest('I32x4 Bitwise', backend, Result, LOriginalState) then
    Exit;

  try
    // NOTE: Use signed literals that are in Int32 range (Debug build enables range checking).
    a := MakeVecI32x4(-16711936, $0F0F0F0F, $12345678, -1);
    b := MakeVecI32x4($00FF00FF, -252645136, -2023406815, 0);

    // 测试 And
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.AndI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.AndI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('AndI32x4 mismatch at [%d]', [diffIdx]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Or
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.OrI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.OrI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('OrI32x4 mismatch at [%d]', [diffIdx]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Xor
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.XorI32x4(a, b);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.XorI32x4(a, b);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('XorI32x4 mismatch at [%d]', [diffIdx]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

    // 测试 Not
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expected := dispatch^.CoreVectors.NotI32x4(a);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actual := dispatch^.CoreVectors.NotI32x4(a);

    if not VecI32x4Equal(expected, actual, diffIdx) then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('NotI32x4 mismatch at [%d]', [diffIdx]);
      Result.DiffLocation := diffIdx;
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// Facade 内存操作测试
// =============================================================================

function TestFacadeMemOps(backend: TSimdBackend): TConsistencyTestResult;
var
  LOriginalState: TSimdSavedBackendState;
  dispatch: PSimdDispatchTable;
  buf1, buf2: array[0..255] of Byte;
  i: Integer;
  expectedBool, actualBool: Boolean;
  expectedIdx, actualIdx: PtrInt;
  expectedSum, actualSum: UInt64;
begin
  if not BeginBackendConsistencyTest('Facade MemOps', backend, Result, LOriginalState) then
    Exit;

  try
    // 初始化测试缓冲区
    for i := 0 to 255 do
    begin
      buf1[i] := Byte(i);
      buf2[i] := Byte(i);
    end;
    buf2[100] := 99;  // 制造一个差异

    // 测试 MemEqual（相等情况）
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedBool := dispatch^.Memory.Equal(@buf1[0], @buf1[0], 256);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualBool := dispatch^.Memory.Equal(@buf1[0], @buf1[0], 256);

    if expectedBool <> actualBool then
    begin
      Result.Passed := False;
      Result.ErrorMessage := 'MemEqual (same) mismatch';
      Exit;
    end;

    // 测试 MemEqual（不等情况）
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedBool := dispatch^.Memory.Equal(@buf1[0], @buf2[0], 256);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualBool := dispatch^.Memory.Equal(@buf1[0], @buf2[0], 256);

    if expectedBool <> actualBool then
    begin
      Result.Passed := False;
      Result.ErrorMessage := 'MemEqual (diff) mismatch';
      Exit;
    end;

    // 测试 MemFindByte
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedIdx := dispatch^.Memory.FindByte(@buf1[0], 256, 100);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualIdx := dispatch^.Memory.FindByte(@buf1[0], 256, 100);

    if expectedIdx <> actualIdx then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('MemFindByte mismatch: expected %d, got %d', [expectedIdx, actualIdx]);
      Exit;
    end;

    // 测试 SumBytes
    SetActiveBackend(sbScalar);
    dispatch := GetDispatchTable;
    expectedSum := dispatch^.Memory.SumBytes(@buf1[0], 256);
    SetActiveBackend(backend);
    dispatch := GetDispatchTable;
    actualSum := dispatch^.Memory.SumBytes(@buf1[0], 256);

    if expectedSum <> actualSum then
    begin
      Result.Passed := False;
      Result.ErrorMessage := TextFormat('SumBytes mismatch: expected %d, got %d', [expectedSum, actualSum]);
      Exit;
    end;

  finally
    RestoreBackendConsistencyState(LOriginalState);
  end;
end;

// =============================================================================
// 运行所有测试
// =============================================================================

function RunAllConsistencyTests: TConsistencyTestResults;
const
  CTestFuncs: array[0..6] of TConsistencyTestFunc = (
    @TestF32x4Arithmetic, @TestF32x4Math,
    @TestF32x4Comparison, @TestF32x4Reduction,
    @TestI32x4Arithmetic, @TestI32x4Bitwise,
    @TestFacadeMemOps
  );
var
  LBackend: TSimdBackend;
  LBackendIndex, LResultIndex, LTestIndex: Integer;
begin
  Result := nil;

  SetLength(Result, Length(CONSISTENCY_BACKENDS) * Length(CTestFuncs));
  LResultIndex := 0;

  for LBackendIndex := Low(CONSISTENCY_BACKENDS) to High(CONSISTENCY_BACKENDS) do
  begin
    LBackend := CONSISTENCY_BACKENDS[LBackendIndex];
    for LTestIndex := Low(CTestFuncs) to High(CTestFuncs) do
    begin
      Result[LResultIndex] := CTestFuncs[LTestIndex](LBackend);
      Inc(LResultIndex);
    end;
  end;
end;

// =============================================================================
// 打印测试摘要
// =============================================================================

procedure PrintTestSummary(const results: TConsistencyTestResults);
var
  i: Integer;
  passCount, failCount, skipCount: Integer;
  backendName: string;
begin
  passCount := 0;
  failCount := 0;
  skipCount := 0;

  WriteLn('=== SIMD Backend Consistency Test Results ===');
  WriteLn;

  for i := 0 to High(results) do
  begin
    backendName := GetConsistencyBackendName(results[i].Backend);

    if IsConsistencyTestSkipped(results[i]) then
    begin
      WriteLn(TextFormat('[SKIP] %s / %s - %s', [backendName, results[i].TestName, results[i].ErrorMessage]));
      Inc(skipCount);
    end
    else if results[i].Passed then
    begin
      WriteLn(TextFormat('[PASS] %s / %s', [backendName, results[i].TestName]));
      Inc(passCount);
    end
    else
    begin
      WriteLn('[FAIL] ' + FormatConsistencyFailureText(results[i], '       '));
      Inc(failCount);
    end;
  end;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn(TextFormat('Passed:  %d', [passCount]));
  WriteLn(TextFormat('Failed:  %d', [failCount]));
  WriteLn(TextFormat('Skipped: %d', [skipCount]));
  WriteLn(TextFormat('Total:   %d', [Length(results)]));

  if failCount = 0 then
    WriteLn('All consistency tests PASSED!')
  else
    WriteLn('Some consistency tests FAILED!');
end;

end.
