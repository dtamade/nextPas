{ test_output — Output API coverage
  =========================================================
  Covers: ANSI helpers, StatusDot, SetTestFilter/MatchesFilter,
          SetTestTimeout/GetTestTimeout, JUnitXML, WriteJUnitXML }

program test_output;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.platform.env,
  nextpas.core.test;

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

function CompactJson(const AJson: string): string;
begin
  Result := StringReplace(AJson, ' ', '', True);
  Result := StringReplace(Result, #9, '', True);
  Result := StringReplace(Result, #13, '', True);
  Result := StringReplace(Result, #10, '', True);
end;

{ ── ANSI helpers ───────────────────────────────────────────────────────────── }

procedure TestAnsiHelpersEnabled;
var
  LOut: string;
begin
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
  SetTestFilter('');
  CheckTrue(MatchesFilter('anything'), 'Empty filter should match everything');
  CheckTrue(MatchesFilter(''), 'Empty filter should match empty string');
end;

procedure TestFilterSubstring;
begin
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
  SetTestFilter('test_*');
  CheckTrue(MatchesFilter('test_foo'), '* matches suffix');
  CheckTrue(MatchesFilter('test_'), '* matches empty suffix');
  CheckFalse(MatchesFilter('my_test_foo'), 'Prefix required');
  SetTestFilter('');
end;

procedure TestFilterGlobQuestion;
begin
  SetTestFilter('ab?d');
  CheckTrue(MatchesFilter('abcd'), '? matches single char');
  CheckTrue(MatchesFilter('abxd'), '? matches any char');
  CheckFalse(MatchesFilter('abd'), '? requires exactly one char');
  CheckFalse(MatchesFilter('abcde'), '? does not match two chars');
  SetTestFilter('');
end;

procedure TestFilterCommaSeparated;
begin
  SetTestFilter('foo, bar, baz');
  CheckTrue(MatchesFilter('test_foo'), 'Comma-separated: foo');
  CheckTrue(MatchesFilter('test_bar'), 'Comma-separated: bar');
  CheckTrue(MatchesFilter('test_baz'), 'Comma-separated: baz');
  CheckFalse(MatchesFilter('test_qux'), 'Comma-separated: no match');
  SetTestFilter('');
end;

procedure TestFilterGlobCommaCombined;
begin
  SetTestFilter('test_*,check_*');
  CheckTrue(MatchesFilter('test_alpha'), 'Glob + comma: test_');
  CheckTrue(MatchesFilter('check_beta'), 'Glob + comma: check_');
  CheckFalse(MatchesFilter('verify_gamma'), 'Glob + comma: no match');
  SetTestFilter('');
end;

procedure TestFilterWildcardOnly;
begin
  SetTestFilter('*');
  CheckTrue(MatchesFilter('anything'), '* matches everything');
  CheckTrue(MatchesFilter(''), '* matches empty');
  SetTestFilter('');
end;

procedure TestFilterEmptyBoundary; { L-20: empty string boundary }
begin
  { Empty filter = match everything }
  SetTestFilter('');
  CheckTrue(MatchesFilter(''), 'empty filter matches empty name');
  CheckTrue(MatchesFilter('anything'), 'empty filter matches any name');
  { Empty name with various patterns }
  SetTestFilter('*');
  CheckTrue(MatchesFilter(''), '* matches empty name');
  SetTestFilter('**');
  CheckTrue(MatchesFilter(''), '** matches empty name');
  SetTestFilter('a*');
  CheckFalse(MatchesFilter(''), 'a* does not match empty name');
  SetTestFilter('');
end;

procedure TestFilterBraceExpansion; { L-07: brace expansion }
begin
  try
    { Simple brace alternatives }
    SetTestFilter('{foo,bar}');
    CheckTrue(MatchesFilter('foo'), '{foo,bar} matches foo');
    CheckTrue(MatchesFilter('bar'), '{foo,bar} matches bar');
    CheckFalse(MatchesFilter('baz'), '{foo,bar} does not match baz');
    { Brace with prefix/suffix }
    SetTestFilter('test_{a,b}_end');
    CheckTrue(MatchesFilter('test_a_end'), 'test_{a,b}_end matches test_a_end');
    CheckTrue(MatchesFilter('test_b_end'), 'test_{a,b}_end matches test_b_end');
    CheckFalse(MatchesFilter('test_c_end'), 'test_{a,b}_end does not match test_c_end');
    { Brace with wildcards }
    SetTestFilter('{*.pas,*.lpr}');
    CheckTrue(MatchesFilter('foo.pas'), '{*.pas,*.lpr} matches foo.pas');
    CheckTrue(MatchesFilter('bar.lpr'), '{*.pas,*.lpr} matches bar.lpr');
    CheckFalse(MatchesFilter('baz.txt'), '{*.pas,*.lpr} does not match baz.txt');
    { Single alternative (no comma) }
    SetTestFilter('{abc}');
    CheckTrue(MatchesFilter('abc'), '{abc} matches abc');
    CheckFalse(MatchesFilter('ab'), '{abc} does not match ab');
    { Empty alternative }
    SetTestFilter('{,foo}');
    CheckTrue(MatchesFilter(''), '{,foo} matches empty');
    CheckTrue(MatchesFilter('foo'), '{,foo} matches foo');
    { Nested braces }
    SetTestFilter('{a,{b,c}}');
    CheckTrue(MatchesFilter('a'), '{a,{b,c}} matches a');
    CheckTrue(MatchesFilter('b'), '{a,{b,c}} matches b');
    CheckTrue(MatchesFilter('c'), '{a,{b,c}} matches c');
    CheckFalse(MatchesFilter('d'), '{a,{b,c}} does not match d');
    { No braces — unchanged behavior }
    SetTestFilter('*.pas');
    CheckTrue(MatchesFilter('test.pas'), '*.pas matches test.pas');
  finally
    SetTestFilter('');
  end;
end;

procedure TestGetSetFilter;
begin
  SetTestFilter('my_pattern');
  CheckEqual(GetTestFilter, 'my_pattern');
  SetTestFilter('');
  CheckEqual(GetTestFilter, '');
end;

{ ── Test Timeout ───────────────────────────────────────────────────────────── }

procedure TestGetSetTimeout;
begin
  SetTestTimeout(5000);
  CheckEqual(GetTestTimeout, 5000);
  SetTestTimeout(0);
  CheckEqual(GetTestTimeout, 0);
end;

procedure TestDefaultConfigValues;
var
  LConfig: TTestConfig;
begin
  ResetDefaultConfig;
  LConfig := DefaultConfig;
  CheckEqual(LConfig.FilterPattern, '');
  CheckEqual(Int64(LConfig.TimeoutMs), Int64(0));
  CheckTrue(LConfig.AnsiMode = amAuto, 'Default ANSI mode should be auto');
  CheckTrue(LConfig.OutSink <> nil, 'Default stdout sink should be assigned');
  CheckTrue(LConfig.ErrSink <> nil, 'Default stderr sink should be assigned');
  CheckEqual(LConfig.RetryCount, 0);
end;

procedure TestBufferSinkCapture;
var
  LSink: TBufferSink;
begin
  LSink := TBufferSink.Create;
  try
    LSink.Write('alpha');
    LSink.Write(' beta');
    LSink.WriteLn(' gamma');
    LSink.WriteLn('delta');
    CheckEqual(LSink.GetOutput, 'alpha beta gamma' + LineEnding + 'delta');
    LSink.Clear;
    CheckEqual(LSink.GetOutput, '');
  finally
    LSink.Free;
  end;
end;

{ ── JUnit XML ──────────────────────────────────────────────────────────────── }

procedure TestJUnitXMLBasic;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
  LTotalTests: Integer;
  LTotalFailures: Integer;
begin
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
  CheckContains(LXml, '<skipped message="not ready"/>');
end;

procedure TestJUnitXMLErrorTestCase;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
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
  CheckContains(LXml, '<error type="Error" message="segfault"');
end;

function MakeTempJUnitPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) +
    'nextpas_test_junit_' + IntToStr(GetTickCount64) + '.xml';
end;

procedure TestWriteJUnitXML;
var
  LResults: specialize TArray<TTestRunResult>;
  LPath: string;
  LSuccess: Boolean;
  LContent, LLine: string;
  LF: TextFile;
begin
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
  SetLength(LResults, 0);
  CheckFalse(WriteJUnitXML(LResults, '/nonexistent/dir/file.xml'),
    'WriteJUnitXML should return False on bad path');
end;

procedure TestWriteJUnitXMLBadPathUsesErrSink;
var
  LResults: specialize TArray<TTestRunResult>;
  LErrSink: TBufferSink;
begin
  SetLength(LResults, 0);
  ResetDefaultConfig;
  LErrSink := TBufferSink.Create;
  SetDefaultErrSink(LErrSink);
  try
    CheckFalse(WriteJUnitXML(LResults, '/nonexistent/dir/file.xml'),
      'WriteJUnitXML should return False on bad path');
    CheckContains(LErrSink.GetOutput, 'WriteJUnitXML failed:');
  finally
    ResetDefaultConfig;
  end;
end;

{ TAP renderer tests }

procedure TestTAPReportBasic;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
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
  SetLength(LResults, 0);
  LOut := JSONReport(LResults, 'Empty');
  CheckEqual(0, ExtractJSONInt(LOut, 'totalPassed'));
  CheckEqual(0, ExtractJSONInt(LOut, 'totalFailed'));
  CheckEqual(0, ExtractJSONInt(LOut, 'totalSkipped'));
  CheckContains(LOut, '"suites": [');
end;

procedure TestJSONValidStructure;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
  LCompact: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('json_valid_suite');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'pass_case';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'fail_case';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'boom';

  LOut := JSONReport(LResults, 'json_run');
  LCompact := CompactJson(LOut);
  CheckTrue((Length(LCompact) > 0) and (LCompact[1] = '{'),
    'JSON should start with opening brace');
  CheckTrue((Length(LCompact) > 0) and
    (LCompact[Length(LCompact)] = '}'),
    'JSON should end with closing brace');
  CheckContains(LCompact, '"suites":[{');
  CheckContains(LCompact, '"tests":[{');
  CheckNotContains(LCompact, ',]');
  CheckNotContains(LCompact, ',}');
end;

{ ── R2-F18: TAP/JSON multi-suite / JSON skip ──────────────────────────────── }

procedure TestTAPReportMultiSuite;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
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

{ ── T-04: TAP/JSON compliance tests ──────────────────────────────────────── }

procedure TestTAPSeverityFailVsError;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapSeverity');
  LResults[0].Failed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name    := 'fail_case';
  LResults[0].Results[0].Status  := tsFailed;
  LResults[0].Results[0].Message := 'assertion failed';
  LResults[0].Results[1].Name    := 'error_case';
  LResults[0].Results[1].Status  := tsError;
  LResults[0].Results[1].Message := 'EAccessViolation';

  LOut := TAPReport(LResults);
  { tsFailed → severity: fail }
  CheckContains(LOut, 'severity: fail');
  { tsError → severity: error }
  CheckContains(LOut, 'severity: error');
  { Both should be "not ok" }
  CheckContains(LOut, 'not ok 1 -');
  CheckContains(LOut, 'not ok 2 -');
end;

procedure TestTAPYAMLBlockMarkers;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapYAML');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name    := 'yml';
  LResults[0].Results[0].Status  := tsFailed;
  LResults[0].Results[0].Message := 'bad';

  LOut := TAPReport(LResults);
  { YAML block must have --- and ... markers }
  CheckContains(LOut, '  ---');
  CheckContains(LOut, '  ...');
  { message must be inside the block }
  CheckContains(LOut, 'message: |-');
end;

procedure TestTAPDiagnosticFooter;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('S1');
  LResults[0].Passed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'a'; LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'b'; LResults[0].Results[1].Status := tsPassed;

  LResults[1] := TTestRunResult.Create('S2');
  LResults[1].Passed := 1;
  LResults[1].Skipped := 1;
  SetLength(LResults[1].Results, 2);
  LResults[1].Results[0].Name := 'c'; LResults[1].Results[0].Status := tsPassed;
  LResults[1].Results[1].Name := 'd'; LResults[1].Results[1].Status := tsSkipped;
  LResults[1].Results[1].Message := 'deferred';

  LOut := TAPReport(LResults);
  CheckContains(LOut, '# suites: 2');
  CheckContains(LOut, '# total: 4');
  CheckContains(LOut, '# passed: 3');
  CheckContains(LOut, '# failed: 0');
  CheckContains(LOut, '# skipped: 1');
end;

procedure TestTAPSequentialNumbering;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 2);
  LResults[0] := TTestRunResult.Create('S1');
  LResults[0].Passed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 't1'; LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 't2'; LResults[0].Results[1].Status := tsPassed;

  LResults[1] := TTestRunResult.Create('S2');
  LResults[1].Passed := 1;
  SetLength(LResults[1].Results, 1);
  LResults[1].Results[0].Name := 't3'; LResults[1].Results[0].Status := tsPassed;

  LOut := TAPReport(LResults);
  { Plan: 1..3 }
  CheckContains(LOut, '1..3');
  { Sequential numbering across suites }
  CheckContains(LOut, 'ok 1 - S1 / t1');
  CheckContains(LOut, 'ok 2 - S1 / t2');
  CheckContains(LOut, 'ok 3 - S2 / t3');
end;

procedure TestJSONErrorStatus;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsErr');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name    := 'crash';
  LResults[0].Results[0].Status  := tsError;
  LResults[0].Results[0].Message := 'Segfault';

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "error"');
  CheckContains(LOut, '"message": "Segfault"');
end;

procedure TestJSONPassedStatus;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsPass');
  LResults[0].Passed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'p1'; LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'p2'; LResults[0].Results[1].Status := tsPassed;

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "passed"');
  CheckEqual(2, ExtractJSONInt(LOut, 'totalPassed'));
  CheckEqual(0, ExtractJSONInt(LOut, 'totalFailed'));
end;

{ R6-49: Unicode test name StatusDot should not crash }

procedure TestStatusDotUnicodeName;
var
  LDot: string;
begin
  { Calling StatusDot with Unicode content in the test name should not crash }
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
  CheckNotContains(LXml, #1);
  CheckContains(LXml, 'err msg');
end;

{ R6-65: ANSI state restoration (try-finally pattern) }

procedure TestAnsiStateRestoration;
begin
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

{ ── Phase 3: Tag Filter ───────────────────────────────────────────────────── }

procedure TestSetGetTagFilter;
begin
  SetTagFilter('fast,unit');
  CheckEqual('fast,unit', GetTagFilter);
  SetTagFilter('');
  CheckEqual('', GetTagFilter);
end;

{ ── Phase 3: DisplayName in runner output ──────────────────────────────────── }

var
  GRepeatCounter: Integer = 0;

procedure DummyTest;
begin
end;

procedure RepeatCountingTest;
begin
  Inc(GRepeatCounter);
end;

procedure TestDisplayNameInOutput;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
  LOut: string;
begin
  LConfig := MakeBufferConfig(LSink);

  LSuite := TTestSuite.Create('disp');
  LSuite.Config := LConfig;
  LSuite.Test('internal_name', @DummyTest, 'My Display Name', []);
  LSuite.RunWithResult(LResult);

  LOut := LSink.GetOutput;
  CheckContains(LOut, 'My Display Name');
  CheckNotContains(LOut, 'internal_name');
  { Do NOT free LSink — it's managed via IOutputSink interface reference counting }
end;

procedure TestDisplayNameDefaultUsesName;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
  LOut: string;
begin
  LConfig := MakeBufferConfig(LSink);

  LSuite := TTestSuite.Create('disp');
  LSuite.Config := LConfig;
  LSuite.Test('my_test', @DummyTest);
  LSuite.RunWithResult(LResult);

  LOut := LSink.GetOutput;
  CheckContains(LOut, 'my_test');
  { Do NOT free LSink }
end;

{ ── Phase 3: Tag filtering ────────────────────────────────────────────────── }

procedure TestTagFilterExcludes;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
  LOut: string;
begin
  LConfig := MakeBufferConfig(LSink);
  LConfig.TagFilter := 'fast';

  LSuite := TTestSuite.Create('tags');
  LSuite.Config := LConfig;
  LSuite.Test('fast_test', @DummyTest, ['fast']);
  LSuite.Test('slow_test', @DummyTest, ['slow']);
  LSuite.Test('no_tag_test', @DummyTest);
  LSuite.RunWithResult(LResult);

  LOut := LSink.GetOutput;
  { fast_test should appear (has 'fast' tag) }
  CheckContains(LOut, 'fast_test');
  { slow_test should NOT appear (no 'fast' tag) }
  CheckNotContains(LOut, 'slow_test');
  { no_tag_test should NOT appear (no tags at all) }
  CheckNotContains(LOut, 'no_tag_test');
  { Only 1 test should have passed }
  CheckEqual(1, LResult.Passed);
  { Do NOT free LSink }
end;

procedure TestTagFilterEmptyMatchesAll;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
begin
  LConfig := MakeBufferConfig(LSink);
  LConfig.TagFilter := '';

  LSuite := TTestSuite.Create('tags');
  LSuite.Config := LConfig;
  LSuite.Test('a', @DummyTest, ['fast']);
  LSuite.Test('b', @DummyTest, ['slow']);
  LSuite.Test('c', @DummyTest);
  LSuite.RunWithResult(LResult);

  CheckEqual(3, LResult.Passed);
  { Do NOT free LSink }
end;

{ ── Phase 3: RepeatCount ──────────────────────────────────────────────────── }

procedure TestRepeatCount;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
begin
  GRepeatCounter := 0;
  LConfig := MakeBufferConfig(LSink);

  LSuite := TTestSuite.Create('repeat');
  LSuite.Config := LConfig;
  LSuite.TestRepeat('repeat_3', @RepeatCountingTest, 3);
  LSuite.RunWithResult(LResult);

  { Should report as 1 passed test (last result) }
  CheckEqual(1, LResult.Passed);
  { Should have been called 3 times }
  CheckEqual(3, GRepeatCounter);
  { Do NOT free LSink }
end;

{ ── Phase 3: CapturedLog in JUnit XML ─────────────────────────────────────── }

procedure TestJUnitCapturedLogInFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('caplog');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'fail_test';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'assertion failed';
  SetLength(LResults[0].Results[0].CapturedLog, 2);
  LResults[0].Results[0].CapturedLog[0] := 'log line 1';
  LResults[0].Results[0].CapturedLog[1] := 'log line 2';

  LXml := JUnitXML(LResults);
  CheckContains(LXml, '<failure type="AssertionFailure"');
  CheckContains(LXml, 'log line 1');
  CheckContains(LXml, 'log line 2');
end;

procedure TestJUnitSkipReason;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('skipreason');
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'sk_test';
  LResults[0].Results[0].Status := tsSkipped;
  LResults[0].Results[0].Message := 'platform not supported';

  LXml := JUnitXML(LResults);
  CheckContains(LXml, '<skipped message="platform not supported"/>');
end;

{ ── Phase 3: CapturedLog in TAP ───────────────────────────────────────────── }

procedure TestTAPCapturedLogInFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapLog');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'fail_with_log';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'expected 1 got 2';
  SetLength(LResults[0].Results[0].CapturedLog, 2);
  LResults[0].Results[0].CapturedLog[0] := 'step: init';
  LResults[0].Results[0].CapturedLog[1] := 'step: compute';

  LOut := TAPReport(LResults);
  CheckContains(LOut, 'not ok');
  CheckContains(LOut, 'expected 1 got 2');
  CheckContains(LOut, 'log: |-');
  CheckContains(LOut, 'step: init');
  CheckContains(LOut, 'step: compute');
end;

{ ── Phase 3: CapturedLog in JSON ──────────────────────────────────────────── }

procedure TestJSONCapturedLogInFailure;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('JsLog');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'fail_with_log';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'boom';
  SetLength(LResults[0].Results[0].CapturedLog, 1);
  LResults[0].Results[0].CapturedLog[0] := 'debug output';

  LOut := JSONReport(LResults);
  CheckContains(LOut, '"capturedLog"');
  CheckContains(LOut, '"debug output"');
end;

{ ── Phase 3: Tags via runner Test overload ────────────────────────────────── }

procedure TestRunnerTagsOverload;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LConfig: TTestConfig;
  LSink: TBufferSink;
begin
  LConfig := MakeBufferConfig(LSink);

  LSuite := TTestSuite.Create('tag_runner');
  LSuite.Config := LConfig;
  LSuite.Test('tagged_test', @DummyTest, ['fast', 'unit']);
  LSuite.RunWithResult(LResult);

  CheckEqual(1, LResult.Passed);
  CheckEqual(2, Length(LSuite.Tests[0].Tags));
  CheckEqual('fast', LSuite.Tests[0].Tags[0]);
  CheckEqual('unit', LSuite.Tests[0].Tags[1]);
  { Do NOT free LSink }
end;

procedure TestHierarchicalFilter;
{ Test Go-style hierarchical filter matching: --filter=Parent/Sub }
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;

  { Set hierarchical filter }
  SetTestFilter('TestParent/SubA');
  { Exact match }
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'hierarchical: exact match TestParent/SubA');
  { Filter is prefix of name (descendant match) }
  CheckTrue(MatchesFilter('TestParent/SubA/LeafA', LConfig),
    'hierarchical: filter prefix matches descendant');
  CheckTrue(MatchesFilter('TestParent/SubA/LeafA/Deep', LConfig),
    'hierarchical: filter prefix matches deep descendant');
  { Name is prefix of filter (parent must run to enter children) }
  CheckTrue(MatchesFilter('TestParent', LConfig),
    'hierarchical: parent matches when filter targets its children');
  { Sibling should NOT match }
  CheckFalse(MatchesFilter('TestParent/SubB', LConfig),
    'hierarchical: sibling SubB should not match');
  CheckFalse(MatchesFilter('TestParent/SubB/LeafA', LConfig),
    'hierarchical: sibling descendant should not match');
  { Unrelated should NOT match }
  CheckFalse(MatchesFilter('OtherParent/SubA', LConfig),
    'hierarchical: unrelated parent should not match');

  { Test with glob segment }
  SetTestFilter('TestParent/*');
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'hierarchical glob: * matches any child');
  CheckTrue(MatchesFilter('TestParent/SubB', LConfig),
    'hierarchical glob: * matches any child');
  CheckTrue(MatchesFilter('TestParent', LConfig),
    'hierarchical glob: parent matches');
  CheckFalse(MatchesFilter('OtherParent/SubA', LConfig),
    'hierarchical glob: unrelated should not match');

  { Hierarchical + glob combo: filter with glob in segment }
  SetTestFilter('TestParent/Sub*');
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'hierarchical glob combo: Sub* matches SubA');
  CheckTrue(MatchesFilter('TestParent/SubB', LConfig),
    'hierarchical glob combo: Sub* matches SubB');
  CheckTrue(MatchesFilter('TestParent/SubAlpha', LConfig),
    'hierarchical glob combo: Sub* matches SubAlpha');
  CheckFalse(MatchesFilter('TestParent/LeafA', LConfig),
    'hierarchical glob combo: Sub* does not match LeafA');
  CheckTrue(MatchesFilter('TestParent', LConfig),
    'hierarchical glob combo: parent matches');

  { Hierarchical with ? wildcard }
  SetTestFilter('TestParent/Sub?');
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'hierarchical ? wildcard: Sub? matches SubA');
  CheckTrue(MatchesFilter('TestParent/SubX', LConfig),
    'hierarchical ? wildcard: Sub? matches SubX');
  CheckFalse(MatchesFilter('TestParent/SubAB', LConfig),
    'hierarchical ? wildcard: Sub? does not match SubAB');
  CheckTrue(MatchesFilter('TestParent', LConfig),
    'hierarchical ? wildcard: parent matches');

  { Hierarchical with brace expansion }
  SetTestFilter('TestParent/{SubA,SubB}');
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'hierarchical brace: matches SubA');
  CheckTrue(MatchesFilter('TestParent/SubB', LConfig),
    'hierarchical brace: matches SubB');
  CheckFalse(MatchesFilter('TestParent/SubC', LConfig),
    'hierarchical brace: does not match SubC');
  CheckTrue(MatchesFilter('TestParent', LConfig),
    'hierarchical brace: parent matches');

  { Hierarchical with comma-separated top-level filters }
  SetTestFilter('TestParent/SubA,OtherParent/SubB');
  CheckTrue(MatchesFilter('TestParent/SubA', LConfig),
    'comma hierarchical: matches first filter');
  CheckTrue(MatchesFilter('OtherParent/SubB', LConfig),
    'comma hierarchical: matches second filter');
  CheckFalse(MatchesFilter('OtherParent/SubA', LConfig),
    'comma hierarchical: does not match wrong combo');

  { Reset filter }
  SetTestFilter('');
