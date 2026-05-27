unit nextpas.core.collections.bitset;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - bitset uses word-based internal storage
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.bitset.intf;

type
  {**
   * TBitSet
   *
   * @desc Implementation of IBitSet using UInt64 array
   * @threadsafety NOT thread-safe. Use external synchronization or atomic operations for concurrent access.
   *}
  TBitSet = class(TCollection, IBitSet)
  private
    FBits: array of UInt64;
    FBitCapacity: SizeUInt;  // Total bits capacity

    procedure EnsureCapacity(aIndex: SizeUInt);
    function PopCount(aValue: UInt64): SizeUInt; inline;

  public
    constructor Create; overload;
    constructor Create(aInitialCapacity: SizeUInt); overload;
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create(aInitialCapacity: SizeUInt; aAllocator: IAllocator); overload;
    destructor Destroy; override;

    // IBitSet interface
    procedure SetBit(aIndex: SizeUInt);
    procedure ClearBit(aIndex: SizeUInt);
    function Test(aIndex: SizeUInt): Boolean;
    procedure Flip(aIndex: SizeUInt);
    function AndWith(const aOther: IBitSet): IBitSet;
    function OrWith(const aOther: IBitSet): IBitSet;
    function XorWith(const aOther: IBitSet): IBitSet;
    function NotBits: IBitSet;
    function Cardinality: SizeUInt;
    procedure SetAll;
    procedure ClearAll;
    function GetBitCapacity: SizeUInt;

    // ICollection interface
    function GetCount: SizeUInt; override;
    // IsEmpty is implemented in base TCollection (GetCount = 0)
    procedure Clear; override;
    function PtrIter: TPtrIter; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    function GetElementSize: SizeUInt;

    // Abstract methods from TCollection
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    property BitCapacity: SizeUInt read GetBitCapacity;
  end;

implementation

const
  BITS_PER_WORD = 64;

{ TBitSet }

constructor TBitSet.Create;
begin
  Create(64, nil);
end;

constructor TBitSet.Create(aInitialCapacity: SizeUInt);
begin
  Create(aInitialCapacity, nil);
end;

constructor TBitSet.Create(aAllocator: IAllocator);
begin
  Create(64, aAllocator);
end;

constructor TBitSet.Create(aInitialCapacity: SizeUInt; aAllocator: IAllocator);
var
  LWordCount: SizeUInt;
begin
  inherited Create(aAllocator);

  if aInitialCapacity = 0 then
    aInitialCapacity := 64;

  // Round up to nearest word boundary
  LWordCount := (aInitialCapacity + BITS_PER_WORD - 1) div BITS_PER_WORD;
  SetLength(FBits, LWordCount);
  FBitCapacity := LWordCount * BITS_PER_WORD;

  // Initialize to zero
  FillChar(FBits[0], Length(FBits) * SizeOf(UInt64), 0);
end;

destructor TBitSet.Destroy;
begin
  SetLength(FBits, 0);
  inherited;
end;

procedure TBitSet.EnsureCapacity(aIndex: SizeUInt);
var
  LRequiredWords, LOldLen, i: SizeUInt;
begin
  if aIndex < FBitCapacity then
    Exit;

  // Calculate required word count
  LRequiredWords := (aIndex + BITS_PER_WORD) div BITS_PER_WORD;
  LOldLen := Length(FBits);

  // Expand array
  SetLength(FBits, LRequiredWords);
  FBitCapacity := LRequiredWords * BITS_PER_WORD;

  // Zero out new words
  for i := LOldLen to LRequiredWords - 1 do
    FBits[i] := 0;
end;

function TBitSet.PopCount(aValue: UInt64): SizeUInt; inline;
begin
  // Use FPC built-in PopCnt (compiles to POPCNT instruction on supported CPUs)
  {$IFDEF CPUX86_64}
  Result := PopCnt(aValue);
  {$ELSE}
  // Optimized software fallback using parallel bit counting (SWAR)
  // Much faster than naive loop: O(1) vs O(64)
  aValue := aValue - ((aValue shr 1) and $5555555555555555);
  aValue := (aValue and $3333333333333333) + ((aValue shr 2) and $3333333333333333);
  aValue := (aValue + (aValue shr 4)) and $0F0F0F0F0F0F0F0F;
  Result := (aValue * $0101010101010101) shr 56;
  {$ENDIF}
