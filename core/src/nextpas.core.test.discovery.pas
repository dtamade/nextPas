{ nextpas.core.test.discovery — RTTI-based automatic test discovery
  =========================================================
  Scans published methods in test fixture classes and registers them
  with TTestSuite automatically.
  v8.24: pluggable ITestDiscoveryBackend — FPC VMT is the default backend;
  nextpas compiler can inject a different backend without changing DiscoverTests.
  Depends on: nextpas.core.test.base, nextpas.core.test.runner }

unit nextpas.core.test.discovery;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.test.base,
  nextpas.core.test.runner;

{ ── Test Fixture Base Class ───────────────────────────────────────────────── }

{ Inherit from TTestFixture and put test methods in published section:
    type
      TMyTests = class(TTestFixture)
      published
        procedure TestSomething;
        procedure TestOther;
      end;

  Test methods are registered with the exact method name.
  Methods MUST be parameterless. }

type
  TTestFixture = class(TObject)
  public
    { Called before each test method. Override for per-test setup (save state, etc).
      Default implementation does nothing. }
    procedure BeforeEach; virtual;
    { Called after each test method. Override for per-test teardown (restore state, etc).
      Default implementation does nothing. }
    procedure AfterEach; virtual;
  end;

  TTestFixtureClass = class of TTestFixture;

  { One published method discovered by a backend. }
  TDiscoveredMethod = record
    Name: string;
    CodeAddr: CodePointer;
  end;
  TDiscoveredMethods = array of TDiscoveredMethod;

  { Compiler-specific published-method enumeration.
    Default = FPC VMT method table. nextpas compiler may SetDiscoveryBackend. }
  ITestDiscoveryBackend = interface
    ['{7C3E9A11-4B2D-4F80-9E6A-1D5C8B0F2A44}']
    { Fill AMethods with published methods of AClass.
      Returns True when enumeration succeeded (AMethods may still be empty).
      Returns False when the backend cannot enumerate this class/compiler. }
    function EnumeratePublishedMethods(AClass: TClass;
      out AMethods: TDiscoveredMethods): Boolean;
  end;

{ ── Discovery backend registry ────────────────────────────────────────────── }

{ FPC VMT backend (default). }
function CreateFpcVmtDiscoveryBackend: ITestDiscoveryBackend;
function GetDiscoveryBackend: ITestDiscoveryBackend;
{ Inject a custom backend (e.g. nextpas RTTI or test double). Pass nil to reset. }
procedure SetDiscoveryBackend(const ABackend: ITestDiscoveryBackend);
procedure ResetDiscoveryBackend;

{ ── Discovery ─────────────────────────────────────────────────────────────── }

{ Create a TTestSuite from a fixture class instance. Published methods are
  discovered via the current ITestDiscoveryBackend.
  ASuiteName: optional override (default: ClassName).
  The suite's Teardown frees the fixture automatically. }
function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string = ''): TTestSuite;

implementation

uses
  nextpas.core.text.conv;

{ ── Method Dispatch ───────────────────────────────────────────────────────── }

type
  TMethodProc = procedure of object;

  PMethodStub = ^TMethodStub;
  TMethodStub = record
    Instance : TObject;
    CodeAddr : CodePointer;
  end;

  { Default backend: parse FPC objpas VMT method name table. }
  TFpcVmtDiscoveryBackend = class(TInterfacedObject, ITestDiscoveryBackend)
  public
    function EnumeratePublishedMethods(AClass: TClass;
      out AMethods: TDiscoveredMethods): Boolean;
  end;

procedure InvokeMethod(AStub: PMethodStub);
var
  LMethod: TMethod;
  LCall: TMethodProc;
begin
  LMethod.Code := AStub^.CodeAddr;
  LMethod.Data := AStub^.Instance;
  Move(LMethod, LCall, SizeOf(TMethod));
  LCall();
end;

function MakeMethodClosure(AStub: PMethodStub): TTestClosure;
begin
  Result := TTestClosure(procedure
  begin
    InvokeMethod(AStub);
  end);
end;

{ ── TTestFixture defaults ─────────────────────────────────────────────────── }

procedure TTestFixture.BeforeEach;
begin
  { default: do nothing }
end;

procedure TTestFixture.AfterEach;
begin
  { default: do nothing }
end;

{ ── FPC VMT Method Table Access ───────────────────────────────────────────── }
{ FPC's VMT method table format (objpas.inc tmethodnametable):
    count : DWord       (4 bytes)
    entries[i]: record
      name : PShortString  (8 bytes, absolute pointer to shortstring)
      addr : CodePointer   (8 bytes)
    end;
  Entries start at offset 4 from the table pointer.
  Each entry is 16 bytes (SizeOf(Pointer) * 2). }