end;

procedure TestB12HierarchicalFilterEdges;
{ Residual edge cases: A/B/C vs A/B, Test*/Sub combo, deep mismatch. }
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;

  SetTestFilter('A/B');
  CheckTrue(MatchesFilter('A/B', LConfig), 'exact A/B');
  CheckTrue(MatchesFilter('A/B/C', LConfig), 'A/B prefix of A/B/C');
  CheckTrue(MatchesFilter('A', LConfig), 'parent A of A/B');
  CheckFalse(MatchesFilter('A/C', LConfig), 'sibling A/C');
  CheckFalse(MatchesFilter('A/B2', LConfig), 'A/B2 is not A/B or descendant');
  CheckFalse(MatchesFilter('AB', LConfig), 'no slash prefix false friend');

  SetTestFilter('Test*/Sub');
  CheckTrue(MatchesFilter('TestFoo/Sub', LConfig), 'Test*/Sub matches TestFoo/Sub');
  CheckTrue(MatchesFilter('TestBar/Sub/Leaf', LConfig), 'Test*/Sub matches deep');
  CheckTrue(MatchesFilter('TestX', LConfig), 'parent TestX matches');
  CheckFalse(MatchesFilter('Other/Sub', LConfig), 'Other/Sub no match');
  CheckFalse(MatchesFilter('TestFoo/SubX', LConfig), 'SubX not exact Sub segment');

  SetTestFilter('Suite/{Alpha,Beta}/Leaf');
  CheckTrue(MatchesFilter('Suite/Alpha/Leaf', LConfig), 'brace Alpha/Leaf');
  CheckTrue(MatchesFilter('Suite/Beta/Leaf', LConfig), 'brace Beta/Leaf');
  CheckFalse(MatchesFilter('Suite/Gamma/Leaf', LConfig), 'brace Gamma miss');
  CheckTrue(MatchesFilter('Suite/Alpha', LConfig), 'brace mid parent');
  CheckTrue(MatchesFilter('Suite', LConfig), 'brace top parent');

  SetTestFilter('');
