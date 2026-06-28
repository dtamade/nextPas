unit nextpas.core.mem.sizeclass;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

const
  { 62 size classes covering 16B - 57344B.
    Bands (all boundaries aligned to step size):
      16B-256B    (16B step)   — 16 classes
      256B-1KB    (64B step)   — 13 classes
      1KB-4KB     (256B step)  — 13 classes
      4KB-8KB     (1KB step)   —  5 classes
      8KB-16KB    (2KB step)   —  5 classes
      16KB-57KB   (4KB step)   — 10 classes
    > 57344B → direct mmap (no size class).
    Internal fragmentation (band 1+): worst 25% (4097→5120, 8193→10240). }
  MEM_SIZECLASS_COUNT = 62;
  MEM_SIZECLASS_MAX = 53248;

  { Minimum size class granularity. Allocations < 16B are rounded up to 16B. }
  MEM_SIZECLASS_MIN = 16;

type
  { Size class table entry: the usable size for a given class index. }
  TSizeClassEntry = SizeUInt;

  { Pre-computed size class table. }
  TSizeClassTable = array[0..MEM_SIZECLASS_COUNT - 1] of TSizeClassEntry;

{** Return the size class index (0..59) for a given allocation size.
    Sizes are rounded up to the nearest class boundary.
    Returns -1 if ASize > MEM_SIZECLASS_MAX (caller should use direct mmap).
    O(1): single table lookup. }
function SizeClassIndex(ASize: SizeUInt): Int32; inline;

{** Return the usable size for a given class index (0..59).
    The returned size is >= the size passed to SizeClassIndex. }
function SizeClassSize(AIndex: Int32): SizeUInt;

{** Return True if ASize qualifies for size-class allocation (≤ 64KB). }
function IsSizeClassable(ASize: SizeUInt): Boolean; inline;

var
  { Global immutable size class table. Initialized in initialization section. }
  SizeClasses: TSizeClassTable;

  { Scan/noscan flags per size class. Initialized in initialization section.
    True = allocation may contain pointers (scannable by GC).
    False = allocation is pure data (no pointers).
    Default: all False (noscan). Call SizeClassSetScan to change.
    I-3: GC preparation — pointer-containing and data-only objects stored
    separately to enable efficient conservative/generational GC. }
  SizeClassIsScan: array[0..MEM_SIZECLASS_COUNT - 1] of Boolean;

{** Return True if the size class is marked as scan (pointer-containing). }
function SizeClassGetScan(AIndex: Int32): Boolean; inline;

{** Set the scan/noscan flag for a size class. }
procedure SizeClassSetScan(AIndex: Int32; AIsScan: Boolean);

implementation

const
  { Band boundaries and step sizes. }
  BAND0_MIN   = 16;
  BAND0_MAX   = 256;
  BAND0_STEP  = 16;
  BAND0_COUNT = (BAND0_MAX - BAND0_MIN) div BAND0_STEP + 1;  // 16

  BAND1_MIN   = 256;
  BAND1_MAX   = 1024;
  BAND1_STEP  = 64;
  BAND1_COUNT = (BAND1_MAX - BAND1_MIN) div BAND1_STEP + 1;  // 13

  BAND2_MIN   = 1024;
  BAND2_MAX   = 4096;
  BAND2_STEP  = 256;
  BAND2_COUNT = (BAND2_MAX - BAND2_MIN) div BAND2_STEP + 1;  // 13

  BAND3_MIN   = 4096;
  BAND3_MAX   = 8192;
  BAND3_STEP  = 1024;
  BAND3_COUNT = (BAND3_MAX - BAND3_MIN) div BAND3_STEP + 1;  // 5

  BAND4_MIN   = 8192;
  BAND4_MAX   = 16384;
  BAND4_STEP  = 2048;
  BAND4_COUNT = (BAND4_MAX - BAND4_MIN) div BAND4_STEP + 1;  // 5

  BAND5_MIN   = 16384;
  BAND5_MAX   = 53248;
  BAND5_STEP  = 4096;
  BAND5_COUNT = (BAND5_MAX - BAND5_MIN) div BAND5_STEP + 1;  // 10

  { Cumulative index offsets. }
  BAND0_OFFSET = 0;
  BAND1_OFFSET = BAND0_COUNT;                           // 16
  BAND2_OFFSET = BAND1_OFFSET + BAND1_COUNT;            // 29
  BAND3_OFFSET = BAND2_OFFSET + BAND2_COUNT;            // 42
  BAND4_OFFSET = BAND3_OFFSET + BAND3_COUNT;            // 47
  BAND5_OFFSET = BAND4_OFFSET + BAND4_COUNT;            // 52

  { Lookup table granularity: 8 bytes. 65536/8 = 8192 entries. }
  LOOKUP_GRANULARITY = 8;
  LOOKUP_SIZE = MEM_SIZECLASS_MAX div LOOKUP_GRANULARITY;  // 8192

