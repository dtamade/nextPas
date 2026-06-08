unit nextpas.core.simd.memutils;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.base;

// === Aligned Memory Allocation ===

// Allocate aligned memory
function AlignedAlloc(size: NativeUInt; alignment: NativeUInt): Pointer;

// Free aligned memory
procedure AlignedFree(ptr: Pointer);

// Reallocate aligned memory
function AlignedRealloc(ptr: Pointer; newSize: NativeUInt; alignment: NativeUInt): Pointer;

// === Alignment Utilities ===

// Check if pointer is aligned to specified boundary
function IsAligned(ptr: Pointer; alignment: NativeUInt): Boolean; inline;

// Align pointer up to next boundary
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
  nextpas.core.platform.memory;

function IsValidAlignment(alignment: NativeUInt): Boolean; inline;
begin
  Result := (alignment >= SizeOf(Pointer)) and ((alignment and (alignment - 1)) = 0);
end;

function AlignedAlloc(size: NativeUInt; alignment: NativeUInt): Pointer;
begin
  Result := platform_aligned_alloc(size, alignment);
end;

procedure AlignedFree(ptr: Pointer);
begin
  platform_aligned_free(ptr);
end;

function AlignedRealloc(ptr: Pointer; newSize: NativeUInt; alignment: NativeUInt): Pointer;
begin
  Result := platform_aligned_realloc(ptr, newSize, alignment);
end;

// === Alignment Utilities ===

function IsAligned(ptr: Pointer; alignment: NativeUInt): Boolean;
begin
  if not IsValidAlignment(alignment) then
    Exit(False);

  {$PUSH}{$WARN 4055 OFF}
  Result := (NativeUInt(ptr) and (alignment - 1)) = 0;
  {$POP}
end;

function AlignUp(ptr: Pointer; alignment: NativeUInt): Pointer;
var
  addr: NativeUInt;
begin
  if not IsValidAlignment(alignment) then
    Exit(nil);

  {$PUSH}{$WARN 4055 OFF}
  addr := NativeUInt(ptr);
  addr := (addr + alignment - 1) and not (alignment - 1);
  Result := Pointer(addr);
  {$POP}
end;

function AlignUpSize(size: NativeUInt; alignment: NativeUInt): NativeUInt;
begin
  if not IsValidAlignment(alignment) then
    Exit(0);
  if size > High(NativeUInt) - (alignment - 1) then
    Exit(0);

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
  {$IFDEF SIMD_DEBUG_ASSERTIONS}
  Assert(IsAligned(src, alignment), 'Source not aligned');
  Assert(IsAligned(dst, alignment), 'Destination not aligned');
  {$ENDIF}

  // Always reference alignment to keep builds hint-clean when SIMD_DEBUG_ASSERTIONS is off.
  if alignment = 0 then ;
  
  // Use optimized copy for aligned memory
  // For now, just use Move - could be optimized with SIMD
  Move(src^, dst^, size);
end;

procedure AlignedMemFill(dst: Pointer; size: NativeUInt; value: Byte; alignment: NativeUInt);
begin
  {$IFDEF SIMD_DEBUG_ASSERTIONS}
  Assert(IsAligned(dst, alignment), 'Destination not aligned');
  {$ENDIF}

  // Always reference alignment to keep builds hint-clean when SIMD_DEBUG_ASSERTIONS is off.
  if alignment = 0 then ;
  
  // Use optimized fill for aligned memory
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
