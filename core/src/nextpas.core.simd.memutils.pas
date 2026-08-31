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
procedure Prefetch(ptr: Pointer);
procedure PrefetchNTA(ptr: Pointer);  // Non-temporal (won't pollute cache)

// SIMD-optimized memory copy (SSE2/AVX2/AVX-512)
procedure SimdMemCopy(src, dst: Pointer; size: NativeUInt);

// SIMD-optimized memory fill
procedure SimdMemFill(dst: Pointer; size: NativeUInt; value: Byte);

// SIMD-optimized memory compare
function SimdMemCompare(p1, p2: Pointer; size: NativeUInt): Integer;

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
  nextpas.core.mem,
  nextpas.core.mem.base,
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
// layout is (F6):
//   [ originalPtr : Pointer ][ totalSize : NativeUInt ][ userSize : NativeUInt ]
//   [ aligned data ... ]
// totalSize is the GetMem block size (sized free without TryBlockSize).
// userSize is the requested payload for AlignedRealloc copy.

const
  ALIGNED_HEADER_SIZE = SizeOf(Pointer) + 2 * SizeOf(NativeUInt);

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

  headerOffset := ALIGNED_HEADER_SIZE;
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
  PNativeUInt(headerBase + SizeOf(Pointer))^ := totalSize;
  PNativeUInt(headerBase + SizeOf(Pointer) + SizeOf(NativeUInt))^ := size;
  {$POP}

  Result := alignedPtr;
end;

procedure AlignedFree(ptr: Pointer);
var
  originalPtr: Pointer;
  headerBase: NativeUInt;
  totalSize: NativeUInt;
begin
  if ptr <> nil then
  begin
    {$PUSH}{$WARN 4055 OFF}
    headerBase := NativeUInt(ptr) - ALIGNED_HEADER_SIZE;
    originalPtr := PPointer(headerBase)^;
    totalSize := PNativeUInt(headerBase + SizeOf(Pointer))^;
    {$POP}
    FreeMem(originalPtr, totalSize);
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

  // Recover the originally requested user size from the header
  {$PUSH}{$WARN 4055 OFF}
  headerBase := NativeUInt(ptr) - ALIGNED_HEADER_SIZE;
  oldSize := PNativeUInt(headerBase + SizeOf(Pointer) + SizeOf(NativeUInt))^;
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
  aligned: SizeUInt;
begin
  RequireValidAlignment(alignment);
  {$PUSH}{$WARN 4055 OFF}
  addr := NativeUInt(ptr);
  { mem.base.AlignUp(0) uses (not 0)+1 under Q+ range checks and overflows; nil stays nil. }
  if addr = 0 then
    Exit(nil);
  aligned := nextpas.core.mem.base.AlignUp(SizeUInt(addr), SizeUInt(alignment));
  if aligned = 0 then
    raise EOutOfMemory.CreateFmt(
      'Aligned pointer overflow: addr=%d, alignment=%d', [addr, alignment]);
  Result := Pointer(aligned);
  {$POP}
end;

function AlignUpSize(size: NativeUInt; alignment: NativeUInt): NativeUInt;
begin
  RequireValidAlignment(alignment);
  { size=0 is valid and must not call mem.base.AlignUp(0) under Q+ range checks. }
  if size = 0 then
    Exit(0);
  { Reuse mem.base.AlignUp (overflow → 0); keep SIMD overflow raise contract. }
  Result := nextpas.core.mem.base.AlignUp(SizeUInt(size), SizeUInt(alignment));
  if Result = 0 then
    raise EOutOfMemory.CreateFmt(
      'Aligned size overflow: size=%d, alignment=%d', [size, alignment]);
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

  if size > 0 then
    SimdMemCopy(src, dst, size);
end;

procedure AlignedMemFill(dst: Pointer; size: NativeUInt; value: Byte; alignment: NativeUInt);
begin
  RequireValidAlignment(alignment);
  {$IFDEF SIMD_DEBUG_ASSERTIONS}
  Assert(IsAligned(dst, alignment), 'Destination not aligned');
  {$ENDIF}

  if size > 0 then
    SimdMemFill(dst, size, value);
