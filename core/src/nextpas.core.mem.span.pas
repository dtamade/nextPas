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

{$POP}

end.
