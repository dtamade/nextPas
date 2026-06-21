{ nextpas.core.test.output — ANSI helpers, test filter, JUnit XML, StatusDot
  =========================================================
  Depends on: nextpas.core.test.base }

unit nextpas.core.test.output;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  Classes,
  nextpas.core.test.base,
  nextpas.core.text.conv;

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
  case AStatus of
    tsPassed:  Result := AnsiGreen(#$2713);
    tsFailed:  Result := AnsiRed(#$2717);
    tsSkipped: Result := AnsiYellow(#$25CB);
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
var
  I, J: Integer;
begin
  { Try matching pattern against name — iterative with recursive * backtracking }
  I := 1; J := 1;
  while (I <= Length(AName)) and (J <= Length(APattern)) do
  begin
    if APattern[J] = '*' then
    begin
      { Skip consecutive stars }
      while (J <= Length(APattern)) and (APattern[J] = '*') do Inc(J);
      if J > Length(APattern) then Exit(True); { trailing * matches rest }
      { Try each possible match position for * }
      while I <= Length(AName) do
      begin
        if MatchesGlob(Copy(AName, I, MaxInt), Copy(APattern, J, MaxInt)) then
          Exit(True);
        Inc(I);
      end;
      Exit(False);
    end
    else if (APattern[J] = '?') or (AName[I] = APattern[J]) then
    begin
      Inc(I); Inc(J);
    end
    else
      Exit(False);
  end;
  { Skip trailing stars in pattern }
  while (J <= Length(APattern)) and (APattern[J] = '*') do Inc(J);
  Result := (I > Length(AName)) and (J > Length(APattern));
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
  LLen, I: Integer;
  LCh: Char;
begin
  LLen := Length(S);
  if LLen = 0 then
  begin
    Result := '';
    Exit;
  end;
  Result := '';
  for I := 1 to LLen do
  begin
    LCh := S[I];
    case LCh of
      '<':  Result := Result + '&lt;';
      '>':  Result := Result + '&gt;';
      '&':  Result := Result + '&amp;';
      '"':  Result := Result + '&quot;';
    else
      Result := Result + LCh;
    end;
  end;
end;

function JUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
var
  LSb: TStringBuilder;
  LRunResult: TTestRunResult;
  LTestResult: TTestResult;
  I, J: Integer;
  LTotalTests, LTotalFailures, LTotalSkipped: Integer;
  LSuiteName: string;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>');

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

    LSb.AppendLine('<testsuites name="' + XmlEscape(ASuiteName) +
      '" tests="' + IntToStr(LTotalTests) +
      '" failures="' + IntToStr(LTotalFailures) +
      '" skipped="' + IntToStr(LTotalSkipped) + '">');

    for I := 0 to High(AResults) do
    begin
      LRunResult := AResults[I];
      if LRunResult.SuiteName <> '' then
        LSuiteName := LRunResult.SuiteName
      else
        LSuiteName := 'suite_' + IntToStr(I);

      LSb.AppendLine('  <testsuite name="' + XmlEscape(LSuiteName) +
        '" tests="' + IntToStr(LRunResult.Passed + LRunResult.Failed + LRunResult.Skipped) +
        '" failures="' + IntToStr(LRunResult.Failed) +
        '" skipped="' + IntToStr(LRunResult.Skipped) + '">');

      for J := 0 to High(LRunResult.Results) do
      begin
        LTestResult := LRunResult.Results[J];
        LSb.Append('    <testcase name="' + XmlEscape(LTestResult.Name) + '"');
        case LTestResult.Status of
          tsFailed, tsError:
            begin
              LSb.AppendLine('>');
              LSb.AppendLine('      <failure message="' +
                XmlEscape(LTestResult.Message) + '"/>');
              LSb.AppendLine('    </testcase>');
            end;
          tsSkipped:
            begin
              LSb.AppendLine('>');
              LSb.AppendLine('      <skipped/>');
              LSb.AppendLine('    </testcase>');
            end;
        else
          LSb.AppendLine('/>');
        end;
      end;

      LSb.AppendLine('  </testsuite>');
    end;

    LSb.AppendLine('</testsuites>');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function WriteJUnitXML(const AResults: specialize TArray<TTestRunResult>;
  const AFileName: string; const ASuiteName: string): Boolean;
var
  LStream: TFileStream;
  LXml: string;
  LBytes: TBytes;
begin
  Result := False;
  try
    LXml := JUnitXML(AResults, ASuiteName);
    LBytes := TEncoding.UTF8.GetBytes(LXml);
    LStream := TFileStream.Create(AFileName, fmCreate);
    try
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
    finally
      LStream.Free;
    end;
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

initialization
  InitAnsi;

end.