end;

procedure Prefetch(ptr: Pointer);
var
  LPtr: Pointer;
begin
  // Platform-specific prefetch instructions would go here.
  if ptr = nil then
    Exit;
  LPtr := ptr;
  {$IF Defined(CPUX86_64)}
  asm
    mov rax, LPtr
    prefetcht0 [rax]
  end;
  {$ELSEIF Defined(CPUX86)}
  asm
    mov eax, LPtr
    prefetcht0 [eax]
  end;
  {$ENDIF}
end;

procedure PrefetchNTA(ptr: Pointer);
var
  LPtr: Pointer;
begin
  // Non-temporal prefetch.
  if ptr = nil then
    Exit;
  LPtr := ptr;
  {$IF Defined(CPUX86_64)}
  asm
    mov rax, LPtr
    prefetchnta [rax]
  end;
  {$ELSEIF Defined(CPUX86)}
  asm
    mov eax, LPtr
    prefetchnta [eax]
  end;
  {$ENDIF}
end;

// === SIMD-optimized Memory Operations ===

{ 手工 SSE2 快路径仅 64 位：i386 上指针寄存器为 32 位，且该路径非 32 位性能面；
  32 位统一走 SimdMemCopy/Fill/Compare 的标量回退 }
{$IF Defined(CPUX86_64)}
procedure SimdMemCopy_SSE2(src, dst: Pointer; size: NativeUInt);
var
  pS, pD: PByte;
  remaining: NativeUInt;
begin
  pS := src;
  pD := dst;
  remaining := size;

  // Large copy path with prefetching (> 4KB)
  if remaining >= 4096 then
  begin
    // Copy 128 bytes at a time with prefetch (8 x 16 bytes)
    while remaining >= 128 do
    begin
      asm
        mov rax, pS
        mov rdx, pD
        // Prefetch next cache line
        prefetchnta [rax + 256]
        // Copy 128 bytes
        movdqu xmm0, [rax]
        movdqu xmm1, [rax + 16]
        movdqu xmm2, [rax + 32]
        movdqu xmm3, [rax + 48]
        movdqu xmm4, [rax + 64]
        movdqu xmm5, [rax + 80]
        movdqu xmm6, [rax + 96]
        movdqu xmm7, [rax + 112]
        movdqu [rdx], xmm0
        movdqu [rdx + 16], xmm1
        movdqu [rdx + 32], xmm2
        movdqu [rdx + 48], xmm3
        movdqu [rdx + 64], xmm4
        movdqu [rdx + 80], xmm5
        movdqu [rdx + 96], xmm6
        movdqu [rdx + 112], xmm7
      end;
      Inc(pS, 128);
      Inc(pD, 128);
      Dec(remaining, 128);
    end;
  end;

  // Copy 64 bytes at a time (4 x 16 bytes)
  while remaining >= 64 do
  begin
    asm
      mov rax, pS
      mov rdx, pD
      movdqu xmm0, [rax]
      movdqu xmm1, [rax + 16]
      movdqu xmm2, [rax + 32]
      movdqu xmm3, [rax + 48]
      movdqu [rdx], xmm0
      movdqu [rdx + 16], xmm1
      movdqu [rdx + 32], xmm2
      movdqu [rdx + 48], xmm3
    end;
    Inc(pS, 64);
    Inc(pD, 64);
    Dec(remaining, 64);
  end;

  // Copy remaining 16-byte blocks
  while remaining >= 16 do
  begin
    asm
      mov rax, pS
      mov rdx, pD
      movdqu xmm0, [rax]
      movdqu [rdx], xmm0
    end;
    Inc(pS, 16);
    Inc(pD, 16);
    Dec(remaining, 16);
  end;

  // Copy remaining bytes
  while remaining > 0 do
  begin
    pD^ := pS^;
    Inc(pS);
    Inc(pD);
    Dec(remaining);
  end;
end;

procedure SimdMemFill_SSE2(dst: Pointer; size: NativeUInt; value: Byte);
var
  pD: PByte;
  remaining: NativeUInt;
  pattern: array[0..15] of Byte;
  i: Integer;
