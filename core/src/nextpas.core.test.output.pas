{ nextpas.core.test.output — ANSI helpers, test filter, JUnit XML, StatusDot
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.output;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,          { GetEnvironmentVariable — platform env, no project alternative }
  nextpas.core.test.base,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.fs;

{ ── ANSI helpers ──────────────────────────────────────────────────────────── }

function AnsiBold(const S: string): string;
function AnsiGreen(const S: string): string;
function AnsiRed(const S: string): string;
function AnsiYellow(const S: string): string;
function AnsiCyan(const S: string): string;
function AnsiDim(const S: string): string;
procedure SetAnsiEnabled(AEnabled: Boolean);

{ ── StatusDot ─────────────────────────────────────────────────────────────── }

function StatusDot(AStatus: TTestStatus): string;

{ ── Test Filter ───────────────────────────────────────────────────────────── }

procedure SetTestFilter(const APattern: string);
function  GetTestFilter: string;
function  MatchesFilter(const AName: string): Boolean;

{ ── Test Timeout ──────────────────────────────────────────────────────────── }

procedure SetTestTimeout(AMillis: Integer);
function  GetTestTimeout: Integer;

{ ── JUnit XML output ─────────────────────────────────────────────────────── }

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;
function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string = ''): Boolean;

{ ── Leak reporting ────────────────────────────────────────────────────────── }

procedure ReportLeakIfAny(AStatus: TTestStatus);

{ ── Utility helpers ───────────────────────────────────────────────────────── }

function JoinLines(const ALines: specialize TArray<string>): string;
function CountFailed(const AResults: specialize TArray<TTestRunResult>): Integer;
function CountSkipped(const AResults: specialize TArray<TTestRunResult>): Integer;

implementation

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
  GAnsiEnabled: Boolean = False;
  GAnsiChecked: Boolean = False;

procedure InitAnsi;
begin
  if not GAnsiChecked then
  begin
    GAnsiChecked := True;
    { Standard: https://no-color.org/ }
    if GetEnvironmentVariable('NO_COLOR') <> '' then
    begin
      GAnsiEnabled := False;
      Exit;
    end;
    {$IFDEF NEXTPAS_LINUX}
    GAnsiEnabled := True;
    {$ELSE}
    GAnsiEnabled := (GetEnvironmentVariable('TERM') <> '') or
                    (GetEnvironmentVariable('ANSICON') <> '') or
                    (GetEnvironmentVariable('ConEmuANSI') = 'ON') or
                    (GetEnvironmentVariable('WT_SESSION') <> '');
    {$ENDIF}
    { Override via NEXTPAS_COLOR: '1' forces on, '0' forces off }
    if GetEnvironmentVariable('NEXTPAS_COLOR') = '1' then
      GAnsiEnabled := True
    else if GetEnvironmentVariable('NEXTPAS_COLOR') = '0' then
      GAnsiEnabled := False;
  end;
end;

function Wrap(const ACode, S: string): string;
begin
  InitAnsi;
  if GAnsiEnabled then
    Result := ACode + S + C_RESET
  else
    Result := S;
end;

function AnsiBold(const S: string): string;  begin Result := Wrap(C_BOLD, S); end;
function AnsiGreen(const S: string): string;  begin Result := Wrap(C_GREEN, S); end;
function AnsiRed(const S: string): string;    begin Result := Wrap(C_RED, S); end;
function AnsiYellow(const S: string): string; begin Result := Wrap(C_YELLOW, S); end;
function AnsiCyan(const S: string): string;   begin Result := Wrap(C_CYAN, S); end;
function AnsiDim(const S: string): string;    begin Result := Wrap(C_DIM, S); end;

procedure SetAnsiEnabled(AEnabled: Boolean);
begin
  GAnsiEnabled := AEnabled;
  GAnsiChecked := True; { prevent InitAnsi from overwriting }
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ StatusDot                                                                    }
{ ═════════════════════════════════════════════════════════════════════════════ }

