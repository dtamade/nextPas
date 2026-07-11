{
    nextpas.core.mem.allocator.logging
    ----------------------------------
    Logging allocator — debug wrapper.

    Wraps an inner allocator with logging callbacks for every
    allocation, reallocation, and free. Useful for debugging
    memory issues in development builds.

    Minimal overhead: just stores a callback function pointer.
}

unit nextpas.core.mem.allocator.logging;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  TLogEvent = (leAlloc, leFree, leRealloc);
  TLogProc = procedure(AEvent: TLogEvent; APtr: Pointer; ASize: SizeUInt);

  TLoggingStats = record
    AllocCount: UInt64;
    FreeCount: UInt64;
    ReallocCount: UInt64;
    TotalBytes: UInt64;
  end;

  TLoggingAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FLogProc: TLogProc;
    FStats: TLoggingStats;
  public
    constructor Create(AInner: IAllocator; ALogProc: TLogProc = nil);
    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    procedure SetLogProc(ALogProc: TLogProc);
    function GetStats: TLoggingStats;
    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.base;

{ TLoggingAllocator }

constructor TLoggingAllocator.Create(AInner: IAllocator; ALogProc: TLogProc);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('TLoggingAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FLogProc := ALogProc;
  FillChar(FStats, SizeOf(FStats), 0);
end;

procedure TLoggingAllocator.SetLogProc(ALogProc: TLogProc);
begin
  FLogProc := ALogProc;
end;

function TLoggingAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
  begin
    Inc(FStats.AllocCount);
    Inc(FStats.TotalBytes, ASize);
    if Assigned(FLogProc) then
      FLogProc(leAlloc, Result, ASize);
  end;
end;

function TLoggingAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
  begin
    Inc(FStats.AllocCount);
    Inc(FStats.TotalBytes, ASize);
    if Assigned(FLogProc) then
      FLogProc(leAlloc, Result, ASize);
  end;
end;

function TLoggingAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
  begin
    Inc(FStats.ReallocCount);
    if Assigned(FLogProc) then
      FLogProc(leRealloc, Result, ASize);
  end;
end;

procedure TLoggingAllocator.FreeMem(APtr: Pointer); inline;
begin
  if APtr = nil then
    Exit;
  if Assigned(FLogProc) then
    FLogProc(leFree, APtr, 0);
  FInner.FreeMem(APtr);
  Inc(FStats.FreeCount);
end;

function TLoggingAllocator.GetStats: TLoggingStats;
begin
  Result := FStats;
end;

function TLoggingAllocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

end.
