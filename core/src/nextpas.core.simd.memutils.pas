unit nextpas.core.simd.memutils;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.base;

// === Aligned Memory Allocation ===

// Allocate aligned memory. Alignment must be a non-zero power of two and at
// least SizeOf(Pointer); SIMD callers should normally use 16, 32, or 64.
function AlignedAlloc(size: NativeUInt; alignment: NativeUInt): Pointer;

// Free aligned memory
procedure AlignedFree(ptr: Pointer);

// Reallocate aligned memory with the same alignment contract as AlignedAlloc.
function AlignedRealloc(ptr: Pointer; newSize: NativeUInt; alignment: NativeUInt): Pointer;

// === Alignment Utilities ===

// Check if pointer is aligned to a valid power-of-two boundary.
function IsAligned(ptr: Pointer; alignment: NativeUInt): Boolean; inline;

// Align pointer/size up to a valid power-of-two boundary.
function AlignUp(ptr: Pointer; alignment: NativeUInt): Pointer; inline;
function AlignUpSize(size: NativeUInt; alignment: NativeUInt): NativeUInt; inline;

// Get alignment of pointer (largest power of 2 that divides address)
function GetAlignment(ptr: Pointer): NativeUInt;

// === Memory Operations ===

// Fast aligned memory copy (requires both src and dst to be aligned)
procedure AlignedMemCopy(src, dst: Pointer; size: NativeUInt; alignment: NativeUInt);

// Fast aligned memory fill
procedure AlignedMemFill(dst: Pointer; size: NativeUInt; value: Byte; alignment: NativeUInt);

// Memory prefetch hints
procedure Prefetch(ptr: Pointer); inline;
procedure PrefetchNTA(ptr: Pointer); inline;  // Non-temporal (won't pollute cache)

// === Aligned Array Helper ===
type
  // RAII-style aligned array
  generic TAlignedArray<T> = record
  private
    FData: Pointer;
    FSize: NativeUInt;
    FAlignment: NativeUInt;
    FOwnsMemory: Boolean;
  public
    // Create aligned array
    class function Create(count: NativeUInt; alignment: NativeUInt = 32): TAlignedArray; static;
    
    // Create from existing aligned memory (doesn't take ownership)
    class function FromPointer(ptr: Pointer; count: NativeUInt; alignment: NativeUInt): TAlignedArray; static;
    
    // Destroy and free memory
    procedure Free;
    
    // Properties
    function GetData: Pointer; inline;
    function GetItem(index: NativeUInt): T; inline;
    procedure SetItem(index: NativeUInt; const value: T); inline;
    function GetCount: NativeUInt; inline;
    function GetAlignment: NativeUInt; inline;
    function IsValid: Boolean; inline;
    
    // Array access
    property Data: Pointer read GetData;
    property Items[index: NativeUInt]: T read GetItem write SetItem; default;
    property Count: NativeUInt read GetCount;
    property Alignment: NativeUInt read GetAlignment;
  end;

// === Constants ===
const
  // Common alignment values
  SIMD_ALIGN_16 = 16;   // SSE alignment
  SIMD_ALIGN_32 = 32;   // AVX alignment  
  SIMD_ALIGN_64 = 64;   // AVX-512 alignment
  SIMD_ALIGN_CACHE = 64; // Cache line alignment

implementation

uses
  nextpas.core.errors;

function IsPowerOfTwo(const AValue: NativeUInt): Boolean; inline;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

procedure RequireValidAlignment(const AAlignment: NativeUInt); inline;
begin
  if (AAlignment < SizeOf(Pointer)) or (not IsPowerOfTwo(AAlignment)) then
    raise EArgumentError.Create(
      'SIMD alignment must be a non-zero power of two and at least SizeOf(Pointer)');
end;

function AddAlignedAllocationSize(
  const ASize, AAlignment, AHeaderSize: NativeUInt): NativeUInt;
