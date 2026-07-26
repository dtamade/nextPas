program nextpas.core.simd.test;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  nextpas.core.simd.testcase,
  nextpas.core.simd.memutils.aliases.testcase,
  nextpas.core.simd.narrowintegerops.testcase,
  nextpas.core.simd.narrow512.testcase,
  nextpas.core.simd.alignment.testcase,
  nextpas.core.simd.saturating.testcase,
  nextpas.core.simd.veci32x8.testcase,
  nextpas.core.simd.vecu32x8.testcase,
  nextpas.core.simd.vecf32x8.testcase,
  nextpas.core.simd.vecf64x4.testcase,
  nextpas.core.simd.ieee754.testcase,
  nextpas.core.simd.dispatchapi.testcase,
  nextpas.core.simd.dispatchapi.support,
  nextpas.core.simd.dispatchapi.controlplane.testcase,
  nextpas.core.simd.dispatchapi.parity.testcase,
  nextpas.core.simd.dispatchapi.batchparity.testcase,
  nextpas.core.simd.dispatchapi.capabilities.testcase,
  nextpas.core.simd.dispatchapi.nonx86.testcase,
  nextpas.core.simd.sse2contracts.testcase,
  nextpas.core.simd.dataplane.testcase,
  nextpas.core.simd.runtime.testcase,
  nextpas.core.simd.dispatchslots.testcase,
  nextpas.core.simd.publicabi.testcase,
  nextpas.core.simd.edgecases.testcase,
  nextpas.core.simd.vec512types.testcase,
  nextpas.core.simd.imageproc.testcase,
  {$IFDEF SIMD_X86_AVAILABLE}
  nextpas.core.simd.direct.testcase,
  {$ENDIF}
  {$IFDEF CPUX86_64}
  nextpas.core.simd.sse3_correctness.testcase,
  {$ENDIF}
  nextpas.core.simd.intrinsics.avx2.testcase,
  nextpas.core.simd.concurrent.testcase,
  nextpas.core.simd.algorithms.testcase,
  nextpas.core.simd.linalg.testcase,
  nextpas.core.simd.arrays.testcase,
  nextpas.core.simd.nn.testcase,
  nextpas.core.simd.signal.testcase,
  nextpas.core.simd.stats.testcase,
  nextpas.core.simd.rvvparity.testcase,
  nextpas.core.simd.bench,
  test_dispatch_accessors,
  nextpas.core.simd.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.dispatch,
  nextpas.core.simd,
  nextpas.core.simd.scalar
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  , nextpas.core.simd.neon
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  , nextpas.core.simd.riscvv
  {$ENDIF}
  {$IFDEF CPUX86_64}
  , nextpas.core.simd.sse2
  , nextpas.core.simd.ssse3
  , nextpas.core.simd.avx2
  {$ENDIF}
  ;

var
  LRunner: TSuiteRunner;
  LDoBench: Boolean;
  LBenchOnly: Boolean;
  LPauseAtEnd: Boolean;
  LVectorAsmEnabled: Boolean;

procedure AddFixture(AFixture: TTestFixture; const ASuiteName: string);
begin
  LRunner.Add(DiscoverTests(AFixture, ASuiteName));
end;

{$IF DEFINED(NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND) OR DEFINED(NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND)}
procedure RegisterTestOptInBackends;
begin
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND}
  nextpas.core.simd.neon.RegisterNEONBackend;
  RegisterBackendRebuilder(sbNEON, @nextpas.core.simd.neon.RegisterNEONBackend);
  {$ENDIF}
  {$IFDEF NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND}
  nextpas.core.simd.riscvv.RegisterRISCVVBackend;
  RegisterBackendRebuilder(sbRISCVV, @nextpas.core.simd.riscvv.RegisterRISCVVBackend);
  {$ENDIF}
end;
{$ENDIF}

procedure RunBenchmarks;
var
  Results: TBenchResults;
  LBackend: TSimdBackend;
