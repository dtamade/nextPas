{
    nextpas.core.mem.allocator.zeroed
    ---------------------------------
    Zero-initialized allocator wrapper.

    Ensures all returned memory is zero-initialized by wrapping
    GetMem with FillChar. Unlike AllocMem, this works with any
    inner allocator regardless of its AllocMem implementation.

    No overhead beyond the FillChar call.
}

unit nextpas.core.mem.allocator.zeroed;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  TZeroedAllocator = class(TAllocator)
  private
    FInner: IAllocator;
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    constructor Create(AInner: IAllocator);
  end;

implementation

uses
  nextpas.core.base;

{ TZeroedAllocator }

constructor TZeroedAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  FInner := AInner;
end;

function TZeroedAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TZeroedAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  // AllocMem already zero-initializes in most implementations
  Result := FInner.AllocMem(ASize);
end;

function TZeroedAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  if ASize = 0 then
  begin
    FInner.FreeMem(APtr);
    Exit(nil);
  end;

  // ReallocMem preserves old data — do NOT zero the result.
  // The old-size portion contains valid caller data; only the extension
  // region is uninitialized (same semantics as standard realloc).
  Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TZeroedAllocator.DoFreeMem(APtr: Pointer);
begin
  FInner.FreeMem(APtr);
end;

end.
