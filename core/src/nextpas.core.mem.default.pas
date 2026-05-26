unit nextpas.core.mem.default;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf;

function DefaultAllocator: IAllocator;

implementation

type
  { TDefaultAllocator - wraps FPC GetMem/FreeMem }
  TDefaultAllocator = class(TInterfacedObject, IAllocator)
  public
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
  end;

var
  GDefaultAllocator: IAllocator = nil;

function DefaultAllocator: IAllocator;
begin
  if GDefaultAllocator = nil then
    GDefaultAllocator := TDefaultAllocator.Create;
  Result := GDefaultAllocator;
end;

{ TDefaultAllocator }

function TDefaultAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TDefaultAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
var
  LPtr: Pointer;
begin
  LPtr := APtr;
  Result := ReAllocMem(LPtr, ANewSize);
end;

procedure TDefaultAllocator.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

end.