type
  TSizeClassLookup = array[0..LOOKUP_SIZE - 1] of Byte;

var
  { Pre-computed lookup table: SizeClassLookup[size div 8] = class index. }
  SizeClassLookup: TSizeClassLookup;

function SizeClassIndex(ASize: SizeUInt): Int32; inline; inline;
var
  LIdx: SizeUInt;
begin
  if ASize > MEM_SIZECLASS_MAX then
    Exit(-1);
  { Round up to 8-byte alignment for table index. }
  LIdx := (ASize + LOOKUP_GRANULARITY - 1) div LOOKUP_GRANULARITY;
  if LIdx = 0 then
    LIdx := 1; { Minimum 16B class. }
  if LIdx > LOOKUP_SIZE then
    Exit(-1);
  Result := Int32(SizeClassLookup[LIdx - 1]);
end;

function SizeClassSize(AIndex: Int32): SizeUInt;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit(0);
  Result := SizeClasses[AIndex];
end;

function IsSizeClassable(ASize: SizeUInt): Boolean;
begin
  Result := ASize <= MEM_SIZECLASS_MAX;
end;

procedure InitSizeClasses;
var
  I: Int32;
begin
  { Band 0: 16, 32, 48, ..., 256 }
  for I := 0 to BAND0_COUNT - 1 do
    SizeClasses[BAND0_OFFSET + I] := BAND0_MIN + SizeUInt(I) * BAND0_STEP;

  { Band 1: 256, 320, 384, ..., 960, 1024 }
  for I := 0 to BAND1_COUNT - 1 do
    SizeClasses[BAND1_OFFSET + I] := BAND1_MIN + SizeUInt(I) * BAND1_STEP;

  { Band 2: 1024, 1280, 1536, ..., 3840, 4096 }
  for I := 0 to BAND2_COUNT - 1 do
    SizeClasses[BAND2_OFFSET + I] := BAND2_MIN + SizeUInt(I) * BAND2_STEP;

  { Band 3: 4096, 5120, 6144, 7168, 8192 }
  for I := 0 to BAND3_COUNT - 1 do
    SizeClasses[BAND3_OFFSET + I] := BAND3_MIN + SizeUInt(I) * BAND3_STEP;

  { Band 4: 8192, 10240, 12288, 14336, 16384 }
  for I := 0 to BAND4_COUNT - 1 do
    SizeClasses[BAND4_OFFSET + I] := BAND4_MIN + SizeUInt(I) * BAND4_STEP;

  { Band 5: 16384, 20480, 24576, ..., 49152, 53248 }
  for I := 0 to BAND5_COUNT - 1 do
    SizeClasses[BAND5_OFFSET + I] := BAND5_MIN + SizeUInt(I) * BAND5_STEP;
end;

procedure InitLookup;
var
  LSize: SizeUInt;
  LBand: Int32;
  LIndex: Int32;
  LSlot: SizeUInt;
begin
  { Fill the lookup table: for each 8-byte-aligned slot, find the class index. }
  for LSlot := 0 to LOOKUP_SIZE - 1 do
  begin
    LSize := (LSlot + 1) * LOOKUP_GRANULARITY; { Actual size: 8, 16, 24, ..., 65536 }
    if LSize < BAND0_MIN then
    begin
      { Sizes < 16B → class 0 (16B). }
      SizeClassLookup[LSlot] := 0;
      Continue;
    end;
    { Find which class this size falls into. }
    LIndex := -1;
    { Scan class table to find smallest class >= LSize.
      Since table is sorted, we scan forward. For 62 entries this is fast.
      Called once at init, not on hot path. }
    for LBand := 0 to MEM_SIZECLASS_COUNT - 1 do
    begin
      if SizeClasses[LBand] >= LSize then
      begin
        LIndex := LBand;
        Break;
      end;
    end;
    if LIndex < 0 then
      LIndex := MEM_SIZECLASS_COUNT - 1; { Fallback: largest class. }
    SizeClassLookup[LSlot] := Byte(LIndex);
  end;
end;

function SizeClassGetScan(AIndex: Int32): Boolean;
begin
  if (AIndex < 0) or (AIndex >= MEM_SIZECLASS_COUNT) then
    Exit(False);
  Result := SizeClassIsScan[AIndex];
end;

procedure SizeClassSetScan(AIndex: Int32; AIsScan: Boolean);
begin
  if (AIndex >= 0) and (AIndex < MEM_SIZECLASS_COUNT) then
    SizeClassIsScan[AIndex] := AIsScan;
end;

initialization
  InitSizeClasses;
  InitLookup;
  { Default: all size classes are noscan (pure data). }
  FillChar(SizeClassIsScan, SizeOf(SizeClassIsScan), 0);

end.