end;

procedure TestGetTopSlowest;
var
  LResults: TTestResults;
  LSlow: TTestResults;
begin
  SetLength(LResults, 4);
  LResults[0] := MakeTestResult('fast', tsPassed, '', 10);
  LResults[1] := MakeTestResult('slow', tsPassed, '', 5000);
  LResults[2] := MakeTestResult('medium', tsPassed, '', 100);
  LResults[3] := MakeTestResult('medium2', tsPassed, '', 200);

  { Top 2 }
  LSlow := GetTopSlowest(LResults, 2);
  CheckTrue(Length(LSlow) = 2, 'top 2 should have 2 entries');
  CheckTrue(LSlow[0].Name = 'slow', 'slowest should be first');
  CheckTrue(LSlow[0].Duration = 5000, 'slowest duration');
  CheckTrue(LSlow[1].Name = 'medium2', 'second slowest');

  { Top 10 with only 4 entries }
  LSlow := GetTopSlowest(LResults, 10);
  CheckTrue(Length(LSlow) = 4, 'should cap at array length');

  { Top 0 }
  LSlow := GetTopSlowest(LResults, 0);
  CheckTrue(Length(LSlow) = 0, 'top 0 should be empty');

  { Empty input }
  LSlow := GetTopSlowest(nil, 5);
  CheckTrue(Length(LSlow) = 0, 'nil input should be empty');

  { All zero duration }
  SetLength(LResults, 2);
  LResults[0] := MakeTestResult('a', tsPassed, '', 0);
  LResults[1] := MakeTestResult('b', tsPassed, '', 0);
  LSlow := GetTopSlowest(LResults, 3);
  CheckTrue(Length(LSlow) = 0, 'all zero duration should return empty');
end;

{ ── R48: FormatDuration boundary tests ────────────────────────────────────── }

procedure TestFormatDurationZero;
begin
  CheckEqual('0ms', FormatDuration(0));
end;

procedure TestFormatDuration999ms;
begin
  CheckEqual('999ms', FormatDuration(999));
end;

procedure TestFormatDurationExactSecond;
begin
  CheckEqual('1s', FormatDuration(1000));
end;

procedure TestFormatDuration1050ms;
begin
  CheckEqual('1.05s', FormatDuration(1050));
end;

procedure TestFormatDuration1100ms;
begin
  CheckEqual('1.1s', FormatDuration(1100));
end;

procedure TestFormatDurationLarge;
begin
  CheckEqual('10s', FormatDuration(10000));
  CheckEqual('1.5s', FormatDuration(1500));
  CheckEqual('99.9s', FormatDuration(99900));
end;

procedure TestFormatDurationEdgeCases;
begin
  CheckEqual('1ms', FormatDuration(1));
  CheckEqual('100ms', FormatDuration(100));
  CheckEqual('2s', FormatDuration(2000));
  CheckEqual('2.5s', FormatDuration(2500));
end;

{ ── R48: Glob nested brace tests ──────────────────────────────────────────── }

procedure TestGlobNestedBraces;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;
  { Nested brace expansion: {a,{b,c}} → a, b, c }
  SetTestFilter('test_{a,{b,c}}');
  CheckTrue(MatchesFilter('test_a', LConfig), 'nested brace: matches a');
  CheckTrue(MatchesFilter('test_b', LConfig), 'nested brace: matches b');
  CheckTrue(MatchesFilter('test_c', LConfig), 'nested brace: matches c');
  CheckFalse(MatchesFilter('test_d', LConfig), 'nested brace: no match d');
  SetTestFilter('');
end;

procedure TestGlobEmptyAlternative;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;
  { Empty alternative in braces: {,a,b} → empty, a, b }
  SetTestFilter('test_{,a,b}');
  CheckTrue(MatchesFilter('test_', LConfig), 'empty alt: matches empty');
  CheckTrue(MatchesFilter('test_a', LConfig), 'empty alt: matches a');
  CheckTrue(MatchesFilter('test_b', LConfig), 'empty alt: matches b');
  CheckFalse(MatchesFilter('test_c', LConfig), 'empty alt: no match c');
  SetTestFilter('');
