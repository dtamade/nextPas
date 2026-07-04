{ nextpas.core.test.config — TTestConfig, IOutputSink, ANSI helpers
  =========================================================
  Configuration record + output sink interface + ANSI formatting. }

unit nextpas.core.test.config;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.base;

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

implementation

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
  if Result.FilterPattern = '' then
    Result.FilterPattern := LDefaults.FilterPattern;
  if Result.TagFilter = '' then
    Result.TagFilter := LDefaults.TagFilter;
  if Result.TimeoutMs = 0 then
    Result.TimeoutMs := LDefaults.TimeoutMs;
  if Result.AnsiMode = amAuto then
    Result.AnsiMode := LDefaults.AnsiMode;
  if Result.OutSink = nil then
    Result.OutSink := LDefaults.OutSink;
  if Result.ErrSink = nil then
    Result.ErrSink := LDefaults.ErrSink;
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
  { FailFast and ListMode: false is the intentional default, no merge needed }
  if Result.RunPattern = '' then
    Result.RunPattern := LDefaults.RunPattern;
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

initialization
  ResetDefaultConfig;

end.
