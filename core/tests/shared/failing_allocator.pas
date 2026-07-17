unit failing_allocator;

{$mode ObjFPC}{$H+}

{ Test helper: IAllocator that fails on the Nth GetMem/AllocMem attempt.
  Used by collections OOM atomicity tests (list / forward_list). }

interface

uses
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.intf;

type
  TFailingAllocatorSnapshot = record
    GetMemCalls: SizeUInt;
    FreeMemCalls: SizeUInt;
  end;

{ Fail on the AFailAt-th GetMem/AllocMem call (1-based). AFailAt=0 never fails. }
function MakeFailingAllocator(AFailAt: SizeUInt): TMemAllocator;
function FailingAllocatorSnapshot: TFailingAllocatorSnapshot;

implementation

uses
  nextpas.core.mem.allocator.crt;

type
  TFailingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FFailAt: SizeUInt;
  public
    constructor Create(AInner: IAllocator; AFailAt: SizeUInt);
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  GGetMemCalls: SizeUInt;
  GFreeMemCalls: SizeUInt;

constructor TFailingAllocator.Create(AInner: IAllocator; AFailAt: SizeUInt);
begin
  inherited Create;
  FInner := AInner;
  FFailAt := AFailAt;
end;

function TFailingAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  if (FFailAt > 0) and (GGetMemCalls = FFailAt) then
    Exit(nil);
  Result := FInner.GetMem(ASize);
end;

function TFailingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  if (FFailAt > 0) and (GGetMemCalls = FFailAt) then
    Exit(nil);
  Result := FInner.AllocMem(ASize);
end;

function TFailingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));
  Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TFailingAllocator.FreeMem(APtr: Pointer);
begin
  if APtr = nil then
    Exit;
  Inc(GFreeMemCalls);
  FInner.FreeMem(APtr);
end;

function TFailingAllocator.Traits: TAllocatorTraits;
begin
  Result := FInner.Traits;
end;

function MakeFailingAllocator(AFailAt: SizeUInt): TMemAllocator;
begin
  GGetMemCalls := 0;
  GFreeMemCalls := 0;
  Result := TFailingAllocator.Create(GetCrtAllocator, AFailAt);
end;

function FailingAllocatorSnapshot: TFailingAllocatorSnapshot;
begin
  Result.GetMemCalls := GGetMemCalls;
  Result.FreeMemCalls := GFreeMemCalls;
end;

end.
