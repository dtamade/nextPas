unit nextpas.core.mem.aligned;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, nextpas.core.base;

{ Minimal, cross-platform aligned allocation shim.
  - Windows: use _aligned_malloc/_aligned_free
  - Unix: use posix_memalign if available (fall back to over-allocate)
  - Others: over-allocate and store original pointer before the returned pointer

  Notes:
  - alignment must be power of two and >= SizeOf(Pointer)
  - FreeAligned must be used to free memory allocated by AllocAligned
}

function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
procedure FreeAligned(APtr: Pointer);

implementation

{$IFDEF MSWINDOWS}
  function _aligned_malloc(size: SizeUInt; alignment: SizeUInt): Pointer; cdecl; external 'msvcrt.dll';
  procedure _aligned_free(memblock: Pointer); cdecl; external 'msvcrt.dll';
{$ENDIF}

{$IFDEF UNIX}
  function posix_memalign(memptr: PPointer; alignment: SizeUInt; size: SizeUInt): LongInt; cdecl; external 'libc' name 'posix_memalign';
  procedure libc_free(aPtr: Pointer); cdecl; external 'libc' name 'free';
{$ENDIF}

function IsPowerOfTwo(x: SizeUInt): Boolean; inline;
begin
  Result := (x <> 0) and ((x and (x - 1)) = 0);
end;

function AlignUpPtr(P: Pointer; AAlignment: SizeUInt): Pointer; inline;
var
  LAddr, LMask: PtrUInt;
begin
  LAddr := PtrUInt(P);
  LMask := PtrUInt(AAlignment - 1);
  Result := Pointer((LAddr + LMask) and not LMask);
end;

function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
var
  LRaw: Pointer;
  LNeeded: SizeUInt;
  LHeaderPtr: PPointer;
begin
  if ASize = 0 then Exit(nil);
  if (AAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(AAlignment)) then
    raise EInvalidArgument.Create('AllocAligned: alignment must be power of two and >= pointer size');

  {$IFDEF MSWINDOWS}
  Result := _aligned_malloc(ASize, AAlignment);
  Exit;
  {$ENDIF}

  {$IFDEF UNIX}
  LRaw := nil;
  if posix_memalign(@LRaw, AAlignment, ASize) = 0 then
  begin
    Result := LRaw;
    Exit;
  end;
  // fall through to over-allocate if posix_memalign failed for some reason
  {$ENDIF}

  // Generic fallback: over-allocate and store the original pointer just before the aligned block
  LNeeded := ASize + AAlignment - 1 + SizeOf(Pointer);
  LRaw := SysGetMem(LNeeded);
  if LRaw = nil then Exit(nil);
  Result := AlignUpPtr(Pointer(PtrUInt(LRaw) + SizeOf(Pointer)), AAlignment);
  LHeaderPtr := PPointer(PtrUInt(Result) - SizeOf(Pointer));
  LHeaderPtr^ := LRaw; // store original pointer
end;

procedure FreeAligned(APtr: Pointer);
var
  LRaw: Pointer;
  LHeaderPtr: PPointer;
begin
  if APtr = nil then Exit;

  {$IFDEF MSWINDOWS}
  _aligned_free(APtr);
  Exit;
  {$ENDIF}

  {$IFDEF UNIX}
  // Memory returned by posix_memalign must be freed with libc free
  libc_free(APtr);
  Exit;
  {$ENDIF}

  // Fallback: load original pointer and free it
  LHeaderPtr := PPointer(PtrUInt(APtr) - SizeOf(Pointer));
  LRaw := LHeaderPtr^;
  SysFreeMem(LRaw);
end;

end.
