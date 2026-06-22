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

procedure AddLine(var ALines: specialize TArray<string>; const ALine: string);
begin
  SetLength(ALines, Length(ALines) + 1);
  ALines[High(ALines)] := ALine;
end;

{ Escape a string for JSON (minimal: quotes, backslash, control chars) }
function JsonEscape(const S: string): string;
var
  I: Integer;
  C: Char;
  LOut: string;
begin
  LOut := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"':  LOut := LOut + '\"';
      '\':  LOut := LOut + '\\';
      #10:  LOut := LOut + '\n';
      #13:  LOut := LOut + '\r';
      #9:   LOut := LOut + '\t';
    else
      LOut := LOut + C;
    end;
  end;
  Result := LOut;
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