function StatusDot(AStatus: TTestStatus): string;
begin
  if not GAnsiEnabled then
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
    tsPassed:  Result := AnsiGreen(#$E2#$9C#$93);
    tsFailed:  Result := AnsiRed(#$E2#$9C#$97);
    tsSkipped: Result := AnsiYellow(#$E2#$97#$8B);
    tsError:   Result := AnsiRed('!');
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Test Filter & Timeout (public API)                                          }
{ ═════════════════════════════════════════════════════════════════════════════ }

var
  GTestFilter: string = '';
  GTestTimeoutMs: Integer = 0;

procedure SetTestFilter(const APattern: string);
begin
  GTestFilter := APattern;
end;

function GetTestFilter: string;
begin
  Result := GTestFilter;
end;

procedure SetTestTimeout(AMillis: Integer);
begin
  GTestTimeoutMs := AMillis;
end;

function GetTestTimeout: Integer;
begin
  Result := GTestTimeoutMs;
end;

{ ── Glob matching (internal) ───────────────────────────────────────────────── }

function MatchesGlob(const AName, APattern: string): Boolean;
{ Iterative backtracking glob matcher — no Copy() allocations.
  On '*', save positions and advance; on mismatch, backtrack. }
var
  I, J, LStarI, LStarJ: Integer;
begin
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

function MatchesFilter(const AName: string): Boolean;
var
  LFilter, LPattern: string;
  LComma: Integer;
begin
  if GTestFilter = '' then
    Exit(True);
  LFilter := GTestFilter;
  while LFilter <> '' do
  begin
    LComma := Pos(',', LFilter);
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
    { No wildcard = substring match; with wildcard = glob match }
    if (Pos('*', LPattern) > 0) or (Pos('?', LPattern) > 0) then
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
      '<':  Inc(LExtra, 3);  { &lt;  = 4 chars, input = 1 }
      '>':  Inc(LExtra, 3);
      '&':  Inc(LExtra, 4);  { &amp; = 5 chars }
      '"':  Inc(LExtra, 5);  { &quot; = 6 chars }
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
  LTotalTests, LTotalFailures, LTotalSkipped: Integer;
  LSuiteName: string;
begin
  LSb.Init;
  try
    LSb.AppendStr('<?xml version="1.0" encoding="UTF-8"?>' + LineEnding);

    { Compute totals across all suites }
    LTotalTests := 0;
    LTotalFailures := 0;
    LTotalSkipped := 0;
    for I := 0 to High(AResults) do
    begin
      LRunResult := AResults[I];
      LTotalTests := LTotalTests + LRunResult.Passed + LRunResult.Failed + LRunResult.Skipped;
      LTotalFailures := LTotalFailures + LRunResult.Failed;
      LTotalSkipped := LTotalSkipped + LRunResult.Skipped;
    end;

    LSb.AppendStr('<testsuites name="' + XmlEscape(ASuiteName) +
      '" tests="' + IntToStr(LTotalTests) +
      '" failures="' + IntToStr(LTotalFailures) +
      '" skipped="' + IntToStr(LTotalSkipped) + '">' + LineEnding);

    for I := 0 to High(AResults) do
    begin
      LRunResult := AResults[I];
      if LRunResult.SuiteName <> '' then
        LSuiteName := LRunResult.SuiteName
      else
        LSuiteName := 'suite_' + IntToStr(I);

      LSb.AppendStr('  <testsuite name="' + XmlEscape(LSuiteName) +
        '" tests="' + IntToStr(LRunResult.Passed + LRunResult.Failed + LRunResult.Skipped) +
        '" failures="' + IntToStr(LRunResult.Failed) +
        '" skipped="' + IntToStr(LRunResult.Skipped) + '">' + LineEnding);

      for J := 0 to High(LRunResult.Results) do
      begin
        LTestResult := LRunResult.Results[J];
        LSb.AppendStr('    <testcase name="' + XmlEscape(LTestResult.Name) + '"');
        case LTestResult.Status of
          tsFailed, tsError:
            begin
              LSb.AppendStr('>' + LineEnding);
              LSb.AppendStr('      <failure message="' +
                XmlEscape(LTestResult.Message) + '"/>' + LineEnding);
              LSb.AppendStr('    </testcase>' + LineEnding);
            end;
          tsSkipped:
            begin
              LSb.AppendStr('>' + LineEnding);
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
    { Return False on any I/O error }
  end;
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Leak Reporting                                                               }
{ ═════════════════════════════════════════════════════════════════════════════ }

procedure ReportLeakIfAny(AStatus: TTestStatus);
begin
  {$IFDEF HASHEAPTRACE}
  if (AStatus = tsPassed) and
     (GExecState <> nil) and (not GExecState^.Failed) and
     (GetFPCHeapStatus.CurrHeapUsed > 0) then
  begin
    WriteLn('  ', AnsiYellow('WARNING leak'), ': ',
      GetFPCHeapStatus.CurrHeapUsed, ' bytes not freed in ',
      AnsiBold(GExecState^.TestName));
  end;
  {$ENDIF}
end;

{ ═════════════════════════════════════════════════════════════════════════════ }
{ Utility Helpers                                                              }
{ ═════════════════════════════════════════════════════════════════════════════ }

function JoinLines(const ALines: specialize TArray<string>): string;
var
  I, LLen, LPos: Integer;
begin
  LLen := 0;
  for I := 0 to High(ALines) do
    Inc(LLen, Length(ALines[I]) + 1); { +1 for newline }
  SetLength(Result, LLen);
  LPos := 1;
  for I := 0 to High(ALines) do
  begin
    if I > 0 then
    begin
      Result[LPos] := #10;
      Inc(LPos);
    end;
    if Length(ALines[I]) > 0 then
    begin
      Move(ALines[I][1], Result[LPos], Length(ALines[I]));
      Inc(LPos, Length(ALines[I]));
    end;
  end;
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
