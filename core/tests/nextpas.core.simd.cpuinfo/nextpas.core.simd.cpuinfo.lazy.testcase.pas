unit nextpas.core.simd.cpuinfo.lazy.testcase;

{$I nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  Classes,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.lazy;

{$M+}
type
  TLazyCPUInfoReaderThread = class(TThread)
  private
    FIterations: Integer;
    FFailed: Boolean;
    FErrorMessage: string;
    FVendor: string;
    FModel: string;
  protected
    procedure Execute; override;
  public
    constructor Create(const aIterations: Integer);
    property Failed: Boolean read FFailed;
    property ErrorMessage: string read FErrorMessage;
    property Vendor: string read FVendor;
    property Model: string read FModel;
  end;

  TTestFixture_LazyCPUInfo = class(TTestFixture)
  published
    procedure Test_ParseCacheSizeTextToKB_Boundaries;
    procedure Test_GetCPUInfoLazy_BasicFields;
    procedure Test_HasFeatureLazy_Consistency;
    procedure Test_X86LazyQuickPredicates_UseUsableView;
    procedure Test_LazyEager_GenericFeatureParity;
    procedure Test_Reset_ReloadConsistency;
    procedure Test_NonX86CacheInfoOnLinux;
    procedure Test_GetCPUInfoLazy_ConcurrentReaders;
    procedure Test_GetCPUInfoLazy_ResetWhileReading;
  end;

implementation

constructor TLazyCPUInfoReaderThread.Create(const aIterations: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIterations := aIterations;
  FFailed := False;
  FErrorMessage := '';
  FVendor := '';
  FModel := '';
end;

procedure TLazyCPUInfoReaderThread.Execute;
var
  LCPUInfo: TCPUInfo;
  LIndex: Integer;
begin
  try
    for LIndex := 1 to FIterations do
    begin
      LCPUInfo := GetCPUInfoLazy;
      if (LCPUInfo.Vendor = '') or (LCPUInfo.Model = '') then
        raise Exception.Create('lazy cpuinfo returned empty vendor/model');

      if LIndex = 1 then
      begin
        FVendor := LCPUInfo.Vendor;
        FModel := LCPUInfo.Model;
      end
      else
      begin
        if LCPUInfo.Vendor <> FVendor then
          raise Exception.Create('vendor changed during concurrent reads');
        if LCPUInfo.Model <> FModel then
          raise Exception.Create('model changed during concurrent reads');
      end;
    end;
  except
    on E: Exception do
    begin
      FFailed := True;
      FErrorMessage := E.Message;
    end;
  end;
end;

procedure TTestFixture_LazyCPUInfo.Test_ParseCacheSizeTextToKB_Boundaries;
begin
  CheckEqual(0, ParseCacheSizeTextToKB(''), 'empty text should parse to 0');
  CheckEqual(0, ParseCacheSizeTextToKB('   '), 'whitespace-only text should parse to 0');
  CheckEqual(32, ParseCacheSizeTextToKB('32K'), '32K should parse to 32KB');
  CheckEqual(64, ParseCacheSizeTextToKB('64KiB'), '64KiB should parse to 64KB');
  CheckEqual(1024, ParseCacheSizeTextToKB('1MiB'), '1MiB should parse to 1024KB');
  CheckEqual(1024 * 1024, ParseCacheSizeTextToKB('1GiB'), '1GiB should parse to 1048576KB');
  CheckEqual(1, ParseCacheSizeTextToKB('1024B'), '1024B should parse to 1KB');
  CheckEqual(2, ParseCacheSizeTextToKB('1025B'), '1025B should ceil to 2KB');
  CheckEqual(2, ParseCacheSizeTextToKB('2048'), 'bare bytes should ceil to KB');
  CheckEqual(0, ParseCacheSizeTextToKB('invalid'), 'invalid size should parse to 0');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('3000000000K'), 'large K value should saturate');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('3000000M'), 'large M value should saturate');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('5000G'), 'large G value should saturate');
  CheckEqual(High(Integer), ParseCacheSizeTextToKB('9223372036854775807B'), 'huge byte value should saturate');
end;

procedure TTestFixture_LazyCPUInfo.Test_GetCPUInfoLazy_BasicFields;
var
  LCPUInfo: TCPUInfo;
