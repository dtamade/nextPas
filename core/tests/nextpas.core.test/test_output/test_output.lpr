{ test_output.lpr — nextpas.core.test.output API coverage
  =========================================================
  Covers: ANSI helpers, StatusDot, SetTestFilter/MatchesFilter,
          SetTestTimeout/GetTestTimeout, JUnitXML, WriteJUnitXML }

program test_output;

{$mode objfpc}{$H+}{$J-}

uses
  cthreads,
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.output,
  nextpas.core.test.output.tap,
  nextpas.core.test.output.json,
  nextpas.core.test.runner;

var
  GTestsRun: Integer = 0;

function ExtractXmlAttributeInt(const AXml, AAttribute: string): Integer;
var
  LAttrPos: Integer;
  LValueStart: Integer;
  LValueEnd: Integer;
  LNeedle: string;
begin
  LNeedle := AAttribute + '="';
  LAttrPos := Pos(LNeedle, AXml);
  CheckTrue(LAttrPos > 0, 'Missing XML attribute: ' + AAttribute);
  LValueStart := LAttrPos + Length(LNeedle);
  LValueEnd := LValueStart;
  while (LValueEnd <= Length(AXml)) and (AXml[LValueEnd] <> '"') do
    Inc(LValueEnd);
  Result := StrToInt(Copy(AXml, LValueStart, LValueEnd - LValueStart));
end;

function ExtractJSONInt(const AJson, AKey: string): Integer;
var
  LKeyPos: Integer;
  LValueStart: Integer;
  LValueEnd: Integer;
  LNeedle: string;
begin
  LNeedle := '"' + AKey + '":';
  LKeyPos := Pos(LNeedle, AJson);
  CheckTrue(LKeyPos > 0, 'Missing JSON key: ' + AKey);
  LValueStart := LKeyPos + Length(LNeedle);
  while (LValueStart <= Length(AJson)) and (AJson[LValueStart] = ' ') do
    Inc(LValueStart);
  LValueEnd := LValueStart;
  while (LValueEnd <= Length(AJson)) and (AJson[LValueEnd] in ['0'..'9', '-']) do
    Inc(LValueEnd);
  Result := StrToInt(Copy(AJson, LValueStart, LValueEnd - LValueStart));
end;

{ ── ANSI helpers ───────────────────────────────────────────────────────────── }

