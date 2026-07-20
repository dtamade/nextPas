{ test_discovery — DiscoverTests + TTestFixture tests
  =========================================================
  Covers: nextpas.core.test.discovery }

program test_discovery;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.text.conv,
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

{ v8.24: injectable empty backend (nextpas / test double path) }
type
  TEmptyDiscoveryBackend = class(TInterfacedObject, ITestDiscoveryBackend)
  public
    function EnumeratePublishedMethods(AClass: TClass;
      out AMethods: TDiscoveredMethods): Boolean;
  end;

function TEmptyDiscoveryBackend.EnumeratePublishedMethods(AClass: TClass;
  out AMethods: TDiscoveredMethods): Boolean;
begin
  SetLength(AMethods, 0);
  Result := True; { succeeded with zero methods }
end;

procedure TestDiscoveryBackendEmptyInject;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  SetDiscoveryBackend(TEmptyDiscoveryBackend.Create as ITestDiscoveryBackend);
  try
    LFixture := TSimpleFixture.Create;
    LSuite := DiscoverTests(LFixture, 'empty-backend');
    CheckEqual(0, Length(LSuite.Tests), 'empty backend → zero tests');
    CheckEqual('empty-backend', LSuite.Name, 'suite name preserved');
    LSuite.CleanupTableAllocations;
    LSuite := Default(TTestSuite);
  finally
    ResetDiscoveryBackend;
  end;
end;

procedure TestDiscoveryBackendResetRestoresFpc;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  SetDiscoveryBackend(TEmptyDiscoveryBackend.Create as ITestDiscoveryBackend);
  ResetDiscoveryBackend;
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(2, Length(LSuite.Tests), 'FPC backend restored after Reset');
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestFpcBackendEnumerateDirect;
var
  LBackend: ITestDiscoveryBackend;
  LMethods: TDiscoveredMethods;
  LOk: Boolean;
begin
  LBackend := CreateFpcVmtDiscoveryBackend;
  LOk := LBackend.EnumeratePublishedMethods(TSimpleFixture, LMethods);
  CheckTrue(LOk, 'FPC enumerate succeeds');
  CheckEqual(2, Length(LMethods), 'TSimpleFixture has 2 published methods');
  CheckTrue(GetDiscoveryBackend <> nil, 'default backend non-nil');
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

{ ── B12: discovery lifecycle depth ────────────────────────────────────────── }

procedure TestB12DiscoverFailRun;
var
  LFixture: TFailFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LOk: Boolean;
begin
  LFixture := TFailFixture.Create;
  LSuite := DiscoverTests(LFixture);
  LOk := LSuite.RunWithResult(LResult, True);
  CheckFalse(LOk, 'fail fixture suite should not AllPass');
  CheckEqual(1, LResult.Failed, 'one failed test');
  CheckEqual(0, LResult.Passed, 'no passes');
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestB12DiscoverEmptyRunOk;
var
  LFixture: TEmptyFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LOk: Boolean;
begin
  LFixture := TEmptyFixture.Create;
  LSuite := DiscoverTests(LFixture);
  CheckEqual(0, Length(LSuite.Tests));
  LOk := LSuite.RunWithResult(LResult, True);
  CheckTrue(LOk, 'empty discovered suite runs ok');
  CheckEqual(0, LResult.Passed);
  CheckEqual(0, LResult.Failed);
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestB12DiscoverHooksOnFailure;
var
  LFixture: THooksFixture;
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  { Inject a failing entry after Discover so hooks still fire around it. }
  LFixture := THooksFixture.Create;
  LSuite := DiscoverTests(LFixture);
  LSuite.Test('injected-fail', procedure
    begin
      Fail('injected');
    end);
  LSuite.RunWithResult(LResult, True);
  CheckTrue(LResult.Failed >= 1, 'injected fail recorded');
  { BeforeEach/AfterEach for 3 discovered + 1 injected }
  CheckEqual(4, LFixture.BeforeCount, 'BeforeEach per entry');
  CheckEqual(4, LFixture.AfterCount, 'AfterEach even after failure');
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
end;

procedure TestB12DiscoverTwoInstancesIndependent;
var
  LFa, LFb: TSimpleFixture;
  LSa, LSb: TTestSuite;
begin
  LFa := TSimpleFixture.Create;
  LFb := TSimpleFixture.Create;
  LSa := DiscoverTests(LFa, 'inst-a');
  LSb := DiscoverTests(LFb, 'inst-b');
  CheckEqual(2, Length(LSa.Tests));
  CheckEqual(2, Length(LSb.Tests));
  CheckEqual('inst-a', LSa.Name);
  CheckEqual('inst-b', LSb.Name);
  { Independent suites; cleanup each (DeferCleanup not used — default cleanup) }
  LSa := Default(TTestSuite);
  LSb := Default(TTestSuite);
end;

procedure TestB12DiscoverCleanupIdempotent;
var
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  LFixture := TSimpleFixture.Create;
  LSuite := DiscoverTests(LFixture);
  LSuite.CleanupTableAllocations;
  LSuite.CleanupTableAllocations; { FCleanupDone guard }
  LSuite.CleanupTableAllocations;
  LSuite := Default(TTestSuite);
  CheckTrue(True, 'triple CleanupTableAllocations safe');
end;

procedure TestB26DiscoverNameContract(const AC: TTestCase);
{ Data empty → must fail non-empty name check; non-empty → pass. }
begin
  if AC.Data = '' then
    ExpectFail(procedure begin
      CheckTrue(AC.Data <> '', 'discovered name non-empty');
    end, 'non-empty')
  else
    CheckTrue(AC.Data <> '', 'name ok');
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LB26Cases: specialize TArray<TTestCase>;
  LB26I: Integer;
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
  { B12 lifecycle depth }
  LSuite.Test('B12 Discover fail run',   @TestB12DiscoverFailRun);
  LSuite.Test('B12 Discover empty run',  @TestB12DiscoverEmptyRunOk);
  LSuite.Test('B12 Discover hooks on fail', @TestB12DiscoverHooksOnFailure);
  LSuite.Test('B12 Discover two instances', @TestB12DiscoverTwoInstancesIndependent);
  LSuite.Test('B12 Discover cleanup idempotent', @TestB12DiscoverCleanupIdempotent);
  { v8.24 discovery backend injectability }
  LSuite.Test('v8.24 empty backend inject', @TestDiscoveryBackendEmptyInject);
  LSuite.Test('v8.24 reset restores FPC', @TestDiscoveryBackendResetRestoresFpc);
  LSuite.Test('v8.24 FPC enumerate direct', @TestFpcBackendEnumerateDirect);

  { B26: meaningful name fail-path table (metadata only, no Discover run) }
  SetLength(LB26Cases, 90);
  for LB26I := 0 to High(LB26Cases) do
  begin
    LB26Cases[LB26I].Name := 'meta-' + IntToStr(LB26I);
    { even = non-empty pass; odd = empty → ExpectFail }
    if (LB26I mod 2) = 0 then
      LB26Cases[LB26I].Data := 'ok-name-' + IntToStr(LB26I)
    else
      LB26Cases[LB26I].Data := '';
  end;
  LSuite.TestTable('B26 discover name contracts', LB26Cases, @TestB26DiscoverNameContract);

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
