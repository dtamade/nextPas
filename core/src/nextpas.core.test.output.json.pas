{ nextpas.core.test.output.json — JSON output format
  =========================================================
  Machine-readable JSON output for CI systems and tooling.
  No external dependencies — hand-built JSON (simple structure).
  Depends on: nextpas.core.test.base, nextpas.core.test.output }

unit nextpas.core.test.output.json;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.output;

{ ── JSON Output ───────────────────────────────────────────────────────────── }

{ Generate JSON report for all test results.
  Returns pretty-printed JSON string. }
function JSONReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;

implementation

{ Escape a string for JSON (quotes, backslash, control chars) }
function JsonEscape(const S: string): string;
var
  I, LLen, LPos, LExtra: Integer;
  C: Char;
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
    C := S[I];
    case C of
      '"', '\':        Inc(LExtra, 1);  { 2 - 1 }
      #8, #9, #10, #12, #13: Inc(LExtra, 1);  { 2 - 1 }
    else
      if Ord(C) < 32 then Inc(LExtra, 5);  { \u00XX = 6 chars - 1 }
    end;
  end;
  SetLength(Result, LLen + LExtra);
  LPos := 1;
  for I := 1 to LLen do
  begin
    C := S[I];
    case C of
      '"':  begin Result[LPos] := '\'; Result[LPos+1] := '"';  Inc(LPos, 2); end;
      '\':  begin Result[LPos] := '\'; Result[LPos+1] := '\';  Inc(LPos, 2); end;
      #8:   begin Result[LPos] := '\'; Result[LPos+1] := 'b';  Inc(LPos, 2); end;
      #9:   begin Result[LPos] := '\'; Result[LPos+1] := 't';  Inc(LPos, 2); end;
      #10:  begin Result[LPos] := '\'; Result[LPos+1] := 'n';  Inc(LPos, 2); end;
      #12:  begin Result[LPos] := '\'; Result[LPos+1] := 'f';  Inc(LPos, 2); end;
      #13:  begin Result[LPos] := '\'; Result[LPos+1] := 'r';  Inc(LPos, 2); end;
    else
      if Ord(C) < 32 then
      begin
        Move('\u00'[1], Result[LPos], 4);
        Move(IntToHex(Ord(C), 2)[1], Result[LPos+4], 2);
        Inc(LPos, 6);
      end
      else
      begin
        Result[LPos] := C;
        Inc(LPos);
      end;
    end;
  end;
  SetLength(Result, LPos - 1);
end;

function StatusName(AStatus: TTestStatus): string;
begin
  case AStatus of
    tsPassed:  Result := 'passed';
    tsFailed:  Result := 'failed';
    tsSkipped: Result := 'skipped';
    tsError:   Result := 'error';
  else
    Result := 'unknown';
  end;
end;

function JSONReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
var
  LTotalPassed, LTotalFailed, LTotalSkipped: Integer;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LLines: specialize TArray<string>;
  LFirst: Boolean;
  LIndent: string;
begin
  LTotalPassed  := 0;
  LTotalFailed  := 0;
  LTotalSkipped := 0;

  for LSuite in AResults do
  begin
    Inc(LTotalPassed,  LSuite.Passed);
    Inc(LTotalFailed,  LSuite.Failed);
    Inc(LTotalSkipped, LSuite.Skipped);
  end;

  SetLength(LLines, 0);

  { Helper macro: add a line with indent }
  LIndent := '  ';

  AddLine(LLines, '{');
  if ASuiteName <> '' then
    AddLine(LLines, LIndent + '"name": "' + JsonEscape(ASuiteName) + '",');
  AddLine(LLines, LIndent + '"totalPassed": '  + IntToStr(LTotalPassed)  + ',');
  AddLine(LLines, LIndent + '"totalFailed": '  + IntToStr(LTotalFailed)  + ',');
  AddLine(LLines, LIndent + '"totalSkipped": ' + IntToStr(LTotalSkipped) + ',');
  AddLine(LLines, LIndent + '"suites": [');

  LFirst := True;
  for LSuite in AResults do
  begin
    if not LFirst then
      AddLine(LLines, '    },');
    LFirst := False;

    AddLine(LLines, '    {');
    AddLine(LLines, '      "name": "' + JsonEscape(LSuite.SuiteName) + '",');
    AddLine(LLines, '      "passed": '  + IntToStr(LSuite.Passed)  + ',');
    AddLine(LLines, '      "failed": '  + IntToStr(LSuite.Failed)  + ',');
    AddLine(LLines, '      "skipped": ' + IntToStr(LSuite.Skipped) + ',');
    if LSuite.AllPassed then
      AddLine(LLines, '      "allPassed": true,')
    else
      AddLine(LLines, '      "allPassed": false,');
    AddLine(LLines, '      "tests": [');

    for LRes in LSuite.Results do
    begin
      AddLine(LLines, '        {');
      AddLine(LLines, '          "name": "' + JsonEscape(LRes.Name) + '",');
      AddLine(LLines, '          "status": "' + StatusName(LRes.Status) + '"');
      if LRes.Message <> '' then
        AddLine(LLines, '          ,"message": "' + JsonEscape(LRes.Message) + '"');
      AddLine(LLines, '          ,"durationMs": ' + IntToStr(LRes.Duration));
      AddLine(LLines, '        },');
    end;

    { Remove trailing comma from last test }
    if Length(LSuite.Results) > 0 then
    begin
      SetLength(LLines, Length(LLines) - 1);
      AddLine(LLines, '        }');
    end;
    AddLine(LLines, '      ]');
  end;

  if Length(AResults) > 0 then
    AddLine(LLines, '    }');

  AddLine(LLines, '  ]');
  AddLine(LLines, '}');

  Result := JoinLines(LLines);
end;

end.
