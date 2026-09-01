unit nextpas.core.system.heap;
{**
 * @desc Sole owner of FPC System heap / Move primitives for nextpas.core.
 *
 * Only this unit (and nextpas.core.system.memmanager for TMemoryManager hooks)
 * may call System.GetMem / FreeMem / ReallocMem / AllocMem / Move.
 * All other core modules must route through these thin inline wrappers.
 *
 * Contract (aligned with process heap expectations):
 *   - GetMem/AllocMem(0) → nil
 *   - FreeMem(nil) → no-op
 *   - ReallocMem(nil, n) → GetMem(n); ReallocMem(p, 0) → FreeMem(p), nil
 *}

{$I nextpas.core.settings.inc}

interface

{** Allocate ASize uninitialized bytes. ASize=0 → nil. }
function NpSystemGetMem(ASize: SizeUInt): Pointer; inline;

{** Allocate ASize zeroed bytes. ASize=0 → nil. }
function NpSystemAllocMem(ASize: SizeUInt): Pointer; inline;

{** Free a block. APtr=nil → no-op. }
procedure NpSystemFreeMem(APtr: Pointer); inline;

{** Free a block with known size (FPC sized free when available). APtr=nil → no-op. }
procedure NpSystemFreeMem(APtr: Pointer; ASize: SizeUInt); inline;

{** Resize block. nil+size→alloc; ptr+0→free+nil. }
function NpSystemReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

{** Move ACount bytes from ASrc to ADst (may overlap per System.Move). }
procedure NpSystemMove(const ASrc; var ADst; ACount: SizeUInt); inline;

{** Return usable heap block size for APtr (via System.MemSize); nil → 0. }
function NpSystemMemSize(APtr: Pointer): SizeUInt; inline;

implementation

function NpSystemGetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.GetMem(ASize);
end;

function NpSystemAllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := System.AllocMem(ASize);
end;

procedure NpSystemFreeMem(APtr: Pointer);
begin
  if APtr = nil then
    Exit;
  System.FreeMem(APtr);
end;

procedure NpSystemFreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  if APtr = nil then
    Exit;
  { Sized free when ASize known; FPC accepts size hint. }
  if ASize > 0 then
    System.FreeMem(APtr, ASize)
  else
    System.FreeMem(APtr);
end;

function NpSystemReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    if APtr <> nil then
      System.FreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(System.GetMem(ASize));
  Result := System.ReallocMem(APtr, ASize);
end;

procedure NpSystemMove(const ASrc; var ADst; ACount: SizeUInt);
begin
  if ACount = 0 then
    Exit;
  System.Move(ASrc, ADst, SizeInt(ACount));
end;

function NpSystemMemSize(APtr: Pointer): SizeUInt;
begin
  if APtr = nil then
    Exit(0);
  Result := SizeUInt(System.MemSize(APtr));
end;

end.
