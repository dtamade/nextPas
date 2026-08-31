{ nextpas.core.test.runner.cli — CLI argument parsing for test runner
  =========================================================
  Pure arg parsing: no dependency on TTestSuite or TSuiteRunner.
  Depends on: nextpas.core.test.config, nextpas.core.test.output }

unit nextpas.core.test.runner.cli;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.text.conv,
  nextpas.core.test.config,
  nextpas.core.test.output;

{ ── Generic arg parsing primitives ───────────────────────────────────────── }

type
  TArgStringParser = function(const AArg: string): string;
  TArgIntParser = function(const AArg: string): Integer;
  TArgFlagChecker = function(const AArg: string): Boolean;

function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
function ExtractArgValue(const AArg, APrefix: string): string;
function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;

{ White-box helpers for test_runner: parse --filter / --tag form from one argv item. }
function ParseFilter(const AArg: string): string;
function ParseTag(const AArg: string): string;

{ Apply CLI arguments from an injectable argv list (tests / embedding).
  Does not read ParamStr. Indexing is 0-based over AArgs. }
procedure ApplyCLIArgsFrom(const AArgs: array of string);

{ Auto-detect process CLI arguments (ParamStr) and apply to global default config. }
procedure ApplyCLIArgs;

implementation

{ ── Single-arg parsers (delegate to generic primitives) ───────────────────── }

function HasArgFlag(const AArg, AFlag1: string;
  const AFlag2: string = ''): Boolean;
begin
  Result := (AArg = AFlag1) or ((AFlag2 <> '') and (AArg = AFlag2));
end;

function ExtractArgValue(const AArg, APrefix: string): string;
begin
  if Copy(AArg, 1, Length(APrefix) + 1) = APrefix + '=' then
    Result := Copy(AArg, Length(APrefix) + 2, MaxInt)
  else
    Result := '';
end;

function ExtractArgIntValue(const AArg, APrefix: string;
  ADefault: Integer): Integer;
var
  LValue: string;
begin
  LValue := ExtractArgValue(AArg, APrefix);
  if LValue = '' then
    Exit(ADefault);
  Result := StrToIntDef(LValue, ADefault);
  if Result < 0 then
    Result := 0;
end;