begin
  LBackend := GetActiveBackend;
  if (not IsVectorAsmEnabled) and (LBackend in [sbAVX2, sbAVX512, sbNEON, sbRISCVV]) then
  begin
    WriteLn('[BENCH] Note: vector-asm is OFF; vector-op rows may still reflect scalar fallback paths.');
    WriteLn('[BENCH] For backend vector throughput, prefer --bench-only --vector-asm or dedicated bench_*.lpr runners.');
    WriteLn;
  end;
  Results := nextpas.core.simd.bench.RunAllBenchmarks;
  PrintBenchResults(Results);
end;

procedure PrintUsage;
var
  LExe: string;
  i: Integer;
begin
  LExe := ParamStr(0);
  for i := Length(LExe) downto 1 do
    if LExe[i] in ['/', '\'] then
    begin
      LExe := Copy(LExe, i + 1, MaxInt);
      Break;
    end;
  WriteLn('Usage: ', LExe, ' [options]');
  WriteLn('Options:');
  WriteLn('  --filter=<substring>   Run only tests whose name contains substring');
  WriteLn('  --list                 List available test suites');
  WriteLn('  --bench                Run performance benchmarks after tests');
  WriteLn('  --bench-only           Run benchmarks only');
  WriteLn('  --no-bench             Do not run benchmarks (default)');
  WriteLn('  --vector-asm           Enable experimental SIMD vector ops (unsafe)');
  WriteLn('  --no-vector-asm        Disable experimental SIMD vector ops (default)');
  WriteLn('  --pause                Pause and wait for Enter before exiting');
  WriteLn('  -h, --help             Show this help');
end;

procedure RegisterAllSuites;
begin
  AddFixture(TTestCase_ImageProc.Create, 'TTestCase_ImageProc');
  AddFixture(TTestCase_Global.Create, 'TTestCase_Global');
  {$IFDEF CPUX86_64}
  AddFixture(TTestCase_BackendConsistency.Create, 'TTestCase_BackendConsistency');
  AddFixture(TTestCase_BackendVectorConsistency.Create, 'TTestCase_BackendVectorConsistency');
  AddFixture(TTestCase_X86BackendPredicates.Create, 'TTestCase_X86BackendPredicates');
  {$ENDIF}
  AddFixture(TTestCase_BackendSmoke.Create, 'TTestCase_BackendSmoke');
  {$IFDEF CPUX86_64}
  {$IFDEF SIMD_BACKEND_AVX512}
  AddFixture(TTestCase_AVX512BackendRequirements.Create, 'TTestCase_AVX512BackendRequirements');
  {$ENDIF}
  {$ENDIF}
  {$IFDEF UNIX}
  {$IFDEF CPUX86_64}
  AddFixture(TTestCase_AVX2VectorAsm.Create, 'TTestCase_AVX2VectorAsm');
  {$IFDEF SIMD_BACKEND_AVX512}
  AddFixture(TTestCase_AVX512VectorAsm.Create, 'TTestCase_AVX512VectorAsm');
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  AddFixture(TTestCase_VectorOps.Create, 'TTestCase_VectorOps');
  AddFixture(TTestCase_IntegerFacadeGuards.Create, 'TTestCase_IntegerFacadeGuards');
  AddFixture(TTestCase_FloatFacadeGuards.Create, 'TTestCase_FloatFacadeGuards');
  AddFixture(TTestCase_LargeData.Create, 'TTestCase_LargeData');
  AddFixture(TTestCase_UnsignedVectorTypes.Create, 'TTestCase_UnsignedVectorTypes');
  AddFixture(TTestCase_OperatorOverloads.Create, 'TTestCase_OperatorOverloads');
  AddFixture(TTestCase_VectorMaskTypes.Create, 'TTestCase_VectorMaskTypes');
  AddFixture(TTestCase_TypeConversion.Create, 'TTestCase_TypeConversion');
  AddFixture(TTestCase_Builder.Create, 'TTestCase_Builder');
  AddFixture(TTestCase_GatherScatter.Create, 'TTestCase_GatherScatter');
  AddFixture(TTestCase_ShuffleSWizzle.Create, 'TTestCase_ShuffleSWizzle');
  AddFixture(TTestCase_MathFunctions.Create, 'TTestCase_MathFunctions');
  AddFixture(TTestCase_AdvancedAlgorithms.Create, 'TTestCase_AdvancedAlgorithms');
  AddFixture(TTestCase_EdgeCases.Create, 'TTestCase_EdgeCases');
  AddFixture(TTestCase_Vec512Types.Create, 'TTestCase_Vec512Types');
  AddFixture(TTestCase_Vec512MaskFacadeGuards.Create, 'TTestCase_Vec512MaskFacadeGuards');
  AddFixture(TTestCase_Memutils.Create, 'TTestCase_Memutils');
  AddFixture(TTestCase_RustStyleAliases.Create, 'TTestCase_RustStyleAliases');
  AddFixture(TTestCase_SaturatingArithmetic.Create, 'TTestCase_SaturatingArithmetic');
  AddFixture(TTestCase_NarrowIntegerOps.Create, 'TTestCase_NarrowIntegerOps');
  AddFixture(TTestCase_Narrow512Ops.Create, 'TTestCase_Narrow512Ops');
  AddFixture(TTestCase_Alignment.Create, 'TTestCase_Alignment');
  AddFixture(TTestCase_VecI32x8.Create, 'TTestCase_VecI32x8');
  AddFixture(TTestCase_VecU32x8.Create, 'TTestCase_VecU32x8');
  AddFixture(TTestCase_VecF32x8.Create, 'TTestCase_VecF32x8');
  AddFixture(TTestCase_VecF64x4.Create, 'TTestCase_VecF64x4');
  AddFixture(TTestCase_IEEE754_F64.Create, 'TTestCase_IEEE754_F64');
  AddFixture(TTestCase_IEEE754EdgeCases.Create, 'TTestCase_IEEE754EdgeCases');
  AddFixture(TTestCase_AVX2RoundTruncIEEE754.Create, 'TTestCase_AVX2RoundTruncIEEE754');
  AddFixture(TTestCase_NonX86IEEE754.Create, 'TTestCase_NonX86IEEE754');
  AddFixture(TTestCase_NonX86BackendParity.Create, 'NonX86BackendParity');
  AddFixture(TTestCase_DispatchAPI.Create, 'TTestCase_DispatchAPI');
  AddFixture(TTestCase_DispatchAPIControlPlane.Create, 'TTestCase_DispatchAPIControlPlane');
  AddFixture(TTestCase_DispatchAPIParity.Create, 'TTestCase_DispatchAPIParity');
  AddFixture(TTestCase_DispatchAPIBatchParity.Create, 'TTestCase_DispatchAPIBatchParity');
  AddFixture(TTestCase_DispatchAPICapabilities.Create, 'TTestCase_DispatchAPICapabilities');
  AddFixture(TTestCase_SSE2Contracts.Create, 'TTestCase_SSE2Contracts');
  AddFixture(TTestCase_DataPlane.Create, 'TTestCase_DataPlane');
  AddFixture(TTestCase_RuntimeAPI.Create, 'TTestCase_RuntimeAPI');
  AddFixture(TTestCase_X86MaskedFmaContract.Create, 'TTestCase_X86MaskedFmaContract');
  AddFixture(TTestCase_RISCVVMaskedOpsContract.Create, 'TTestCase_RISCVVMaskedOpsContract');
  AddFixture(TTestCase_RISCVFallbackDispatchContract.Create, 'TTestCase_RISCVFallbackDispatchContract');
  AddFixture(TTestCase_DispatchAllSlots.Create, 'TTestCase_DispatchAllSlots');
  AddFixture(TTestCase_PublicAbi.Create, 'TTestCase_PublicAbi');
  {$IFDEF SIMD_X86_AVAILABLE}
  AddFixture(TTestCase_DirectDispatch.Create, 'TTestCase_DirectDispatch');
  AddFixture(TTestCase_DirectDispatchConcurrent.Create, 'TTestCase_DirectDispatchConcurrent');
  {$ENDIF}
  AddFixture(TTestCase_AVX2IntrinsicsFallback.Create, 'TTestCase_AVX2IntrinsicsFallback');
  AddFixture(TTestCase_SimdConcurrent.Create, 'TTestCase_SimdConcurrent');
  AddFixture(TTestCase_SimdConcurrentPublicAbi.Create, 'TTestCase_SimdConcurrentPublicAbi');
  AddFixture(TTestCase_SimdConcurrentFramework.Create, 'TTestCase_SimdConcurrentFramework');
  AddFixture(TTestCase_SimdConcurrentRegistration.Create, 'TTestCase_SimdConcurrentRegistration');
  AddFixture(TTestCase_SimdAlgorithms.Create, 'TTestCase_SimdAlgorithms');
  AddFixture(TTestCase_SimdLinalg.Create, 'TTestCase_SimdLinalg');
  AddFixture(TTestCase_SimdArrays.Create, 'TTestCase_SimdArrays');
  AddFixture(TTestCase_SimdNN.Create, 'TTestCase_SimdNN');
  AddFixture(TTestCase_SimdSignal.Create, 'TTestCase_SimdSignal');
  AddFixture(TTestCase_SimdStats.Create, 'TTestCase_SimdStats');
  AddFixture(TTestCase_RVVParity.Create, 'TTestCase_RVVParity');
  AddFixture(TTestDispatchAccessors.Create, 'TTestDispatchAccessors');
  {$IFDEF CPUX86_64}
  AddFixture(TTestCase_SSE3Correctness.Create, 'TTestCase_SSE3Correctness');
  {$ENDIF}
end;

procedure ParseCustomArgs;
var
  LArgIndex: Integer;
  LArg: string;
begin
  LDoBench := False;
  LBenchOnly := False;
  LPauseAtEnd := False;
  LVectorAsmEnabled := False;

  LArgIndex := 1;
  while LArgIndex <= ParamCount do
  begin
    LArg := ParamStr(LArgIndex);

    if LArg = '--bench' then
      LDoBench := True
    else if LArg = '--no-bench' then
      LDoBench := False
    else if LArg = '--bench-only' then
    begin
      LDoBench := True;
      LBenchOnly := True;
    end
    else if LArg = '--pause' then
      LPauseAtEnd := True
    else if LArg = '--vector-asm' then
      LVectorAsmEnabled := True
    else if LArg = '--no-vector-asm' then
      LVectorAsmEnabled := False
    else if (LArg = '--help') or (LArg = '-h') then
    begin
      PrintUsage;
      Halt(0);
    end;

    Inc(LArgIndex);
  end;
end;

begin
  LDoBench := False;
  LBenchOnly := False;
  LPauseAtEnd := False;
  LVectorAsmEnabled := False;
  ParseCustomArgs;

  WriteLn('=== nextpas.core.simd Test Suite ===');
  WriteLn('Starting SIMD facade function tests...');
  WriteLn;

  SetVectorAsmEnabled(LVectorAsmEnabled);
  {$IF DEFINED(NEXTPAS_SIMD_TEST_REGISTER_NEON_BACKEND) OR DEFINED(NEXTPAS_SIMD_TEST_REGISTER_RISCVV_BACKEND)}
  RegisterTestOptInBackends;
  {$ENDIF}

  WriteLn('CPU Features:');
  WriteLn('  SSE2: ', HasSSE2);
  WriteLn('  AVX2: ', HasAVX2);
  WriteLn('  Active Backend: ', Ord(GetActiveBackend));
  WriteLn('  VectorAsm: ', IsVectorAsmEnabled);
  WriteLn('  Benchmarks: ', LDoBench);
  WriteLn;

  if LBenchOnly then
  begin
    RunBenchmarks;
    Halt(0);
  end;

  LRunner := TSuiteRunner.Create('SIMD Tests');
  RegisterAllSuites;
  LRunner.RunAll;
  LRunner.Summary;

  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;

  if LDoBench and (ExitCode = 0) then
  begin
    WriteLn;
    RunBenchmarks;
  end;

  if LPauseAtEnd then
  begin
    WriteLn('Press Enter to exit...');
    ReadLn;
  end;

  { Release suite closures/results before unit finalization so heaptrc
    does not report DiscoverTests/AppendResult blocks as unfreed.
    (Unit finalization can run before program-level managed fields are cleared.) }
  LRunner := Default(TSuiteRunner);
end.