var
  LPadding: NativeUInt;
begin
  RequireValidAlignment(AAlignment);
  LPadding := AAlignment - 1;
  if (ASize > High(NativeUInt) - AHeaderSize) or
    (ASize + AHeaderSize > High(NativeUInt) - LPadding) then
    raise EOutOfMemory.CreateFmt(
      'Allocation size overflow: size=%d, alignment=%d', [ASize, AAlignment]);
  Result := ASize + AHeaderSize + LPadding;
end;

{$IFDEF WINDOWS}
// Windows CRT aligned memory functions
function _aligned_malloc(size: NativeUInt; alignment: NativeUInt): Pointer; cdecl; external 'msvcrt.dll' name '_aligned_malloc';
procedure _aligned_free(ptr: Pointer); cdecl; external 'msvcrt.dll' name '_aligned_free';
function _aligned_realloc(ptr: Pointer; size: NativeUInt; alignment: NativeUInt): Pointer; cdecl; external 'msvcrt.dll' name '_aligned_realloc';
{$ENDIF}

// === Platform-specific aligned allocation ===

{$IFDEF WINDOWS}

function AlignedAlloc(size: NativeUInt; alignment: NativeUInt): Pointer;
begin
  RequireValidAlignment(alignment);
  if size = 0 then
    Exit(nil);

  Result := _aligned_malloc(size, alignment);
  if Result = nil then
    raise EOutOfMemory.CreateFmt('Failed to allocate %d bytes with %d alignment', [size, alignment]);
end;

procedure AlignedFree(ptr: Pointer);
begin
  if ptr <> nil then
    _aligned_free(ptr);
end;

function AlignedRealloc(ptr: Pointer; newSize: NativeUInt; alignment: NativeUInt): Pointer;
begin
  RequireValidAlignment(alignment);
  if newSize = 0 then
  begin
    AlignedFree(ptr);
    Exit(nil);
  end;

  Result := _aligned_realloc(ptr, newSize, alignment);
  if (Result = nil) and (newSize > 0) then
    raise EOutOfMemory.CreateFmt('Failed to reallocate %d bytes with %d alignment', [newSize, alignment]);
end;

{$ELSE} // UNIX/Linux

// On UNIX-like systems we emulate aligned allocation by over-allocating and
// storing a small header immediately before the aligned pointer. The header
// layout is:
//   [ originalPtr : Pointer ][ allocSize : NativeUInt ][ aligned data ... ]
// This allows AlignedFree and AlignedRealloc to recover both the original
// pointer returned by GetMem and the originally requested size.

function AlignedAlloc(size: NativeUInt; alignment: NativeUInt): Pointer;
var
  originalPtr: Pointer;
  alignedPtr: Pointer;
  headerOffset: NativeUInt;
  headerBase: NativeUInt;
  totalSize: NativeUInt;
begin
  if size = 0 then
  begin
    RequireValidAlignment(alignment);
    Exit(nil);
  end;

  headerOffset := SizeOf(Pointer) + SizeOf(NativeUInt);
  totalSize := AddAlignedAllocationSize(size, alignment, headerOffset);
  originalPtr := GetMem(totalSize);
  if originalPtr = nil then
    raise EOutOfMemory.CreateFmt('Failed to allocate %d bytes with %d alignment', [size, alignment]);

  {$PUSH}{$WARN 4055 OFF}
  // Calculate aligned address, leaving room for the header just before it
  alignedPtr := Pointer(
    (NativeUInt(originalPtr) + headerOffset + alignment - 1) and not (alignment - 1));

  // Store header immediately before the aligned pointer
  headerBase := NativeUInt(alignedPtr) - headerOffset;
  PPointer(headerBase)^ := originalPtr;
  PNativeUInt(headerBase + SizeOf(Pointer))^ := size;
  {$POP}

  Result := alignedPtr;
end;