function ParseFilter(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--filter');
end;

function ParseTag(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--tag');
end;

function ParseCount(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--count', 0);
end;

function ParseShuffleSeed(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--shuffle-seed', 0);
end;

function IsShuffleFlag(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--shuffle', '');
end;

function IsFailFastArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--failfast', '--fail-fast');
end;

function IsListArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--list', '--list-tests');
end;

function IsShortArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--short', '-short');
end;

function IsProgressArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--progress', '-progress');
end;

function ParseMaxFailures(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--failures-max', 0);
end;

function IsJsonArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--json', '-json');
end;

function IsVerboseArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--verbose', '-v');
end;

function ParseRunTimeout(const AArg: string): Integer;
begin
  Result := ExtractArgIntValue(AArg, '--timeout', 0);
end;

function ParseBenchPattern(const AArg: string): string;
begin
  if AArg = '--bench' then
    Exit('.');  { match all benchmarks }
  if Copy(AArg, 1, 8) = '--bench=' then
    Exit(Copy(AArg, 9, MaxInt));
  Result := '';
end;

function ParseBenchTime(const AArg: string): Integer;
var
  LVal: string;
  LNum: Integer;
begin
  if Copy(AArg, 1, 12) = '--benchtime=' then
  begin
    LVal := Copy(AArg, 13, MaxInt);
    if (Length(LVal) > 1) and (LVal[Length(LVal)] = 's') then
    begin
      LNum := StrToIntDef(Copy(LVal, 1, Length(LVal) - 1), 0);
      if LNum > 0 then Exit(LNum * 1000);
    end;
    if (Length(LVal) > 2) and (Copy(LVal, Length(LVal) - 1, 2) = 'ms') then
    begin
      LNum := StrToIntDef(Copy(LVal, 1, Length(LVal) - 2), 0);
      if LNum > 0 then Exit(LNum);
    end;
    { bare number = seconds }
    LNum := StrToIntDef(LVal, 0);
    if LNum > 0 then Exit(LNum * 1000);
  end;
  Result := 0;
end;

function IsBenchMemArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--benchmem', '-benchmem');
end;

function ParseBenchSavePattern(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--benchsave');
end;

function ParseBenchComparePattern(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--benchcompare');
end;

function ParseRunPattern(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--run');
end;

function IsCacheArg(const AArg: string): Boolean;
begin
  Result := HasArgFlag(AArg, '--cache', '-cache');
end;

{ ── Injectable argv helpers (0-based open array) ─────────────────────────── }

function FindArgValueIn(
  const AArgs: array of string;
  AParseFunc: TArgStringParser;
  const ALongFlag: string
): string;
var
  K: Integer;
  LVal: string;
begin
  for K := 0 to High(AArgs) do
  begin
    LVal := AParseFunc(AArgs[K]);
    if LVal <> '' then
      Exit(LVal);
    if (AArgs[K] = ALongFlag) and (K < High(AArgs)) then
      Exit(AArgs[K + 1]);
  end;
  Result := '';
end;

function FindArgIntIn(
  const AArgs: array of string;
  AParseFunc: TArgIntParser;
  const ALongFlag: string;
  ADefault: Integer
): Integer;
var
  K: Integer;
  LVal: Integer;
begin
  for K := 0 to High(AArgs) do
  begin
    LVal := AParseFunc(AArgs[K]);
    if LVal <> 0 then
      Exit(LVal);
    if (AArgs[K] = ALongFlag) and (K < High(AArgs)) then
    begin
      Result := StrToIntDef(AArgs[K + 1], ADefault);
      if Result < 0 then Result := 0;
      Exit;
    end;
  end;
  Result := ADefault;
end;

function FindFlagInArgsList(
  const AArgs: array of string;
  AIsFlagFunc: TArgFlagChecker
): Boolean;
var
  K: Integer;
begin
  for K := 0 to High(AArgs) do
    if AIsFlagFunc(AArgs[K]) then
      Exit(True);
  Result := False;
end;

{ ── ParamStr-backed FromArgs (process CLI) ───────────────────────────────── }

function CollectParamArgs: specialize TArray<string>;
var
  K: Integer;
begin
  Result := nil;
  SetLength(Result, ParamCount);
  for K := 1 to ParamCount do
    Result[K - 1] := ParamStr(K);
end;

function ParseFilterFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseFilter, '--filter');
end;

function ParseTagFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseTag, '--tag');
end;

function ParseCountFromArgsList(const AArgs: array of string): Integer;
begin
  Result := FindArgIntIn(AArgs, @ParseCount, '--count', 0);
end;

function ParseShuffleFromArgsList(const AArgs: array of string): Integer;
begin
  if FindFlagInArgsList(AArgs, @IsShuffleFlag) then
    Exit(-1);
  Result := FindArgIntIn(AArgs, @ParseShuffleSeed, '--shuffle-seed', 0);
end;

function ParseFailFastFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsFailFastArg);
end;

function ParseListFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsListArg);
end;

function ParseShortFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsShortArg);
end;

function ParseProgressFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsProgressArg);
end;

function ParseMaxFailuresFromArgsList(const AArgs: array of string): Integer;
begin
  Result := FindArgIntIn(AArgs, @ParseMaxFailures, '--failures-max', 0);
end;

function ParseJsonFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsJsonArg);
end;

function ParseVerboseFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsVerboseArg);
end;

function ParseRunTimeoutFromArgsList(const AArgs: array of string): Integer;
begin
  Result := FindArgIntIn(AArgs, @ParseRunTimeout, '--timeout', 0);
end;

function ParseBenchFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseBenchPattern, '--bench');
end;