begin
  LazyCPUInfo.Reset;
  LCPUInfo := GetCPUInfoLazy;

  CheckTrue(LCPUInfo.Vendor <> '', 'Vendor should not be empty');
  CheckTrue(LCPUInfo.Model <> '', 'Model should not be empty');
  CheckTrue(LCPUInfo.LogicalCores > 0, 'Logical cores should be positive');
  CheckTrue(LCPUInfo.PhysicalCores > 0, 'Physical cores should be positive');
  CheckTrue(LCPUInfo.PhysicalCores <= LCPUInfo.LogicalCores, 'Physical cores should not exceed logical cores');
end;

procedure TTestFixture_LazyCPUInfo.Test_HasFeatureLazy_Consistency;
var
  LCPUInfo: TCPUInfo;
  LFeature: TGenericFeature;
begin
  LazyCPUInfo.Reset;
  LCPUInfo := GetCPUInfoLazy;

  for LFeature := Low(TGenericFeature) to High(TGenericFeature) do
    CheckEqual(LFeature in LCPUInfo.GenericUsable, HasFeatureLazy(LFeature), 'HasFeatureLazy consistency for feature #' + IntToStr(Ord(LFeature)));
end;

procedure TTestFixture_LazyCPUInfo.Test_X86LazyQuickPredicates_UseUsableView;
var
  LLazy: TLazyCPUInfo;
  LCPUInfo: TCPUInfo;
begin
  {$IFDEF SIMD_X86_AVAILABLE}
  LLazy := LazyCPUInfo;
  LLazy.Reset;
  LCPUInfo := GetCPUInfoLazy;

  if LCPUInfo.Arch = caX86 then
  begin
    CheckEqual(LCPUInfo.X86.HasAVX2 and (gfSimd256 in LCPUInfo.GenericUsable), LLazy.HasAVX2, 'lazy HasAVX2 property should use usable AVX2 semantics');
    CheckEqual(LCPUInfo.X86.HasAVX512F and (gfSimd512 in LCPUInfo.GenericUsable), LLazy.HasAVX512F, 'lazy HasAVX512F property should use usable AVX-512 semantics');
  end;
  {$ELSE}
  Skip('lazy x86 quick predicate semantics skipped when SIMD_X86_AVAILABLE is off');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_LazyCPUInfo.Test_LazyEager_GenericFeatureParity;
var
  LLazyCPUInfo: TCPUInfo;
  LEagerCPUInfo: TCPUInfo;
  LFeature: TGenericFeature;
begin
  LazyCPUInfo.Reset;
  ResetCPUInfo;

  LLazyCPUInfo := GetCPUInfoLazy;
  LEagerCPUInfo := GetCPUInfo;

  CheckEqual(Ord(LEagerCPUInfo.Arch), Ord(LLazyCPUInfo.Arch), 'Lazy/eager architecture should match');
  CheckEqual(LEagerCPUInfo.LogicalCores, LLazyCPUInfo.LogicalCores, 'Lazy/eager logical core count should match');
  CheckEqual(LEagerCPUInfo.PhysicalCores, LLazyCPUInfo.PhysicalCores, 'Lazy/eager physical core count should match');

  for LFeature := Low(TGenericFeature) to High(TGenericFeature) do
  begin
    CheckEqual(LFeature in LEagerCPUInfo.GenericRaw, LFeature in LLazyCPUInfo.GenericRaw, 'Lazy/eager GenericRaw parity for feature #' + IntToStr(Ord(LFeature)));
    CheckEqual(LFeature in LEagerCPUInfo.GenericUsable, LFeature in LLazyCPUInfo.GenericUsable, 'Lazy/eager GenericUsable parity for feature #' + IntToStr(Ord(LFeature)));
  end;
end;

procedure TTestFixture_LazyCPUInfo.Test_Reset_ReloadConsistency;
var
  LBefore: TCPUInfo;
  LAfter: TCPUInfo;
  LLazy: TLazyCPUInfo;
begin
  LLazy := LazyCPUInfo;
  LLazy.PreloadAll;
  LBefore := GetCPUInfoLazy;

  LLazy.Reset;
  LAfter := GetCPUInfoLazy;

  CheckEqual(LBefore.Vendor, LAfter.Vendor, 'Vendor should remain stable after reset');
  CheckEqual(LBefore.Model, LAfter.Model, 'Model should remain stable after reset');
  CheckTrue(LAfter.LogicalCores > 0, 'Logical cores should stay valid after reset');
  CheckTrue(LAfter.PhysicalCores > 0, 'Physical cores should stay valid after reset');
