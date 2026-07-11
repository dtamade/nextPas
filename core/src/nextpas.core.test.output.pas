{ nextpas.core.test.output — ANSI helpers, test filter, JUnit XML, StatusDot
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.output;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.atomic,
  nextpas.core.platform.env,
  nextpas.core.platform.console,
  nextpas.core.test.base,
  nextpas.core.test.config,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.fs;

{ ── ANSI helpers ──────────────────────────────────────────────────────────── }

function AnsiBold(const S: string): string; overload;
function AnsiBold(const S: string; const AConfig: TTestConfig): string; overload;
function AnsiGreen(const S: string): string; overload;
function AnsiGreen(const S: string; const AConfig: TTestConfig): string; overload;
function AnsiRed(const S: string): string; overload;
function AnsiRed(const S: string; const AConfig: TTestConfig): string; overload;
function AnsiYellow(const S: string): string; overload;
function AnsiYellow(const S: string; const AConfig: TTestConfig): string; overload;
function AnsiCyan(const S: string): string; overload;
function AnsiCyan(const S: string; const AConfig: TTestConfig): string; overload;
function AnsiDim(const S: string): string; overload;
function AnsiDim(const S: string; const AConfig: TTestConfig): string; overload;
procedure SetAnsiEnabled(AEnabled: Boolean);

{ ── StatusDot ─────────────────────────────────────────────────────────────── }

function StatusDot(AStatus: TTestStatus): string; overload;
function StatusDot(AStatus: TTestStatus; const AConfig: TTestConfig): string; overload;

{ ── FormatStatusLine ──────────────────────────────────────────────────────── }
{ Assembles "StatusDot + name" with proper ANSI coloring.
  Indentation is the caller's responsibility. }

function FormatStatusLine(AStatus: TTestStatus; const AName: string;
  const AConfig: TTestConfig): string; overload;
function FormatStatusLine(AStatus: TTestStatus; const AName: string;
  const AReason: string; const AConfig: TTestConfig): string; overload;

{ ── FormatFailDetail ──────────────────────────────────────────────────────── }
{ Returns the indented failure detail line: AnsiRed(msg) or AnsiRed('(assertion failed)')
  if msg is empty. }

function FormatFailDetail(const AMsg: string;
  const AConfig: TTestConfig): string;

{ Print captured log lines (from Ctx.Log) in a visually distinct block.
  Used on test failure to show diagnostic output without --verbose. }

procedure WriteCapturedLog(const ALines: specialize TArray<string>;
  const ASink: IOutputSink; const AConfig: TTestConfig);

{ ── Meta-Test Helpers (for test programs that verify the framework) ───────── }

procedure FailTest(const AMsg: string);
  { Print red 'FAIL: ...' message and Halt(1). For meta-tests that run outside
    the framework and cannot use Check* assertions. }
procedure PassTest(const AMsg: string);
  { Print green 'OK: ...' message. Companion to FailTest. }
procedure SectionHeader(const ATitle: string);
  { Print bold '─── Title ───' section separator. }

{ ── Per-Test Output ───────────────────────────────────────────────────────── }

procedure WriteTestStatus(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write formatted per-test status line to ASink. Shows timing for non-zero durations. }
procedure WriteTestStatusVerbose(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write verbose per-test status line with duration to ASink. }
procedure WriteTestOutput(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Dispatch to WriteTestStatusVerbose or WriteTestStatus based on config. }

{ ── Diagnostic Output ─────────────────────────────────────────────────────── }

procedure WriteRetryHint(ACurrent, ATotal: Integer;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write yellow 'retrying (N/M)...' hint to ASink. }
procedure WriteWarning(const AMsg: string;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write yellow 'WARNING: ...' to ASink (2-space indent). }
procedure WriteSuiteHeader(const AName, ASuffix: string;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write blank line + bold '> Name (suffix)' suite header to ASink. }
procedure WriteSuiteHeaderEx(const AName: string; ATestCount: Integer;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Enhanced suite header with test count: '> SuiteName (15 tests)' }
procedure WriteSlowTests(const ASlowTests: TTestResults;
  const ASink: IOutputSink; const AConfig: TTestConfig);
  { Write slow test report: '  Slowest tests:' followed by top N entries. }
function FormatDuration(AMillis: Int64): string;
  { Format milliseconds as '12ms' or '1.23s' for >= 1000ms. }

{ ── Benchmark Output ─────────────────────────────────────────────────────── }

function FormatBenchLine(const AR: nextpas.core.test.base.TBenchResult;
  AShowMem: Boolean; const AConfig: TTestConfig): string;
  { Format a single benchmark result line.
    Output: '  BenchmarkName  1000000  3.2 ns/op  48 B/op  1 allocs/op' }

{ ── Test Filter ───────────────────────────────────────────────────────────── }

procedure SetTestFilter(const APattern: string);
function  GetTestFilter: string; overload;
function  GetTestFilter(const AConfig: TTestConfig): string; overload;
function  MatchesFilter(const AName: string): Boolean; overload;
function  MatchesFilter(const AName: string; const AConfig: TTestConfig): Boolean; overload;

{ ── Tag Filter ───────────────────────────────────────────────────────────── }

procedure SetTagFilter(const APattern: string);
function  GetTagFilter: string; overload;
function  GetTagFilter(const AConfig: TTestConfig): string; overload;

{ ── Test Timeout ──────────────────────────────────────────────────────────── }

procedure SetTestTimeout(AMillis: Integer);
function  GetTestTimeout: Integer; overload;
function  GetTestTimeout(const AConfig: TTestConfig): Integer; overload;

{ ── JUnit XML output ─────────────────────────────────────────────────────── }

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;
function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string = ''): Boolean;

{ ── Leak reporting ────────────────────────────────────────────────────────── }

procedure ReportLeakIfAny(AStatus: TTestStatus); overload;
procedure ReportLeakIfAny(AStatus: TTestStatus; const AConfig: TTestConfig); overload;

{ ── Utility helpers ───────────────────────────────────────────────────────── }

procedure AddLine(var ALines: specialize TArray<string>; const ALine: string);
function JoinLines(const ALines: specialize TArray<string>): string;
function CountFailed(const AResults: specialize TArray<TTestRunResult>): Integer;
function CountSkipped(const AResults: specialize TArray<TTestRunResult>): Integer;

implementation

{ Local wrapper: platform_env_get_str returns '' for missing vars }
function GetEnv(const AName: string): string;
begin
  Result := string(platform_env_get_str(AnsiString(AName)));
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ ANSI Helpers                                                                 }
{ ═════════════════════════════════════════════════════════════════════════════ }