end;

procedure TBitSet.SetBit(aIndex: SizeUInt);
var
  LWordIndex, LBitIndex: SizeUInt;
begin
  EnsureCapacity(aIndex);
  LWordIndex := aIndex div BITS_PER_WORD;
  LBitIndex := aIndex mod BITS_PER_WORD;
  FBits[LWordIndex] := FBits[LWordIndex] or (UInt64(1) shl LBitIndex);
end;

procedure TBitSet.ClearBit(aIndex: SizeUInt);
var
  LWordIndex, LBitIndex: SizeUInt;
begin
  if aIndex >= FBitCapacity then
    Exit;  // Bit is already 0 (doesn't exist)

  LWordIndex := aIndex div BITS_PER_WORD;
  LBitIndex := aIndex mod BITS_PER_WORD;
  FBits[LWordIndex] := FBits[LWordIndex] and not (UInt64(1) shl LBitIndex);
end;

function TBitSet.Test(aIndex: SizeUInt): Boolean;
var
  LWordIndex, LBitIndex: SizeUInt;
begin
  if aIndex >= FBitCapacity then
    Exit(False);

  LWordIndex := aIndex div BITS_PER_WORD;
  LBitIndex := aIndex mod BITS_PER_WORD;
  Result := (FBits[LWordIndex] and (UInt64(1) shl LBitIndex)) <> 0;
end;

procedure TBitSet.Flip(aIndex: SizeUInt);
var
  LWordIndex, LBitIndex: SizeUInt;
begin
  EnsureCapacity(aIndex);
  LWordIndex := aIndex div BITS_PER_WORD;
  LBitIndex := aIndex mod BITS_PER_WORD;
  FBits[LWordIndex] := FBits[LWordIndex] xor (UInt64(1) shl LBitIndex);
end;

function TBitSet.AndWith(const aOther: IBitSet): IBitSet;
var
  LResult: TBitSet;
  LMinWords, i, LBlocks: SizeUInt;
  LOtherBitSet: TBitSet;
  pSrc1, pSrc2, pDst: PUInt64;
begin
  LOtherBitSet := aOther as TBitSet;
  LMinWords := Length(FBits);
  if Length(LOtherBitSet.FBits) < LMinWords then
    LMinWords := Length(LOtherBitSet.FBits);

  LResult := TBitSet.Create(FBitCapacity, FAllocator);

  if LMinWords = 0 then
  begin
    Result := LResult;
    Exit;
  end;

  // 4-way loop unrolling for better performance
  pSrc1 := @FBits[0];
  pSrc2 := @LOtherBitSet.FBits[0];
  pDst := @LResult.FBits[0];
  LBlocks := LMinWords div 4;

  if LBlocks > 0 then
  begin
    for i := 0 to LBlocks - 1 do
    begin
      pDst[0] := pSrc1[0] and pSrc2[0];
      pDst[1] := pSrc1[1] and pSrc2[1];
      pDst[2] := pSrc1[2] and pSrc2[2];
      pDst[3] := pSrc1[3] and pSrc2[3];
      Inc(pSrc1, 4);
      Inc(pSrc2, 4);
      Inc(pDst, 4);
    end;
  end;

  // Handle remaining words
  for i := LBlocks * 4 to LMinWords - 1 do
    LResult.FBits[i] := FBits[i] and LOtherBitSet.FBits[i];

  Result := LResult;
end;

function TBitSet.OrWith(const aOther: IBitSet): IBitSet;
var
  LResult: TBitSet;
  LMaxWords, i: SizeUInt;
  LOtherBitSet: TBitSet;
begin
  LOtherBitSet := aOther as TBitSet;
  LMaxWords := Length(FBits);
  if Length(LOtherBitSet.FBits) > LMaxWords then
    LMaxWords := Length(LOtherBitSet.FBits);

  LResult := TBitSet.Create(LMaxWords * BITS_PER_WORD, FAllocator);

  for i := 0 to Length(FBits) - 1 do
    LResult.FBits[i] := FBits[i];

  for i := 0 to Length(LOtherBitSet.FBits) - 1 do
    LResult.FBits[i] := LResult.FBits[i] or LOtherBitSet.FBits[i];

  Result := LResult;
end;

function TBitSet.XorWith(const aOther: IBitSet): IBitSet;
var
  LResult: TBitSet;
  LMaxWords, i: SizeUInt;
  LOtherBitSet: TBitSet;
