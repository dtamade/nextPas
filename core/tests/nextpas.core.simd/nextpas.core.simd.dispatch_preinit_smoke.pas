program nextpas.core.simd.dispatch_preinit_smoke;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  SysUtils,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.scalar
  {$IFDEF CPUX86_64}
  , nextpas.core.simd.sse2
  , nextpas.core.simd.sse3
  , nextpas.core.simd.ssse3
  , nextpas.core.simd.sse41
  , nextpas.core.simd.sse42
  , nextpas.core.simd.avx2
  {$ENDIF}
  {$IFDEF CPU386}
  , nextpas.core.simd.sse2.i386
  , nextpas.core.simd.sse3
  , nextpas.core.simd.ssse3
  , nextpas.core.simd.sse41
  , nextpas.core.simd.sse42
  {$ENDIF}
  ;

procedure Fail(const aMessage: string);
begin
  WriteLn('[FAIL] ', aMessage);
  Halt(1);
end;

procedure CheckBackendMarkedUnavailable(const aBackend: TSimdBackend);
var
  LTable: TSimdDispatchTable;
begin
  if not TryGetRegisteredBackendDispatchTable(aBackend, LTable) then
    Exit;

  if LTable.BackendInfo.Available then
    Fail(GetBackendInfo(aBackend).Name +
      ' should not remain marked Available after pre-init SetVectorAsmEnabled(False)');
end;

begin
  SetVectorAsmEnabled(False);

  if IsVectorAsmEnabled then
    Fail('Vector asm should stay disabled before first dispatch initialization');

  if GetBestDispatchableBackend <> sbScalar then
    Fail('Best dispatchable backend should be Scalar after pre-init SetVectorAsmEnabled(False), got ' +
      GetBackendInfo(GetBestDispatchableBackend).Name);

  if GetActiveBackend <> sbScalar then
    Fail('Active backend should be Scalar after pre-init SetVectorAsmEnabled(False), got ' +
      GetBackendInfo(GetActiveBackend).Name);

  {$IFDEF CPUX86_64}
  CheckBackendMarkedUnavailable(sbAVX2);
  CheckBackendMarkedUnavailable(sbSSE42);
  CheckBackendMarkedUnavailable(sbSSE41);
  CheckBackendMarkedUnavailable(sbSSSE3);
  CheckBackendMarkedUnavailable(sbSSE3);
  CheckBackendMarkedUnavailable(sbSSE2);
  {$ENDIF}
  {$IFDEF CPU386}
  CheckBackendMarkedUnavailable(sbSSE42);
  CheckBackendMarkedUnavailable(sbSSE41);
  CheckBackendMarkedUnavailable(sbSSSE3);
  CheckBackendMarkedUnavailable(sbSSE3);
  CheckBackendMarkedUnavailable(sbSSE2);
  {$ENDIF}

  WriteLn('[PASS] pre-init vector-asm toggle updated dispatchable backend selection');
end.