const
  ESC     = #27'[';
  C_RESET = ESC + '0m';
  C_BOLD  = ESC + '1m';
  C_GREEN = ESC + '32m';
  C_RED   = ESC + '31m';
  C_YELLOW= ESC + '33m';
  C_CYAN  = ESC + '36m';
  C_DIM   = ESC + '2m';

var
  { Thread-safety: SetAnsiEnabled must be called BEFORE spawning worker threads.
    After that, GAnsiEnabled/GAnsiChecked are only read (via InitAnsi/Wrap).
    Using TAtomicBool for ARM safety — plain Boolean is safe on x86-64 TSO
    but ARM has weaker memory ordering. }
  GAnsiEnabled: TAtomicBool;
  GAnsiChecked: TAtomicBool;

procedure InitAnsi;
var
  LExpected: Boolean;
begin
  { P1 #7 fix: use CAS to prevent double initialization by parallel workers }
  LExpected := False;
  if not GAnsiChecked.CompareExchangeStrong(LExpected, True) then
    Exit;  { already initialized by another thread }
  { Standard: https://no-color.org/ }
  if GetEnv('NO_COLOR') <> '' then
  begin
    GAnsiEnabled.Store(False, mo_release);
    Exit;
  end;
    {$IFDEF NEXTPAS_LINUX}
    { Enable ANSI if stdout is a TTY (terminal).
      When piped to a file or non-TTY, disable to avoid escape sequences. }
    GAnsiEnabled.Store(platform_console_is_terminal(1), mo_release);
    {$ELSE}
    GAnsiEnabled.Store(
      (GetEnv('TERM') <> '') or
      (GetEnv('ANSICON') <> '') or
      (GetEnv('ConEmuANSI') = 'ON') or
      (GetEnv('WT_SESSION') <> ''), mo_release);
    {$ENDIF}
    { Override via NEXTPAS_COLOR: '1' forces on, '0' forces off }
    if GetEnv('NEXTPAS_COLOR') = '1' then
      GAnsiEnabled.Store(True, mo_release)
    else if GetEnv('NEXTPAS_COLOR') = '0' then
      GAnsiEnabled.Store(False, mo_release);
end;

function UseAnsi(const AConfig: TTestConfig): Boolean;
var
  LConfig: TTestConfig;
begin
  LConfig := ResolveConfig(AConfig);
  case LConfig.AnsiMode of
    amOn:  Exit(True);
    amOff: Exit(False);
    amAuto: ; { fall through to auto-detect }
  end;
  InitAnsi;
  Result := GAnsiEnabled.Load(mo_relaxed);
end;

function Wrap(const ACode, S: string; const AConfig: TTestConfig): string; overload;
begin
  if UseAnsi(AConfig) then
    Result := ACode + S + C_RESET
  else
    Result := S;
end;

function Wrap(const ACode, S: string): string; overload;
begin
  Result := Wrap(ACode, S, DefaultConfig);
end;

function AnsiBold(const S: string): string;
begin
  Result := Wrap(C_BOLD, S);
end;

function AnsiBold(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_BOLD, S, AConfig);
end;

function AnsiGreen(const S: string): string;
begin
  Result := Wrap(C_GREEN, S);
end;

function AnsiGreen(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_GREEN, S, AConfig);
end;

function AnsiRed(const S: string): string;
begin
  Result := Wrap(C_RED, S);
end;

function AnsiRed(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_RED, S, AConfig);
end;

function AnsiYellow(const S: string): string;
begin
  Result := Wrap(C_YELLOW, S);
end;

function AnsiYellow(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_YELLOW, S, AConfig);
end;

function AnsiCyan(const S: string): string;
begin
  Result := Wrap(C_CYAN, S);
end;

function AnsiCyan(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_CYAN, S, AConfig);
end;

function AnsiDim(const S: string): string;
begin
  Result := Wrap(C_DIM, S);
end;

function AnsiDim(const S: string; const AConfig: TTestConfig): string;
begin
  Result := Wrap(C_DIM, S, AConfig);
end;

procedure SetAnsiEnabled(AEnabled: Boolean);
begin
  GAnsiEnabled.Store(AEnabled, mo_release);
  GAnsiChecked.Store(True, mo_release); { prevent InitAnsi from overwriting }
  if AEnabled then
    SetDefaultAnsiMode(amOn)
  else
    SetDefaultAnsiMode(amOff);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ StatusDot                                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

function StatusDot(AStatus: TTestStatus; const AConfig: TTestConfig): string;
begin
  if not UseAnsi(AConfig) then
  begin
    case AStatus of
      tsPassed:  Result := '+';
      tsFailed:  Result := 'x';
      tsSkipped: Result := 'o';
      tsError:   Result := '!';
    end;
    Exit;
  end;

  case AStatus of
    tsPassed:  Result := AnsiGreen(#$E2#$9C#$93, AConfig);
    tsFailed:  Result := AnsiRed(#$E2#$9C#$97, AConfig);
    tsSkipped: Result := AnsiYellow(#$E2#$97#$8B, AConfig);
    tsError:   Result := AnsiRed('!', AConfig);
  end;
end;

function StatusDot(AStatus: TTestStatus): string;
begin
  Result := StatusDot(AStatus, DefaultConfig);
end;

{ FormatStatusLine — 2-param: name only }

function FormatStatusLine(AStatus: TTestStatus; const AName: string;
  const AConfig: TTestConfig): string;
begin
  case AStatus of
    tsPassed:  Result := StatusDot(AStatus, AConfig) + ' ' + AName;
    tsFailed:  Result := StatusDot(AStatus, AConfig) + ' ' + AnsiRed(AName, AConfig);
    tsSkipped: Result := StatusDot(AStatus, AConfig) + ' ' + AnsiDim(AName, AConfig);
    tsError:   Result := StatusDot(AStatus, AConfig) + ' ' + AnsiRed(AName, AConfig);
  end;
end;

{ FormatStatusLine — 3-param: name + suffix (skip reason, error tag, etc.) }

function FormatStatusLine(AStatus: TTestStatus; const AName: string;
  const AReason: string; const AConfig: TTestConfig): string;
begin
  Result := FormatStatusLine(AStatus, AName, AConfig) + ' -- ' + AReason;
end;

{ FormatFailDetail — failure message with assertion-failed fallback }

function FormatFailDetail(const AMsg: string; const AConfig: TTestConfig): string;
var
  LBracketPos, LColonPos: Integer;
  LMsg, LTrace: string;
begin
  if AMsg = '' then
    Exit(AnsiRed('(assertion failed)', AConfig));
  { Extract [file:line] trace appended by AppendTestTrace.
    Pattern: 'message [file:line]' — find last ' [' and split.
    P2 #20 fix: validate that trace contains ':' (file:line pattern) to avoid
    misclassifying brackets in assertion messages like "Expected [1] got [2]". }
  LBracketPos := Length(AMsg) - 1;
  while (LBracketPos > 1) and not ((AMsg[LBracketPos] = ' ') and (AMsg[LBracketPos + 1] = '[')) do
    Dec(LBracketPos);
  if LBracketPos > 1 then
  begin
    LTrace := Copy(AMsg, LBracketPos + 1, MaxInt);
    { Validate trace looks like [file:line] — must contain ':' and end with ']' }
    LColonPos := Pos(':', LTrace);
    if (LColonPos > 2) and (Length(LTrace) > 2) and
       (LTrace[Length(LTrace)] = ']') and
       (LColonPos < Length(LTrace) - 1) then
    begin
      LMsg := Copy(AMsg, 1, LBracketPos - 1);
      Result := AnsiRed(LMsg, AConfig) + #10 +
        '    ' + AnsiDim(LTrace, AConfig);
    end
    else
      Result := AnsiRed(AMsg, AConfig);
  end
  else
    Result := AnsiRed(AMsg, AConfig);
end;

{ WriteCapturedLog — print captured log lines on failure/error }

procedure WriteCapturedLog(const ALines: specialize TArray<string>;
  const ASink: IOutputSink; const AConfig: TTestConfig);
var
  I: Integer;
begin
  if Length(ALines) = 0 then Exit;
  ASink.WriteLn('  ' + AnsiDim('─── test log ───', AConfig));
  for I := 0 to High(ALines) do
    ASink.WriteLn('  ' + AnsiDim(ALines[I], AConfig));
  ASink.WriteLn('  ' + AnsiDim('─────────────────', AConfig));
end;

{ Meta-Test Helpers }

procedure FailTest(const AMsg: string);
begin
  WriteLn(AnsiRed('FAIL: ' + AMsg));
  Halt(1);
end;

procedure PassTest(const AMsg: string);
begin
  WriteLn(AnsiGreen('OK: ' + AMsg));
end;

procedure SectionHeader(const ATitle: string);
begin
  WriteLn(AnsiBold('─── ' + ATitle + ' ───'));
end;

function ResolveSkipReason(const ASkipReason, AFailMsg: string): string;
{ Priority: ASkipReason > AFailMsg > '' }
begin
  if ASkipReason <> '' then
    Result := ASkipReason
  else if AFailMsg <> '' then
    Result := AFailMsg
  else
    Result := '';
end;

procedure WriteTestStatus(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
var
  LDurStr: string;
begin
  if ADurationMs > 0 then
    LDurStr := AnsiDim(' (' + FormatDuration(ADurationMs) + ')', AConfig)
  else
    LDurStr := '';
  case AStatus of
    tsPassed:
      ASink.WriteLn('  ' + FormatStatusLine(tsPassed, AName, AConfig) + LDurStr);
    tsFailed:
      begin
        ASink.WriteLn('  ' + FormatStatusLine(tsFailed, AName, AConfig) + LDurStr);
        ASink.WriteLn('    ' + FormatFailDetail(AFailMsg, AConfig));
      end;
    tsSkipped:
      ASink.WriteLn('  ' + FormatStatusLine(tsSkipped, AName,
        ResolveSkipReason(ASkipReason, AFailMsg), AConfig));
    tsError:
      begin
        ASink.WriteLn('  ' + FormatStatusLine(tsError, AName, AConfig) +
          LDurStr + ' [unexpected exception]');
        if AFailMsg <> '' then
          ASink.WriteLn('    ' + FormatFailDetail(AFailMsg, AConfig));
      end;
  end;
end;

procedure WriteTestStatusVerbose(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
{ Verbose mode: show every test with status + duration.
  Format: '  [PASS] name (12ms)' or '  [FAIL] name (1.23s)' or '  [SKIP] name - reason'. }
var
  LDurStr, LSkipMsg: string;
begin
  LDurStr := ' (' + FormatDuration(ADurationMs) + ')';
  case AStatus of
    tsPassed:
      ASink.WriteLn('  ' + AnsiGreen('[PASS]', AConfig) + ' ' +
        AName + AnsiDim(LDurStr, AConfig));
    tsFailed:
      begin
        ASink.WriteLn('  ' + AnsiRed('[FAIL]', AConfig) + ' ' +
          AName + AnsiDim(LDurStr, AConfig));
        ASink.WriteLn('    ' + FormatFailDetail(AFailMsg, AConfig));
      end;
    tsSkipped:
      begin
        LSkipMsg := ResolveSkipReason(ASkipReason, AFailMsg);
        if LSkipMsg <> '' then
          ASink.WriteLn('  ' + AnsiYellow('[SKIP]', AConfig) + ' ' +
            AName + ' - ' + LSkipMsg)
        else
          ASink.WriteLn('  ' + AnsiYellow('[SKIP]', AConfig) + ' ' + AName);
      end;
    tsError:
      begin
        ASink.WriteLn('  ' + AnsiRed('[FAIL]', AConfig) + ' ' +
          AName + AnsiDim(LDurStr, AConfig) + ' [unexpected exception]');
        if AFailMsg <> '' then
          ASink.WriteLn('    ' + FormatFailDetail(AFailMsg, AConfig));
      end;
  end;
end;

procedure WriteTestOutput(AStatus: TTestStatus; const AName, AFailMsg,
  ASkipReason: string; ADurationMs: Int64;
  const ASink: IOutputSink; const AConfig: TTestConfig);
begin
  if AConfig.VerboseMode then
    WriteTestStatusVerbose(AStatus, AName, AFailMsg, ASkipReason,
      ADurationMs, ASink, AConfig)
  else
    WriteTestStatus(AStatus, AName, AFailMsg, ASkipReason,
      ADurationMs, ASink, AConfig);
end;

procedure WriteRetryHint(ACurrent, ATotal: Integer;
  const ASink: IOutputSink; const AConfig: TTestConfig);
begin
  ASink.WriteLn(
    '  ' + AnsiYellow('retrying', AConfig) + ' (' +
    IntToStr(ACurrent) + '/' + IntToStr(ATotal) + ')...');
end;

procedure WriteWarning(const AMsg: string;
  const ASink: IOutputSink; const AConfig: TTestConfig);
begin
  ASink.WriteLn('  ' + AnsiYellow('WARNING ', AConfig) + AMsg);
end;

procedure WriteSuiteHeader(const AName, ASuffix: string;
  const ASink: IOutputSink; const AConfig: TTestConfig);
begin
  ASink.WriteLn('');
  ASink.WriteLn(
    AnsiBold('> ', AConfig) +
    AnsiCyan(AName, AConfig) +
    AnsiDim(' (' + ASuffix + ')', AConfig));
end;

procedure WriteSuiteHeaderEx(const AName: string; ATestCount: Integer;
  const ASink: IOutputSink; const AConfig: TTestConfig);
var
  LSuffix: string;
begin
  if ATestCount <= 0 then Exit;
  if ATestCount = 1 then
    LSuffix := '1 test'
  else
    LSuffix := IntToStr(ATestCount) + ' tests';
  ASink.WriteLn('');
  ASink.WriteLn(
    AnsiBold('> ', AConfig) +
    AnsiCyan(AName, AConfig) +
    AnsiDim(' (' + LSuffix + ')', AConfig));
end;

function FormatDuration(AMillis: Int64): string;
var
  LMs: Integer;
begin
  if AMillis < 1000 then
    Result := IntToStr(AMillis) + 'ms'
  else
  begin
    LMs := AMillis mod 1000;
    if LMs = 0 then
      Result := IntToStr(AMillis div 1000) + 's'
    else if LMs mod 100 = 0 then
      Result := IntToStr(AMillis div 1000) + '.' + IntToStr(LMs div 100) + 's'
    else
      Result := IntToStr(AMillis div 1000) + '.' +
        Copy(IntToStr(1000 + LMs), 2, 2) + 's';
  end;
end;

function FormatBenchLine(const AR: nextpas.core.test.base.TBenchResult;
  AShowMem: Boolean; const AConfig: TTestConfig): string;
{ Format: '  BenchmarkName  1000000  3.2 ns/op  48 B/op  1 allocs/op' }
var
  LNsOp: string;
begin
  { Format ns/op with appropriate unit }
  if AR.NsPerOp >= 1000000000 then
    LNsOp := FormatFloat('0.00', AR.NsPerOp / 1000000000.0) + ' s/op'
  else if AR.NsPerOp >= 1000000 then
    LNsOp := FormatFloat('0.00', AR.NsPerOp / 1000000.0) + ' ms/op'
  else if AR.NsPerOp >= 1000 then
    LNsOp := FormatFloat('0.00', AR.NsPerOp / 1000.0) + ' us/op'
  else
    LNsOp := IntToStr(AR.NsPerOp) + ' ns/op';
  Result := '  ' + AnsiCyan(AR.Name, AConfig) + '  ' +
    AnsiBold(IntToStr(AR.N), AConfig) + '  ' +
    AnsiGreen(LNsOp, AConfig);
  if AShowMem then
    Result := Result + '  ' + IntToStr(AR.AllocBytes) + ' B/op' +
      '  ' + IntToStr(AR.AllocCount) + ' allocs/op';
end;

procedure WriteSlowTests(const ASlowTests: TTestResults;
  const ASink: IOutputSink; const AConfig: TTestConfig);
var
  I: Integer;
begin
  if Length(ASlowTests) = 0 then Exit;
  ASink.WriteLn('');
  ASink.WriteLn(AnsiDim('  Slowest tests:', AConfig));
  for I := 0 to High(ASlowTests) do
    ASink.WriteLn(
      AnsiDim('    ' + FormatDuration(ASlowTests[I].Duration) +
        '  ' + ASlowTests[I].Name, AConfig));
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Test Filter & Timeout (public API)                                          }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure SetTestFilter(const APattern: string);
begin
  SetDefaultFilterPattern(APattern);
end;

function GetTestFilter: string;
begin
  Result := GetTestFilter(DefaultConfig);
end;

function GetTestFilter(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).FilterPattern;
end;

procedure SetTestTimeout(AMillis: Integer);
begin
  if AMillis < 0 then
    SetDefaultTimeoutMs(0)
  else
    SetDefaultTimeoutMs(UInt64(AMillis));
end;

function GetTestTimeout: Integer;
begin
  Result := GetTestTimeout(DefaultConfig);
end;

function GetTestTimeout(const AConfig: TTestConfig): Integer;
var
  LTimeoutMs: UInt64;
begin
  LTimeoutMs := ResolveConfig(AConfig).TimeoutMs;
  if LTimeoutMs > UInt64(High(Integer)) then
    Result := High(Integer)
  else
    Result := Integer(LTimeoutMs);
end;

{ ── Glob matching (internal) ───────────────────────────────────────────────── }

{ ── Glob matching helpers ────────────────────────────────────────────────── }

{ BuildAlt: construct a pattern string by concatenating three segments.
  P2 #4: wraps the Copy+Copy+Copy pattern in a single function for clarity.
  Future optimization: replace with SetLength+Move for single allocation. }
function BuildAlt(const ASrc1: string; AStart1, ALen1: Integer;
                  const ASrc2: string; AStart2, ALen2: Integer;
                  const ASrc3: string; AStart3, ALen3: Integer): string;
begin
  Result := Copy(ASrc1, AStart1, ALen1) +
            Copy(ASrc2, AStart2, ALen2) +
            Copy(ASrc3, AStart3, ALen3);
end;

function MatchesGlob(const AName, APattern: string; ADepth: Integer = 0): Boolean;
{ Iterative backtracking glob matcher with brace expansion support.
  Handles '*', '?', and brace groups (alt1,alt2,...).
  Brace groups can be nested. ADepth prevents stack overflow on deep nesting. }
var
  I, J, LStarI, LStarJ, LDepth, LStart, LEnd: Integer;
  LAlt: string;
begin
  { P1 #9 fix: depth guard to prevent stack overflow on malicious brace patterns }
  if ADepth > 20 then
    Exit(False);
  { ── Brace expansion ─────────────────────────────────────────────────────── }
  I := 1;
  while I <= Length(APattern) do
  begin
    if APattern[I] = '{' then
    begin
      (* Find matching '}' with nesting depth tracking *)
      LDepth := 1;
      J := I + 1;
      while (J <= Length(APattern)) and (LDepth > 0) do
      begin
        if APattern[J] = '{' then Inc(LDepth)
        else if APattern[J] = '}' then Dec(LDepth);
        Inc(J);
      end;
      if LDepth <> 0 then
        Break; (* unmatched brace — treat as literal *)
      LEnd := J - 1; (* position of '}' *)
      (* Try each comma-separated alternative inside the braces *)
      LStart := I + 1;
      J := LStart;
      while J <= LEnd do
      begin
        if APattern[J] = ',' then
        begin
          { Top-level comma: build alternative via BuildAlt helper }
          LAlt := BuildAlt(APattern, 1, I - 1,
                           APattern, LStart, J - LStart,
                           APattern, LEnd + 1, Length(APattern));
          if MatchesGlob(AName, LAlt, ADepth + 1) then
            Exit(True);
          LStart := J + 1;
        end
        else if APattern[J] = '{' then
        begin
          { Skip nested brace group }
          LDepth := 1;
          Inc(J);
          while (J <= LEnd) and (LDepth > 0) do
          begin
            if APattern[J] = '{' then Inc(LDepth)
            else if APattern[J] = '}' then Dec(LDepth);
            Inc(J);
          end;
          Continue;
        end;
        Inc(J);
      end;
      { Try last alternative: build via BuildAlt helper }
      LAlt := BuildAlt(APattern, 1, I - 1,
                       APattern, LStart, LEnd - LStart,
                       APattern, LEnd + 1, Length(APattern));
      Exit(MatchesGlob(AName, LAlt, ADepth + 1));
    end;
    Inc(I);
  end;

  { ── Core glob matching (iterative backtracking) ─────────────────────────── }
  I := 1; J := 1;
  LStarI := 0; LStarJ := 0;
  while I <= Length(AName) do
  begin
    if (J <= Length(APattern)) and (APattern[J] = '*') then
    begin
      { Save backtrack point: star matches zero characters initially }
      LStarI := I;
      LStarJ := J;
      Inc(J); { skip the star in pattern }
    end
    else if (J <= Length(APattern)) and
            ((APattern[J] = '?') or (AName[I] = APattern[J])) then
    begin
      Inc(I); Inc(J);
    end
    else if LStarJ > 0 then
    begin
      { Backtrack: let the star match one more character }
      Inc(LStarI);
      I := LStarI;
      J := LStarJ + 1; { pattern after the star }
    end
    else
      Exit(False);
  end;
  { Skip remaining stars in pattern }
  while (J <= Length(APattern)) and (APattern[J] = '*') do Inc(J);
  Result := J > Length(APattern);
end;

function SplitPathSegment(const APath: string; AStart: Integer;
  out ASegment: string): Integer;
{ Extract segment from APath starting at AStart up to next '/'.
  Returns position after '/' or past-end if no more segments. }
var
  LSlash: Integer;
begin
  LSlash := Pos('/', Copy(APath, AStart, MaxInt));
  if LSlash > 0 then
  begin
    ASegment := Copy(APath, AStart, LSlash - 1);
    Result := AStart + LSlash;
  end
  else
  begin
    ASegment := Copy(APath, AStart, MaxInt);
    Result := Length(APath) + 1;
  end;
end;

function MatchesHierarchical(const AName, AFilter: string): Boolean;
{ Hierarchical filter matching (Go-style -run TestParent/SubA).
  Rules:
    1. Filter is prefix of name: matches parent + all descendants.
       "P/S" matches "P/S" and "P/S/L" and "P/S/L/X"
    2. Name is prefix of filter: matches parent so it can enter children.
       "P" matches filter "P/S" (P must run to test P/S)
    3. Segment-level glob matching: "P/*" matches "P/anything" }
var
  LNameSeg, LFilterSeg: string;
  LNamePos, LFilterPos: Integer;
  LMatchedSegments: Integer;
begin
  Result := False;
  LNamePos := 1;
  LFilterPos := 1;
  LMatchedSegments := 0;

  while (LNamePos <= Length(AName)) and (LFilterPos <= Length(AFilter)) do
  begin
    LNamePos := SplitPathSegment(AName, LNamePos, LNameSeg);
    LFilterPos := SplitPathSegment(AFilter, LFilterPos, LFilterSeg);

    { Glob match on this segment }
    if MatchesGlob(LNameSeg, LFilterSeg) then
      Inc(LMatchedSegments)
    else
      Exit(False);
  end;

  { At least one segment matched. Either:
    - Both exhausted (exact match)
    - Name exhausted, filter has more (name is prefix — parent matches)
    - Filter exhausted, name has more (filter is prefix — descendant matches) }
  Result := LMatchedSegments > 0;
end;

function MatchesFilter(const AName: string; const AConfig: TTestConfig): Boolean;
var
  LFilter, LPattern: string;
  LComma, LDepth, LPos: Integer;
begin
  { --run: exact name match (case-insensitive) takes priority }
  if GetRunPattern(AConfig) <> '' then
    Exit(SameText(AName, GetRunPattern(AConfig)));
  LFilter := GetTestFilter(AConfig);
  if LFilter = '' then
    Exit(True);
  while LFilter <> '' do
  begin
    { Find top-level comma (not inside braces) }
    LComma := 0;
    LDepth := 0;
    for LPos := 1 to Length(LFilter) do
    begin
      if LFilter[LPos] = '{' then Inc(LDepth)
      else if LFilter[LPos] = '}' then Dec(LDepth)
      else if (LFilter[LPos] = ',') and (LDepth = 0) then
      begin
        LComma := LPos;
        Break;
      end;
    end;
    if LComma > 0 then
    begin
      LPattern := Copy(LFilter, 1, LComma - 1);
      Delete(LFilter, 1, LComma);
    end
    else
    begin
      LPattern := LFilter;
      LFilter := '';
    end;
    { Trim whitespace }
    while (LPattern <> '') and (LPattern[1] = ' ') do Delete(LPattern, 1, 1);
    while (LPattern <> '') and (LPattern[Length(LPattern)] = ' ') do
      SetLength(LPattern, Length(LPattern) - 1);
    if LPattern = '' then
      Continue;
    { Hierarchical filter: pattern contains '/' — match segment-by-segment.
      Go-style: --filter=TestParent/SubA matches TestParent/SubA/LeafA (filter is prefix)
      and also TestParent/SubA itself (exact match).
      Name prefix match: if filter starts with name, the parent should run
      (so its children can be tested). E.g. filter=TestParent/SubA should
      let TestParent run so it can enter subtests. }
    if Pos('/', LPattern) > 0 then
    begin
      if MatchesHierarchical(AName, LPattern) then
        Exit(True);
    end
    { No wildcard/brace = substring match; with wildcard/brace = glob match }
    else if (Pos('*', LPattern) > 0) or (Pos('?', LPattern) > 0) or
       (Pos('{', LPattern) > 0) then
    begin
      if MatchesGlob(AName, LPattern) then
        Exit(True);
    end
    else
    begin
      if Pos(LPattern, AName) > 0 then
        Exit(True);
    end;
  end;
  Result := False;
end;

function MatchesFilter(const AName: string): Boolean;
begin
  Result := MatchesFilter(AName, DefaultConfig);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Tag Filter                                                                   }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure SetTagFilter(const APattern: string);
begin
  SetDefaultTagFilter(APattern);
end;

function GetTagFilter: string;
begin
  Result := GetTagFilter(DefaultConfig);
end;

function GetTagFilter(const AConfig: TTestConfig): string;
begin
  Result := ResolveConfig(AConfig).TagFilter;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ JUnit XML Output                                                            }
{ ═════════════════════════════════════════════════════════════════════════════ }

function XmlEscape(const S: string): string;
var
  LLen, I, LPos, LExtra: Integer;
  LCh: Char;
begin
  LLen := Length(S);
  if LLen = 0 then
  begin
    Result := '';
    Exit;
  end;
  { Pre-calculate output length }
  LExtra := 0;
  for I := 1 to LLen do
  begin
    LCh := S[I];
    case LCh of
      '<':  Inc(LExtra, 3);  { &lt;   = 4 chars, input = 1 }
      '>':  Inc(LExtra, 3);
      '&':  Inc(LExtra, 4);  { &amp;  = 5 chars }
      '"':  Inc(LExtra, 5);  { &quot; = 6 chars }
      '''': Inc(LExtra, 5);  { &apos; = 6 chars }
    end;
  end;
  SetLength(Result, LLen + LExtra);
  LPos := 1;
  for I := 1 to LLen do
  begin
    LCh := S[I];
    case LCh of
      '<':
        begin Move('&lt;'[1], Result[LPos], 4); Inc(LPos, 4); end;
      '>':
        begin Move('&gt;'[1], Result[LPos], 4); Inc(LPos, 4); end;
      '&':
        begin Move('&amp;'[1], Result[LPos], 5); Inc(LPos, 5); end;
      '"':
        begin Move('&quot;'[1], Result[LPos], 6); Inc(LPos, 6); end;
      '''':
        begin Move('&apos;'[1], Result[LPos], 6); Inc(LPos, 6); end;
    else
      if (Ord(LCh) < 32) and (LCh <> #9) and (LCh <> #10) and (LCh <> #13) then
      begin
        Result[LPos] := ' '; Inc(LPos);
      end
      else
      begin
        Result[LPos] := LCh; Inc(LPos);
      end;
    end;
  end;
  SetLength(Result, LPos - 1);
end;

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
var
  LSb: TBufStringBuilder;
  LRunResult: TTestRunResult;
  LTestResult: TTestResult;
  I, J: Integer;
  LTotalTests, LTotalFailures, LTotalErrors, LTotalSkipped: Integer;
  LSuiteName: string;
  LSuiteErrors: Integer;
  procedure AppendFailureBlock(const ATag, AType: string;
    const AResult: TTestResult);
  begin
    LSb.AppendStr('>' + LineEnding);
    LSb.AppendStr('      <' + ATag + ' type="' + AType + '" message="' +
      XmlEscape(AResult.Message) + '">');
    if Length(AResult.CapturedLog) > 0 then
    begin
      LSb.AppendStr(LineEnding);
      LSb.AppendStr(XmlEscape(JoinLines(AResult.CapturedLog)));
      LSb.AppendStr(LineEnding + '      ');
    end;
    LSb.AppendStr('</' + ATag + '>' + LineEnding);
    LSb.AppendStr('    </testcase>' + LineEnding);
  end;
begin
  LSb.Init;
  try
    LSb.AppendStr('<?xml version="1.0" encoding="UTF-8"?>' + LineEnding);

    { Compute totals across all suites }
    LTotalTests := 0;
    LTotalFailures := 0;
    LTotalErrors := 0;
    LTotalSkipped := 0;
    for I := 0 to High(AResults) do
    begin
      LRunResult := AResults[I];
      LTotalTests := LTotalTests + LRunResult.Passed + LRunResult.Failed + LRunResult.Skipped;
      LTotalFailures := LTotalFailures + LRunResult.Failed;
      LTotalSkipped := LTotalSkipped + LRunResult.Skipped;
    end;

    { Count errors (tsError) across all results for top-level attribute }
    for I := 0 to High(AResults) do
      for J := 0 to High(AResults[I].Results) do
        if AResults[I].Results[J].Status = tsError then
          Inc(LTotalErrors);
    { Subtract errors from failures count — they were counted in Failed by runner.
      Guard against negative: when runner sets Failed=0 but has tsError results,
      don't go below zero. }
    if LTotalFailures > LTotalErrors then
      LTotalFailures := LTotalFailures - LTotalErrors
    else
      LTotalFailures := 0;
    { P2 #19 fix: include errors in total test count }
    LTotalTests := LTotalTests + LTotalErrors;

    LSb.AppendStr('<testsuites name="' + XmlEscape(ASuiteName) +
      '" tests="' + IntToStr(LTotalTests) +
      '" failures="' + IntToStr(LTotalFailures) +
      '" errors="' + IntToStr(LTotalErrors) +
      '" skipped="' + IntToStr(LTotalSkipped) + '">' + LineEnding);

    for I := 0 to High(AResults) do
    begin
      LRunResult := AResults[I];
      if LRunResult.SuiteName <> '' then
        LSuiteName := LRunResult.SuiteName
      else
        LSuiteName := 'suite_' + IntToStr(I);

      { Count per-suite errors }
      LSuiteErrors := 0;
      for J := 0 to High(LRunResult.Results) do
        if LRunResult.Results[J].Status = tsError then
          Inc(LSuiteErrors);

      { Guard against negative: when runner sets Failed=0 but has tsError results }
      if LRunResult.Failed > LSuiteErrors then
        LRunResult.Failed := LRunResult.Failed - LSuiteErrors
      else
        LRunResult.Failed := 0;
      { P2 #19 fix: include errors in per-suite test count }
      LSb.AppendStr('  <testsuite name="' + XmlEscape(LSuiteName) +
        '" tests="' + IntToStr(LRunResult.Passed + LRunResult.Failed + LRunResult.Skipped + LSuiteErrors) +
        '" failures="' + IntToStr(LRunResult.Failed) +
        '" errors="' + IntToStr(LSuiteErrors) +
        '" skipped="' + IntToStr(LRunResult.Skipped) + '">' + LineEnding);

      for J := 0 to High(LRunResult.Results) do
      begin
        LTestResult := LRunResult.Results[J];
        LSb.AppendStr('    <testcase name="' + XmlEscape(LTestResult.Name) +
          '" time="' + FormatFloat('0.000', LTestResult.Duration / 1000.0) + '"');
        case LTestResult.Status of
          tsFailed:
            AppendFailureBlock('failure', 'AssertionFailure', LTestResult);
          tsError:
            AppendFailureBlock('error', 'Error', LTestResult);
          tsSkipped:
            begin
              LSb.AppendStr('>' + LineEnding);
              if LTestResult.Message <> '' then
                LSb.AppendStr('      <skipped message="' +
                  XmlEscape(LTestResult.Message) + '"/>' + LineEnding)
              else
                LSb.AppendStr('      <skipped/>' + LineEnding);
              LSb.AppendStr('    </testcase>' + LineEnding);
            end;
        else
          LSb.AppendStr('/>' + LineEnding);
        end;
      end;

      LSb.AppendStr('  </testsuite>' + LineEnding);
    end;

    LSb.AppendStr('</testsuites>' + LineEnding);
    Result := LSb.ToString;
  finally
    LSb.Done;
  end;
end;

function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string): Boolean;
begin
  Result := False;
  try
    WriteFileText(AFileName, JUnitXML(AResults, ASuiteName));
    Result := True;
  except
    { Bare except — catches both FPC Exception and nextpas.core.exception descendants }
    ResolveErrSink(DefaultConfig).WriteLn(
      'WriteJUnitXML failed: could not write to ' + AFileName);
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Leak Reporting                                                               }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure ReportLeakIfAny(AStatus: TTestStatus; const AConfig: TTestConfig);
begin
  {$IFDEF HASHEAPTRACE}
  if (AStatus = tsPassed) and
     (GExecState <> nil) and (not GExecState^.Failed) and
     (GetFPCHeapStatus.CurrHeapUsed > 0) then
  begin
    ResolveOutSink(AConfig).WriteLn(
      '  ' + AnsiYellow('WARNING leak', AConfig) + ': ' +
      IntToStr(GetFPCHeapStatus.CurrHeapUsed) + ' bytes not freed in ' +
      AnsiBold(GExecState^.TestName, AConfig));
  end;
  {$ENDIF}
end;

procedure ReportLeakIfAny(AStatus: TTestStatus);
begin
  ReportLeakIfAny(AStatus, DefaultConfig);
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Utility Helpers                                                              }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure AddLine(var ALines: specialize TArray<string>; const ALine: string);
var
  LOldLen, LCap: Integer;
begin
  LOldLen := Length(ALines);
  LCap := GrowCapacity(LOldLen, 8);
  if LCap > LOldLen then SetLength(ALines, LCap);
  ALines[LOldLen] := ALine;
  SetLength(ALines, LOldLen + 1);
end;

function JoinLines(const ALines: specialize TArray<string>): string;
var
  I: Integer;
begin
  if Length(ALines) = 0 then
    Exit('');
  Result := ALines[0];
  for I := 1 to High(ALines) do
    Result := Result + LineEnding + ALines[I];
end;

function CountFailed(const AResults: specialize TArray<TTestRunResult>): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AResults) do
    Inc(Result, AResults[I].Failed);
end;

function CountSkipped(const AResults: specialize TArray<TTestRunResult>): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(AResults) do
    Inc(Result, AResults[I].Skipped);
end;

initialization
  InitAnsi;

end.
