unit nextpas.core.mem.span;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass;

const
  { Maximum slots per span = 64 (one UInt64 bitmap). }
  SPAN_MAX_SLOTS = 64;

  { Multi-level span constants. }
  SPAN_LEVEL1_SLOTS = 64;                    { 一级 span: 64 slots }
  SPAN_LEVEL2_SLOTS = 64 * 64;               { 二级 span: 4096 slots }
  SPAN_LEVEL3_SLOTS = 64 * 64 * 64;          { 三级 span: 262144 slots }

type
  {** A span is a contiguous memory region divided into fixed-size slots.
      Allocation uses a 64-bit bitmap: 1=free, 0=used.
      BSF/TZCNT finds the first free slot in O(1). }
  PSpan = ^TSpan;
  TSpan = record
    FBase: Pointer;      { Span memory base address. }
    FBitmap: UInt64;     { Free-slot bitmap: bit=1 means free. }
    FSlotSize: SizeUInt; { Bytes per slot (aligned). }
    FSlotCount: Byte;    { Total slots (1..64). }
    FFreeCount: Byte;    { Remaining free slots. }
  end;

  {** Multi-level span for large-scale allocation scenarios.
      Uses hierarchical bitmaps for O(1) allocation with BSF batch positioning.
      Reduces cache misses in large-scale allocation scenarios. }

  { 一级 span: 64 slots }
  PSpanLevel1 = ^TSpanLevel1;
  TSpanLevel1 = TSpan;

  { 二级 span: 4096 slots (64 * 64) }
  PSpanLevel2 = ^TSpanLevel2;
  TSpanLevel2 = record
    FBase: Pointer;           { Span memory base address. }
    FSlotSize: SizeUInt;      { Bytes per slot (aligned). }
    FSummaryBitmap: UInt64;   { Summary bitmap: bit=1 means level1 span has free slot. }
    FFreeCount: SizeUInt;     { Total remaining free slots. }
    FLevel1Spans: array[0..63] of TSpanLevel1; { 64 level1 spans. }
  end;

  { 三级 span: 262144 slots (64 * 64 * 64) }
  PSpanLevel3 = ^TSpanLevel3;
  TSpanLevel3 = record
    FBase: Pointer;           { Span memory base address. }
    FSlotSize: SizeUInt;      { Bytes per slot (aligned). }
    FSummaryBitmap: UInt64;   { Summary bitmap: bit=1 means level2 span has free slot. }
    FFreeCount: SizeUInt;     { Total remaining free slots. }
    FLevel2Spans: array[0..63] of TSpanLevel2; { 64 level2 spans. }
  end;

{** Initialize a span over a pre-allocated memory region.
    ARegionSize must be >= ASlotCount * ASlotSize.
    All slots start as free (bitmap = all-ones for ASlotCount bits). }
procedure SpanInit(out ASpan: TSpan; ABase: Pointer;
  ASlotSize: SizeUInt; ASlotCount: Byte);

{** Allocate one slot from the span. Returns nil if full.
    O(1): BSF to find first set bit, then clear it. }
function SpanAlloc(var ASpan: TSpan): Pointer;

{** Free a previously allocated slot back to the span.
    APtr must have been returned by SpanAlloc from this span.
    O(1): compute bit index, set the bit.
    Returns True on success, False if the pointer is out-of-range or
    already free (double-free detection). }
function SpanFree(var ASpan: TSpan; APtr: Pointer): Boolean;

{** Return True if the span has at least one free slot. }
function SpanHasFree(const ASpan: TSpan): Boolean; inline;

{** Return the number of free slots. }
function SpanFreeCount(const ASpan: TSpan): Byte; inline;

{** Return True if the span is completely empty (all slots free). }
function SpanIsEmpty(const ASpan: TSpan): Boolean; inline;

{ === Multi-level span operations === }