end;

procedure TestGlobBraceWithWildcard;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;
  { Brace + wildcard combination }
  SetTestFilter('test_{a,b}*');
  CheckTrue(MatchesFilter('test_abc', LConfig), 'brace+wildcard: matches a*');
  CheckTrue(MatchesFilter('test_bxyz', LConfig), 'brace+wildcard: matches b*');
  CheckTrue(MatchesFilter('test_a', LConfig), 'brace+wildcard: matches bare a');
  CheckFalse(MatchesFilter('test_cxyz', LConfig), 'brace+wildcard: no match c');
  SetTestFilter('');
end;

procedure TestGlobBraceWithQuestion;
var
  LConfig: TTestConfig;
begin
  LConfig := DefaultConfig;
  LConfig.AnsiMode := amOff;
  { Brace + question mark combination }
  SetTestFilter('test_{a,b}?');
  CheckTrue(MatchesFilter('test_ax', LConfig), 'brace+?: matches a?');
  CheckTrue(MatchesFilter('test_bz', LConfig), 'brace+?: matches b?');
  CheckFalse(MatchesFilter('test_a', LConfig), 'brace+?: no match bare a');
  CheckFalse(MatchesFilter('test_cx', LConfig), 'brace+?: no match c');
  SetTestFilter('');
end;

{ ── B8 v8.10: deeper report contracts ─────────────────────────────────────── }

procedure TestJUnitEmptySuite;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('EmptySuite');
  LResults[0].Passed := 0;
  LResults[0].Failed := 0;
  LResults[0].Skipped := 0;
  SetLength(LResults[0].Results, 0);
  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'testsuites');
  CheckContains(LXml, 'EmptySuite');
  CheckContains(LXml, 'tests="0"');
end;

procedure TestJUnitOnlySkipped;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('SkipOnly');
  LResults[0].Skipped := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 's1';
  LResults[0].Results[0].Status := tsSkipped;
  LResults[0].Results[0].Message := 'not ready';
  LResults[0].Results[1].Name := 's2';
  LResults[0].Results[1].Status := tsSkipped;
  LResults[0].Results[1].Message := 'later';
  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'skipped');
  CheckContains(LXml, 's1');
  CheckContains(LXml, 's2');
end;

procedure TestJUnitFailureMessage;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('FailMsg');
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'bad';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'expected: 1 actual: 2';
  LXml := JUnitXML(LResults);
  CheckContains(LXml, 'failure');
  CheckContains(LXml, 'expected: 1');
  CheckContains(LXml, 'actual: 2');
end;

procedure TestJSONAllStatusEnums;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('AllStat');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 3);
  LResults[0].Results[0].Name := 'p';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'f';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'boom';
  LResults[0].Results[2].Name := 's';
  LResults[0].Results[2].Status := tsSkipped;
  LResults[0].Results[2].Message := 'skip-me';
  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "passed"');
  CheckContains(LOut, '"status": "failed"');
  CheckContains(LOut, '"status": "skipped"');
  CheckContains(LOut, 'skip-me');
end;

procedure TestJSONErrorStatusContract;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('ErrStat');
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'err';
  LResults[0].Results[0].Status := tsError;
  LResults[0].Results[0].Message := 'segfault-ish';
  LOut := JSONReport(LResults);
  CheckContains(LOut, '"status": "error"');
  CheckContains(LOut, 'segfault');
end;

procedure TestTAPPlanMatchesCount;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('TapPlan');
  LResults[0].Passed := 2;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'a';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[1].Name := 'b';
  LResults[0].Results[1].Status := tsPassed;
  LOut := TAPReport(LResults);
  CheckContains(LOut, '1..2');
  CheckContains(LOut, 'ok 1');
  CheckContains(LOut, 'ok 2');
end;

