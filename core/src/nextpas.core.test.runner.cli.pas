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

{ Auto-detect CLI arguments and apply to global default config. }
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

function ParseRunPattern(const AArg: string): string;
begin
  Result := ExtractArgValue(AArg, '--run');
end;

{ ── FromArgs helpers (iterate ParamCount, delegate to single-arg parsers) ── }

function FindArgValue(
  AParseFunc: TArgStringParser;
  const ALongFlag: string
): string;
var
  K: Integer;
  LVal: string;
begin
  for K := 1 to ParamCount do
  begin
    LVal := AParseFunc(ParamStr(K));
    if LVal <> '' then
      Exit(LVal);
    if (ParamStr(K) = ALongFlag) and (K < ParamCount) then
      Exit(ParamStr(K + 1));
  end;
  Result := '';
end;

function FindArgInt(
  AParseFunc: TArgIntParser;
  const ALongFlag: string;
  ADefault: Integer
): Integer;
var
  K: Integer;
  LVal: Integer;
begin
  for K := 1 to ParamCount do
  begin
    LVal := AParseFunc(ParamStr(K));
    if LVal <> 0 then
      Exit(LVal);
    if (ParamStr(K) = ALongFlag) and (K < ParamCount) then
    begin
      Result := StrToIntDef(ParamStr(K + 1), ADefault);
      if Result < 0 then Result := 0;
      Exit;
    end;
  end;
  Result := ADefault;
end;

function FindFlagInArgs(
  AIsFlagFunc: TArgFlagChecker
): Boolean;
var
  K: Integer;
begin
  for K := 1 to ParamCount do
    if AIsFlagFunc(ParamStr(K)) then
      Exit(True);
  Result := False;
end;

function ParseFilterFromArgs: string;
begin
  Result := FindArgValue(@ParseFilter, '--filter');
end;

function ParseTagFromArgs: string;
begin
  Result := FindArgValue(@ParseTag, '--tag');
end;

function ParseCountFromArgs: Integer;
begin
  Result := FindArgInt(@ParseCount, '--count', 0);
end;

function ParseShuffleFromArgs: Integer;
begin
  if FindFlagInArgs(@IsShuffleFlag) then
    Exit(-1);
  Result := FindArgInt(@ParseShuffleSeed, '--shuffle-seed', 0);
end;

function ParseFailFastFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsFailFastArg);
end;

function ParseListFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsListArg);
end;

function ParseShortFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsShortArg);
end;

function ParseProgressFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsProgressArg);
end;

function ParseMaxFailuresFromArgs: Integer;
begin
  Result := FindArgInt(@ParseMaxFailures, '--failures-max', 0);
end;

function ParseJsonFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsJsonArg);
end;

function ParseVerboseFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsVerboseArg);
end;

function ParseRunTimeoutFromArgs: Integer;
begin
  Result := FindArgInt(@ParseRunTimeout, '--timeout', 0);
end;

function ParseBenchFromArgs: string;
begin
  Result := FindArgValue(@ParseBenchPattern, '--bench');
end;

function ParseBenchTimeFromArgs: Integer;
begin
  Result := FindArgInt(@ParseBenchTime, '--benchtime', 0);
end;

function ParseBenchMemFromArgs: Boolean;
begin
  Result := FindFlagInArgs(@IsBenchMemArg);
end;

function ParseRunFromArgs: string;
begin
  Result := FindArgValue(@ParseRunPattern, '--run');
end;

{ ── ApplyCLIArgs ─────────────────────────────────────────────────────────── }

procedure ApplyCLIArgs;
var
  LCount, LShuffleSeed, LMaxFail, LRunTimeout, LBenchTime: Integer;
  LBenchPattern, LRunPattern: string;
begin
  if GetTestFilter = '' then
    SetTestFilter(ParseFilterFromArgs);
  if GetTagFilter = '' then
    SetTagFilter(ParseTagFromArgs);
  if GetRunPattern(DefaultConfig) = '' then
  begin
    LRunPattern := ParseRunFromArgs;
    if LRunPattern <> '' then
      SetDefaultRunPattern(LRunPattern);
  end;
  if GetRepeatAllCount(DefaultConfig) = 0 then
  begin
    LCount := ParseCountFromArgs;
    if LCount > 0 then
      SetDefaultRepeatAllCount(LCount);
  end;
  LShuffleSeed := ParseShuffleFromArgs;
  if LShuffleSeed <> 0 then
    SetDefaultShuffleSeed(LShuffleSeed);
  if ParseFailFastFromArgs then
    SetDefaultFailFast(True);
  if ParseListFromArgs then
    SetDefaultListMode(True);
  if ParseShortFromArgs then
    SetDefaultShortMode(True);
  if ParseProgressFromArgs then
    SetDefaultShowProgress(True);
  LMaxFail := ParseMaxFailuresFromArgs;
  if LMaxFail > 0 then
    SetDefaultMaxFailures(LMaxFail);
  if ParseJsonFromArgs then
    SetDefaultJsonOutput(True);
  if ParseVerboseFromArgs then
    SetDefaultVerboseMode(True);
  LRunTimeout := ParseRunTimeoutFromArgs;
  if LRunTimeout > 0 then
    SetDefaultRunTimeoutSec(LRunTimeout);
  LBenchPattern := ParseBenchFromArgs;
  if LBenchPattern <> '' then
  begin
    SetDefaultBenchEnabled(True);
    SetDefaultFilterPattern(LBenchPattern);
  end;
  LBenchTime := ParseBenchTimeFromArgs;
  if LBenchTime > 0 then
    SetDefaultBenchTimeMs(LBenchTime);
  if ParseBenchMemFromArgs then
    SetDefaultBenchMem(True);
end;

end.
