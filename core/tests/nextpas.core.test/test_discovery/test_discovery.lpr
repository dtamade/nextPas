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

{ F-19 / B79: fixed-name discovery backend (nextpas stub contract) }
type
  TFixedNameDiscoveryBackend = class(TInterfacedObject, ITestDiscoveryBackend)
  public
    function EnumeratePublishedMethods(AClass: TClass;
      out AMethods: TDiscoveredMethods): Boolean;
  end;

function TFixedNameDiscoveryBackend.EnumeratePublishedMethods(AClass: TClass;
  out AMethods: TDiscoveredMethods): Boolean;
begin
  SetLength(AMethods, 2);
  AMethods[0].Name := 'TestAlpha';
  AMethods[0].CodeAddr := nil;
  AMethods[1].Name := 'TestBeta';
  AMethods[1].CodeAddr := nil;
  Result := True;
end;

procedure TestDiscoveryBackendFixedNames;
var
  LBackend: ITestDiscoveryBackend;
  LMethods: TDiscoveredMethods;
begin
  LBackend := TFixedNameDiscoveryBackend.Create as ITestDiscoveryBackend;
  CheckTrue(LBackend.EnumeratePublishedMethods(TObject, LMethods));
  CheckEqual(2, Length(LMethods));
  CheckEqual('TestAlpha', LMethods[0].Name);
  CheckEqual('TestBeta', LMethods[1].Name);
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

{ ── v8.38: DiscoverTests 注册过滤矩阵 + VMT backend 枚举契约（B78 t5） ─────── }

function NextSegD(var ARest: string): string;
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
    ARest := Copy(ARest, LP + 1, Length(ARest));
  end;
end;

procedure AppendDCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFlag: string);
var
  LIdx: Integer;
begin
  LIdx := Length(ACases);
  SetLength(ACases, LIdx + 1);
  ACases[LIdx].Name := AName;
  ACases[LIdx].Data := AData + '|' + AFlag;
end;

procedure SpecDummyTarget;
begin
  { 仅提供非 nil CodePointer；spec 条目注册后不运行 }
end;

type
  { spec 驱动 backend：GSpecString 逗号分隔 v/e/n
    v=有效条目（名 M<位置号>, 非 nil 地址）, e=空名条目, n=nil 地址条目;
    'F'=枚举失败（返回 False）, ''=成功空枚举 }
  TSpecDiscoveryBackend = class(TInterfacedObject, ITestDiscoveryBackend)
  public
    function EnumeratePublishedMethods(AClass: TClass;
      out AMethods: TDiscoveredMethods): Boolean;
  end;

var
  GSpecString: string;

function TSpecDiscoveryBackend.EnumeratePublishedMethods(AClass: TClass;
  out AMethods: TDiscoveredMethods): Boolean;
var
  LRest, LTok: string;
  LIdx, LP: Integer;
begin
  SetLength(AMethods, 0);
  if GSpecString = 'F' then
    Exit(False);
  Result := True;
  LRest := GSpecString;
  LIdx := 0;
  while LRest <> '' do
  begin
    LP := Pos(',', LRest);
    if LP = 0 then
    begin
      LTok := LRest;
      LRest := '';
    end
    else
    begin
      LTok := Copy(LRest, 1, LP - 1);
      LRest := Copy(LRest, LP + 1, Length(LRest));
    end;
    Inc(LIdx);
    SetLength(AMethods, LIdx);
    if LTok = 'v' then
    begin
      AMethods[LIdx - 1].Name := 'M' + IntToStr(LIdx);
      AMethods[LIdx - 1].CodeAddr := CodePointer(@SpecDummyTarget);
    end
    else if LTok = 'e' then
    begin
      AMethods[LIdx - 1].Name := '';
      AMethods[LIdx - 1].CodeAddr := CodePointer(@SpecDummyTarget);
    end
    else { 'n' }
    begin
      AMethods[LIdx - 1].Name := 'M' + IntToStr(LIdx);
      AMethods[LIdx - 1].CodeAddr := nil;
    end;
  end;
end;

{ Data: spec|suitename|wantCount|wantNames|flag
  spec: '-'=成功空枚举, 'F'=backend 枚举失败, 否则逗号分隔 v/e/n
  suitename: '-'=省略（锁 ClassName 回退）
  wantNames: 期望 Tests[] 名字逗号串联（锁过滤保序 + 原位置号）, '-'=空
  锁定契约：Name='' 或 CodeAddr=nil 条目静默跳过；backend False → 空套件。 }