begin
  pD := dst;
  remaining := size;

  // Create 16-byte pattern
  for i := 0 to 15 do
    pattern[i] := value;

  // Fill 64 bytes at a time (4 x 16 bytes)
  if remaining >= 64 then
  begin
    asm
      mov rax, pD
      lea rdx, pattern
      movdqu xmm0, [rdx]
      movdqa xmm1, xmm0
      movdqa xmm2, xmm0
      movdqa xmm3, xmm0
    end;

    while remaining >= 64 do
    begin
      asm
        mov rax, pD
        movdqu [rax], xmm0
        movdqu [rax + 16], xmm1
        movdqu [rax + 32], xmm2
        movdqu [rax + 48], xmm3
      end;
      Inc(pD, 64);
      Dec(remaining, 64);
    end;
  end;

  // Fill remaining 16-byte blocks
  while remaining >= 16 do
  begin
    asm
      mov rax, pD
      lea rdx, pattern
      movdqu xmm0, [rdx]
      movdqu [rax], xmm0
    end;
    Inc(pD, 16);
    Dec(remaining, 16);
  end;

  // Fill remaining bytes
  while remaining > 0 do
  begin
    pD^ := value;
    Inc(pD);
    Dec(remaining);
  end;
end;

function SimdMemCompare_SSE2(p1, p2: Pointer; size: NativeUInt): Integer;
var
  ptr1, ptr2: PByte;
  remaining: NativeUInt;
  matchMask: UInt32;
  i: Integer;
begin
  ptr1 := p1;
  ptr2 := p2;
  remaining := size;

  // Compare 16 bytes at a time
  while remaining >= 16 do
  begin
    matchMask := 0;
    asm
      mov rax, ptr1
      mov rdx, ptr2
      movdqu xmm0, [rax]
      movdqu xmm1, [rdx]
      pcmpeqb xmm0, xmm1
      pmovmskb eax, xmm0
      mov matchMask, eax
    end;

    // Check if all 16 bytes matched
    if matchMask <> $FFFF then
    begin
      // Found difference, compare byte by byte
      for i := 0 to 15 do
      begin
        if ptr1[i] < ptr2[i] then
          Exit(-1)
        else if ptr1[i] > ptr2[i] then
          Exit(1);
      end;
    end;

    Inc(ptr1, 16);
    Inc(ptr2, 16);
    Dec(remaining, 16);
  end;

  // Compare remaining bytes
  while remaining > 0 do
  begin
    if ptr1^ < ptr2^ then
      Exit(-1)
    else if ptr1^ > ptr2^ then
      Exit(1);
    Inc(ptr1);
    Inc(ptr2);
    Dec(remaining);
  end;

  Result := 0;
end;
{$ENDIF}

procedure SimdMemCopy(src, dst: Pointer; size: NativeUInt);
begin
  if (src = nil) or (dst = nil) or (size = 0) then
    Exit;

  {$IF Defined(CPUX86_64)}
  SimdMemCopy_SSE2(src, dst, size);
  {$ELSE}
  Move(src^, dst^, size);
  {$ENDIF}
end;

procedure SimdMemFill(dst: Pointer; size: NativeUInt; value: Byte);
begin
  if (dst = nil) or (size = 0) then
    Exit;

  {$IF Defined(CPUX86_64)}
  SimdMemFill_SSE2(dst, size, value);
  {$ELSE}
  FillChar(dst^, size, value);
  {$ENDIF}
end;

function SimdMemCompare(p1, p2: Pointer; size: NativeUInt): Integer;
begin
  if (p1 = nil) or (p2 = nil) then
  begin
    if p1 = p2 then
      Exit(0)
    else if p1 = nil then
      Exit(-1)
    else
      Exit(1);
  end;

  if size = 0 then
    Exit(0);

  {$IF Defined(CPUX86_64)}
  Result := SimdMemCompare_SSE2(p1, p2, size);
  {$ELSE}
  Result := CompareByte(p1^, p2^, size);
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
    { Avoid High(NativeUInt) under Q+ range checks — FPC treats it as signed -1. }
    maxCount := NativeUInt(not NativeUInt(0)) div NativeUInt(SizeOf(T));
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
