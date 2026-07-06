{ nextpas.core.test.config — TTestConfig, IOutputSink, ANSI helpers
  =========================================================
  Configuration record + output sink interface + ANSI formatting. }

unit nextpas.core.test.config;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.base,
  nextpas.core.base,
  nextpas.core.text.conv;

type
  TAnsiMode = (amAuto, amOn, amOff);

  TConfigKey = (ckFilter, ckTag, ckTimeout, ckAnsi,
    ckOutSink, ckErrSink, ckRetry, ckWorkers, ckCount, ckSlow,
    ckShuffle, ckFailFast, ckList, ckShort, ckProgress, ckMaxFail,
    ckJsonOutput, ckVerbose, ckRunTimeout,
    ckBench, ckBenchTime, ckBenchMem, ckRun,
    ckBenchSave, ckBenchCompare);
  TConfigKeys = set of TConfigKey;

  IOutputSink = interface
    ['{92B1BE7D-E6E5-49B1-8533-1D934BF43D07}']
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStdoutSink = class(TInterfacedObject, IOutputSink)
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStderrSink = class(TInterfacedObject, IOutputSink)
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
  end;

  TStringLines = array of string;

  TBufferSink = class(TInterfacedObject, IOutputSink)
  private
    FLines: TStringLines;
    FLineCap: Integer;
    FHasOpenLine: Boolean;
    function GetLines: TStringLines;
    procedure EnsureOpenLine;
  public
    procedure Write(const AText: string);
    procedure WriteLn(const AText: string);
    procedure Flush;
    function GetOutput: string;
    procedure Clear;
    property Lines: TStringLines read GetLines;
  end;

  TTestConfig = record
    FilterPattern: string;
    TagFilter: string;  { comma-separated tag filter; empty = no tag filter }
    TimeoutMs: UInt64;
    AnsiMode: TAnsiMode;
    OutSink: IOutputSink;
    ErrSink: IOutputSink;
    RetryCount: Integer;
    MaxParallelWorkers: Integer;
      { 0 = unlimited (current behavior, one OS thread per test)
        >0 = max concurrent OS threads in parallel mode (batch dispatch) }
    RepeatAllCount: Integer; { --count=N: run all tests N times (>1), 0=once }
    SlowTestCount : Integer; { N slowest tests to show in summary (0=off, default=5) }
    ShuffleSeed   : Integer; { 0=off, -1=random, >0=specific seed }
    FailFast      : Boolean; { true = stop on first failure }
    ListMode      : Boolean; { true = list test names only, don't run }
    ShortMode     : Boolean; { true = skip tests marked with ShortSkip }
    ShowProgress  : Boolean; { true = show [N/Total] progress counter }
    MaxFailures   : Integer; { 0=unlimited, >0 = stop after N total failures }
    JsonOutput    : Boolean; { true = emit JSON report to stdout after run }
    VerboseMode   : Boolean; { true = show per-test [PASS]/[FAIL]/[SKIP] with duration }
    RunTimeoutSec : Integer; { 0=unlimited, >0 = global suite runner timeout in seconds }
    BenchEnabled  : Boolean; { true = run benchmarks (Go -bench=. equivalent) }
    BenchTimeMs   : Integer; { benchmark target duration in ms (default 1000 = 1s) }
    BenchMem      : Boolean; { true = report memory allocations per op }
    RunPattern    : string;  { --run: exact test name match (case-insensitive) }
    BenchSaveFile : string;  { --benchsave=<file>: save benchmark results to JSON }
    BenchCompareFile: string; { --benchcompare=<file>: compare against baseline JSON }
    CacheEnabled  : Boolean; { true = use test result cache (--cache) }
    CacheDir      : string;  { cache directory (default .nextpas/test-cache/) }
  end;

  {** Fluent builder for TTestConfig
   *
   *  Usage:
   *    LConfig := TTestConfigBuilder.Create
   *      .WithFilter('my-test')
   *      .WithTimeout(5000)
   *      .WithFailFast(True)
   *      .Build;
   *}
  TTestConfigBuilder = record
  private
    FConfig: TTestConfig;
  public
    class function Create: TTestConfigBuilder; static;
    function WithFilter(const APattern: string): TTestConfigBuilder;
    function WithTag(const ATag: string): TTestConfigBuilder;
    function WithTimeout(ATimeoutMs: UInt64): TTestConfigBuilder;
    function WithAnsiMode(AMode: TAnsiMode): TTestConfigBuilder;
    function WithOutSink(const ASink: IOutputSink): TTestConfigBuilder;
    function WithErrSink(const ASink: IOutputSink): TTestConfigBuilder;
    function WithRetry(ACount: Integer): TTestConfigBuilder;
    function WithWorkers(AWorkers: Integer): TTestConfigBuilder;
    function WithRepeat(ACount: Integer): TTestConfigBuilder;
    function WithSlowCount(ACount: Integer): TTestConfigBuilder;
    function WithShuffle(ASeed: Integer): TTestConfigBuilder;
    function WithFailFast(AFailFast: Boolean = True): TTestConfigBuilder;
    function WithListMode(AListMode: Boolean = True): TTestConfigBuilder;
    function WithShortMode(AShortMode: Boolean = True): TTestConfigBuilder;
    function WithProgress(AProgress: Boolean = True): TTestConfigBuilder;
    function WithMaxFailures(AMax: Integer): TTestConfigBuilder;
    function WithJsonOutput(AJson: Boolean = True): TTestConfigBuilder;
    function WithVerbose(AVerbose: Boolean = True): TTestConfigBuilder;
    function WithRunTimeout(ATimeoutSec: Integer): TTestConfigBuilder;
    function WithBench(AEnabled: Boolean = True): TTestConfigBuilder;
    function WithBenchTime(ATimeMs: Integer): TTestConfigBuilder;
    function WithBenchMem(AMem: Boolean = True): TTestConfigBuilder;
    function WithRunPattern(const APattern: string): TTestConfigBuilder;
    function WithBenchSave(const AFile: string): TTestConfigBuilder;
    function WithBenchCompare(const AFile: string): TTestConfigBuilder;
    function WithCache(AEnabled: Boolean = True): TTestConfigBuilder;
    function WithCacheDir(const ADir: string): TTestConfigBuilder;
    function Build: TTestConfig;
  end;

function DefaultConfig: TTestConfig;
function ResolveConfig(const AConfig: TTestConfig): TTestConfig;
function ResolveOutSink(const AConfig: TTestConfig): IOutputSink;
function ResolveErrSink(const AConfig: TTestConfig): IOutputSink;
procedure ResetDefaultConfig;
procedure SetDefaultFilterPattern(const APattern: string);
procedure SetDefaultTagFilter(const APattern: string);
procedure SetDefaultTimeoutMs(const ATimeoutMs: UInt64);
procedure SetDefaultAnsiMode(AAnsiMode: TAnsiMode);
procedure SetDefaultOutSink(const ASink: IOutputSink);
procedure SetDefaultErrSink(const ASink: IOutputSink);
procedure SetDefaultRetryCount(ARetryCount: Integer);
procedure SetDefaultMaxParallelWorkers(AMaxWorkers: Integer);
procedure SetDefaultRepeatAllCount(ARepeatCount: Integer);
procedure SetDefaultSlowTestCount(ACount: Integer);
procedure SetDefaultShuffleSeed(ASeed: Integer);
procedure SetDefaultFailFast(AFailFast: Boolean);
procedure SetDefaultListMode(AListMode: Boolean);
procedure SetDefaultShortMode(AShortMode: Boolean);
procedure SetDefaultShowProgress(AShowProgress: Boolean);
procedure SetDefaultMaxFailures(AMaxFailures: Integer);
procedure SetDefaultJsonOutput(AJsonOutput: Boolean);
procedure SetDefaultVerboseMode(AVerbose: Boolean);
procedure SetDefaultRunTimeoutSec(ATimeoutSec: Integer);
procedure SetDefaultBenchEnabled(AEnabled: Boolean);
procedure SetDefaultBenchTimeMs(ATimeMs: Integer);
procedure SetDefaultBenchMem(ABenchMem: Boolean);
procedure SetDefaultRunPattern(const APattern: string);
procedure SetDefaultBenchSaveFile(const AFile: string);
procedure SetDefaultBenchCompareFile(const AFile: string);
procedure SetDefaultCacheEnabled(AEnabled: Boolean);
procedure SetDefaultCacheDir(const ADir: string);
function  GetRepeatAllCount(const AConfig: TTestConfig): Integer;
function  GetSlowTestCount(const AConfig: TTestConfig): Integer;
function  GetShuffleSeed(const AConfig: TTestConfig): Integer;
function  GetFailFast(const AConfig: TTestConfig): Boolean;
function  GetListMode(const AConfig: TTestConfig): Boolean;
function  GetShortMode(const AConfig: TTestConfig): Boolean;
function  GetShowProgress(const AConfig: TTestConfig): Boolean;
function  GetMaxFailures(const AConfig: TTestConfig): Integer;
function  GetJsonOutput(const AConfig: TTestConfig): Boolean;
function  GetVerboseMode(const AConfig: TTestConfig): Boolean;
function  GetRunTimeoutSec(const AConfig: TTestConfig): Integer;
function  GetBenchEnabled(const AConfig: TTestConfig): Boolean;
function  GetBenchTimeMs(const AConfig: TTestConfig): Integer;
function  GetBenchMem(const AConfig: TTestConfig): Boolean;
function  GetRunPattern(const AConfig: TTestConfig): string;
function  GetBenchSaveFile(const AConfig: TTestConfig): string;
function  GetBenchCompareFile(const AConfig: TTestConfig): string;
function  GetCacheEnabled(const AConfig: TTestConfig): Boolean;
function  GetCacheDir(const AConfig: TTestConfig): string;

{ ── Test Cache ────────────────────────────────────────────────────────────── }

type
  TCacheEntry = record
    Status  : Integer;  { Ord(TTestStatus) }
    Message : string;
    Duration: Int64;
    Time    : Int64;    { Unix timestamp }
  end;

  TTestCache = record
    CacheDir: string;

    class function Create(const ACacheDir: string): TTestCache; static;
    function  ComputeKey(const ASources: array of string;
                const ACompilerVersion: string;
                const AConfig: TTestConfig): string;
    function  Get(const AKey: string; ATestName: string;
                out AEntry: TCacheEntry): Boolean;
    procedure Put(const AKey: string; ATestName: string;
                const AEntry: TCacheEntry);
    procedure Clean(AmaxAgeDays: Integer = 30);
    procedure Invalidate;
  end;

implementation

uses
  nextpas.core.fs;

var
  GDefaultConfig: TTestConfig;
  GExplicit: TConfigKeys;

function CreateDefaultConfig: TTestConfig;
begin
  Result.FilterPattern := '';
  Result.TagFilter := '';
  Result.TimeoutMs := 0;
  Result.AnsiMode := amAuto;
  Result.OutSink := TStdoutSink.Create;
  Result.ErrSink := TStderrSink.Create;
  Result.RetryCount := 0;
  Result.MaxParallelWorkers := 0; { unlimited by default }
  Result.RepeatAllCount := 0; { run once by default }
  Result.SlowTestCount := 5; { show top 5 slowest by default }
  Result.ShuffleSeed   := 0; { shuffle off by default }
  Result.FailFast      := False;
  Result.ListMode      := False;
  Result.ShortMode     := False;
  Result.ShowProgress  := False;
  Result.MaxFailures   := 0; { unlimited by default }
  Result.JsonOutput    := False;
  Result.VerboseMode   := False;
  Result.RunTimeoutSec := 0; { unlimited by default }
  Result.BenchEnabled  := False;
  Result.BenchTimeMs   := 1000; { default 1 second per benchmark }
  Result.BenchMem      := False;
  Result.RunPattern    := '';
  Result.BenchSaveFile := '';
  Result.BenchCompareFile := '';
  Result.CacheEnabled  := False;
  Result.CacheDir      := '.nextpas/test-cache';
end;

function DefaultConfig: TTestConfig;
begin
  Result := GDefaultConfig;
end;

function ResolveConfig(const AConfig: TTestConfig): TTestConfig;
var
  LDefaults: TTestConfig;
begin
  Result := AConfig;
  LDefaults := DefaultConfig;
  { String fields: merge if empty (zero-value check is sufficient) }
  if Result.FilterPattern = '' then
    Result.FilterPattern := LDefaults.FilterPattern;
  if Result.TagFilter = '' then
    Result.TagFilter := LDefaults.TagFilter;
  if Result.RunPattern = '' then
    Result.RunPattern := LDefaults.RunPattern;
  if Result.BenchSaveFile = '' then
    Result.BenchSaveFile := LDefaults.BenchSaveFile;
  if Result.BenchCompareFile = '' then
    Result.BenchCompareFile := LDefaults.BenchCompareFile;
  if Result.CacheDir = '' then
    Result.CacheDir := LDefaults.CacheDir;
  { Numeric fields: merge if zero (zero-value check is sufficient) }
  if Result.TimeoutMs = 0 then
    Result.TimeoutMs := LDefaults.TimeoutMs;
  if Result.RetryCount = 0 then
    Result.RetryCount := LDefaults.RetryCount;
  if Result.MaxParallelWorkers = 0 then
    Result.MaxParallelWorkers := LDefaults.MaxParallelWorkers;
  if (Result.RepeatAllCount = 0) and not (ckCount in GExplicit) then
    Result.RepeatAllCount := LDefaults.RepeatAllCount;
  if (Result.SlowTestCount = 0) and not (ckSlow in GExplicit) then
    Result.SlowTestCount := LDefaults.SlowTestCount;
  if (Result.ShuffleSeed = 0) and not (ckShuffle in GExplicit) then
    Result.ShuffleSeed := LDefaults.ShuffleSeed;
  if Result.MaxFailures = 0 then
    Result.MaxFailures := LDefaults.MaxFailures;
  if Result.RunTimeoutSec = 0 then
    Result.RunTimeoutSec := LDefaults.RunTimeoutSec;
  if Result.BenchTimeMs = 0 then
    Result.BenchTimeMs := LDefaults.BenchTimeMs;
  { Enum/interface fields: merge if default }
  if Result.AnsiMode = amAuto then
    Result.AnsiMode := LDefaults.AnsiMode;
  if Result.OutSink = nil then
    Result.OutSink := LDefaults.OutSink;
  if Result.ErrSink = nil then
    Result.ErrSink := LDefaults.ErrSink;
  { Boolean fields: merge via GExplicit (false ≠ "not set") }
  if not (ckFailFast in GExplicit) then
    Result.FailFast := Result.FailFast or LDefaults.FailFast;
  if not (ckList in GExplicit) then
    Result.ListMode := Result.ListMode or LDefaults.ListMode;
  if not (ckShort in GExplicit) then
    Result.ShortMode := Result.ShortMode or LDefaults.ShortMode;
  if not (ckProgress in GExplicit) then
    Result.ShowProgress := Result.ShowProgress or LDefaults.ShowProgress;
  if not (ckJsonOutput in GExplicit) then
    Result.JsonOutput := Result.JsonOutput or LDefaults.JsonOutput;
  if not (ckVerbose in GExplicit) then
    Result.VerboseMode := Result.VerboseMode or LDefaults.VerboseMode;
  if not (ckBench in GExplicit) then
    Result.BenchEnabled := Result.BenchEnabled or LDefaults.BenchEnabled;
  if not (ckBenchMem in GExplicit) then
    Result.BenchMem := Result.BenchMem or LDefaults.BenchMem;
  Result.CacheEnabled := Result.CacheEnabled or LDefaults.CacheEnabled;
end;

function ResolveOutSink(const AConfig: TTestConfig): IOutputSink;
begin
  Result := ResolveConfig(AConfig).OutSink;
end;

function ResolveErrSink(const AConfig: TTestConfig): IOutputSink;
begin
  Result := ResolveConfig(AConfig).ErrSink;
end;

procedure ResetDefaultConfig;
begin
  GDefaultConfig := CreateDefaultConfig;
  GExplicit := [];
end;

procedure SetDefaultFilterPattern(const APattern: string);
begin
  GDefaultConfig.FilterPattern := APattern;
  Include(GExplicit, ckFilter);
end;

procedure SetDefaultTagFilter(const APattern: string);
begin
  GDefaultConfig.TagFilter := APattern;
  Include(GExplicit, ckTag);
end;

procedure SetDefaultTimeoutMs(const ATimeoutMs: UInt64);
begin
  GDefaultConfig.TimeoutMs := ATimeoutMs;
  Include(GExplicit, ckTimeout);
end;

procedure SetDefaultAnsiMode(AAnsiMode: TAnsiMode);
begin
  GDefaultConfig.AnsiMode := AAnsiMode;
  Include(GExplicit, ckAnsi);
end;

procedure SetDefaultOutSink(const ASink: IOutputSink);
begin
  if ASink = nil then
    GDefaultConfig.OutSink := TStdoutSink.Create
  else
    GDefaultConfig.OutSink := ASink;
  Include(GExplicit, ckOutSink);
end;

procedure SetDefaultErrSink(const ASink: IOutputSink);
begin
  if ASink = nil then
    GDefaultConfig.ErrSink := TStderrSink.Create
  else
    GDefaultConfig.ErrSink := ASink;
  Include(GExplicit, ckErrSink);
end;

procedure SetDefaultRetryCount(ARetryCount: Integer);
begin
  GDefaultConfig.RetryCount := ARetryCount;
  Include(GExplicit, ckRetry);
end;

procedure SetDefaultMaxParallelWorkers(AMaxWorkers: Integer);
begin
  GDefaultConfig.MaxParallelWorkers := AMaxWorkers;
  Include(GExplicit, ckWorkers);
end;

procedure SetDefaultRepeatAllCount(ARepeatCount: Integer);
begin
  GDefaultConfig.RepeatAllCount := ARepeatCount;
  Include(GExplicit, ckCount);
end;

procedure SetDefaultSlowTestCount(ACount: Integer);
begin
  GDefaultConfig.SlowTestCount := ACount;
  Include(GExplicit, ckSlow);
end;

procedure SetDefaultShuffleSeed(ASeed: Integer);
begin
  GDefaultConfig.ShuffleSeed := ASeed;
  Include(GExplicit, ckShuffle);
end;

procedure SetDefaultFailFast(AFailFast: Boolean);
begin
  GDefaultConfig.FailFast := AFailFast;
  Include(GExplicit, ckFailFast);
end;

procedure SetDefaultListMode(AListMode: Boolean);
begin
  GDefaultConfig.ListMode := AListMode;
  Include(GExplicit, ckList);
end;

procedure SetDefaultShortMode(AShortMode: Boolean);
begin
  GDefaultConfig.ShortMode := AShortMode;
  Include(GExplicit, ckShort);
end;

procedure SetDefaultShowProgress(AShowProgress: Boolean);
begin
  GDefaultConfig.ShowProgress := AShowProgress;
  Include(GExplicit, ckProgress);
end;

procedure SetDefaultMaxFailures(AMaxFailures: Integer);
begin
  GDefaultConfig.MaxFailures := AMaxFailures;
  Include(GExplicit, ckMaxFail);
end;

procedure SetDefaultJsonOutput(AJsonOutput: Boolean);
begin
  GDefaultConfig.JsonOutput := AJsonOutput;
  Include(GExplicit, ckJsonOutput);
end;

procedure SetDefaultVerboseMode(AVerbose: Boolean);
begin
  GDefaultConfig.VerboseMode := AVerbose;
  Include(GExplicit, ckVerbose);
end;

procedure SetDefaultRunTimeoutSec(ATimeoutSec: Integer);
begin
  GDefaultConfig.RunTimeoutSec := ATimeoutSec;
  Include(GExplicit, ckRunTimeout);
end;

procedure SetDefaultBenchEnabled(AEnabled: Boolean);
begin
  GDefaultConfig.BenchEnabled := AEnabled;
  Include(GExplicit, ckBench);
end;

procedure SetDefaultBenchTimeMs(ATimeMs: Integer);
begin
  GDefaultConfig.BenchTimeMs := ATimeMs;
  Include(GExplicit, ckBenchTime);
end;

procedure SetDefaultBenchMem(ABenchMem: Boolean);
begin
  GDefaultConfig.BenchMem := ABenchMem;
  Include(GExplicit, ckBenchMem);
end;

procedure SetDefaultRunPattern(const APattern: string);
begin
  GDefaultConfig.RunPattern := APattern;
  Include(GExplicit, ckRun);
end;

procedure SetDefaultBenchSaveFile(const AFile: string);
begin
  GDefaultConfig.BenchSaveFile := AFile;
  Include(GExplicit, ckBenchSave);
end;

procedure SetDefaultBenchCompareFile(const AFile: string);
begin
  GDefaultConfig.BenchCompareFile := AFile;
  Include(GExplicit, ckBenchCompare);
end;

procedure SetDefaultCacheEnabled(AEnabled: Boolean);
begin
  GDefaultConfig.CacheEnabled := AEnabled;
end;

procedure SetDefaultCacheDir(const ADir: string);
begin
  GDefaultConfig.CacheDir := ADir;
end;

function GetRepeatAllCount(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).RepeatAllCount;
end;

function GetSlowTestCount(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).SlowTestCount;
end;

function GetShuffleSeed(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).ShuffleSeed;
end;

function GetFailFast(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).FailFast;
end;

function GetListMode(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).ListMode;
end;

function GetShortMode(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).ShortMode;
end;

function GetShowProgress(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).ShowProgress;
end;

function GetMaxFailures(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).MaxFailures;
end;

function GetJsonOutput(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).JsonOutput;
end;

function GetVerboseMode(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).VerboseMode;
end;

function GetRunTimeoutSec(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).RunTimeoutSec;
end;

function GetBenchEnabled(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).BenchEnabled;
end;

function GetBenchTimeMs(const AConfig: TTestConfig): Integer;
begin
  Result := ResolveConfig(AConfig).BenchTimeMs;
end;

function GetBenchMem(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).BenchMem;
end;

function GetRunPattern(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).RunPattern;
end;

function GetBenchSaveFile(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).BenchSaveFile;
end;

function GetBenchCompareFile(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).BenchCompareFile;
end;

function GetCacheEnabled(const AConfig: TTestConfig): Boolean;
begin
  Result := ResolveConfig(AConfig).CacheEnabled;
end;

function GetCacheDir(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).CacheDir;
end;

procedure TStdoutSink.Write(const AText: string);
begin
  System.Write(AText);
end;

procedure TStdoutSink.WriteLn(const AText: string);
begin
  System.WriteLn(AText);
end;

procedure TStdoutSink.Flush;
begin
  System.Flush(Output);
end;

procedure TStderrSink.Write(const AText: string);
begin
  System.Write(StdErr, AText);
end;

procedure TStderrSink.WriteLn(const AText: string);
begin
  System.WriteLn(StdErr, AText);
end;

procedure TStderrSink.Flush;
begin
  System.Flush(StdErr);
end;

function TBufferSink.GetLines: TStringLines;
begin
  Result := FLines;
end;

procedure TBufferSink.EnsureOpenLine;
var
  LOldLen, LCap: Integer;
begin
  if not FHasOpenLine then
  begin
    LOldLen := Length(FLines);
    LCap := FLineCap;
    if LOldLen >= LCap then
    begin
      if LCap < 8 then LCap := 8
      else LCap := LCap * 2;
      FLineCap := LCap;
      SetLength(FLines, LCap);
    end;
    SetLength(FLines, LOldLen + 1);
    FLines[LOldLen] := '';
    FHasOpenLine := True;
  end;
end;

procedure TBufferSink.Write(const AText: string);
begin
  EnsureOpenLine;
  FLines[High(FLines)] := FLines[High(FLines)] + AText;
end;

procedure TBufferSink.WriteLn(const AText: string);
begin
  EnsureOpenLine;
  FLines[High(FLines)] := FLines[High(FLines)] + AText;
  FHasOpenLine := False;
end;

procedure TBufferSink.Flush;
begin
end;

function TBufferSink.GetOutput: string;
var
  I, LTotal, LLEn, LPos: Integer;
  LLE: string;
begin
  I := Length(FLines);
  if I = 0 then
    Exit('');
  if I = 1 then
    Exit(FLines[0]);
  LLE := LineEnding;
  LLEn := Length(LLE);
  LTotal := 0;
  for I := 0 to High(FLines) do
    Inc(LTotal, Length(FLines[I]));
  Inc(LTotal, LLEn * (Length(FLines) - 1));
  SetLength(Result, LTotal);
  LPos := 1;
  I := Length(FLines[0]);
  if I > 0 then
  begin
    Move(FLines[0][1], Result[LPos], I);
    Inc(LPos, I);
  end;
  for I := 1 to High(FLines) do
  begin
    if LLEn > 0 then
    begin
      Move(LLE[1], Result[LPos], LLEn);
      Inc(LPos, LLEn);
    end;
    if Length(FLines[I]) > 0 then
    begin
      Move(FLines[I][1], Result[LPos], Length(FLines[I]));
      Inc(LPos, Length(FLines[I]));
    end;
  end;
end;

procedure TBufferSink.Clear;
begin
  FLines := nil;
  FLineCap := 0;
  FHasOpenLine := False;
end;

{ TTestConfigBuilder }

class function TTestConfigBuilder.Create: TTestConfigBuilder;
begin
  Result.FConfig := DefaultConfig;
end;

function TTestConfigBuilder.WithFilter(const APattern: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.FilterPattern := APattern;
end;

function TTestConfigBuilder.WithTag(const ATag: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.TagFilter := ATag;
end;

function TTestConfigBuilder.WithTimeout(ATimeoutMs: UInt64): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.TimeoutMs := ATimeoutMs;
end;

function TTestConfigBuilder.WithAnsiMode(AMode: TAnsiMode): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.AnsiMode := AMode;
end;

function TTestConfigBuilder.WithOutSink(const ASink: IOutputSink): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.OutSink := ASink;
end;

function TTestConfigBuilder.WithErrSink(const ASink: IOutputSink): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.ErrSink := ASink;
end;

function TTestConfigBuilder.WithRetry(ACount: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.RetryCount := ACount;
end;

function TTestConfigBuilder.WithWorkers(AWorkers: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.MaxParallelWorkers := AWorkers;
end;

function TTestConfigBuilder.WithRepeat(ACount: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.RepeatAllCount := ACount;
end;

function TTestConfigBuilder.WithSlowCount(ACount: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.SlowTestCount := ACount;
end;

function TTestConfigBuilder.WithShuffle(ASeed: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.ShuffleSeed := ASeed;
end;

function TTestConfigBuilder.WithFailFast(AFailFast: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.FailFast := AFailFast;
end;

function TTestConfigBuilder.WithListMode(AListMode: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.ListMode := AListMode;
end;

function TTestConfigBuilder.WithShortMode(AShortMode: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.ShortMode := AShortMode;
end;

function TTestConfigBuilder.WithProgress(AProgress: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.ShowProgress := AProgress;
end;

function TTestConfigBuilder.WithMaxFailures(AMax: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.MaxFailures := AMax;
end;

function TTestConfigBuilder.WithJsonOutput(AJson: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.JsonOutput := AJson;
end;

function TTestConfigBuilder.WithVerbose(AVerbose: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.VerboseMode := AVerbose;
end;

function TTestConfigBuilder.WithRunTimeout(ATimeoutSec: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.RunTimeoutSec := ATimeoutSec;
end;

function TTestConfigBuilder.WithBench(AEnabled: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.BenchEnabled := AEnabled;
end;

function TTestConfigBuilder.WithBenchTime(ATimeMs: Integer): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.BenchTimeMs := ATimeMs;
end;

function TTestConfigBuilder.WithBenchMem(AMem: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.BenchMem := AMem;
end;

function TTestConfigBuilder.WithRunPattern(const APattern: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.RunPattern := APattern;
end;

function TTestConfigBuilder.WithBenchSave(const AFile: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.BenchSaveFile := AFile;
end;

function TTestConfigBuilder.WithBenchCompare(const AFile: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.BenchCompareFile := AFile;
end;

function TTestConfigBuilder.WithCache(AEnabled: Boolean): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.CacheEnabled := AEnabled;
end;

function TTestConfigBuilder.WithCacheDir(const ADir: string): TTestConfigBuilder;
begin
  Result := Self;
  Result.FConfig.CacheDir := ADir;
end;

function TTestConfigBuilder.Build: TTestConfig;
begin
  Result := FConfig;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ TTestCache                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

class function TTestCache.Create(const ACacheDir: string): TTestCache;
begin
  Result.CacheDir := ACacheDir;
end;

function TTestCache.ComputeKey(const ASources: array of string;
  const ACompilerVersion: string; const AConfig: TTestConfig): string;
var
  LHash: UInt64;
  I, J: Integer;
  LContent: string;
begin
  { Simple hash: combine source file contents + compiler version + config flags }
  LHash := 14695981039346656037; { FNV-1a offset basis }
  for I := 0 to High(ASources) do
  begin
    if FileExists(ASources[I]) then
    begin
      LContent := ReadFileText(ASources[I]);
      { Hash each byte }
      for J := 1 to Length(LContent) do
        LHash := (LHash xor Ord(LContent[J])) * 1099511628211; { FNV-1a prime }
    end;
  end;
  { Hash compiler version }
  for I := 1 to Length(ACompilerVersion) do
    LHash := (LHash xor Ord(ACompilerVersion[I])) * 1099511628211;
  { Hash config flags that affect test behavior }
  LHash := (LHash xor Ord(AConfig.ShuffleSeed <> 0)) * 1099511628211;
  LHash := (LHash xor Ord(AConfig.ShortMode)) * 1099511628211;
  LHash := (LHash xor Ord(AConfig.VerboseMode)) * 1099511628211;
  LHash := (LHash xor Ord(AConfig.FilterPattern <> '')) * 1099511628211;
  Result := IntToHex(LHash, 16);
end;

function TTestCache.Get(const AKey: string; ATestName: string;
  out AEntry: TCacheEntry): Boolean;
var
  LDir, LFile: string;
  LLines: TStringArray;
begin
  Result := False;
  LDir := CacheDir + '/' + AKey;
  LFile := LDir + '/' + ATestName + '.cache';
  if not FileExists(LFile) then
    Exit;
  try
    LLines := ReadFileLines(LFile);
    if Length(LLines) < 3 then
      Exit;
    AEntry.Status := StrToIntDef(LLines[0], 0);
    AEntry.Message := LLines[1];
    AEntry.Duration := StrToInt64Def(LLines[2], 0);
    if Length(LLines) >= 4 then
      AEntry.Time := StrToInt64Def(LLines[3], 0)
    else
      AEntry.Time := 0;
    Result := True;
  except
    Result := False;
  end;
end;

procedure TTestCache.Put(const AKey: string; ATestName: string;
  const AEntry: TCacheEntry);
var
  LDir, LFile: string;
begin
  LDir := CacheDir + '/' + AKey;
  ForceDirectories(LDir);
  LFile := LDir + '/' + ATestName + '.cache';
  try
    WriteFileText(LFile,
      IntToStr(AEntry.Status) + LineEnding +
      AEntry.Message + LineEnding +
      IntToStr(AEntry.Duration) + LineEnding +
      IntToStr(AEntry.Time));
  except
    { Silently ignore cache write failures }
  end;
end;

procedure TTestCache.Clean(AmaxAgeDays: Integer);
begin
  { No-op: cleaning handled by caller if needed }
end;

procedure TTestCache.Invalidate;
begin
  { No-op: removal handled by caller if needed }
end;

initialization
  ResetDefaultConfig;

end.