function ParseBenchTimeFromArgsList(const AArgs: array of string): Integer;
begin
  Result := FindArgIntIn(AArgs, @ParseBenchTime, '--benchtime', 0);
end;

function ParseBenchMemFromArgsList(const AArgs: array of string): Boolean;
begin
  Result := FindFlagInArgsList(AArgs, @IsBenchMemArg);
end;

function ParseBenchSaveFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseBenchSavePattern, '--benchsave');
end;

function ParseBenchCompareFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseBenchComparePattern, '--benchcompare');
end;

function ParseRunFromArgsList(const AArgs: array of string): string;
begin
  Result := FindArgValueIn(AArgs, @ParseRunPattern, '--run');
end;

{ ── ApplyCLIArgsFrom / ApplyCLIArgs ──────────────────────────────────────── }

procedure ApplyCLIArgsFrom(const AArgs: array of string);
var
  LCount, LShuffleSeed, LMaxFail, LRunTimeout, LBenchTime: Integer;
  LBenchPattern, LRunPattern, LBenchSave, LBenchCompare: string;
begin
  if GetTestFilter = '' then
    SetTestFilter(ParseFilterFromArgsList(AArgs));
  if GetTagFilter = '' then
    SetTagFilter(ParseTagFromArgsList(AArgs));
  if GetRunPattern(DefaultConfig) = '' then
  begin
    LRunPattern := ParseRunFromArgsList(AArgs);
    if LRunPattern <> '' then
      SetDefaultRunPattern(LRunPattern);
  end;
  if GetRepeatAllCount(DefaultConfig) = 0 then
  begin
    LCount := ParseCountFromArgsList(AArgs);
    if LCount > 0 then
      SetDefaultRepeatAllCount(LCount);
  end;
  LShuffleSeed := ParseShuffleFromArgsList(AArgs);
  if LShuffleSeed <> 0 then
    SetDefaultShuffleSeed(LShuffleSeed);
  if ParseFailFastFromArgsList(AArgs) then
    SetDefaultFailFast(True);
  if ParseListFromArgsList(AArgs) then
    SetDefaultListMode(True);
  if ParseShortFromArgsList(AArgs) then
    SetDefaultShortMode(True);
  if ParseProgressFromArgsList(AArgs) then
    SetDefaultShowProgress(True);
  LMaxFail := ParseMaxFailuresFromArgsList(AArgs);
  if LMaxFail > 0 then
    SetDefaultMaxFailures(LMaxFail);
  if ParseJsonFromArgsList(AArgs) then
    SetDefaultJsonOutput(True);
  if ParseVerboseFromArgsList(AArgs) then
    SetDefaultVerboseMode(True);
  LRunTimeout := ParseRunTimeoutFromArgsList(AArgs);
  if LRunTimeout > 0 then
    SetDefaultRunTimeoutSec(LRunTimeout);
  LBenchPattern := ParseBenchFromArgsList(AArgs);
  if LBenchPattern <> '' then
  begin
    SetDefaultBenchEnabled(True);
    SetDefaultFilterPattern(LBenchPattern);
  end;
  LBenchTime := ParseBenchTimeFromArgsList(AArgs);
  if LBenchTime > 0 then
    SetDefaultBenchTimeMs(LBenchTime);
  if ParseBenchMemFromArgsList(AArgs) then
    SetDefaultBenchMem(True);
  LBenchSave := ParseBenchSaveFromArgsList(AArgs);
  if LBenchSave <> '' then
    SetDefaultBenchSaveFile(LBenchSave);
  LBenchCompare := ParseBenchCompareFromArgsList(AArgs);
  if LBenchCompare <> '' then
    SetDefaultBenchCompareFile(LBenchCompare);
  if FindFlagInArgsList(AArgs, @IsCacheArg) then
    SetDefaultCacheEnabled(True);
end;

procedure ApplyCLIArgs;
begin
  ApplyCLIArgsFrom(CollectParamArgs);
end;

end.