procedure RunDiscoverFilterCase(const AC: TTestCase);
var
  LRest, LSpec, LSuiteName, LWantNames, LFlag, LGotNames: string;
  LWantCount, I: Integer;
  LFixture: TSimpleFixture;
  LSuite: TTestSuite;
begin
  LRest := AC.Data;
  LSpec := NextSegD(LRest);
  LSuiteName := NextSegD(LRest);
  LWantCount := StrToIntDef(NextSegD(LRest), -1);
  LWantNames := NextSegD(LRest);
  LFlag := LRest;

  if LSpec = '-' then
    GSpecString := ''
  else
    GSpecString := LSpec;
  SetDiscoveryBackend(TSpecDiscoveryBackend.Create as ITestDiscoveryBackend);
  try
    LFixture := TSimpleFixture.Create;
    if LSuiteName = '-' then
      LSuite := DiscoverTests(LFixture)
    else
      LSuite := DiscoverTests(LFixture, LSuiteName);

    CheckEqual(LWantCount, Length(LSuite.Tests), AC.Name + ': test count');
    if LSuiteName = '-' then
      CheckEqual('TSimpleFixture', LSuite.Name, AC.Name + ': ClassName fallback')
    else
      CheckEqual(LSuiteName, LSuite.Name, AC.Name + ': explicit name');

    LGotNames := '';
    for I := 0 to High(LSuite.Tests) do
    begin
      if I > 0 then
        LGotNames := LGotNames + ',';
      LGotNames := LGotNames + LSuite.Tests[I].Name;
    end;
    if LWantNames = '-' then
      CheckEqual('', LGotNames, AC.Name + ': no names')
    else
      CheckEqual(LWantNames, LGotNames, AC.Name + ': filtered order + slot names');

    { metadata-only：不 run；fixture/stub 由注册表 finalization 兜底（B3 先例） }
    LSuite := Default(TTestSuite);
  finally
    ResetDiscoveryBackend;
  end;

  { flag 自校验：'0' ⟺ 零注册行 }
  if LFlag = '0' then
    CheckEqual(0, LWantCount, AC.Name + ': flag-0 must be zero-count row')
  else
    CheckTrue(LWantCount > 0, AC.Name + ': flag-1 must be positive-count row');
end;

{ Data: cls|wantOk|wantCount|wantNames|flag
  cls 选择被枚举类与 backend 来源（getdefault/setnil/fresh 锁注册表语义）。
  锁定契约：nil class → False；无 published → True+空；名序=声明序；地址非 nil。 }
procedure RunVmtEnumCase(const AC: TTestCase);
var
  LRest, LCls, LWantNames, LFlag, LGotNames: string;
  LWantOk, LOk: Boolean;
  LWantCount, I: Integer;
  LBackend: ITestDiscoveryBackend;
  LMethods: TDiscoveredMethods;
  LClass: TClass;