procedure AlignedFree(ptr: Pointer);
var
  originalPtr: Pointer;
  headerBase: NativeUInt;
begin
  if ptr <> nil then
  begin
    // Retrieve original pointer from header and free whole block
    {$PUSH}{$WARN 4055 OFF}
    headerBase := NativeUInt(ptr) - (SizeOf(Pointer) + SizeOf(NativeUInt));
    originalPtr := PPointer(headerBase)^;
    {$POP}
    FreeMem(originalPtr);
  end;
end;

function AlignedRealloc(ptr: Pointer; newSize: NativeUInt; alignment: NativeUInt): Pointer;
var
  newPtr: Pointer;
  oldSize, copySize: NativeUInt;
  headerBase: NativeUInt;
begin
  RequireValidAlignment(alignment);

  // Behave like malloc when ptr = nil
  if ptr = nil then
  begin
    if newSize = 0 then
      Exit(nil);
    Result := AlignedAlloc(newSize, alignment);
    Exit;
  end;

  // Behave like free when newSize = 0
  if newSize = 0 then
  begin
    AlignedFree(ptr);
    Result := nil;
    Exit;
  end;

  // Recover the originally requested size from the header
  {$PUSH}{$WARN 4055 OFF}
  headerBase := NativeUInt(ptr) - (SizeOf(Pointer) + SizeOf(NativeUInt));
  oldSize := PNativeUInt(headerBase + SizeOf(Pointer))^;
  {$POP}

  // Allocate new aligned memory
  newPtr := AlignedAlloc(newSize, alignment);

  // Copy the overlapping part only
  if oldSize < newSize then
    copySize := oldSize
  else
    copySize := newSize;
  if copySize > 0 then
    Move(ptr^, newPtr^, copySize);

  // Free old memory
  AlignedFree(ptr);

  Result := newPtr;
end;

{$ENDIF}

// === Alignment Utilities ===

function IsAligned(ptr: Pointer; alignment: NativeUInt): Boolean;
begin
  RequireValidAlignment(alignment);
  {$PUSH}{$WARN 4055 OFF}
  Result := (NativeUInt(ptr) and (alignment - 1)) = 0;
  {$POP}
end;

function AlignUp(ptr: Pointer; alignment: NativeUInt): Pointer;
var
  addr: NativeUInt;
begin
  RequireValidAlignment(alignment);
  {$PUSH}{$WARN 4055 OFF}
  addr := NativeUInt(ptr);
  if addr > High(NativeUInt) - (alignment - 1) then
    raise EOutOfMemory.CreateFmt(
      'Aligned pointer overflow: addr=%d, alignment=%d', [addr, alignment]);
  addr := (addr + alignment - 1) and not (alignment - 1);
  Result := Pointer(addr);
  {$POP}
end;

function AlignUpSize(size: NativeUInt; alignment: NativeUInt): NativeUInt;
begin
  RequireValidAlignment(alignment);
  if size > High(NativeUInt) - (alignment - 1) then
    raise EOutOfMemory.CreateFmt(
      'Aligned size overflow: size=%d, alignment=%d', [size, alignment]);
  Result := (size + alignment - 1) and not (alignment - 1);
end;

function GetAlignment(ptr: Pointer): NativeUInt;
var
  addr: NativeUInt;
begin
  {$PUSH}{$WARN 4055 OFF}
  addr := NativeUInt(ptr);
  {$POP}
  if addr = 0 then
  begin
    Result := 0;
    Exit;
  end;
  
  // Find largest power of 2 that divides address
  Result := 1;
  while (addr and Result) = 0 do
    Result := Result shl 1;
end;

// === Memory Operations ===

procedure AlignedMemCopy(src, dst: Pointer; size: NativeUInt; alignment: NativeUInt);
begin
  RequireValidAlignment(alignment);
  {$IFDEF SIMD_DEBUG_ASSERTIONS}
  Assert(IsAligned(src, alignment), 'Source not aligned');
  Assert(IsAligned(dst, alignment), 'Destination not aligned');
  {$ENDIF}
  
  // Use optimized copy for aligned memory
  // For now, just use Move - could be optimized with SIMD
  if size > 0 then
    Move(src^, dst^, size);