{** Initialize a level2 span over a pre-allocated memory region.
    ARegionSize must be >= SPAN_LEVEL2_SLOTS * ASlotSize. }
procedure SpanLevel2Init(out ASpan: TSpanLevel2; ABase: Pointer;
  ASlotSize: SizeUInt);

{** Allocate one slot from a level2 span. Returns nil if full.
    O(1): Two BSF operations - summary bitmap then level1 bitmap. }
function SpanLevel2Alloc(var ASpan: TSpanLevel2): Pointer;

{** Free a previously allocated slot back to a level2 span.
    Returns True on success, False if the pointer is out-of-range or
    already free (double-free detection). }
function SpanLevel2Free(var ASpan: TSpanLevel2; APtr: Pointer): Boolean;

{** Return True if the level2 span has at least one free slot. }
function SpanLevel2HasFree(const ASpan: TSpanLevel2): Boolean; inline;

{** Return the number of free slots in the level2 span. }
function SpanLevel2FreeCount(const ASpan: TSpanLevel2): SizeUInt; inline;

{** Initialize a level3 span over a pre-allocated memory region.
    ARegionSize must be >= SPAN_LEVEL3_SLOTS * ASlotSize. }
procedure SpanLevel3Init(out ASpan: TSpanLevel3; ABase: Pointer;
  ASlotSize: SizeUInt);

{** Allocate one slot from a level3 span. Returns nil if full.
    O(1): Three BSF operations - summary bitmap then level2 then level1. }
function SpanLevel3Alloc(var ASpan: TSpanLevel3): Pointer;

{** Free a previously allocated slot back to a level3 span.
    Returns True on success, False if the pointer is out-of-range or
    already free (double-free detection). }
function SpanLevel3Free(var ASpan: TSpanLevel3; APtr: Pointer): Boolean;

{** Return True if the level3 span has at least one free slot. }
function SpanLevel3HasFree(const ASpan: TSpanLevel3): Boolean; inline;

{** Return the number of free slots in the level3 span. }
function SpanLevel3FreeCount(const ASpan: TSpanLevel3): SizeUInt; inline;

implementation

{$PUSH}
{$Q-} { No overflow checks on bitmap ops. }
{$R-} { No range checks on bit shifts. }

procedure SpanInit(out ASpan: TSpan; ABase: Pointer;
  ASlotSize: SizeUInt; ASlotCount: Byte);
var
  LMask: UInt64;
begin
  ASpan.FBase := ABase;
  ASpan.FSlotSize := ASlotSize;
  if ASlotCount > SPAN_MAX_SLOTS then
    ASlotCount := SPAN_MAX_SLOTS;
  ASpan.FSlotCount := ASlotCount;
  ASpan.FFreeCount := ASlotCount;
  { Set bits 0..ASlotCount-1 to 1 (free). }
  if ASlotCount >= SPAN_MAX_SLOTS then
    LMask := High(UInt64)
  else
    LMask := (UInt64(1) shl ASlotCount) - 1;
  ASpan.FBitmap := LMask;
end;

function SpanAlloc(var ASpan: TSpan): Pointer;
var
  LBit: SizeUInt;
begin
  if ASpan.FFreeCount = 0 then
    Exit(nil);
  { Find first set bit (first free slot). }
  LBit := SizeUInt(BsfQWord(ASpan.FBitmap));
  { Clear the bit (mark as used). }
  ASpan.FBitmap := ASpan.FBitmap and (not (UInt64(1) shl LBit));
  Dec(ASpan.FFreeCount);
  { Calculate slot address: base + bit * slot_size. }
  Result := Pointer(PByte(ASpan.FBase) + LBit * ASpan.FSlotSize);
end;

function SpanFree(var ASpan: TSpan; APtr: Pointer): Boolean;
var
  LOffset: SizeUInt;
  LBit: SizeUInt;
  LBitMask: UInt64;
