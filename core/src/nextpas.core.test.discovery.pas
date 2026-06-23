{ nextpas.core.test.discovery — RTTI-based automatic test discovery
  =========================================================
  Scans published methods in test fixture classes via FPC VMT method table
  and registers them with TTestSuite automatically.
  Depends on: nextpas.core.test.base, nextpas.core.test.runner }

unit nextpas.core.test.discovery;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
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
  end;

  TTestFixtureClass = class of TTestFixture;

{ ── Discovery ─────────────────────────────────────────────────────────────── }

{ Create a TTestSuite from a fixture class instance. Published methods are
  discovered via VMT method table. ASuiteName: optional override (default: ClassName).
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

{ ── VMT Method Table Access ───────────────────────────────────────────────── }
{ FPC's VMT method table format (objpas.inc tmethodnametable):
    count : DWord       (4 bytes)
    entries[i]: record
      name : PShortString  (8 bytes, absolute pointer to shortstring)
      addr : CodePointer   (8 bytes)
    end;
  Entries start at offset 4 from the table pointer.
  Each entry is 16 bytes (SizeOf(Pointer) * 2). }

const
  { Offtings into the VMT method table }
  CEntrySize   = SizeOf(Pointer) * 2;           { 16 bytes per entry }
  CCountSize   = SizeOf(DWord);                  { 4 bytes for count }
  CEntriesOff  = CCountSize;                     { entries start right after count }

function DiscoverTests(AFixture: TTestFixture;
  const ASuiteName: string): TTestSuite;
var
  LTable: PByte;
  LCount: DWord;
  LEntryBase: PByte;
  LNamePtr: PShortString;
  LAddr: CodePointer;
  LPStub: PMethodStub;
  LSuiteName: string;
  I: Integer;
begin
  if ASuiteName <> '' then
    LSuiteName := ASuiteName
  else
    LSuiteName := AFixture.ClassName;

  Result := TTestSuite.Create(LSuiteName);

  { Access VMT method name table via vmtMethodTable offset }
  LTable := PByte(PPointer(Pointer(AFixture.ClassType) + vmtMethodTable)^);

  if LTable = nil then
    Exit;

  Move(LTable^, LCount, SizeOf(DWord));
  if LCount = 0 then
    Exit;

  LEntryBase := LTable + CEntriesOff;

  for I := 0 to LCount - 1 do
  begin
    LNamePtr := PShortString(PPointer(LEntryBase + I * CEntrySize)^);
    LAddr := CodePointer(PPointer(LEntryBase + I * CEntrySize + SizeOf(Pointer))^);

    if (LNamePtr = nil) or (LAddr = nil) then
      Continue;

    { Heap-allocate a dispatch record per published method.
      Each closure needs its own stub to avoid reference-capture aliasing. }
    New(LPStub);
    LPStub^.Instance := AFixture;
    LPStub^.CodeAddr := LAddr;

    Result.Test(string(LNamePtr^), MakeMethodClosure(LPStub));

    { Track stub for disposal after suite finishes running }
    RegisterStub(Result, Pointer(LPStub));
  end;

  { Auto-free the fixture when the suite finishes }
  Result.SetTeardown(procedure
  begin
    AFixture.Free;
  end);
end;

end.
