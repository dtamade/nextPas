unit nextpas.core.simd.cpuinfo.lazy.testcase;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils,
  fpcunit, testregistry,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.lazy;

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

  TTestCase_LazyCPUInfo = class(TTestCase)
  published
    procedure Test_ParseCacheSizeTextToKB_Boundaries;
    procedure Test_GetCPUInfoLazy_BasicFields;
    procedure Test_HasFeatureLazy_Consistency;
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

procedure TTestCase_LazyCPUInfo.Test_ParseCacheSizeTextToKB_Boundaries;
begin
  AssertEquals('empty text should parse to 0', 0, ParseCacheSizeTextToKB(''));
  AssertEquals('whitespace-only text should parse to 0', 0, ParseCacheSizeTextToKB('   '));
  AssertEquals('32K should parse to 32KB', 32, ParseCacheSizeTextToKB('32K'));
  AssertEquals('64KiB should parse to 64KB', 64, ParseCacheSizeTextToKB('64KiB'));
  AssertEquals('1MiB should parse to 1024KB', 1024, ParseCacheSizeTextToKB('1MiB'));
  AssertEquals('1GiB should parse to 1048576KB', 1024 * 1024, ParseCacheSizeTextToKB('1GiB'));
  AssertEquals('1024B should parse to 1KB', 1, ParseCacheSizeTextToKB('1024B'));
  AssertEquals('1025B should ceil to 2KB', 2, ParseCacheSizeTextToKB('1025B'));
  AssertEquals('bare bytes should ceil to KB', 2, ParseCacheSizeTextToKB('2048'));
  AssertEquals('invalid size should parse to 0', 0, ParseCacheSizeTextToKB('invalid'));
  AssertEquals('large K value should saturate', High(Integer), ParseCacheSizeTextToKB('3000000000K'));
  AssertEquals('large M value should saturate', High(Integer), ParseCacheSizeTextToKB('3000000M'));
  AssertEquals('large G value should saturate', High(Integer), ParseCacheSizeTextToKB('5000G'));
  AssertEquals('huge byte value should saturate', High(Integer), ParseCacheSizeTextToKB('9223372036854775807B'));
end;

procedure TTestCase_LazyCPUInfo.Test_GetCPUInfoLazy_BasicFields;
var
  LCPUInfo: TCPUInfo;
begin
  LazyCPUInfo.Reset;
  LCPUInfo := GetCPUInfoLazy;

  AssertTrue('Vendor should not be empty', LCPUInfo.Vendor <> '');
  AssertTrue('Model should not be empty', LCPUInfo.Model <> '');
  AssertTrue('Logical cores should be positive', LCPUInfo.LogicalCores > 0);
  AssertTrue('Physical cores should be positive', LCPUInfo.PhysicalCores > 0);
  AssertTrue('Physical cores should not exceed logical cores',
    LCPUInfo.PhysicalCores <= LCPUInfo.LogicalCores);
end;

procedure TTestCase_LazyCPUInfo.Test_HasFeatureLazy_Consistency;
var
  LCPUInfo: TCPUInfo;
  LFeature: TGenericFeature;
begin
  LazyCPUInfo.Reset;
  LCPUInfo := GetCPUInfoLazy;

  for LFeature := Low(TGenericFeature) to High(TGenericFeature) do
    AssertEquals(
      'HasFeatureLazy consistency for feature #' + IntToStr(Ord(LFeature)),
      LFeature in LCPUInfo.GenericUsable,
      HasFeatureLazy(LFeature)
    );
end;

procedure TTestCase_LazyCPUInfo.Test_LazyEager_GenericFeatureParity;
var
  LLazyCPUInfo: TCPUInfo;
  LEagerCPUInfo: TCPUInfo;
  LFeature: TGenericFeature;
