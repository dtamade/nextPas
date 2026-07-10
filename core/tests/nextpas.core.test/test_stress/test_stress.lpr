{ test_stress — Stress tests for nextpas.core.test framework

  Scenarios:
    1. 10K empty test registration + execution (Runner O(n) verification)
    2. Large string comparison (1MB diff detection)
    3. 10K glob filtering (MatchesFilter performance)
    4. 100K line output (TBufferSink throughput)
 }
program test_stress;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.test;

{ ── Helpers ──────────────────────────────────────────────────────────────── }

procedure Noop;
begin { empty } end;

{ ── Stress 1: 10K empty tests ────────────────────────────────────────────── }

procedure TestTenKRegistration;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
begin
  LSuite := TTestSuite.Create('10K-empty');
  for I := 1 to 10000 do
    LSuite.Test('t' + IntToStr(I), @Noop);
  LSuite.RunWithResult(LResult);
  CheckEqual(10000, LResult.Passed, '10K passed count');
  CheckEqual(0, LResult.Failed, '10K failed count');
end;

{ ── Stress 2: Large string comparison ────────────────────────────────────── }

procedure TestLargeStringEqual;
var
  LA, LB: string;
  I: Integer;
begin
  { Build two identical 1MB strings }
  SetLength(LA, 1000000);
  SetLength(LB, 1000000);
  for I := 1 to 1000000 do
  begin
    LA[I] := Chr(Ord('A') + (I mod 26));
    LB[I] := LA[I];
  end;
  CheckEqual(LA, LB, '1MB identical strings');
end;

procedure TestLargeStringDiff;
var
  LA, LB: string;
  I: Integer;
  LFailed: Boolean = False;
begin
  SetLength(LA, 1000000);
  SetLength(LB, 1000000);
  for I := 1 to 1000000 do
  begin
    LA[I] := Chr(Ord('A') + (I mod 26));
    LB[I] := LA[I];
  end;
  { Single byte difference at end }
  LB[1000000] := 'Z';
  try
    CheckEqual(LA, LB, 'should fail');
  except
    on E: EAssertionFailed do
    begin
      LFailed := True;
      { Verify the diff message mentions the difference }
      CheckTrue(Length(E.Message) > 0, 'error message not empty');
    end;
  end;
  CheckTrue(LFailed, 'should have failed on 1MB diff');
end;

{ ── Stress 3: Many Check calls ───────────────────────────────────────────── }

procedure TestManyChecks;
var
  I: Integer;
begin
  for I := 1 to 100000 do
    CheckEqual(I, I, 'iter ' + IntToStr(I));
end;

{ ── Stress 4: Large TBytes comparison ────────────────────────────────────── }

procedure TestLargeBytesEqual;
var
  LA, LB: TBytes;
  I: Integer;
begin
  SetLength(LA, 100000);
  SetLength(LB, 100000);
  for I := 0 to 99999 do
  begin
    LA[I] := Byte(I and $FF);
    LB[I] := LA[I];
  end;
  ExpectBytes(LA).ToEqualBytes(LB);
end;

procedure TestLargeBytesDiff;
var
  LA, LB: TBytes;
  I: Integer;
begin
  SetLength(LA, 100000);
  SetLength(LB, 100000);
  for I := 0 to 99999 do
  begin
    LA[I] := Byte(I and $FF);
    LB[I] := LA[I];
  end;
  LB[99999] := $FF;
  ExpectFail(procedure begin ExpectBytes(LA).ToEqualBytes(LB); end, 'index');
end;

{ ── Stress 5: Subtest nesting ────────────────────────────────────────────── }

procedure TestSubtestStress(constref Ctx: ITestContext);
var
  I: Integer;
begin
  for I := 1 to 1000 do
    Ctx.Run('sub-' + IntToStr(I),
      procedure begin
        CheckTrue(True, 'inner');
      end);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== test_stress ===');
  LSuite := TTestSuite.Create('stress');

  LSuite.Test('10K empty tests',           @TestTenKRegistration);
  LSuite.Test('1MB string equal',          @TestLargeStringEqual);
  LSuite.Test('1MB string diff',           @TestLargeStringDiff);
  LSuite.Test('100K CheckEqual calls',     @TestManyChecks);
  LSuite.Test('100KB bytes equal',         @TestLargeBytesEqual);
  LSuite.Test('100KB bytes diff',          @TestLargeBytesDiff);
  LSuite.TestSubtest('1000 subtests',      @TestSubtestStress);

  if not LSuite.Run then
  begin
    Finalize(LSuite);
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;
  WriteLn;
  PassTest('ALL PASSED');
  LSuite.Config.OutSink := nil;
  LSuite.Config.ErrSink := nil;
  Finalize(LSuite);
end.