end;

procedure AlignedMemFill(dst: Pointer; size: NativeUInt; value: Byte; alignment: NativeUInt);
begin
  RequireValidAlignment(alignment);
  {$IFDEF SIMD_DEBUG_ASSERTIONS}
  Assert(IsAligned(dst, alignment), 'Destination not aligned');
  {$ENDIF}
  
  // Use optimized fill for aligned memory
  if size > 0 then
    FillChar(dst^, size, value);
end;

procedure Prefetch(ptr: Pointer);
begin
  // Platform-specific prefetch instructions would go here.
  // For now, keep it as a no-op while still referencing the parameter.
  if ptr = nil then
    Exit;
  {$IFDEF SIMD_X86_AVAILABLE}
  // Could use: asm prefetcht0 [ptr] end;
  {$ENDIF}
end;

procedure PrefetchNTA(ptr: Pointer);
begin
  // Non-temporal prefetch.
  if ptr = nil then
    Exit;
  {$IFDEF SIMD_X86_AVAILABLE}
  // Could use: asm prefetchnta [ptr] end;
  {$ENDIF}
end;

// === TAlignedArray Implementation ===

class function TAlignedArray.Create(count: NativeUInt; alignment: NativeUInt): TAlignedArray;
var
  maxCount: NativeUInt;
begin
  AlignUpSize(0, alignment);
  Result.FSize := count;
  Result.FAlignment := alignment;
  Result.FOwnsMemory := True;

  if count > 0 then
  begin
    // ✅ Safety check: prevent integer overflow in size calculation
    maxCount := NativeUInt(High(NativeUInt)) div NativeUInt(SizeOf(T));
    if count > maxCount then
      raise EOutOfMemory.CreateFmt('Allocation size overflow: count=%d, elemSize=%d', [count, SizeOf(T)]);
    Result.FData := AlignedAlloc(count * SizeOf(T), alignment);
  end
  else
    Result.FData := nil;
end;

class function TAlignedArray.FromPointer(ptr: Pointer; count: NativeUInt; alignment: NativeUInt): TAlignedArray;
begin
  AlignUpSize(0, alignment);
  Result.FData := ptr;
  Result.FSize := count;
  Result.FAlignment := alignment;
  Result.FOwnsMemory := False;
end;

procedure TAlignedArray.Free;
begin
  if FOwnsMemory and (FData <> nil) then
  begin
    AlignedFree(FData);
    FData := nil;
  end;
  FSize := 0;
end;

function TAlignedArray.GetData: Pointer;
begin
  Result := FData;
end;

function TAlignedArray.GetItem(index: NativeUInt): T;
type
  PT = ^T;
begin
  {$IFDEF SIMD_BOUNDS_CHECK}
  if index >= FSize then
    raise EOutOfRange.CreateFmt('Index %d out of range [0..%d]', [index, FSize - 1]);
  {$ENDIF}
  
  Result := PT(FData)[index];
end;

procedure TAlignedArray.SetItem(index: NativeUInt; const value: T);
type
  PT = ^T;
begin
  {$IFDEF SIMD_BOUNDS_CHECK}
  if index >= FSize then
    raise EOutOfRange.CreateFmt('Index %d out of range [0..%d]', [index, FSize - 1]);
  {$ENDIF}
  
  PT(FData)[index] := value;
end;

function TAlignedArray.GetCount: NativeUInt;
begin
  Result := FSize;
end;

function TAlignedArray.GetAlignment: NativeUInt;
begin
  Result := FAlignment;
end;

function TAlignedArray.IsValid: Boolean;
begin
  Result := FData <> nil;
end;

end.