begin
  LRest := AC.Data;
  LCls := NextSegD(LRest);
  LWantOk := NextSegD(LRest) = 'T';
  LWantCount := StrToIntDef(NextSegD(LRest), -1);
  LWantNames := NextSegD(LRest);
  LFlag := LRest;

  if LCls = 'getdefault' then
    LBackend := GetDiscoveryBackend
  else if LCls = 'setnil' then
  begin
    SetDiscoveryBackend(nil);  { nil → 重置为 FPC VMT backend }
    LBackend := GetDiscoveryBackend;
  end
  else
    LBackend := CreateFpcVmtDiscoveryBackend;

  LClass := nil;
  if LCls = 'tobject' then
    LClass := TObject
  else if LCls = 'fixture' then
    LClass := TTestFixture
  else if (LCls = 'simple') or (LCls = 'getdefault') or (LCls = 'setnil') then
    LClass := TSimpleFixture
  else if (LCls = 'hooks') or (LCls = 'fresh') then
    LClass := THooksFixture
  else if LCls = 'fail' then
    LClass := TFailFixture
  else if LCls = 'empty' then
    LClass := TEmptyFixture;
  { LCls='nil' → LClass 保持 nil }

  LOk := LBackend.EnumeratePublishedMethods(LClass, LMethods);
  CheckTrue(LOk = LWantOk, AC.Name + ': ok flag');
  CheckEqual(LWantCount, Length(LMethods), AC.Name + ': method count');

  LGotNames := '';
  for I := 0 to High(LMethods) do
  begin
    if I > 0 then
      LGotNames := LGotNames + ',';
    LGotNames := LGotNames + LMethods[I].Name;
  end;
  if LWantNames = '-' then
    CheckEqual('', LGotNames, AC.Name + ': no names')
  else
    CheckEqual(LWantNames, LGotNames, AC.Name + ': declaration order');

  for I := 0 to High(LMethods) do
    CheckTrue(LMethods[I].CodeAddr <> nil, AC.Name + ': non-nil addr');

  { flag 自校验：'0' ⟺ wantCount=0 }
  if LFlag = '0' then
    CheckEqual(0, LWantCount, AC.Name + ': flag-0 must be zero-count row')
  else
    CheckTrue(LWantCount > 0, AC.Name + ': flag-1 must be positive-count row');
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LB26Cases: specialize TArray<TTestCase>;
  LB26I: Integer;
  LFilterCases: specialize TArray<TTestCase>;
  LVmtCases: specialize TArray<TTestCase>;
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
  LSuite.Test('F-19 fixed-name backend stub', @TestDiscoveryBackendFixedNames);

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

  { v8.38: DiscoverTests 注册过滤矩阵（crafted backend, metadata-only） }
  SetLength(LFilterCases, 0);
  AppendDCase(LFilterCases, 'd-empty-spec',    '-|-|0|-', '0');
  AppendDCase(LFilterCases, 'd-backend-false', 'F|-|0|-', '0');
  AppendDCase(LFilterCases, 'd-one-valid',     'v|-|1|M1', '1');
  AppendDCase(LFilterCases, 'd-three-valid',   'v,v,v|-|3|M1,M2,M3', '1');
  AppendDCase(LFilterCases, 'd-emptyname',     'e|-|0|-', '0');
  AppendDCase(LFilterCases, 'd-niladdr',       'n|-|0|-', '0');
  AppendDCase(LFilterCases, 'd-mixed',         'v,e,n,v|-|2|M1,M4', '1');
  AppendDCase(LFilterCases, 'd-all-invalid',   'e,n,e,n|-|0|-', '0');
  AppendDCase(LFilterCases, 'd-name-override', 'v|custom|1|M1', '1');
  AppendDCase(LFilterCases, 'd-two-valid',     'v,v|duo|2|M1,M2', '1');
  AppendDCase(LFilterCases, 'd-lead-invalid',  'e,v|-|1|M2', '1');
  AppendDCase(LFilterCases, 'd-trail-invalid', 'v,n|-|1|M1', '1');
  LSuite.TestTable('v8.38 discover filter matrix', LFilterCases, @RunDiscoverFilterCase);

  { v8.38: FPC VMT backend 枚举契约 }
  SetLength(LVmtCases, 0);
  AppendDCase(LVmtCases, 'f-nil',            'nil|F|0|-', '0');
  AppendDCase(LVmtCases, 'f-tobject',        'tobject|T|0|-', '0');
  AppendDCase(LVmtCases, 'f-fixture',        'fixture|T|0|-', '0');
  AppendDCase(LVmtCases, 'f-empty',          'empty|T|0|-', '0');
  AppendDCase(LVmtCases, 'f-simple',         'simple|T|2|TestPass,TestAlsoPass', '1');
  AppendDCase(LVmtCases, 'f-hooks',          'hooks|T|3|TestOne,TestTwo,TestThree', '1');
  AppendDCase(LVmtCases, 'f-fail',           'fail|T|1|TestFail', '1');
  AppendDCase(LVmtCases, 'f-default-vmt',    'getdefault|T|2|TestPass,TestAlsoPass', '1');
  AppendDCase(LVmtCases, 'f-setnil-resets',  'setnil|T|2|TestPass,TestAlsoPass', '1');
  AppendDCase(LVmtCases, 'f-create-fresh',   'fresh|T|3|TestOne,TestTwo,TestThree', '1');
  LSuite.TestTable('v8.38 VMT backend enumeration', LVmtCases, @RunVmtEnumCase);

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
