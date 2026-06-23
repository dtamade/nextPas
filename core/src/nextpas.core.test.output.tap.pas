{ nextpas.core.test.output.tap — TAP v13 output format
  =========================================================
  Test Anything Protocol — machine-readable output for CI systems.
  Depends on: nextpas.core.test.base, nextpas.core.test.output }

unit nextpas.core.test.output.tap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.test.base,
  nextpas.core.test.output;

{ ── TAP v13 Output ────────────────────────────────────────────────────────── }

{ Generate TAP v13 header + result lines for all test results.
  ASuiteName: optional label for the suite (default: "nextPas tests").
  Returns multi-line string. }
function TAPReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string = ''): string;

implementation

{ Add a YAML block scalar (|-) to LLines, indenting every line of AMessage. }
procedure AddYAMLBlockScalar(var ALines: specialize TArray<string>;
  const AKey, AMessage: string);
var
  LStart, LEnd, LLen: Integer;
begin
  AddLine(ALines, '  ' + AKey + ': |-');
  LLen := Length(AMessage);
  LStart := 1;
  while LStart <= LLen do
  begin
    LEnd := LStart;
    while (LEnd <= LLen) and (AMessage[LEnd] <> #10) and (AMessage[LEnd] <> #13) do
      Inc(LEnd);
    AddLine(ALines, '    ' + Copy(AMessage, LStart, LEnd - LStart));
    if (LEnd <= LLen) and (AMessage[LEnd] = #13) then
      Inc(LEnd);
    if (LEnd <= LLen) and (AMessage[LEnd] = #10) then
      Inc(LEnd);
    LStart := LEnd;
  end;
end;

function TAPReport(const AResults: specialize TArray<TTestRunResult>;
  const ASuiteName: string): string;
var
  LTotal, LCount: Integer;
  LSuite: TTestRunResult;
  LRes: TTestResult;
  LLines: specialize TArray<string>;
  LLine: string;
begin
  { Count total tests }
  LTotal := 0;
  for LSuite in AResults do
    Inc(LTotal, Length(LSuite.Results));

  { TAP header }
  SetLength(LLines, 0);
  AddLine(LLines, 'TAP version 13');
  AddLine(LLines, '1..' + IntToStr(LTotal));

  LCount := 0;
  for LSuite in AResults do
  begin
    for LRes in LSuite.Results do
    begin
      Inc(LCount);
      case LRes.Status of
        tsPassed:
        begin
          LLine := 'ok ' + IntToStr(LCount) + ' - ' +
            LSuite.SuiteName + ' / ' + LRes.Name;
          if LRes.Duration > 0 then
            LLine := LLine + ' # duration_ms: ' + IntToStr(LRes.Duration);
          AddLine(LLines, LLine);
        end;
        tsFailed:
        begin
          LLine := 'not ok ' + IntToStr(LCount) + ' - ' +
            LSuite.SuiteName + ' / ' + LRes.Name;
          AddLine(LLines, LLine);
          AddLine(LLines, '  ---');
          AddYAMLBlockScalar(LLines, 'message', LRes.Message);
          AddLine(LLines, '  severity: fail');
          AddLine(LLines, '  ...');
        end;
        tsError:
        begin
          LLine := 'not ok ' + IntToStr(LCount) + ' - ' +
            LSuite.SuiteName + ' / ' + LRes.Name;
          AddLine(LLines, LLine);
          AddLine(LLines, '  ---');
          AddYAMLBlockScalar(LLines, 'message', LRes.Message);
          AddLine(LLines, '  severity: error');
          AddLine(LLines, '  ...');
        end;
        tsSkipped:
        begin
          LLine := 'ok ' + IntToStr(LCount) + ' - ' +
            LSuite.SuiteName + ' / ' + LRes.Name + ' # skip';
          if LRes.Message <> '' then
            LLine := LLine + ' ' + LRes.Message;
          AddLine(LLines, LLine);
        end;
      end;
    end;
  end;

  { Diagnostic footer }
  AddLine(LLines, '# suites: ' + IntToStr(Length(AResults)));
  AddLine(LLines, '# total: ' + IntToStr(LTotal));
  AddLine(LLines, '# passed: ' + IntToStr(LTotal -
    CountFailed(AResults) - CountSkipped(AResults)));
  AddLine(LLines, '# failed: ' + IntToStr(CountFailed(AResults)));
  AddLine(LLines, '# skipped: ' + IntToStr(CountSkipped(AResults)));

  Result := JoinLines(LLines);
end;

end.
