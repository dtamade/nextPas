{ nextpas.core.test.config — TTestConfig, IOutputSink, ANSI helpers
  =========================================================
  Configuration record + output sink interface + ANSI formatting. }

unit nextpas.core.test.config;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

type
  TAnsiMode = (amAuto, amOn, amOff);

  TConfigKey = (ckFilter, ckTag, ckTimeout, ckAnsi,
    ckOutSink, ckErrSink, ckRetry, ckWorkers, ckCount, ckSlow,
    ckShuffle, ckFailFast, ckList);
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
function  GetRepeatAllCount(const AConfig: TTestConfig): Integer;
function  GetSlowTestCount(const AConfig: TTestConfig): Integer;
function  GetShuffleSeed(const AConfig: TTestConfig): Integer;
function  GetFailFast(const AConfig: TTestConfig): Boolean;
function  GetListMode(const AConfig: TTestConfig): Boolean;

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
begin
  if not FHasOpenLine then
  begin
    SetLength(FLines, Length(FLines) + 1);
    FLines[High(FLines)] := '';
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
  I: Integer;
begin
  if Length(FLines) = 0 then
    Exit('');
  Result := FLines[0];
  for I := 1 to High(FLines) do
    Result := Result + LineEnding + FLines[I];
end;

procedure TBufferSink.Clear;
begin
  FLines := nil;
  FHasOpenLine := False;
end;

initialization
  ResetDefaultConfig;

end.