begin
  Result := False;
  { Bounds check: pointer must be within this span's memory range. }
  LOffset := SizeUInt(PByte(APtr) - PByte(ASpan.FBase));
  if LOffset >= SizeUInt(ASpan.FSlotCount) * ASpan.FSlotSize then
    Exit;
  LBit := LOffset div ASpan.FSlotSize;
  { Double-free check: if the bit is already set, the slot is already free. }
  LBitMask := UInt64(1) shl LBit;
  if (ASpan.FBitmap and LBitMask) <> 0 then
    Exit;
  { Set the bit (mark as free). }
  ASpan.FBitmap := ASpan.FBitmap or LBitMask;
  Inc(ASpan.FFreeCount);
  Result := True;
end;

function SpanHasFree(const ASpan: TSpan): Boolean;
begin
  Result := ASpan.FFreeCount > 0;
end;

function SpanFreeCount(const ASpan: TSpan): Byte;
begin
  Result := ASpan.FFreeCount;
end;

function SpanIsEmpty(const ASpan: TSpan): Boolean;
begin
  Result := ASpan.FFreeCount = ASpan.FSlotCount;
end;

{ === Multi-level span operations === }

procedure SpanLevel2Init(out ASpan: TSpanLevel2; ABase: Pointer;
  ASlotSize: SizeUInt);
var
  I: Int32;
  LLevel1Base: Pointer;
begin
  ASpan.FBase := ABase;
  ASpan.FSlotSize := ASlotSize;
  ASpan.FFreeCount := SPAN_LEVEL2_SLOTS;
  { All level1 spans have free slots initially. }
  ASpan.FSummaryBitmap := High(UInt64);
  { Initialize each level1 span. }
  for I := 0 to 63 do
  begin
    LLevel1Base := Pointer(PByte(ABase) + SizeUInt(I) * SPAN_LEVEL1_SLOTS * ASlotSize);
    SpanInit(ASpan.FLevel1Spans[I], LLevel1Base, ASlotSize, SPAN_LEVEL1_SLOTS);
  end;
end;

function SpanLevel2Alloc(var ASpan: TSpanLevel2): Pointer;
var
  LLevel1Idx: SizeUInt;
  LBitmap: UInt64;
begin
  if ASpan.FFreeCount = 0 then
    Exit(nil);
  { Find first level1 span with free slots using summary bitmap. }
  LBitmap := ASpan.FSummaryBitmap;
  if LBitmap = 0 then
    Exit(nil); { Should not happen if FFreeCount > 0. }
  LLevel1Idx := SizeUInt(BsfQWord(LBitmap));
  { Allocate from the level1 span. }
  Result := SpanAlloc(ASpan.FLevel1Spans[LLevel1Idx]);
  if Result <> nil then
  begin
    Dec(ASpan.FFreeCount);
    { Update summary bitmap if level1 span is now full. }
    if ASpan.FLevel1Spans[LLevel1Idx].FFreeCount = 0 then
      ASpan.FSummaryBitmap := ASpan.FSummaryBitmap and (not (UInt64(1) shl LLevel1Idx));
  end;
end;

function SpanLevel2Free(var ASpan: TSpanLevel2; APtr: Pointer): Boolean;
var
  LOffset: SizeUInt;
  LLevel1Idx: SizeUInt;
begin
  Result := False;
  { Bounds check: pointer must be within this span's memory range. }
  LOffset := SizeUInt(PByte(APtr) - PByte(ASpan.FBase));
  if LOffset >= SPAN_LEVEL2_SLOTS * ASpan.FSlotSize then
    Exit;
  { Determine which level1 span this pointer belongs to. }
  LLevel1Idx := LOffset div (SPAN_LEVEL1_SLOTS * ASpan.FSlotSize);
  if LLevel1Idx > 63 then
    Exit;
  { Free the slot in the level1 span. }
  if SpanFree(ASpan.FLevel1Spans[LLevel1Idx], APtr) then
  begin
    Inc(ASpan.FFreeCount);
    { Update summary bitmap: level1 span now has free slots. }
    ASpan.FSummaryBitmap := ASpan.FSummaryBitmap or (UInt64(1) shl LLevel1Idx);
    Result := True;
  end;
end;

function SpanLevel2HasFree(const ASpan: TSpanLevel2): Boolean;
begin
  Result := ASpan.FFreeCount > 0;
end;

function SpanLevel2FreeCount(const ASpan: TSpanLevel2): SizeUInt;
begin
  Result := ASpan.FFreeCount;
end;

procedure SpanLevel3Init(out ASpan: TSpanLevel3; ABase: Pointer;
  ASlotSize: SizeUInt);
var
  I: Int32;
  LLevel2Base: Pointer;
begin
  ASpan.FBase := ABase;
  ASpan.FSlotSize := ASlotSize;
  ASpan.FFreeCount := SPAN_LEVEL3_SLOTS;
  { All level2 spans have free slots initially. }
  ASpan.FSummaryBitmap := High(UInt64);
  { Initialize each level2 span. }
  for I := 0 to 63 do
  begin
    LLevel2Base := Pointer(PByte(ABase) + SizeUInt(I) * SPAN_LEVEL2_SLOTS * ASlotSize);
    SpanLevel2Init(ASpan.FLevel2Spans[I], LLevel2Base, ASlotSize);
  end;
end;

function SpanLevel3Alloc(var ASpan: TSpanLevel3): Pointer;
var
  LLevel2Idx: SizeUInt;
  LBitmap: UInt64;
begin
  if ASpan.FFreeCount = 0 then
    Exit(nil);
  { Find first level2 span with free slots using summary bitmap. }
  LBitmap := ASpan.FSummaryBitmap;
  if LBitmap = 0 then
    Exit(nil); { Should not happen if FFreeCount > 0. }
  LLevel2Idx := SizeUInt(BsfQWord(LBitmap));
  { Allocate from the level2 span. }
  Result := SpanLevel2Alloc(ASpan.FLevel2Spans[LLevel2Idx]);
  if Result <> nil then
  begin
    Dec(ASpan.FFreeCount);
    { Update summary bitmap if level2 span is now full. }
    if ASpan.FLevel2Spans[LLevel2Idx].FFreeCount = 0 then
      ASpan.FSummaryBitmap := ASpan.FSummaryBitmap and (not (UInt64(1) shl LLevel2Idx));
  end;
end;

function SpanLevel3Free(var ASpan: TSpanLevel3; APtr: Pointer): Boolean;
var
  LOffset: SizeUInt;
  LLevel2Idx: SizeUInt;
begin
  Result := False;
  { Bounds check: pointer must be within this span's memory range. }
  LOffset := SizeUInt(PByte(APtr) - PByte(ASpan.FBase));
  if LOffset >= SPAN_LEVEL3_SLOTS * ASpan.FSlotSize then
    Exit;
  { Determine which level2 span this pointer belongs to. }
  LLevel2Idx := LOffset div (SPAN_LEVEL2_SLOTS * ASpan.FSlotSize);
  if LLevel2Idx > 63 then
    Exit;
  { Free the slot in the level2 span. }
  if SpanLevel2Free(ASpan.FLevel2Spans[LLevel2Idx], APtr) then
  begin
    Inc(ASpan.FFreeCount);
    { Update summary bitmap: level2 span now has free slots. }
    ASpan.FSummaryBitmap := ASpan.FSummaryBitmap or (UInt64(1) shl LLevel2Idx);
    Result := True;
  end;
end;

function SpanLevel3HasFree(const ASpan: TSpanLevel3): Boolean;
begin
  Result := ASpan.FFreeCount > 0;
end;

function SpanLevel3FreeCount(const ASpan: TSpanLevel3): SizeUInt;
begin
  Result := ASpan.FFreeCount;
end;

{$POP}

end.