begin
  LazyCPUInfo.Reset;
  ResetCPUInfo;

  LLazyCPUInfo := GetCPUInfoLazy;
  LEagerCPUInfo := GetCPUInfo;

  AssertEquals('Lazy/eager architecture should match',
    Ord(LEagerCPUInfo.Arch), Ord(LLazyCPUInfo.Arch));
  AssertEquals('Lazy/eager logical core count should match',
    LEagerCPUInfo.LogicalCores, LLazyCPUInfo.LogicalCores);
  AssertEquals('Lazy/eager physical core count should match',
    LEagerCPUInfo.PhysicalCores, LLazyCPUInfo.PhysicalCores);

  for LFeature := Low(TGenericFeature) to High(TGenericFeature) do
  begin
    AssertEquals(
      'Lazy/eager GenericRaw parity for feature #' + IntToStr(Ord(LFeature)),
      LFeature in LEagerCPUInfo.GenericRaw,
      LFeature in LLazyCPUInfo.GenericRaw
    );
    AssertEquals(
      'Lazy/eager GenericUsable parity for feature #' + IntToStr(Ord(LFeature)),
      LFeature in LEagerCPUInfo.GenericUsable,
      LFeature in LLazyCPUInfo.GenericUsable
    );
  end;
end;

procedure TTestCase_LazyCPUInfo.Test_Reset_ReloadConsistency;
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

  AssertEquals('Vendor should remain stable after reset', LBefore.Vendor, LAfter.Vendor);
  AssertEquals('Model should remain stable after reset', LBefore.Model, LAfter.Model);
  AssertTrue('Logical cores should stay valid after reset', LAfter.LogicalCores > 0);
  AssertTrue('Physical cores should stay valid after reset', LAfter.PhysicalCores > 0);
end;

procedure TTestCase_LazyCPUInfo.Test_NonX86CacheInfoOnLinux;
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

  AssertEquals('Lazy/eager non-x86 vendor should match', LEagerInfo.Vendor, LLazyInfo.Vendor);
  AssertEquals('Lazy/eager non-x86 model should match', LEagerInfo.Model, LLazyInfo.Model);
  AssertTrue('Lazy non-x86 cache line size should be positive', LLazyInfo.Cache.LineSize > 0);
  AssertEquals('Lazy/eager non-x86 cache line size should match', LEagerInfo.Cache.LineSize, LLazyInfo.Cache.LineSize);
  AssertEquals('Lazy/eager non-x86 L1 data cache should match', LEagerInfo.Cache.L1DataKB, LLazyInfo.Cache.L1DataKB);
  AssertEquals('Lazy/eager non-x86 L1 instruction cache should match', LEagerInfo.Cache.L1InstrKB, LLazyInfo.Cache.L1InstrKB);
  AssertEquals('Lazy/eager non-x86 L2 cache should match', LEagerInfo.Cache.L2KB, LLazyInfo.Cache.L2KB);
  AssertEquals('Lazy/eager non-x86 L3 cache should match', LEagerInfo.Cache.L3KB, LLazyInfo.Cache.L3KB);
  {$ELSE}
  Ignore('Lazy non-x86 cache test skipped on non-Linux');
  Exit;
  {$ENDIF}
end;

procedure TTestCase_LazyCPUInfo.Test_GetCPUInfoLazy_ConcurrentReaders;
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
    AssertTrue('Reference vendor should not be empty', LRefVendor <> '');
    AssertTrue('Reference model should not be empty', LRefModel <> '');

    for LIndex := 0 to THREAD_COUNT - 1 do
    begin
      AssertFalse(
        'Reader thread #' + IntToStr(LIndex) + ' should not fail: ' + LThreads[LIndex].ErrorMessage,
        LThreads[LIndex].Failed
      );
      AssertEquals('Vendor should be stable across threads', LRefVendor, LThreads[LIndex].Vendor);
      AssertEquals('Model should be stable across threads', LRefModel, LThreads[LIndex].Model);
    end;
  finally
    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].Free;
  end;
end;

procedure TTestCase_LazyCPUInfo.Test_GetCPUInfoLazy_ResetWhileReading;
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
      AssertFalse(
        'Reset/read race thread #' + IntToStr(LIndex) + ' should not fail: ' + LThreads[LIndex].ErrorMessage,
        LThreads[LIndex].Failed
      );
  finally
    for LIndex := 0 to THREAD_COUNT - 1 do
      LThreads[LIndex].Free;
  end;
end;

initialization
  RegisterTest(TTestCase_LazyCPUInfo);

end.