const
  CEntrySize   = SizeOf(Pointer) * 2;
  CCountSize   = SizeOf(DWord);
  CEntriesOff  = CCountSize;

var
  GDiscoveryBackend: ITestDiscoveryBackend;

function TFpcVmtDiscoveryBackend.EnumeratePublishedMethods(AClass: TClass;
  out AMethods: TDiscoveredMethods): Boolean;
var
  LTable: PByte;
  LCount: DWord;
  LEntryBase: PByte;
  LNamePtr: PShortString;
  LAddr: CodePointer;
  I, LOut: Integer;
begin
  Result := False;
  SetLength(AMethods, 0);
  if AClass = nil then
    Exit;

  LTable := PByte(PPointer(Pointer(AClass) + vmtMethodTable)^);
  if LTable = nil then
  begin
    { No published methods — successful empty enumeration. }
    Result := True;
    Exit;
  end;

  Move(LTable^, LCount, SizeOf(DWord));
  if LCount = 0 then
  begin
    Result := True;
    Exit;
  end;

  LEntryBase := LTable + CEntriesOff;
  SetLength(AMethods, LCount);
  LOut := 0;
  for I := 0 to LCount - 1 do
  begin
    LNamePtr := PShortString(PPointer(LEntryBase + I * CEntrySize)^);
    LAddr := CodePointer(PPointer(LEntryBase + I * CEntrySize + SizeOf(Pointer))^);
    if (LNamePtr = nil) or (LAddr = nil) then
      Continue;
    AMethods[LOut].Name := string(LNamePtr^);
    AMethods[LOut].CodeAddr := LAddr;
    Inc(LOut);
  end;
  SetLength(AMethods, LOut);
  Result := True;
end;

function CreateFpcVmtDiscoveryBackend: ITestDiscoveryBackend;
begin
  Result := TFpcVmtDiscoveryBackend.Create;
end;

function GetDiscoveryBackend: ITestDiscoveryBackend;
begin
  if GDiscoveryBackend = nil then
    GDiscoveryBackend := CreateFpcVmtDiscoveryBackend;
  Result := GDiscoveryBackend;
end;

procedure SetDiscoveryBackend(const ABackend: ITestDiscoveryBackend);
begin
  if ABackend = nil then
    GDiscoveryBackend := CreateFpcVmtDiscoveryBackend
  else
    GDiscoveryBackend := ABackend;
end;

procedure ResetDiscoveryBackend;
begin
  GDiscoveryBackend := CreateFpcVmtDiscoveryBackend;
end;

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string): TTestSuite;
var
  LBackend: ITestDiscoveryBackend;
  LMethods: TDiscoveredMethods;
  LPStub: PMethodStub;
  LSuiteName: string;
  I: Integer;
begin
  if ASuiteName <> '' then
    LSuiteName := ASuiteName
  else
    LSuiteName := AFixture.ClassName;

  Result := TTestSuite.Create(LSuiteName);

  LBackend := GetDiscoveryBackend;
  if (LBackend = nil) or
     (not LBackend.EnumeratePublishedMethods(AFixture.ClassType, LMethods)) then
  begin
    { Backend missing or failed: empty suite (hooks still wire below). }
    SetLength(LMethods, 0);
  end;

  for I := 0 to High(LMethods) do
  begin
    if (LMethods[I].Name = '') or (LMethods[I].CodeAddr = nil) then
      Continue;

    { Heap-allocate a dispatch record per published method.
      Each closure needs its own stub to avoid reference-capture aliasing. }
    New(LPStub);
    if LPStub = nil then
      Continue;  { skip method on OOM instead of crash }
    LPStub^.Instance := AFixture;
    LPStub^.CodeAddr := LMethods[I].CodeAddr;

    Result.Test(LMethods[I].Name, MakeMethodClosure(LPStub));

    { Track stub for disposal after suite finishes running }
    RegisterStub(Result, Pointer(LPStub));
  end;

  { R6-05: Register the fixture for safety-net disposal.
    CleanupTableAllocations (called by FinalizeResults after each run) frees
    the fixture and nils the GFixtureRegistry entry to prevent double-free.
    If the suite is never run, finalization frees any remaining entries. }
  RegisterFixture(Result, AFixture);

  { Wire up BeforeEach/AfterEach virtual methods as suite hooks }
  Result.OnBeforeEach(procedure begin AFixture.BeforeEach end);
  Result.OnAfterEach(procedure begin AFixture.AfterEach end);
end;

initialization
  GDiscoveryBackend := CreateFpcVmtDiscoveryBackend;

finalization
  GDiscoveryBackend := nil;

end.