end;

procedure TTestFixture_LazyCPUInfo.Test_NonX86CacheInfoOnLinux;
var
  LLazyInfo: TCPUInfo;
  LEagerInfo: TCPUInfo;
begin
  {$IFDEF LINUX}
  LazyCPUInfo.Reset;
  ResetCPUInfo;

  LLazyInfo := GetCPUInfoLazy;
  if not (LLazyInfo.Arch in [caARM, caRISCV, caLoongArch]) then
    Exit;

  LEagerInfo := GetCPUInfo;

  CheckEqual(LEagerInfo.Vendor, LLazyInfo.Vendor, 'Lazy/eager non-x86 vendor should match');
  CheckEqual(LEagerInfo.Model, LLazyInfo.Model, 'Lazy/eager non-x86 model should match');
  CheckTrue(LLazyInfo.Cache.LineSize > 0, 'Lazy non-x86 cache line size should be positive');
  CheckEqual(LEagerInfo.Cache.LineSize, LLazyInfo.Cache.LineSize, 'Lazy/eager non-x86 cache line size should match');
  CheckEqual(LEagerInfo.Cache.L1DataKB, LLazyInfo.Cache.L1DataKB, 'Lazy/eager non-x86 L1 data cache should match');
  CheckEqual(LEagerInfo.Cache.L1InstrKB, LLazyInfo.Cache.L1InstrKB, 'Lazy/eager non-x86 L1 instruction cache should match');
  CheckEqual(LEagerInfo.Cache.L2KB, LLazyInfo.Cache.L2KB, 'Lazy/eager non-x86 L2 cache should match');
  CheckEqual(LEagerInfo.Cache.L3KB, LLazyInfo.Cache.L3KB, 'Lazy/eager non-x86 L3 cache should match');
  {$ELSE}
  Skip('Lazy non-x86 cache test skipped on non-Linux');
  Exit;
  {$ENDIF}
end;

procedure TTestFixture_LazyCPUInfo.Test_GetCPUInfoLazy_ConcurrentReaders;
const
  THREAD_COUNT = 4;
  ITERATIONS_PER_THREAD = 200;
var
  LThreads: array[0..THREAD_COUNT - 1] of TLazyCPUInfoReaderThread;
  LIndex: Integer;
  LRefVendor: string;
  LRefModel: string;
begin
  LazyCPUInfo.Reset;

  for LIndex := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[LIndex] := TLazyCPUInfoReaderThread.Create(ITERATIONS_PER_THREAD);
    LThreads[LIndex].Start;
  end;

  try
    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].WaitFor;

    LRefVendor := LThreads[0].Vendor;
    LRefModel := LThreads[0].Model;
    CheckTrue(LRefVendor <> '', 'Reference vendor should not be empty');
    CheckTrue(LRefModel <> '', 'Reference model should not be empty');

    for LIndex := 0 to THREAD_COUNT - 1 do
    begin
      CheckFalse(LThreads[LIndex].Failed, 'Reader thread #' + IntToStr(LIndex) + ' should not fail: ' + LThreads[LIndex].ErrorMessage);
      CheckEqual(LRefVendor, LThreads[LIndex].Vendor, 'Vendor should be stable across threads');
      CheckEqual(LRefModel, LThreads[LIndex].Model, 'Model should be stable across threads');
    end;
  finally
    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].Free;
  end;
end;

procedure TTestFixture_LazyCPUInfo.Test_GetCPUInfoLazy_ResetWhileReading;
const
  THREAD_COUNT = 4;
  ITERATIONS_PER_THREAD = 300;
  RESET_ROUNDS = 80;
var
  LThreads: array[0..THREAD_COUNT - 1] of TLazyCPUInfoReaderThread;
  LIndex: Integer;
begin
  LazyCPUInfo.Reset;

  for LIndex := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[LIndex] := TLazyCPUInfoReaderThread.Create(ITERATIONS_PER_THREAD);
    LThreads[LIndex].Start;
  end;

  try
    for LIndex := 1 to RESET_ROUNDS do
    begin
      LazyCPUInfo.Reset;
      ThreadSwitch;
    end;

    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to THREAD_COUNT - 1 do
      CheckFalse(LThreads[LIndex].Failed, 'Reset/read race thread #' + IntToStr(LIndex) + ' should not fail: ' + LThreads[LIndex].ErrorMessage);
  finally
    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].Free;
  end;
end;

end.