begin
  LOtherBitSet := aOther as TBitSet;
  LMaxWords := Length(FBits);
  if Length(LOtherBitSet.FBits) > LMaxWords then
    LMaxWords := Length(LOtherBitSet.FBits);

  LResult := TBitSet.Create(LMaxWords * BITS_PER_WORD, FAllocator);

  for i := 0 to Length(FBits) - 1 do
    LResult.FBits[i] := FBits[i];

  for i := 0 to Length(LOtherBitSet.FBits) - 1 do
    LResult.FBits[i] := LResult.FBits[i] xor LOtherBitSet.FBits[i];

  Result := LResult;
end;

function TBitSet.NotBits: IBitSet;
var
  LResult: TBitSet;
  i: SizeUInt;
begin
  LResult := TBitSet.Create(FBitCapacity, FAllocator);
  for i := 0 to Length(FBits) - 1 do
    LResult.FBits[i] := not FBits[i];

  Result := LResult;
end;

function TBitSet.Cardinality: SizeUInt;
var
  i, LLen, LBlocks: SizeUInt;
  c0, c1, c2, c3: SizeUInt;
  pBits: PUInt64;
begin
  LLen := Length(FBits);
  if LLen = 0 then
    Exit(0);

  Result := 0;
  pBits := @FBits[0];
  LBlocks := LLen div 4;

  // 4-way loop unrolling to reduce loop overhead
  if LBlocks > 0 then
  begin
    for i := 0 to LBlocks - 1 do
    begin
      c0 := PopCount(pBits[0]);
      c1 := PopCount(pBits[1]);
      c2 := PopCount(pBits[2]);
      c3 := PopCount(pBits[3]);
      Result := Result + c0 + c1 + c2 + c3;
      Inc(pBits, 4);
    end;
  end;

  // Handle remaining words
  for i := LBlocks * 4 to LLen - 1 do
    Result := Result + PopCount(FBits[i]);
end;

procedure TBitSet.SetAll;
begin
  if Length(FBits) > 0 then
    FillQWord(FBits[0], Length(FBits), High(UInt64));
end;

procedure TBitSet.ClearAll;
begin
  if Length(FBits) > 0 then
    FillChar(FBits[0], Length(FBits) * SizeOf(UInt64), 0);
end;

function TBitSet.GetBitCapacity: SizeUInt;
begin
  Result := FBitCapacity;
end;

function TBitSet.GetCount: SizeUInt;
begin
  Result := Cardinality;
end;

procedure TBitSet.Clear;
begin
  ClearAll;
end;

function TBitSet.PtrIter: TPtrIter;
begin
  // BitSet uses UInt64 array, not suitable for generic pointer iteration
  // Callers should use specific methods like Test() to access bits
  FillChar(Result, SizeOf(TPtrIter), 0);
end;

procedure TBitSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LByteCount: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;

  LByteCount := aCount * SizeOf(UInt64);
  if LByteCount > Length(FBits) * SizeOf(UInt64) then
    LByteCount := Length(FBits) * SizeOf(UInt64);

  Move(FBits[0], aDst^, LByteCount);
end;

function TBitSet.GetElementSize: SizeUInt;
begin
  Result := SizeOf(UInt64);
end;

function TBitSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // BitSet uses dynamic array, no overlap possible
  Result := False;
end;

procedure TBitSet.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  LSrcWords: ^UInt64;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LSrcWords := aSrc;
  for i := 0 to aElementCount - 1 do
  begin
    // Append by OR-ing words
    if i < Length(FBits) then
      FBits[i] := FBits[i] or LSrcWords[i];
    Inc(LSrcWords);
  end;
end;

procedure TBitSet.AppendToUnChecked(const aDst: TCollection);
var
  LDstBitSet: TBitSet;
  i: SizeUInt;
begin
  if aDst = nil then
    Exit;

  if aDst is TBitSet then
  begin
    LDstBitSet := TBitSet(aDst);
    for i := 0 to Length(FBits) - 1 do
    begin
      if i < Length(LDstBitSet.FBits) then
        LDstBitSet.FBits[i] := LDstBitSet.FBits[i] or FBits[i];
    end;
  end
  else
    raise EInvalidOperation.Create('Cannot append BitSet to incompatible container type');
end;

end.
