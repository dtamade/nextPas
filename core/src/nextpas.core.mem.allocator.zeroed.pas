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
  nextpas.core.mem.error;

type
  TZeroedAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
  public
    constructor Create(AInner: IAllocator);
    destructor Destroy; override;
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.base;

{ TZeroedAllocator }

constructor TZeroedAllocator.Create(AInner: IAllocator);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TZeroedAllocator.Create: AInner must not be nil');
  FInner := AInner;
end;

destructor TZeroedAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

function TZeroedAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TZeroedAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  // AllocMem already zero-initializes in most implementations
  Result := FInner.AllocMem(ASize);
end;

function TZeroedAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  // ReallocMem preserves old data — do NOT zero the result.
  // The old-size portion contains valid caller data; only the extension
  // region is uninitialized (same semantics as standard realloc).
  Result := FInner.ReallocMem(APtr, ASize);
end;

procedure TZeroedAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then Exit;
  FInner.FreeMem(APtr);
end;

function TZeroedAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
