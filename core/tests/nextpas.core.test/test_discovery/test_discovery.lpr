{ test_discovery — DiscoverTests + TTestFixture tests
  =========================================================
  Covers: nextpas.core.test.discovery }

program test_discovery;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.test,
  nextpas.core.test.base,
  nextpas.core.test.runner,
  nextpas.core.test.discovery,
  nextpas.core.test.helpers;

{ ── Test Fixtures ──────────────────────────────────────────────────────────── }

{$M+}

type
  { Simple fixture with two published test methods }
  TSimpleFixture = class(TTestFixture)
  published
    procedure TestPass;
    procedure TestAlsoPass;
  end;

  { Fixture with BeforeEach/AfterEach hooks }
  THooksFixture = class(TTestFixture)
  public
    BeforeCount: Integer;
    AfterCount: Integer;
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure TestOne;
    procedure TestTwo;
    procedure TestThree;
  end;

  { Empty fixture — no published methods }
  TEmptyFixture = class(TTestFixture)
  published
  end;

  { Fixture with failing test }
  TFailFixture = class(TTestFixture)
  published
    procedure TestFail;
  end;

procedure TSimpleFixture.TestPass;
begin
  CheckTrue(True, 'should pass');
end;

procedure TSimpleFixture.TestAlsoPass;
begin
  CheckEqual(42, 42, 'should also pass');
end;

procedure THooksFixture.BeforeEach;
begin
  Inc(BeforeCount);
end;

procedure THooksFixture.AfterEach;
begin
  Inc(AfterCount);
end;

procedure THooksFixture.TestOne;
begin
  CheckTrue(True);
end;

procedure THooksFixture.TestTwo;
begin
  CheckTrue(True);
end;

procedure THooksFixture.TestThree;
begin
  CheckTrue(True);
end;

procedure TFailFixture.TestFail;
begin
  Fail('intentional failure');
end;

{ ── DiscoverTests tests ───────────────────────────────────────────────────── }

procedure TestDiscoverSimple;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(2, Length(LSuite.Tests), 'Should discover 2 methods');
  CheckEqual('TestPass', LSuite.Tests[0].Name);
  CheckEqual('TestAlsoPass', LSuite.Tests[1].Name);
  LSuite.RunWithResult(LResult);
  CheckEqual(2, LResult.Passed, 'Both tests should pass');
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverCustomName;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture, 'my-custom-suite');
  CheckEqual('my-custom-suite', LSuite.Name);
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverDefaultName;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual('TSimpleFixture', LSuite.Name);
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverEmpty;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests), 'Empty fixture should have 0 tests');
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverBeforeEach;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  { Defer cleanup so we can check fixture fields after run }
  LSuite.RunWithResult(LResult, True);
  CheckEqual(3, LResult.Passed, 'All 3 tests should pass');
  CheckEqual(3, LFixture.BeforeCount, 'BeforeEach should be called 3 times');
  CheckEqual(3, LFixture.AfterCount, 'AfterEach should be called 3 times');
  { Now manually cleanup }
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverAfterEach;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  LSuite.RunWithResult(LResult, True);
  CheckEqual(3, LFixture.AfterCount, 'AfterEach should be called 3 times');
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverMethodCount;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
begin
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(3, Length(LSuite.Tests), 'THooksFixture has 3 published methods');
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverMethodName;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
begin
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual('TestOne', LSuite.Tests[0].Name);
  CheckEqual('TestTwo', LSuite.Tests[1].Name);
  CheckEqual('TestThree', LSuite.Tests[2].Name);
  LSuite := Default(TTestSuite);
end;

{ ── B3 scale: discovery metadata (no extra RunWithResult — fixture registry) ─ }

procedure TestDiscoverEmptyZeroTests;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests), 'empty fixture has zero tests');
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverSimpleNames;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(2, Length(LSuite.Tests));
  CheckTrue((LSuite.Tests[0].Name = 'TestPass') or (LSuite.Tests[1].Name = 'TestPass'));
  CheckTrue((LSuite.Tests[0].Name = 'TestAlsoPass') or (LSuite.Tests[1].Name = 'TestAlsoPass'));
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverFailMethodName;
var
  LFixture: TFailFixture;
  LSuite: TTestSuite;
begin
  LFixture := TFailFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(1, Length(LSuite.Tests));
  CheckEqual('TestFail', LSuite.Tests[0].Name);
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverEntryNamesNonEmpty;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
  I: Integer;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  for I := 0 to High(LSuite.Tests) do
    CheckTrue(LSuite.Tests[I].Name <> '', 'discovered name non-empty');
  LSuite := Default(TTestSuite);
end;

procedure TestDiscoverHooksMethodCountAgain;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
begin
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(3, Length(LSuite.Tests));
  LSuite := Default(TTestSuite);
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
begin
  WriteLn('=== test_discovery ===');
  LSuite := TTestSuite.Create('discovery');

  LSuite.Test('Discover simple',         @TestDiscoverSimple);
  LSuite.Test('Discover custom name',    @TestDiscoverCustomName);
  LSuite.Test('Discover default name',   @TestDiscoverDefaultName);
  LSuite.Test('Discover empty',          @TestDiscoverEmpty);
  LSuite.Test('Discover BeforeEach',     @TestDiscoverBeforeEach);
  LSuite.Test('Discover AfterEach',      @TestDiscoverAfterEach);
  LSuite.Test('Discover method count',   @TestDiscoverMethodCount);
  LSuite.Test('Discover method names',   @TestDiscoverMethodName);
  { B3 scale — metadata only (avoid fixture registry double-run AV) }
  LSuite.Test('Discover empty zero',     @TestDiscoverEmptyZeroTests);
  LSuite.Test('Discover simple names',   @TestDiscoverSimpleNames);
  LSuite.Test('Discover fail method name',@TestDiscoverFailMethodName);
  LSuite.Test('Discover entry names',    @TestDiscoverEntryNamesNonEmpty);
  LSuite.Test('Discover hooks count again',@TestDiscoverHooksMethodCountAgain);

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