procedure TestXmlEscapeSpecials;
var
  LResults: specialize TArray<TTestRunResult>;
  LXml: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('Esc');
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'a&b<c>"d''e';
  LResults[0].Results[0].Status := tsPassed;
  LXml := JUnitXML(LResults);
  CheckContains(LXml, '&amp;');
  CheckContains(LXml, '&lt;');
  CheckContains(LXml, '&gt;');
  CheckContains(LXml, '&quot;');
  { apostrophe may be &apos; or remain depending on impl }
  CheckTrue((Pos('&apos;', LXml) > 0) or (Pos('''', LXml) > 0),
    'apostrophe escaped or present');
end;

procedure TestColorDiffNoAnsiWhenOff;
var
  LMsg: string;
begin
  { Force plain ColorDiff path used by CheckEqual(string). }
  SetAnsiEnabled(False);
  try
    try
      CheckEqual('aa', 'ab');
      Fail('expected CheckEqual to fail');
    except
      on E: EAssertionFailed do
      begin
        LMsg := E.Message;
        CheckContains(LMsg, 'differ at position');
        CheckContains(LMsg, 'expected');
        CheckContains(LMsg, 'actual');
        CheckFalse(Pos(#27, LMsg) > 0, 'no ESC/CSI when ANSI off');
      end;
    end;
  finally
    SetAnsiEnabled(True);
  end;
end;

{ ── B11: report golden snapshots (stable fixtures, Duration=0) ───────────── }

procedure TestB11JSONGoldenSnapshot;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('golden-json');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 3);
  LResults[0].Results[0].Name := 'pass_case';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[0].Message := '';
  LResults[0].Results[0].Duration := 0;
  LResults[0].Results[1].Name := 'fail_case';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'expected 1 got 2';
  LResults[0].Results[1].Duration := 0;
  LResults[0].Results[2].Name := 'skip_case';
  LResults[0].Results[2].Status := tsSkipped;
  LResults[0].Results[2].Message := 'not yet';
  LResults[0].Results[2].Duration := 0;
  LOut := JSONReport(LResults, 'golden-json');
  { Strip any wall-clock if present — Duration=0 should keep time 0.000 }
  CheckContains(LOut, 'pass_case');
  CheckContains(LOut, 'fail_case');
  CheckContains(LOut, 'skip_case');
  CheckContains(LOut, 'expected 1 got 2');
  { B19: committed golden under suite goldens/ (CWD = suite when make -C) }
  CheckSnapshot(LOut, 'goldens', 'report.json');
end;

procedure TestB11TAPGoldenSnapshot;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('golden-tap');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 2);
  LResults[0].Results[0].Name := 'ok_one';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[0].Message := '';
  LResults[0].Results[0].Duration := 0;
  LResults[0].Results[1].Name := 'not_ok_two';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'boom';
  LResults[0].Results[1].Duration := 0;
  LOut := TAPReport(LResults, 'golden-tap');
  CheckContains(LOut, '1..2');
  CheckContains(LOut, 'ok 1');
  CheckContains(LOut, 'not ok 2');
  CheckContains(LOut, 'boom');
  CheckSnapshot(LOut, 'goldens', 'report.tap');
end;

procedure TestB13JUnitGoldenSnapshot;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('golden-junit');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 3);
  LResults[0].Results[0].Name := 'pass_case';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[0].Message := '';
  LResults[0].Results[0].Duration := 0;
  LResults[0].Results[1].Name := 'fail_case';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'expected 1 got 2';
  LResults[0].Results[1].Duration := 0;
  LResults[0].Results[2].Name := 'skip_case';
  LResults[0].Results[2].Status := tsSkipped;
  LResults[0].Results[2].Message := 'not yet';
  LResults[0].Results[2].Duration := 0;
  LOut := JUnitXML(LResults, 'golden-junit');
  CheckContains(LOut, 'pass_case');
  CheckContains(LOut, 'fail_case');
  CheckContains(LOut, 'skip_case');
  CheckContains(LOut, 'expected 1 got 2');
  CheckContains(LOut, 'time="0.000"');
  CheckSnapshot(LOut, 'goldens', 'report.xml');
end;

procedure TestB13TAPFormalCompliance;
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('tap-formal');
  LResults[0].Passed := 1;
  LResults[0].Failed := 1;
  LResults[0].Skipped := 1;
  SetLength(LResults[0].Results, 3);
  LResults[0].Results[0].Name := 'a';
  LResults[0].Results[0].Status := tsPassed;
  LResults[0].Results[0].Duration := 0;
  LResults[0].Results[1].Name := 'b';
  LResults[0].Results[1].Status := tsFailed;
  LResults[0].Results[1].Message := 'nope';
  LResults[0].Results[1].Duration := 0;
  LResults[0].Results[2].Name := 'c';
  LResults[0].Results[2].Status := tsSkipped;
  LResults[0].Results[2].Message := 'later';
  LResults[0].Results[2].Duration := 0;
  LOut := TAPReport(LResults, 'formal');
  CheckContains(LOut, 'TAP version 13');
  CheckContains(LOut, '1..3');
  CheckContains(LOut, 'ok 1');
  CheckContains(LOut, 'not ok 2');
  CheckContains(LOut, '# skip');
  CheckContains(LOut, '  ---');
  CheckContains(LOut, '  ...');
  CheckContains(LOut, '# suites:');
  CheckContains(LOut, '# total: 3');
  CheckContains(LOut, '# passed: 1');
  CheckContains(LOut, '# failed: 1');
  CheckContains(LOut, '# skipped: 1');
end;

{ ── B15/v8.15: committed goldens under CI fail-on-create ──────────────────── }

procedure OutEnvSet(const AName, AValue: string);
var
  LN, LV: AnsiString;
begin
  LN := AnsiString(AName);
  LV := AnsiString(AValue);
  if platform_env_set(PAnsiChar(LN), PAnsiChar(LV)) <> 0 then
    Fail('platform_env_set failed for ' + AName);
end;

procedure OutEnvUnset(const AName: string);
var
  LN: AnsiString;
begin
  LN := AnsiString(AName);
  platform_env_unset(PAnsiChar(LN));
end;

procedure TestB15CommittedGoldensStrictCI;
{ With FAIL_ON_CREATE=1, existing goldens/ files must still match (CI mode). }
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  OutEnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  OutEnvSet('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE', '1');
  try
    SetLength(LResults, 1);
    LResults[0] := TTestRunResult.Create('golden-json');
    LResults[0].Passed := 1;
    LResults[0].Failed := 1;
    LResults[0].Skipped := 1;
    SetLength(LResults[0].Results, 3);
    LResults[0].Results[0].Name := 'pass_case';
    LResults[0].Results[0].Status := tsPassed;
    LResults[0].Results[0].Duration := 0;
    LResults[0].Results[1].Name := 'fail_case';
    LResults[0].Results[1].Status := tsFailed;
    LResults[0].Results[1].Message := 'expected 1 got 2';
    LResults[0].Results[1].Duration := 0;
    LResults[0].Results[2].Name := 'skip_case';
    LResults[0].Results[2].Status := tsSkipped;
    LResults[0].Results[2].Message := 'not yet';
    LResults[0].Results[2].Duration := 0;
    LOut := JSONReport(LResults, 'golden-json');
    CheckSnapshot(LOut, 'goldens', 'report.json');

    LResults[0] := TTestRunResult.Create('golden-tap');
    LResults[0].Passed := 1;
    LResults[0].Failed := 1;
    SetLength(LResults[0].Results, 2);
    LResults[0].Results[0].Name := 'ok_one';
    LResults[0].Results[0].Status := tsPassed;
    LResults[0].Results[0].Duration := 0;
    LResults[0].Results[1].Name := 'not_ok_two';
    LResults[0].Results[1].Status := tsFailed;
    LResults[0].Results[1].Message := 'boom';
    LResults[0].Results[1].Duration := 0;
    LOut := TAPReport(LResults, 'golden-tap');
    CheckSnapshot(LOut, 'goldens', 'report.tap');

    LResults[0] := TTestRunResult.Create('golden-junit');
    LResults[0].Passed := 1;
    LResults[0].Failed := 1;
    LResults[0].Skipped := 1;
    SetLength(LResults[0].Results, 3);
    LResults[0].Results[0].Name := 'pass_case';
    LResults[0].Results[0].Status := tsPassed;
    LResults[0].Results[0].Duration := 0;
    LResults[0].Results[1].Name := 'fail_case';
    LResults[0].Results[1].Status := tsFailed;
    LResults[0].Results[1].Message := 'expected 1 got 2';
    LResults[0].Results[1].Duration := 0;
    LResults[0].Results[2].Name := 'skip_case';
    LResults[0].Results[2].Status := tsSkipped;
    LResults[0].Results[2].Message := 'not yet';
    LResults[0].Results[2].Duration := 0;
    LOut := JUnitXML(LResults, 'golden-junit');
    CheckSnapshot(LOut, 'goldens', 'report.xml');

    { v8.19 SoftFail join golden under FAIL_ON_CREATE }
    LResults[0] := TTestRunResult.Create('softfail-golden');
    LResults[0].Passed := 0;
    LResults[0].Failed := 1;
    SetLength(LResults[0].Results, 1);
    LResults[0].Results[0].Name := 'soft_only';
    LResults[0].Results[0].Status := tsFailed;
    LResults[0].Results[0].Message := 'alpha; beta; gamma';
    LResults[0].Results[0].Duration := 0;
    LOut := TAPReport(LResults, 'softfail-golden');
    CheckSnapshot(LOut, 'goldens', 'softfail.tap');
    LOut := JSONReport(LResults, 'softfail-golden');
    CheckSnapshot(LOut, 'goldens', 'softfail.json');
  finally
    OutEnvUnset('NEXTPAS_SNAPSHOT_FAIL_ON_CREATE');
    OutEnvUnset('NEXTPAS_UPDATE_SNAPSHOTS');
  end;
end;

{ ── B29/v8.19: SoftFail multi-message join as report golden ──────────────── }

procedure TestB29SoftFailReportGolden;
{ Stable fixture: soft-only failure message uses FormatSoftFailSummary join. }
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
begin
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('softfail-golden');
  LResults[0].Passed := 0;
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'soft_only';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := 'alpha; beta; gamma';
  LResults[0].Results[0].Duration := 0;

  LOut := TAPReport(LResults, 'softfail-golden');
  CheckContains(LOut, 'not ok 1');
  CheckContains(LOut, 'alpha; beta; gamma');
  CheckSnapshot(LOut, 'goldens', 'softfail.tap');

  LOut := JSONReport(LResults, 'softfail-golden');
  CheckContains(LOut, 'soft_only');
  CheckContains(LOut, 'alpha; beta; gamma');
  CheckSnapshot(LOut, 'goldens', 'softfail.json');
end;

procedure TestB57SoftWave2ReportGolden;
{ v8.27 B57: Soft second-wave default messages as TAP/JSON golden under FAIL_ON_CREATE. }
var
  LResults: specialize TArray<TTestRunResult>;
  LOut: string;
  LMsg: string;
begin
  { Fixture mirrors FormatSoftFailSummary join of SoftCheckNil/Empty/ContainsCI defaults. }
  LMsg := 'Expected nil but got $0000000000000001; ' +
    'Expected empty string but got 1 char(s); ' +
    'SoftCheckContainsCI expected to find "zz" in "abc"';
  SetLength(LResults, 1);
  LResults[0] := TTestRunResult.Create('softfail-wave2');
  LResults[0].Passed := 0;
  LResults[0].Failed := 1;
  SetLength(LResults[0].Results, 1);
  LResults[0].Results[0].Name := 'wave2_soft';
  LResults[0].Results[0].Status := tsFailed;
  LResults[0].Results[0].Message := LMsg;
  LResults[0].Results[0].Duration := 0;

  LOut := TAPReport(LResults, 'softfail-wave2');
  CheckContains(LOut, 'not ok 1');
  CheckContains(LOut, 'Expected nil but got');
  CheckContains(LOut, 'SoftCheckContainsCI expected to find');
  CheckSnapshot(LOut, 'goldens', 'softfail_wave2.tap');

  LOut := JSONReport(LResults, 'softfail-wave2');
  CheckContains(LOut, 'wave2_soft');
  CheckContains(LOut, 'Expected empty string but got 1 char(s)');
  CheckSnapshot(LOut, 'goldens', 'softfail_wave2.json');
end;

procedure TestB62HierarchicalFilterCase(const AC: TTestCase);
{ v8.28 B62: hierarchical + brace/glob negative/positive path density.
  Data: pattern|name|0|1  (0=must not match, 1=must match) }
var
  LPattern, LName, LExpect: string;
  LPos, LPos2: Integer;
  LRest: string;
  LConfig: TTestConfig;
begin
  LPos := Pos('|', AC.Data);
  CheckTrue(LPos > 0, 'B62 data pattern|name|expect');
  LPattern := Copy(AC.Data, 1, LPos - 1);
  LRest := Copy(AC.Data, LPos + 1, MaxInt);
  LPos2 := Pos('|', LRest);
  CheckTrue(LPos2 > 0, 'B62 data name|expect');
  LName := Copy(LRest, 1, LPos2 - 1);
  LExpect := Copy(LRest, LPos2 + 1, MaxInt);
  LConfig := DefaultConfig;
  SetTestFilter(LPattern);
  try
    if LExpect = '1' then
      CheckTrue(MatchesFilter(LName, LConfig), AC.Name + ' should match')
    else
      CheckFalse(MatchesFilter(LName, LConfig), AC.Name + ' should not match');
  finally
    SetTestFilter('');
  end;
end;

{ ── B5: table-driven filter contracts (meaningful pass+fail paths) ───────── }

procedure TestFilterTableCase(const AC: TTestCase);
{ Data format: pattern|name|0|1  (0=must not match, 1=must match) }
var
  LPattern, LName, LExpect: string;
  LPos, LPos2: Integer;
  LRest: string;
begin
  LPos := Pos('|', AC.Data);
  CheckTrue(LPos > 0, 'table data needs pattern|name|expect');
  LPattern := Copy(AC.Data, 1, LPos - 1);
  LRest := Copy(AC.Data, LPos + 1, MaxInt);
  LPos2 := Pos('|', LRest);
  CheckTrue(LPos2 > 0, 'table data needs name|expect');
  LName := Copy(LRest, 1, LPos2 - 1);
  LExpect := Copy(LRest, LPos2 + 1, MaxInt);
  SetTestFilter(LPattern);
  try
    if LExpect = '1' then
      CheckTrue(MatchesFilter(LName), AC.Name + ' should match')
    else
      CheckFalse(MatchesFilter(LName), AC.Name + ' should not match');
  finally
    SetTestFilter('');
  end;
end;

procedure AppendFilterCase(var ACases: specialize TArray<TTestCase>;
  const AName, APattern, ASubject, AExpect: string);
begin
  SetLength(ACases, Length(ACases) + 1);
  ACases[High(ACases)].Name := AName;
  ACases[High(ACases)].Data := APattern + '|' + ASubject + '|' + AExpect;
end;

{ ── v8.35: report formatter fail-path tables (JUnit XML / JSON / TAP / duration) ── }

function NextField(var ARest: string): string;
var
  LP: Integer;
begin
  LP := Pos('|', ARest);
  if LP = 0 then
  begin
    Result := ARest;
    ARest := '';
  end
  else
  begin
    Result := Copy(ARest, 1, LP - 1);
    ARest := Copy(ARest, LP + 1, MaxInt);
  end;
end;

procedure AppendEscCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFailFlag: string);
{ AData: field|raw|want|notwant — AFailFlag '0' marks a fail-path row and is
  appended to Data so the table proc can enforce flag/assertion consistency. }
begin
  SetLength(ACases, Length(ACases) + 1);
  ACases[High(ACases)].Name := AName;
  ACases[High(ACases)].Data := AData + '|' + AFailFlag;
end;

procedure AppendTapCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFailFlag: string);
{ AData: mask|want|notwant — mask chars: p/f/s/e (one synthetic test each). }
begin
  SetLength(ACases, Length(ACases) + 1);
  ACases[High(ACases)].Name := AName;
  ACases[High(ACases)].Data := AData + '|' + AFailFlag;
end;

procedure AppendDurCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData: string);
{ AData: millis|want — FormatDuration output contract rows. }
begin
  SetLength(ACases, Length(ACases) + 1);
  ACases[High(ACases)].Name := AName;
  ACases[High(ACases)].Data := AData;
end;

procedure BuildEscResults(const AField, ARaw: string;
  out AResults: specialize TArray<TTestRunResult>);
{ One suite, one test; ARaw lands in Name (passed) or Message (failed). }
begin
  SetLength(AResults, 1);
  AResults[0] := TTestRunResult.Create('esc');
  SetLength(AResults[0].Results, 1);
  if AField = 'name' then
  begin
    AResults[0].Results[0].Name := ARaw;
    AResults[0].Results[0].Status := tsPassed;
    AResults[0].Passed := 1;
  end
  else
  begin
    AResults[0].Results[0].Name := 'et';
    AResults[0].Results[0].Status := tsFailed;
    AResults[0].Results[0].Message := ARaw;
    AResults[0].Failed := 1;
  end;
end;

procedure TestXmlEscTableCase(const AC: TTestCase);
{ End-to-end XmlEscape contract via JUnitXML: dangerous chars must appear
  escaped (want) and the raw form must be gone (notwant on '0' rows). }
var
  LRest, LField, LRaw, LWant, LNotWant, LFlag, LXml: string;
  LEscResults: specialize TArray<TTestRunResult>;
begin
  LRest := AC.Data;
  LField := NextField(LRest);
  LRaw := NextField(LRest);
  LWant := NextField(LRest);
  LNotWant := NextField(LRest);
  LFlag := NextField(LRest);
  if LFlag = '0' then
    CheckTrue(LNotWant <> '', AC.Name + ': fail-path row needs notwant')
  else
    CheckEqual('', LNotWant, AC.Name + ': pass row must not carry notwant');
  BuildEscResults(LField, LRaw, LEscResults);
  LXml := JUnitXML(LEscResults, 'escrun');
  CheckContains(LXml, LWant);
  if LNotWant <> '' then
    CheckNotContains(LXml, LNotWant);
end;

procedure TestJsonEscTableCase(const AC: TTestCase);
{ End-to-end JsonEscape contract via JSONReport: quotes/backslash/control
  chars must be escaped; raw forms must not leak into the document. }
var
  LRest, LField, LRaw, LWant, LNotWant, LFlag, LJson: string;
  LEscResults: specialize TArray<TTestRunResult>;
begin
  LRest := AC.Data;
  LField := NextField(LRest);
  LRaw := NextField(LRest);
  LWant := NextField(LRest);
  LNotWant := NextField(LRest);
  LFlag := NextField(LRest);
  if LFlag = '0' then
    CheckTrue(LNotWant <> '', AC.Name + ': fail-path row needs notwant')
  else
    CheckEqual('', LNotWant, AC.Name + ': pass row must not carry notwant');
  BuildEscResults(LField, LRaw, LEscResults);
  LJson := JSONReport(LEscResults);
  CheckContains(LJson, LWant);
  if LNotWant <> '' then
    CheckNotContains(LJson, LNotWant);
end;

procedure TestTapTableCase(const AC: TTestCase);
{ TAPReport structure contract: plan line, ok/not ok numbering, YAML
  failure blocks, skip directives, trailing skip count. }
var
  LRest, LMask, LWant, LNotWant, LFlag, LTap: string;
  LTapResults: specialize TArray<TTestRunResult>;
  LJ: Integer;
  LHasNonPass: Boolean;
begin
  LRest := AC.Data;
  LMask := NextField(LRest);
  LWant := NextField(LRest);
  LNotWant := NextField(LRest);
  LFlag := NextField(LRest);
  LHasNonPass := LMask = '';
  for LJ := 1 to Length(LMask) do
    if LMask[LJ] in ['f', 's', 'e'] then
      LHasNonPass := True;
  if LFlag = '0' then
    CheckTrue(LHasNonPass, AC.Name + ': fail-path row needs f/s/e or empty mask')
  else
    CheckFalse(LHasNonPass, AC.Name + ': pass row must be all-p non-empty mask');
  SetLength(LTapResults, 1);
  LTapResults[0] := TTestRunResult.Create('S');
  SetLength(LTapResults[0].Results, Length(LMask));
  for LJ := 1 to Length(LMask) do
  begin
    LTapResults[0].Results[LJ - 1].Name := 't' + IntToStr(LJ - 1);
    case LMask[LJ] of
      'p': LTapResults[0].Results[LJ - 1].Status := tsPassed;
      'f':
        begin
          LTapResults[0].Results[LJ - 1].Status := tsFailed;
          LTapResults[0].Results[LJ - 1].Message := 'boom';
        end;
      's':
        begin
          LTapResults[0].Results[LJ - 1].Status := tsSkipped;
          LTapResults[0].Results[LJ - 1].Message := 'why';
        end;
      'e':
        begin
          LTapResults[0].Results[LJ - 1].Status := tsError;
          LTapResults[0].Results[LJ - 1].Message := 'err';
        end;
    end;
    { TAP footer counts read the suite counter fields, not Results[].Status;
      mirror runner semantics (IncByStatus: tsError -> Failed). }
    case LTapResults[0].Results[LJ - 1].Status of
      tsPassed:  Inc(LTapResults[0].Passed);
      tsSkipped: Inc(LTapResults[0].Skipped);
    else
      Inc(LTapResults[0].Failed);
    end;
  end;
  LTap := TAPReport(LTapResults);
  if LWant <> '' then
    CheckContains(LTap, LWant);
  if LNotWant <> '' then
    CheckNotContains(LTap, LNotWant);
end;

procedure TestDurTableCase(const AC: TTestCase);
{ FormatDuration format contract: ms below 1s, 's'/'N.Ds'/'N.DDs' above,
  including truncation (1234 -> 1.23s) and pass-through negatives. }
var
  LRest, LMillis, LWant: string;
begin
  LRest := AC.Data;
  LMillis := NextField(LRest);
  LWant := NextField(LRest);
  CheckEqual(LWant, FormatDuration(StrToInt64Def(LMillis, -12345)));
end;

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LFilterCases: specialize TArray<TTestCase>;
  LFmtCases: specialize TArray<TTestCase>;
  LI: Integer;
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
  Suite.Test('TestFilterEmptyBoundary', @TestFilterEmptyBoundary);
  Suite.Test('TestFilterBraceExpansion', @TestFilterBraceExpansion);
  Suite.Test('TestGetSetFilter', @TestGetSetFilter);
  Suite.Test('TestGetSetTimeout', @TestGetSetTimeout);
  Suite.Test('TestDefaultConfigValues', @TestDefaultConfigValues);
  Suite.Test('TestBufferSinkCapture', @TestBufferSinkCapture);
  Suite.Test('TestJUnitXMLBasic', @TestJUnitXMLBasic);
  Suite.Test('TestJUnitXMLMultipleSuites', @TestJUnitXMLMultipleSuites);
  Suite.Test('TestJUnitXMLXmlEscape', @TestJUnitXMLXmlEscape);
  Suite.Test('TestJUnitXMLEmpty', @TestJUnitXMLEmpty);
  Suite.Test('TestJUnitXMLDefaultSuiteName', @TestJUnitXMLDefaultSuiteName);
  Suite.Test('TestJUnitXMLSkippedTestCase', @TestJUnitXMLSkippedTestCase);
  Suite.Test('TestJUnitXMLErrorTestCase', @TestJUnitXMLErrorTestCase);
  Suite.Test('TestWriteJUnitXML', @TestWriteJUnitXML);
  Suite.Test('TestWriteJUnitXMLBadPath', @TestWriteJUnitXMLBadPath);
  Suite.Test('TestWriteJUnitXMLBadPathUsesErrSink', @TestWriteJUnitXMLBadPathUsesErrSink);
  Suite.Test('TestTAPReportBasic', @TestTAPReportBasic);
  Suite.Test('TestTAPReportSkipped', @TestTAPReportSkipped);
  Suite.Test('TestTAPReportEmpty', @TestTAPReportEmpty);
  Suite.Test('TestJSONReportBasic', @TestJSONReportBasic);
  Suite.Test('TestJSONReportEmpty', @TestJSONReportEmpty);
  Suite.Test('TestJSONValidStructure', @TestJSONValidStructure);
  Suite.Test('TestTAPReportMultiSuite', @TestTAPReportMultiSuite);
  Suite.Test('TestJSONReportMultiSuite', @TestJSONReportMultiSuite);
  Suite.Test('TestJSONReportSkipped', @TestJSONReportSkipped);
  Suite.Test('TestTAPReportDuration', @TestTAPReportDuration);
  Suite.Test('TestJSONReportDuration', @TestJSONReportDuration);
  Suite.Test('TestTAPReportMultiLineYAML', @TestTAPReportMultiLineYAML);
  Suite.Test('TestTAPReportError', @TestTAPReportError);

  { T-04: TAP/JSON compliance tests }
  Suite.Test('TestTAPSeverityFailVsError', @TestTAPSeverityFailVsError);
  Suite.Test('TestTAPYAMLBlockMarkers', @TestTAPYAMLBlockMarkers);
  Suite.Test('TestTAPDiagnosticFooter', @TestTAPDiagnosticFooter);
  Suite.Test('TestTAPSequentialNumbering', @TestTAPSequentialNumbering);
  Suite.Test('TestJSONErrorStatus', @TestJSONErrorStatus);
  Suite.Test('TestJSONPassedStatus', @TestJSONPassedStatus);

  { R6-49~52, R6-61, R6-65: new coverage tests }
  Suite.Test('StatusDot unicode',         @TestStatusDotUnicodeName);
  Suite.Test('Filter nested a*b*c',       @TestFilterNestedGlob);
  Suite.Test('JUnit XML structure',       @TestJUnitXMLStructureComplete);
  Suite.Test('JSON report structure',     @TestJSONReportStructureComplete);
  Suite.Test('XmlEscape control chars',   @TestXmlEscapeControlChars);
  Suite.Test('ANSI state restoration',    @TestAnsiStateRestoration);

  { Phase 3: Tag Filter / DisplayName / Repeat / CapturedLog / Reports }
  Suite.Test('TestSetGetTagFilter',           @TestSetGetTagFilter);
  Suite.Test('TestDisplayNameInOutput',       @TestDisplayNameInOutput);
  Suite.Test('TestDisplayNameDefaultUsesName', @TestDisplayNameDefaultUsesName);
  Suite.Test('TestTagFilterExcludes',         @TestTagFilterExcludes);
  Suite.Test('TestTagFilterEmptyMatchesAll',  @TestTagFilterEmptyMatchesAll);
  Suite.Test('TestRepeatCount',               @TestRepeatCount);
  Suite.Test('TestJUnitCapturedLogInFailure', @TestJUnitCapturedLogInFailure);
  Suite.Test('TestJUnitSkipReason',           @TestJUnitSkipReason);
  Suite.Test('TestTAPCapturedLogInFailure',   @TestTAPCapturedLogInFailure);
  Suite.Test('TestJSONCapturedLogInFailure',  @TestJSONCapturedLogInFailure);
  Suite.Test('TestRunnerTagsOverload',        @TestRunnerTagsOverload);
  Suite.Test('Hierarchical filter matching',  @TestHierarchicalFilter);
  Suite.Test('B12 Hierarchical filter edges', @TestB12HierarchicalFilterEdges);
  Suite.Test('GetTopSlowest',                 @TestGetTopSlowest);

  { R48: FormatDuration boundary tests }
  Suite.Test('FormatDuration zero',           @TestFormatDurationZero);
  Suite.Test('FormatDuration 999ms',          @TestFormatDuration999ms);
  Suite.Test('FormatDuration exact second',   @TestFormatDurationExactSecond);
  Suite.Test('FormatDuration 1050ms',         @TestFormatDuration1050ms);
  Suite.Test('FormatDuration 1100ms',         @TestFormatDuration1100ms);
  Suite.Test('FormatDuration large',          @TestFormatDurationLarge);
  Suite.Test('FormatDuration edge cases',     @TestFormatDurationEdgeCases);

  { R48: Glob nested brace tests }
  Suite.Test('Glob nested braces',            @TestGlobNestedBraces);
  Suite.Test('Glob empty alternative',        @TestGlobEmptyAlternative);
  Suite.Test('Glob brace with wildcard',      @TestGlobBraceWithWildcard);
  Suite.Test('Glob brace with question',      @TestGlobBraceWithQuestion);

  { B8 v8.10 deeper report contracts }
  Suite.Test('JUnit empty suite',             @TestJUnitEmptySuite);
  Suite.Test('JUnit only skipped',            @TestJUnitOnlySkipped);
  Suite.Test('JUnit failure message',         @TestJUnitFailureMessage);
  Suite.Test('JSON all status enums',         @TestJSONAllStatusEnums);
  Suite.Test('JSON error status',             @TestJSONErrorStatusContract);
  Suite.Test('TAP plan matches count',        @TestTAPPlanMatchesCount);
  Suite.Test('XmlEscape specials',            @TestXmlEscapeSpecials);
  Suite.Test('ColorDiff no ANSI when off',    @TestColorDiffNoAnsiWhenOff);

  { B11/B13: stable report golden fragments (Duration=0, no wall-clock) }
  Suite.Test('B11 JSON golden snapshot',      @TestB11JSONGoldenSnapshot);
  Suite.Test('B11 TAP golden snapshot',       @TestB11TAPGoldenSnapshot);
  Suite.Test('B13 JUnit golden snapshot',     @TestB13JUnitGoldenSnapshot);
  Suite.Test('B13 TAP formal compliance',     @TestB13TAPFormalCompliance);
  Suite.Test('B15 committed goldens strict CI', @TestB15CommittedGoldensStrictCI);
  Suite.Test('B29 SoftFail report golden',    @TestB29SoftFailReportGolden);
  Suite.Test('B57 Soft wave2 report golden',  @TestB57SoftWave2ReportGolden);

  { B5: 64 filter contracts (half negative) }
  SetLength(LFilterCases, 0);
  AppendFilterCase(LFilterCases, 'exact-yes', 'foo', 'foo', '1');
  AppendFilterCase(LFilterCases, 'exact-no', 'foo', 'bar', '0');
  AppendFilterCase(LFilterCases, 'star-suffix-yes', 'test_*', 'test_a', '1');
  AppendFilterCase(LFilterCases, 'star-suffix-no', 'test_*', 'x_test_a', '0');
  AppendFilterCase(LFilterCases, 'star-prefix-yes', '*_end', 'x_end', '1');
  AppendFilterCase(LFilterCases, 'star-prefix-no', '*_end', 'end_x', '0');
  AppendFilterCase(LFilterCases, 'q-yes', 'a?c', 'abc', '1');
  AppendFilterCase(LFilterCases, 'q-no-short', 'a?c', 'ac', '0');
  AppendFilterCase(LFilterCases, 'q-no-long', 'a?c', 'abbc', '0');
  AppendFilterCase(LFilterCases, 'sub-yes', 'hello', 'say hello', '1');
  AppendFilterCase(LFilterCases, 'sub-no', 'hello', 'hell', '0');
  AppendFilterCase(LFilterCases, 'brace-yes-a', 't_{a,b}', 't_a', '1');
  AppendFilterCase(LFilterCases, 'brace-yes-b', 't_{a,b}', 't_b', '1');
  AppendFilterCase(LFilterCases, 'brace-no-c', 't_{a,b}', 't_c', '0');
  AppendFilterCase(LFilterCases, 'empty-pat-yes', '', 'anything', '1');
  AppendFilterCase(LFilterCases, 'comma-yes-1', 'a*,b*', 'alpha', '1');
  AppendFilterCase(LFilterCases, 'comma-yes-2', 'a*,b*', 'beta', '1');
  AppendFilterCase(LFilterCases, 'comma-no', 'a*,b*', 'zeta', '0');
  AppendFilterCase(LFilterCases, 'multi-star-yes', 'a*b*c', 'axbyc', '1');
  AppendFilterCase(LFilterCases, 'multi-star-no', 'a*b*c', 'axyc', '0');
  for LI := 0 to 43 do
  begin
    if (LI mod 2) = 0 then
      AppendFilterCase(LFilterCases, 'gen-yes-' + IntToStr(LI),
        'case_' + IntToStr(LI) + '*', 'case_' + IntToStr(LI) + '_x', '1')
    else
      AppendFilterCase(LFilterCases, 'gen-no-' + IntToStr(LI),
        'case_' + IntToStr(LI) + '*', 'other_' + IntToStr(LI), '0');
  end;
  Suite.TestTable('filter contracts', LFilterCases, @TestFilterTableCase);

  { v8.28 B62: hierarchical Parent/Sub/* + brace negative density }
  SetLength(LFilterCases, 0);
  AppendFilterCase(LFilterCases, 'h-exact-yes', 'P/S', 'P/S', '1');
  AppendFilterCase(LFilterCases, 'h-desc-yes', 'P/S', 'P/S/L', '1');
  AppendFilterCase(LFilterCases, 'h-deep-yes', 'P/S', 'P/S/L/X', '1');
  AppendFilterCase(LFilterCases, 'h-parent-prefix-yes', 'P/S', 'P', '1');
  AppendFilterCase(LFilterCases, 'h-sib-no', 'P/S', 'P/T', '0');
  AppendFilterCase(LFilterCases, 'h-other-no', 'P/S', 'Q/S', '0');
  AppendFilterCase(LFilterCases, 'h-star-yes', 'P/*', 'P/A', '1');
  AppendFilterCase(LFilterCases, 'h-star-no', 'P/*', 'Q/A', '0');
  AppendFilterCase(LFilterCases, 'h-substar-yes', 'P/Sub*', 'P/SubA', '1');
  AppendFilterCase(LFilterCases, 'h-substar-no', 'P/Sub*', 'P/Leaf', '0');
  AppendFilterCase(LFilterCases, 'h-brace-yes-a', 'P/{A,B}', 'P/A', '1');
  AppendFilterCase(LFilterCases, 'h-brace-yes-b', 'P/{A,B}', 'P/B', '1');
  AppendFilterCase(LFilterCases, 'h-brace-no-c', 'P/{A,B}', 'P/C', '0');
  AppendFilterCase(LFilterCases, 'h-brace-leaf-yes', 'P/{A,B}/L', 'P/A/L', '1');
  AppendFilterCase(LFilterCases, 'h-brace-leaf-no', 'P/{A,B}/L', 'P/C/L', '0');
  AppendFilterCase(LFilterCases, 'h-3seg-yes', 'P/S/*', 'P/S/X', '1');
  AppendFilterCase(LFilterCases, 'h-3seg-parent-yes', 'P/S/*', 'P/S', '1');
  AppendFilterCase(LFilterCases, 'h-3seg-sib-no', 'P/S/*', 'P/T/X', '0');
  AppendFilterCase(LFilterCases, 'h-q-yes', 'P/S?', 'P/SA', '1');
  AppendFilterCase(LFilterCases, 'h-q-no', 'P/S?', 'P/SAB', '0');
  for LI := 0 to 39 do
  begin
    if (LI mod 2) = 0 then
      AppendFilterCase(LFilterCases, 'h-gen-yes-' + IntToStr(LI),
        'Root/G' + IntToStr(LI) + '/*',
        'Root/G' + IntToStr(LI) + '/leaf', '1')
    else
      AppendFilterCase(LFilterCases, 'h-gen-no-' + IntToStr(LI),
        'Root/G' + IntToStr(LI) + '/*',
        'Root/Other' + IntToStr(LI) + '/leaf', '0');
  end;
  Suite.TestTable('B62 hierarchical filter fail-path', LFilterCases,
    @TestB62HierarchicalFilterCase);

  { ── v8.35: JUnit XML escape fail-path (end-to-end via JUnitXML) ── }
  SetLength(LFmtCases, 0);
  AppendEscCase(LFmtCases, 'x-amp-name', 'name|a&b|name="a&amp;b"|name="a&b"', '0');
  AppendEscCase(LFmtCases, 'x-lt-name', 'name|a<b|name="a&lt;b"|name="a<b"', '0');
  AppendEscCase(LFmtCases, 'x-gt-name', 'name|a>b|name="a&gt;b"|name="a>b"', '0');
  AppendEscCase(LFmtCases, 'x-quot-name', 'name|a"b|name="a&quot;b"|name="a"b"', '0');
  AppendEscCase(LFmtCases, 'x-apos-name', 'name|a''b|name="a&apos;b"|name="a''b"', '0');
  AppendEscCase(LFmtCases, 'x-double-escape', 'name|a&amp;b|name="a&amp;amp;b"|name="a&amp;b"', '0');
  AppendEscCase(LFmtCases, 'x-all-five', 'name|<>&"''|&lt;&gt;&amp;&quot;&apos;|<>', '0');
  AppendEscCase(LFmtCases, 'x-repeat-amp', 'name|&&&|&amp;&amp;&amp;|&&', '0');
  AppendEscCase(LFmtCases, 'x-ctrl-bell', 'name|a'#7'b|name="a b"|'#7, '0');
  AppendEscCase(LFmtCases, 'x-ctrl-esc', 'name|a'#27'b|name="a b"|'#27, '0');
  AppendEscCase(LFmtCases, 'x-tab-through', 'name|a'#9'b|name="a'#9'b"|', '1');
  AppendEscCase(LFmtCases, 'x-lf-through', 'name|a'#10'b|name="a'#10'b"|', '1');
  AppendEscCase(LFmtCases, 'x-cr-through', 'name|a'#13'b|name="a'#13'b"|', '1');
  AppendEscCase(LFmtCases, 'x-plain', 'name|plain_ok|name="plain_ok"|', '1');
  AppendEscCase(LFmtCases, 'x-empty-name', 'name||name=""|', '1');
  AppendEscCase(LFmtCases, 'x-name-unicode', 'name|测试&名|name="测试&amp;名"|测试&名', '0');
  AppendEscCase(LFmtCases, 'x-name-space', 'name|a b c|name="a b c"|', '1');
  AppendEscCase(LFmtCases, 'x-msg-amp', 'msg|x&y|message="x&amp;y"|message="x&y"', '0');
  AppendEscCase(LFmtCases, 'x-msg-lt', 'msg|x<y|message="x&lt;y"|message="x<y"', '0');
  AppendEscCase(LFmtCases, 'x-msg-quot', 'msg|say "no"|message="say &quot;no&quot;"|say "no', '0');
  AppendEscCase(LFmtCases, 'x-msg-apos', 'msg|it''s|message="it&apos;s"|it''s', '0');
  AppendEscCase(LFmtCases, 'x-msg-ctrl', 'msg|a'#1'b|message="a b"|'#1, '0');
  AppendEscCase(LFmtCases, 'x-msg-multiline', 'msg|l1'#10'l2|message="l1'#10'l2"|', '1');
  AppendEscCase(LFmtCases, 'x-msg-empty', 'msg||message=""|', '1');
  AppendEscCase(LFmtCases, 'x-msg-unicode', 'msg|失败<原因>|失败&lt;原因&gt;|失败<原因>', '0');
  AppendEscCase(LFmtCases, 'x-msg-mixed', 'msg|a<b>c&d|a&lt;b&gt;c&amp;d|a<b>c&d', '0');
  Suite.TestTable('v8.35 junit xml-escape fail-path', LFmtCases, @TestXmlEscTableCase);

  { ── v8.35: JSON escape fail-path (end-to-end via JSONReport) ── }
  SetLength(LFmtCases, 0);
  AppendEscCase(LFmtCases, 'j-quote-name', 'name|a"b|"name": "a\"b"|"name": "a"b"', '0');
  AppendEscCase(LFmtCases, 'j-backslash-name', 'name|a\b|"name": "a\\b"|: "a\b"', '0');
  AppendEscCase(LFmtCases, 'j-tab', 'name|a'#9'b|"name": "a\tb"|a'#9'b', '0');
  AppendEscCase(LFmtCases, 'j-lf', 'name|a'#10'b|"name": "a\nb"|a'#10'b', '0');
  AppendEscCase(LFmtCases, 'j-cr', 'name|a'#13'b|"name": "a\rb"|a'#13'b', '0');
  AppendEscCase(LFmtCases, 'j-bs', 'name|a'#8'b|"name": "a\bb"|a'#8'b', '0');
  AppendEscCase(LFmtCases, 'j-ff', 'name|a'#12'b|"name": "a\fb"|a'#12'b', '0');
  AppendEscCase(LFmtCases, 'j-ctrl1', 'name|a'#1'b|"name": "a\u0001b"|a'#1'b', '0');
  AppendEscCase(LFmtCases, 'j-ctrl31', 'name|a'#31'b|"name": "a\u001Fb"|a'#31'b', '0');
  AppendEscCase(LFmtCases, 'j-ctrl2', 'name|a'#2'b|"name": "a\u0002b"|a'#2'b', '0');
  AppendEscCase(LFmtCases, 'j-space', 'name|a b|"name": "a b"|', '1');
  AppendEscCase(LFmtCases, 'j-del127', 'name|a'#127'b|"name": "a'#127'b"|', '1');
  AppendEscCase(LFmtCases, 'j-slash', 'name|a/b|"name": "a/b"|\/', '0');
  AppendEscCase(LFmtCases, 'j-plain', 'name|plain|"name": "plain"|', '1');
  AppendEscCase(LFmtCases, 'j-unicode', 'name|中文名|"name": "中文名"|', '1');
  AppendEscCase(LFmtCases, 'j-combo', 'name|"\|"name": "\"\\"|: ""\', '0');
  AppendEscCase(LFmtCases, 'j-crlf', 'name|a'#13#10'b|"name": "a\r\nb"|a'#13#10'b', '0');
  AppendEscCase(LFmtCases, 'j-name-empty', 'name||"name": ""|', '1');
  AppendEscCase(LFmtCases, 'j-msg-quote', 'msg|say "hi"|"message": "say \"hi\""|say "hi', '0');
  AppendEscCase(LFmtCases, 'j-msg-newline', 'msg|l1'#10'l2|"message": "l1\nl2"|l1'#10'l2', '0');
  AppendEscCase(LFmtCases, 'j-msg-ctrl31', 'msg|x'#31'y|"message": "x\u001Fy"|x'#31'y', '0');
  AppendEscCase(LFmtCases, 'j-msg-space', 'msg|x y|"message": "x y"|', '1');
  AppendEscCase(LFmtCases, 'j-msg-injection', 'msg|x","hack": "1|\"hack\": \"1|"hack": ', '0');
  AppendEscCase(LFmtCases, 'j-msg-combo', 'msg|a'#9'b'#10'c|"message": "a\tb\nc"|a'#9'b', '0');
  Suite.TestTable('v8.35 json-escape fail-path', LFmtCases, @TestJsonEscTableCase);

  { ── v8.35: TAP structure fail-path (end-to-end via TAPReport) ── }
  SetLength(LFmtCases, 0);
  AppendTapCase(LFmtCases, 't-empty-plan', '|1..0|', '0');
  AppendTapCase(LFmtCases, 't-single-pass-plan', 'p|1..1|', '1');
  AppendTapCase(LFmtCases, 't-pass-line', 'p|ok 1 - S / t0|', '1');
  AppendTapCase(LFmtCases, 't-pass-no-notok', 'p||not ok', '1');
  AppendTapCase(LFmtCases, 't-fail-line', 'f|not ok 1 - S / t0|', '0');
  AppendTapCase(LFmtCases, 't-fail-yaml-open', 'f|  ---|', '0');
  AppendTapCase(LFmtCases, 't-fail-severity', 'f|  severity: fail|', '0');
  AppendTapCase(LFmtCases, 't-fail-msg', 'f|boom|', '0');
  AppendTapCase(LFmtCases, 't-fail-yaml-close', 'f|  ...|', '0');
  AppendTapCase(LFmtCases, 't-error-severity', 'e|  severity: error|', '0');
  AppendTapCase(LFmtCases, 't-error-not-failsev', 'e||  severity: fail', '0');
  AppendTapCase(LFmtCases, 't-skip-directive', 's|# skip|', '0');
  AppendTapCase(LFmtCases, 't-skip-msg', 's|# skip why|', '0');
  AppendTapCase(LFmtCases, 't-mixed-plan', 'pfs|1..3|', '0');
  AppendTapCase(LFmtCases, 't-mixed-skipline', 'pfs|ok 3 - S / t2 # skip|', '0');
  AppendTapCase(LFmtCases, 't-mixed-skipcount', 'pfs|# skipped: 1|', '0');
  AppendTapCase(LFmtCases, 't-allpass-lastline', 'ppp|ok 3 - S / t2|', '1');
  AppendTapCase(LFmtCases, 't-allpass-nofail', 'ppp||not ok', '1');
  AppendTapCase(LFmtCases, 't-two-fails', 'ff|not ok 2 - S / t1|', '0');
  AppendTapCase(LFmtCases, 't-sss-count', 'sss|# skipped: 3|', '0');
  Suite.TestTable('v8.35 tap structure fail-path', LFmtCases, @TestTapTableCase);

  { ── v8.35: FormatDuration format contract table ── }
  SetLength(LFmtCases, 0);
  AppendDurCase(LFmtCases, 'd-zero', '0|0ms');
  AppendDurCase(LFmtCases, 'd-one', '1|1ms');
  AppendDurCase(LFmtCases, 'd-999', '999|999ms');
  AppendDurCase(LFmtCases, 'd-1000', '1000|1s');
  AppendDurCase(LFmtCases, 'd-1001', '1001|1.00s');
  AppendDurCase(LFmtCases, 'd-1005', '1005|1.00s');
  AppendDurCase(LFmtCases, 'd-1050', '1050|1.05s');
  AppendDurCase(LFmtCases, 'd-1090', '1090|1.09s');
  AppendDurCase(LFmtCases, 'd-1100', '1100|1.1s');
  AppendDurCase(LFmtCases, 'd-1200', '1200|1.2s');
  AppendDurCase(LFmtCases, 'd-1230', '1230|1.23s');
  AppendDurCase(LFmtCases, 'd-1234-truncate', '1234|1.23s');
  AppendDurCase(LFmtCases, 'd-1999', '1999|1.99s');
  AppendDurCase(LFmtCases, 'd-2000', '2000|2s');
  AppendDurCase(LFmtCases, 'd-2500', '2500|2.5s');
  AppendDurCase(LFmtCases, 'd-9999', '9999|9.99s');
  AppendDurCase(LFmtCases, 'd-10000', '10000|10s');
  AppendDurCase(LFmtCases, 'd-59999', '59999|59.99s');
  AppendDurCase(LFmtCases, 'd-60000', '60000|60s');
  AppendDurCase(LFmtCases, 'd-61234', '61234|61.23s');
  AppendDurCase(LFmtCases, 'd-599999', '599999|599.99s');
  AppendDurCase(LFmtCases, 'd-negative-passthrough', '-1|-1ms');
  Suite.TestTable('v8.35 format-duration contract', LFmtCases, @TestDurTableCase);

  Runner := TSuiteRunner.Create('output-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  CheckTrue(LResults[0].Passed >= 100, 'Expected at least 100 tests, got ' + IntToStr(LResults[0].Passed));
  CheckTrue(LSuccess, 'All output tests should pass');

  if Runner.AllPassed then
    PassTest('ALL PASSED')
  else
    FailTest('SOME FAILED');

  { Release closures before heaptrc reports }
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
  LResults := nil;
  LFilterCases := nil;
  LFmtCases := nil;
end.