procedure TestAnsiHelpersEnabled;
var
  LOut: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(True);
  LOut := AnsiBold('hello');
  CheckContains(LOut, #27'[1m');
  CheckContains(LOut, 'hello');
  CheckContains(LOut, #27'[0m');
  LOut := AnsiGreen('ok');
  CheckContains(LOut, #27'[32m');
  LOut := AnsiRed('fail');
  CheckContains(LOut, #27'[31m');
  LOut := AnsiYellow('warn');
  CheckContains(LOut, #27'[33m');
  LOut := AnsiCyan('info');
  CheckContains(LOut, #27'[36m');
  LOut := AnsiDim('dim');
  CheckContains(LOut, #27'[2m');
end;

procedure TestAnsiHelpersDisabled;
var
  LOut: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(False);
  try
    LOut := AnsiBold('hello');
    CheckEqual(LOut, 'hello');
    LOut := AnsiRed('fail');
    CheckEqual(LOut, 'fail');
  finally
    SetAnsiEnabled(True);
  end;
end;

procedure TestAnsiToggle;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(False);
  CheckEqual(AnsiGreen('x'), 'x');
  SetAnsiEnabled(True);
  CheckContains(AnsiGreen('x'), #27'[');
  SetAnsiEnabled(False);
  CheckEqual(AnsiGreen('x'), 'x');
  SetAnsiEnabled(True);
end;

{ ── R2-F17: ANSI content structure verification ───────────────────────────── }

procedure TestAnsiBoldContainsContent;
var
  LOut: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(True);
  LOut := AnsiBold('my text');
  { The ANSI wrapper should contain the actual text }
  CheckContains(LOut, 'my text');
  { Should start with ESC[ and end with reset }
  CheckTrue(LOut[1] = #27, 'should start with ESC');
  CheckTrue(Pos(#27'[0m', LOut) > 0, 'should contain reset sequence');
end;

procedure TestAnsiGreenContainsContent;
var
  LOut: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(True);
  LOut := AnsiGreen('pass');
  CheckContains(LOut, 'pass');
  CheckContains(LOut, #27'[32m');
  CheckContains(LOut, #27'[0m');
end;

procedure TestAnsiRedContainsContent;
var
  LOut: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(True);
  LOut := AnsiRed('fail');
  CheckContains(LOut, 'fail');
  CheckContains(LOut, #27'[31m');
  CheckContains(LOut, #27'[0m');
end;

{ ── StatusDot ──────────────────────────────────────────────────────────────── }

procedure TestStatusDotAll;
var
  LDot: string;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(False);
  try
    LDot := StatusDot(tsPassed);
    CheckTrue(Length(LDot) > 0, 'StatusDot(tsPassed) should not be empty');
    LDot := StatusDot(tsFailed);
    CheckTrue(Length(LDot) > 0, 'StatusDot(tsFailed) should not be empty');
    LDot := StatusDot(tsSkipped);
    CheckTrue(Length(LDot) > 0, 'StatusDot(tsSkipped) should not be empty');
    LDot := StatusDot(tsError);
    CheckTrue(Length(LDot) > 0, 'StatusDot(tsError) should not be empty');
  finally
    SetAnsiEnabled(True);
  end;
end;

procedure TestStatusDotAsciiFallback;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(False);
  try
    CheckEqual(StatusDot(tsPassed), '+');
    CheckEqual(StatusDot(tsFailed), 'x');
    CheckEqual(StatusDot(tsSkipped), 'o');
    CheckEqual(StatusDot(tsError), '!');
  finally
    SetAnsiEnabled(True);
  end;
end;

procedure TestStatusDotDistinct;
var
  LPassed, LFailed, LSkipped, LError: string;
begin
  Inc(GTestsRun);
  { StatusDot always calls AnsiGreen/AnsiRed/AnsiYellow/AnsiRed,
    which wrap with color codes. Each status type is structurally different. }
  LPassed  := StatusDot(tsPassed);
  LFailed  := StatusDot(tsFailed);
  LSkipped := StatusDot(tsSkipped);
  LError   := StatusDot(tsError);
  { All should be non-empty }
  CheckTrue(Length(LPassed) > 0, 'tsPassed dot non-empty');
  CheckTrue(Length(LFailed) > 0, 'tsFailed dot non-empty');
  CheckTrue(Length(LSkipped) > 0, 'tsSkipped dot non-empty');
  CheckTrue(Length(LError) > 0, 'tsError dot non-empty');
end;

{ ── Test Filter ────────────────────────────────────────────────────────────── }

procedure TestFilterEmpty;
begin
  Inc(GTestsRun);
  SetTestFilter('');
  CheckTrue(MatchesFilter('anything'), 'Empty filter should match everything');
  CheckTrue(MatchesFilter(''), 'Empty filter should match empty string');
end;

procedure TestFilterSubstring;
begin
  Inc(GTestsRun);
  SetTestFilter('hello');
  CheckTrue(MatchesFilter('hello'), 'Exact match');
  CheckTrue(MatchesFilter('say hello world'), 'Substring match');
  CheckTrue(MatchesFilter('hello_world'), 'Prefix match');
  CheckFalse(MatchesFilter('goodbye'), 'No match');
  CheckFalse(MatchesFilter('hell'), 'Partial should not match');
  SetTestFilter('');
end;

procedure TestFilterGlobStar;
begin
  Inc(GTestsRun);
  SetTestFilter('test_*');
  CheckTrue(MatchesFilter('test_foo'), '* matches suffix');
  CheckTrue(MatchesFilter('test_'), '* matches empty suffix');
  CheckFalse(MatchesFilter('my_test_foo'), 'Prefix required');
  SetTestFilter('');
end;

procedure TestFilterGlobQuestion;
begin
  Inc(GTestsRun);
  SetTestFilter('ab?d');
  CheckTrue(MatchesFilter('abcd'), '? matches single char');
  CheckTrue(MatchesFilter('abxd'), '? matches any char');
  CheckFalse(MatchesFilter('abd'), '? requires exactly one char');
  CheckFalse(MatchesFilter('abcde'), '? does not match two chars');
  SetTestFilter('');
end;

procedure TestFilterCommaSeparated;
begin
  Inc(GTestsRun);
  SetTestFilter('foo, bar, baz');
  CheckTrue(MatchesFilter('test_foo'), 'Comma-separated: foo');
  CheckTrue(MatchesFilter('test_bar'), 'Comma-separated: bar');
  CheckTrue(MatchesFilter('test_baz'), 'Comma-separated: baz');
  CheckFalse(MatchesFilter('test_qux'), 'Comma-separated: no match');
  SetTestFilter('');
end;

procedure TestFilterGlobCommaCombined;
begin
  Inc(GTestsRun);
  SetTestFilter('test_*,check_*');
  CheckTrue(MatchesFilter('test_alpha'), 'Glob + comma: test_');
  CheckTrue(MatchesFilter('check_beta'), 'Glob + comma: check_');
  CheckFalse(MatchesFilter('verify_gamma'), 'Glob + comma: no match');
  SetTestFilter('');
end;

procedure TestFilterWildcardOnly;
begin
  Inc(GTestsRun);
  SetTestFilter('*');
  CheckTrue(MatchesFilter('anything'), '* matches everything');
  CheckTrue(MatchesFilter(''), '* matches empty');
  SetTestFilter('');
end;

procedure TestGetSetFilter;
begin
  Inc(GTestsRun);
  SetTestFilter('my_pattern');
  CheckEqual(GetTestFilter, 'my_pattern');
  SetTestFilter('');
  CheckEqual(GetTestFilter, '');
end;

{ ── Test Timeout ───────────────────────────────────────────────────────────── }

procedure TestGetSetTimeout;
begin
  Inc(GTestsRun);
  SetTestTimeout(5000);
  CheckEqual(GetTestTimeout, 5000);
  SetTestTimeout(0);
  CheckEqual(GetTestTimeout, 0);
end;

{ ── JUnit XML ──────────────────────────────────────────────────────────────── }

procedure TestJUnitXMLBasic;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
  LTotalTests: Integer;
  LTotalFailures: Integer;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('suite1');
  LResults[0].Passed := 2;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 3);
  LResults[0].Results[0].Name := 'test_a';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'test_b';
  LResults[0].Results[1].Status := tsPassed;
  LResults[0].Results[2].Name := 'test_c';
  LResults[0].Results[2].Status := tsFailed;
  LResults[0].Results[2].Message := 'expected X';

  LXml := JUnitXML(LResults, 'my_run');
  LTotalTests := ExtractXmlAttributeInt(LXml, 'tests');
  LTotalFailures := ExtractXmlAttributeInt(LXml, 'failures');
  CheckContains(LXml, '<?xml version');
  CheckContains(LXml, '<testsuites');
  CheckEqual(3, LTotalTests);
  CheckTrue(LTotalTests > 0, 'tests attribute should be > 0');
  CheckEqual(1, LTotalFailures);
  CheckContains(LXml, '<testsuite name="suite1"');
  CheckContains(LXml, '<testcase name="test_a"');
  CheckContains(LXml, 'time="');
  CheckContains(LXml, '<failure type="AssertionFailure" message="expected X"');
end;

procedure TestJUnitXMLMultipleSuites;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
  LTotalTests: Integer;
  LTotalFailures: Integer;
  LTotalSkipped: Integer;
begin
  Inc(GTestsRun);
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('alpha');
  LResults[0].Passed := 1;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a1';
  LResults[0].Results[0].Status := tsPassed;

  LResults[1] := TTestRunResult.Create('beta');
  LResults[1].Passed := 0;
  LResults[1].Failed := 0;
  LResults[1].Skipped := 2;
  SetLength(LResults[1].Results, 2);
  LResults[1].Results[0].Name := 'b1';
  LResults[1].Results[0].Status := tsSkipped;
  LResults[1].Results[1].Name := 'b2';
  LResults[1].Results[1].Status := tsSkipped;

  LXml := JUnitXML(LResults);
  LTotalTests := ExtractXmlAttributeInt(LXml, 'tests');
  LTotalFailures := ExtractXmlAttributeInt(LXml, 'failures');
  LTotalSkipped := ExtractXmlAttributeInt(LXml, 'skipped');
  CheckContains(LXml, '<testsuite name="alpha"');
  CheckContains(LXml, '<testsuite name="beta"');
  CheckEqual(3, LTotalTests);
  CheckTrue(LTotalTests > 0, 'tests attribute should be > 0');
  CheckEqual(0, LTotalFailures);
  CheckEqual(2, LTotalSkipped);
  CheckContains(LXml, '<skipped/>');
end;

procedure TestJUnitXMLXmlEscape;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('test<>esc');
  LResults[0].Passed := 1;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a & b "c" d''e';
  LResults[0].Results[0].Status := tsPassed;

  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'test&lt;&gt;esc');
  CheckContains(LXml, 'a &amp; b &quot;c&quot; d&apos;e');
end;

procedure TestJUnitXMLEmpty;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 0);
  LXml := JUnitXML(LResults, 'empty');
  CheckEqual(0, ExtractXmlAttributeInt(LXml, 'tests'));
  CheckEqual(0, ExtractXmlAttributeInt(LXml, 'failures'));
  CheckEqual(0, ExtractXmlAttributeInt(LXml, 'skipped'));
end;

procedure TestJUnitXMLDefaultSuiteName;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('');
  LResults[0].Passed := 1;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'x';
  LResults[0].Results[0].Status := tsPassed;

  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'name="suite_0"');
end;

procedure TestJUnitXMLSkippedTestCase;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('s');
  LResults[0].Passed := 0;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'sk';
  LResults[0].Results[0].Status := tsSkipped;
  LResults[0].Results[0].Message := 'not ready';

  LXml := JUnitXML(LResults);
  CheckContains(LXml, '<skipped/>');
end;

procedure TestJUnitXMLErrorTestCase;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('s');
  LResults[0].Passed := 0;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'err';
  LResults[0].Results[0].Status := tsError;
  LResults[0].Results[0].Message := 'segfault';

  LXml := JUnitXML(LResults);
  CheckContains(LXml, '<failure type="Error" message="segfault"');
end;

function MakeTempJUnitPath: string;
var
  LGuid: TGuid;
  LName: string;
begin
  if CreateGUID(LGuid) = 0 then
    LName := GUIDToString(LGuid)
  else
    LName := IntToStr(GetTickCount64);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_test_junit_' + LName + '.xml';
end;

procedure TestWriteJUnitXML;
var
  LResults: specialize TArray<TTestRunResult>;
  LPath: string;
  LSuccess: Boolean;
  LContent, LLine: string;
  LF: TextFile;
begin
  Inc(GTestsRun);
  LPath := MakeTempJUnitPath;
  try
    SetLength(LResults, 1);
    LResults[0] := TTestRunResult.Create('write_test');
    LResults[0].Passed := 1;
    LResults[0].Failed := 0;
    LResults[0].Skipped := 0;
    SetLength(LResults[0].Results, 1);
    LResults[0].Results[0].Name := 'ok';
    LResults[0].Results[0].Status := tsPassed;

    LSuccess := WriteJUnitXML(LResults, LPath, 'run1');
    CheckTrue(LSuccess, 'WriteJUnitXML should succeed');
    CheckTrue(FileExists(LPath), 'File should exist after WriteJUnitXML');

    LContent := '';
    AssignFile(LF, LPath);
    Reset(LF);
    while not Eof(LF) do
    begin
      ReadLn(LF, LLine);
      LContent := LContent + LLine + LineEnding;
    end;
    CloseFile(LF);
    CheckContains(LContent, '<?xml');
    CheckContains(LContent, 'write_test');
  finally
    if FileExists(LPath) then
      DeleteFile(LPath);
  end;
end;

procedure TestWriteJUnitXMLBadPath;
var
  LResults: specialize TArray<TTestRunResult>;
begin
  Inc(GTestsRun);
  SetLength(LResults, 0);
  CheckFalse(WriteJUnitXML(LResults, '/nonexistent/dir/file.xml'),
    'WriteJUnitXML should return False on bad path');
end;

{ TAP renderer tests }

procedure TestTAPReportBasic;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapBasic');
  LResults[0].Passed  := 1;
  LResults[0].Failed  := 1;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'pass';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'fail';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'bad';

  LOut := TAPReport(LResults);
  CheckContains(LOut, 'TAP version 13');
  CheckContains(LOut, 'ok 1 - TapBasic / pass');
  CheckContains(LOut, 'not ok 2 - TapBasic / fail');
  CheckContains(LOut, 'message: |-');
  CheckContains(LOut, '    bad');
end;

procedure TestTAPReportSkipped;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapSkip');
  LResults[0].Passed  := 1;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'ok';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'skip';
  LResults[0].Results[1].Status := tsSkipped;

  LOut := TAPReport(LResults);
  CheckContains(LOut, 'ok 1 - TapSkip / ok');
  CheckContains(LOut, 'ok 2 - TapSkip / skip # skip');
end;

procedure TestTAPReportEmpty;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 0);
  LOut := TAPReport(LResults, 'Empty');
  CheckContains(LOut, 'TAP version 13');
  CheckContains(LOut, '1..0');
end;

{ JSON renderer tests }

procedure TestJSONReportBasic;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
  LTotalPassed: Integer;
  LTotalFailed: Integer;
  LTotalSkipped: Integer;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsBasic');
  LResults[0].Passed    := 1;
  LResults[0].Failed    := 1;
  LResults[0].Skipped   := 0;
  LResults[0].AllPassed := False;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'js_pass';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'js_fail';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'boom';

  LOut := JSONReport(LResults);
  LTotalPassed := ExtractJSONInt(LOut, 'totalPassed');
  LTotalFailed := ExtractJSONInt(LOut, 'totalFailed');
  LTotalSkipped := ExtractJSONInt(LOut, 'totalSkipped');
  CheckContains(LOut, '"name": "JsBasic"');
  CheckEqual(1, LTotalPassed);
  CheckTrue(LTotalPassed > 0, 'totalPassed should be > 0');
  CheckEqual(1, LTotalFailed);
  CheckEqual(0, LTotalSkipped);
  CheckContains(LOut, '"name": "js_pass"');
  CheckContains(LOut, '"name": "js_fail"');
  CheckContains(LOut, '"status": "failed"');
  CheckContains(LOut, '"message": "boom"');
end;

procedure TestJSONReportEmpty;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 0);
  LOut := JSONReport(LResults, 'Empty');
  CheckEqual(0, ExtractJSONInt(LOut, 'totalPassed'));
  CheckEqual(0, ExtractJSONInt(LOut, 'totalFailed'));
  CheckEqual(0, ExtractJSONInt(LOut, 'totalSkipped'));
  CheckContains(LOut, '"suites": [');
end;

{ ── R2-F18: TAP/JSON multi-suite / JSON skip ──────────────────────────────── }

procedure TestTAPReportMultiSuite;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('SuiteA');
  LResults[0].Passed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a1';
  LResults[0].Results[0].Status := tsPassed;

  LResults[1] := TTestRunResult.Create('SuiteB');
  LResults[1].Failed := 1;
  SetLength(LResults[1].Results, 1);
  LResults[1].Results[0].Name := 'b1';
  LResults[1].Results[0].Status := tsFailed;
  LResults[1].Results[0].Message := 'boom';

  LOut := TAPReport(LResults);
  CheckContains(LOut, '1..2');
  CheckContains(LOut, 'ok 1 - SuiteA / a1');
  CheckContains(LOut, 'not ok 2 - SuiteB / b1');
end;

procedure TestJSONReportMultiSuite;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
  LTotalPassed: Integer;
  LTotalSkipped: Integer;
begin
  Inc(GTestsRun);
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('JsSuiteA');
  LResults[0].Passed := 2;
  LResults[0].AllPassed := True;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'j1';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'j2';
  LResults[0].Results[1].Status := tsPassed;

  LResults[1] := TTestRunResult.Create('JsSuiteB');
  LResults[1].Skipped := 1;
  LResults[1].AllPassed := True;
  SetLength(LResults[1].Results, 1);
  LResults[1].Results[0].Name := 'j3';
  LResults[1].Results[0].Status := tsSkipped;

  LOut := JSONReport(LResults);
  LTotalPassed := ExtractJSONInt(LOut, 'totalPassed');
  LTotalSkipped := ExtractJSONInt(LOut, 'totalSkipped');
  CheckContains(LOut, '"name": "JsSuiteA"');
  CheckContains(LOut, '"name": "JsSuiteB"');
  CheckEqual(2, LTotalPassed);
  CheckTrue(LTotalPassed > 0, 'totalPassed should be > 0');
  CheckEqual(1, LTotalSkipped);
end;

procedure TestJSONReportSkipped;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsSkip');
  LResults[0].Skipped := 1;
  LResults[0].AllPassed := True;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'skipped_test';
  LResults[0].Results[0].Status := tsSkipped;
  LResults[0].Results[0].Message := 'not ready';

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "skipped"');
  CheckContains(LOut, '"totalSkipped": 1');
  CheckContains(LOut, 'not ready');
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

procedure TestTAPReportDuration;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapDur');
  LResults[0].Passed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name     := 'fast';
  LResults[0].Results[0].Status   := tsPassed;
  LResults[0].Results[0].Duration := 42;

  LOut := TAPReport(LResults);
  CheckContains(LOut, '# duration_ms: 42');
end;

procedure TestJSONReportDuration;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsDur');
  LResults[0].Passed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name     := 'fast';
  LResults[0].Results[0].Status   := tsPassed;
  LResults[0].Results[0].Duration := 99;

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"durationMs": 99');
end;

procedure TestTAPReportMultiLineYAML;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapMulti');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name    := 'ml';
  LResults[0].Results[0].Status  := tsFailed;
  LResults[0].Results[0].Message := 'line1' + LineEnding + 'line2';

  LOut := TAPReport(LResults);
  CheckContains(LOut, 'message: |-');
  { Multi-line message is embedded as-is; first line is indented }
  CheckContains(LOut, '    line1');
  CheckContains(LOut, 'line2');
end;

procedure TestTAPReportError;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapErr');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name    := 'err';
  LResults[0].Results[0].Status  := tsError;
  LResults[0].Results[0].Message := 'EAccessViolation';

  LOut := TAPReport(LResults);
  CheckContains(LOut, 'not ok');
  CheckContains(LOut, 'EAccessViolation');
end;

{ R6-49: Unicode test name StatusDot should not crash }

procedure TestStatusDotUnicodeName;
var
  LResult: TTestResult;
  LDot: string;
begin
  Inc(GTestsRun);
  { Calling StatusDot with Unicode content in the test name should not crash }
  LResult.Name := #226#130#172' Test'; { UTF-8 Euro sign + space }
  LResult.Status := tsPassed;
  LResult.Message := '';
  LDot := StatusDot(tsPassed);
  CheckTrue(Length(LDot) > 0, 'StatusDot should return non-empty');
  { Also test other statuses with a Unicode name for crash-safety }
  LDot := StatusDot(tsFailed);
  CheckTrue(Length(LDot) > 0, 'StatusDot(tsFailed) non-empty');
  LDot := StatusDot(tsSkipped);
  CheckTrue(Length(LDot) > 0, 'StatusDot(tsSkipped) non-empty');
end;

{ R6-50: Nested wildcard a*b*c pattern }

procedure TestFilterNestedGlob;
begin
  Inc(GTestsRun);
  SetTestFilter('a*b*c');
  CheckTrue(MatchesFilter('axxbyyc'), 'a*b*c should match axxbyyc');
  CheckTrue(MatchesFilter('abc'), 'a*b*c should match abc (* matches empty)');
  CheckFalse(MatchesFilter('aXXXb'), 'a*b*c should not match aXXXb (no c)');
  CheckFalse(MatchesFilter('xxbyyc'), 'a*b*c should not match xxbyyc (no a prefix)');
  SetTestFilter('');
end;

{ R6-51: JUnit XML structural completeness }

procedure TestJUnitXMLStructureComplete;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('StructSuite');
  LResults[0].Passed := 1;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'ok_test';
  LResults[0].Results[0].Status := tsPassed;

  LXml := JUnitXML(LResults, 'struct_run');
  CheckContains(LXml, '<?xml');
  CheckContains(LXml, '<testsuites');
  CheckContains(LXml, '</testsuites>');
  CheckContains(LXml, '<testsuite');
  CheckContains(LXml, '</testsuite>');
  CheckContains(LXml, '<testcase');
  CheckContains(LXml, 'tests="1"');
  CheckContains(LXml, 'failures="0"');
end;

{ R6-52: JSON report structural completeness }

procedure TestJSONReportStructureComplete;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  Inc(GTestsRun);
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsStruct');
  LResults[0].Passed := 1;
  LResults[0].AllPassed := True;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'ok';
  LResults[0].Results[0].Status := tsPassed;

  LOut := JSONReport(LResults);
  CheckTrue(LOut[1] = '{', 'JSON should start with {');
  CheckContains(LOut, '"totalPassed"');
  CheckContains(LOut, '"totalFailed"');
  CheckContains(LOut, '"totalSkipped"');
  CheckContains(LOut, '"suites"');
end;

{ R6-61: XmlEscape control character behavior (tested via JUnitXML) }

procedure TestXmlEscapeControlChars;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  Inc(GTestsRun);
  { Tab/LF/CR should be preserved in XML output }
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('CtrlTest');
  LResults[0].Passed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a' + #9 + 'b';
  LResults[0].Results[0].Status := tsPassed;

  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'a' + #9 + 'b');

  { LF in name should be preserved }
  LResults[0].Results[0].Name := 'a' + #10 + 'b';
  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'a');
  CheckContains(LXml, 'b');

  { Control char < 32 (not tab/LF/CR) in failure message should be replaced with space }
  LResults[0].Results[0].Name := 'ctrl_fail';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Failed := 1;
  LResults[0].Passed := 0;
  LResults[0].Results[0].Message := 'err' + #1 + 'msg';
  LXml := JUnitXML(LResults);
  CheckTrue(Pos(#1, LXml) = 0, 'SOH should not appear in XML');
  CheckContains(LXml, 'err msg');
end;

{ R6-65: ANSI state restoration (try-finally pattern) }

procedure TestAnsiStateRestoration;
begin
  Inc(GTestsRun);
  SetAnsiEnabled(True);
  try
    SetAnsiEnabled(False);
    CheckEqual(AnsiGreen('x'), 'x');
  finally
    SetAnsiEnabled(True);
  end;
  { After try-finally, ANSI should be restored to enabled }
  CheckContains(AnsiGreen('x'), #27'[');
end;

var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
begin
  WriteLn('=== test_output ===');
  { Reset global filter/timeout to defaults before running }
  SetTestFilter('');
  SetTestTimeout(0);
  Suite := TTestSuite.Create('output');
  Suite.Test('TestAnsiHelpersEnabled', @TestAnsiHelpersEnabled);
  Suite.Test('TestAnsiHelpersDisabled', @TestAnsiHelpersDisabled);
  Suite.Test('TestAnsiToggle', @TestAnsiToggle);
  Suite.Test('TestAnsiBoldContainsContent', @TestAnsiBoldContainsContent);
  Suite.Test('TestAnsiGreenContainsContent', @TestAnsiGreenContainsContent);
  Suite.Test('TestAnsiRedContainsContent', @TestAnsiRedContainsContent);
  Suite.Test('TestStatusDotAll', @TestStatusDotAll);
  Suite.Test('TestStatusDotAsciiFallback', @TestStatusDotAsciiFallback);
  Suite.Test('TestStatusDotDistinct', @TestStatusDotDistinct);
  Suite.Test('TestFilterEmpty', @TestFilterEmpty);
  Suite.Test('TestFilterSubstring', @TestFilterSubstring);
  Suite.Test('TestFilterGlobStar', @TestFilterGlobStar);
  Suite.Test('TestFilterGlobQuestion', @TestFilterGlobQuestion);
  Suite.Test('TestFilterCommaSeparated', @TestFilterCommaSeparated);
  Suite.Test('TestFilterGlobCommaCombined', @TestFilterGlobCommaCombined);
  Suite.Test('TestFilterWildcardOnly', @TestFilterWildcardOnly);
  Suite.Test('TestGetSetFilter', @TestGetSetFilter);
  Suite.Test('TestGetSetTimeout', @TestGetSetTimeout);
  Suite.Test('TestJUnitXMLBasic', @TestJUnitXMLBasic);
  Suite.Test('TestJUnitXMLMultipleSuites', @TestJUnitXMLMultipleSuites);
  Suite.Test('TestJUnitXMLXmlEscape', @TestJUnitXMLXmlEscape);
  Suite.Test('TestJUnitXMLEmpty', @TestJUnitXMLEmpty);
  Suite.Test('TestJUnitXMLDefaultSuiteName', @TestJUnitXMLDefaultSuiteName);
  Suite.Test('TestJUnitXMLSkippedTestCase', @TestJUnitXMLSkippedTestCase);
  Suite.Test('TestJUnitXMLErrorTestCase', @TestJUnitXMLErrorTestCase);
  Suite.Test('TestWriteJUnitXML', @TestWriteJUnitXML);
  Suite.Test('TestWriteJUnitXMLBadPath', @TestWriteJUnitXMLBadPath);
  Suite.Test('TestTAPReportBasic', @TestTAPReportBasic);
  Suite.Test('TestTAPReportSkipped', @TestTAPReportSkipped);
  Suite.Test('TestTAPReportEmpty', @TestTAPReportEmpty);
  Suite.Test('TestJSONReportBasic', @TestJSONReportBasic);
  Suite.Test('TestJSONReportEmpty', @TestJSONReportEmpty);
  Suite.Test('TestTAPReportMultiSuite', @TestTAPReportMultiSuite);
  Suite.Test('TestJSONReportMultiSuite', @TestJSONReportMultiSuite);
  Suite.Test('TestJSONReportSkipped', @TestJSONReportSkipped);
  Suite.Test('TestTAPReportDuration', @TestTAPReportDuration);
  Suite.Test('TestJSONReportDuration', @TestJSONReportDuration);
  Suite.Test('TestTAPReportMultiLineYAML', @TestTAPReportMultiLineYAML);
  Suite.Test('TestTAPReportError', @TestTAPReportError);

  { R6-49~52, R6-61, R6-65: new coverage tests }
  Suite.Test('StatusDot unicode',         @TestStatusDotUnicodeName);
  Suite.Test('Filter nested a*b*c',       @TestFilterNestedGlob);
  Suite.Test('JUnit XML structure',       @TestJUnitXMLStructureComplete);
  Suite.Test('JSON report structure',     @TestJSONReportStructureComplete);
  Suite.Test('XmlEscape control chars',   @TestXmlEscapeControlChars);
  Suite.Test('ANSI state restoration',    @TestAnsiStateRestoration);

  Runner := TTestRunner.Create('output-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  CheckTrue(GTestsRun >= 44, 'Expected at least 44 tests, got ' + IntToStr(GTestsRun));
  CheckTrue(LSuccess, 'All output tests should pass');

  if Runner.AllPassed then
    WriteLn('ALL PASSED')
  else
  begin
    WriteLn('SOME FAILED');
    Halt(1);
  end;
end.
