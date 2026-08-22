{******************************************************************************
  nextpas.core.lockfree.xorfilter

  XOR Filter — compact static membership filter.

  Design:
  - Similar to Bloom Filter: tests set membership with false positives
  - Slot count: ~1.33 * n plus padding; slots currently use UInt32 storage
  - Construction: graph-based peeling algorithm with 3 hash positions per key
  - Lookup: XOR 3 fingerprints, compare with key hash
  - False positive rate: ~0.39% (1/256) for 8-bit fingerprints
  - Static: requires all keys at construction time
  - Immutable after construction; lookup reads three fingerprint slots

  Theory: Graf & Lemire "XOR Filters: Faster and Smaller Than Bloom Filters"

  2026-07-06  Phase 11
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.xorfilter;

interface

uses
  nextpas.core.lockfree.base;

const
  XOR_FINGERPRINT_BITS = 8;
  XOR_FINGERPRINT_MASK = (1 shl XOR_FINGERPRINT_BITS) - 1; { 255 }

type
  TXorFilterResult = (xfOk, xfNotFound, xfFalsePositive, xfClosed);

  {** @desc XOR 布隆过滤器
    @details 静态成员过滤器；每次查找读取 3 个指纹槽位。
      静态构建：需要在构造时提供所有键。
      假阳性率约 0.39% (8-bit 指纹)。 }
  TXorFilter = class
  private
    FFilters: array of UInt32;
    FCapacity: Int32;
    FCount: Int32;
    FSeed: UInt32;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock; inline;
    procedure Unlock; inline;
    function Hash(AKey: UInt64; ASeed: UInt32): UInt32;
    function FingerPrint(AKey: UInt64): UInt32;
  public
    constructor Create(const AKeys: array of UInt64);
    destructor Destroy; override;
    function Contains(AKey: UInt64): Boolean;
    function GetCount: Int32;
    function GetCapacity: Int32;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TXorFilter.Create(const AKeys: array of UInt64);
var
  N, M, I, J, K: Int32;
  Seed: UInt32;
  Q0, Q1, Q2: array of Int32;
  H0, H1, H2: Int32;
  Counts: array of Int32;
  Stack: array of Int32;
  StackSize: Int32;
  Order: array of Int32;
  PeelPos: array of Int32;
  OrderSize: Int32;
  Assigned: array of Boolean;
  Done: Boolean;
  FP: UInt32;
begin
  N := Length(AKeys);
  if N = 0 then
    raise EArgumentError.Create('TXorFilter: empty key set');
  inherited Create;
  { Size: ~1.23 * N, rounded up to multiple of 3, with padding }
  M := N + N div 3 + 20;
  M := ((M + 2) div 3) * 3;
  FCapacity := M;
  FCount := N;
  FLock := 0;
  FClosed := 0;
  SetLength(FFilters, M);
  SetLength(Q0, N);
  SetLength(Q1, N);
  SetLength(Q2, N);
  SetLength(Counts, M);
  SetLength(Stack, M);
  SetLength(Order, N);
  SetLength(PeelPos, N);
  SetLength(Assigned, N);
  { Try construction with different seeds }
  Done := False;
  for I := 0 to 499 do
  begin
    Seed := UInt32(I * 2654435761) + 12345;
    { Compute 3 hash positions for each key }
    for J := 0 to N - 1 do
    begin
      Q0[J] := Int32(Hash(UInt64(AKeys[J]), Seed + 0) mod UInt32(M));
      Q1[J] := Int32(Hash(UInt64(AKeys[J]), Seed + 1) mod UInt32(M));
      Q2[J] := Int32(Hash(UInt64(AKeys[J]), Seed + 2) mod UInt32(M));
    end;
    { Count how many keys map to each position }
    for J := 0 to M - 1 do
      Counts[J] := 0;
    for J := 0 to N - 1 do
    begin
      Inc(Counts[Q0[J]]);
      Inc(Counts[Q1[J]]);
      Inc(Counts[Q2[J]]);
    end;
    { Initialize }
    for J := 0 to N - 1 do
      Assigned[J] := False;
    for J := 0 to M - 1 do
      FFilters[J] := 0;
    { Find positions with degree 1 (exactly 1 key) }
    StackSize := 0;
    for J := 0 to M - 1 do
      if Counts[J] = 1 then
      begin
        Stack[StackSize] := J;
        Inc(StackSize);
      end;
    { Peel: process stack }
    OrderSize := 0;
    while StackSize > 0 do
    begin
      Dec(StackSize);
      H0 := Stack[StackSize];
      if Counts[H0] <> 1 then
        Continue;
      { Find the unassigned key that maps to H0 }
      for J := 0 to N - 1 do
      begin
        if Assigned[J] then
          Continue;
        if (Q0[J] = H0) or (Q1[J] = H0) or (Q2[J] = H0) then
        begin
          Assigned[J] := True;
          Order[OrderSize] := J;
          PeelPos[OrderSize] := H0;
          Inc(OrderSize);
          { Decrement counts for other positions of this key }
          H1 := Q0[J];
          if H1 <> H0 then
          begin
            Dec(Counts[H1]);
            if Counts[H1] = 1 then
            begin
              Stack[StackSize] := H1;
              Inc(StackSize);
            end;
          end;
          H1 := Q1[J];
          if H1 <> H0 then
          begin
            Dec(Counts[H1]);
            if Counts[H1] = 1 then
            begin
              Stack[StackSize] := H1;
              Inc(StackSize);
            end;
          end;
          H1 := Q2[J];
          if H1 <> H0 then
          begin
            Dec(Counts[H1]);
            if Counts[H1] = 1 then
            begin
              Stack[StackSize] := H1;
              Inc(StackSize);
            end;
          end;
          Break;
        end;
      end;
    end;
    { Check if all keys were assigned }
    if OrderSize = N then
    begin
      FSeed := Seed;
      { Assign fingerprints in reverse peeling order }
      for J := N - 1 downto 0 do
      begin
        K := Order[J];
        H0 := Q0[K];
        H1 := Q1[K];
        H2 := Q2[K];
        FP := FingerPrint(UInt64(AKeys[K]));
        { Only xor the two non-peel positions. The peel slot is assigned here. }
        if PeelPos[J] = H0 then
          FFilters[H0] := FP xor FFilters[H1] xor FFilters[H2]
        else if PeelPos[J] = H1 then
          FFilters[H1] := FP xor FFilters[H0] xor FFilters[H2]
        else
          FFilters[H2] := FP xor FFilters[H0] xor FFilters[H1];
      end;
      Done := True;
      Break;
    end;
  end;
  if not Done then
    raise EArgumentError.Create('TXorFilter: construction failed (too many keys or bad seed)');
end;

function TXorFilter.Hash(AKey: UInt64; ASeed: UInt32): UInt32;
var
  LH: UInt64;
begin
  LH := 14695981039346656037;
  LH := (LH xor AKey) * 1099511628211;
  LH := (LH xor UInt64(ASeed)) * 1099511628211;
  Result := UInt32(LH);
end;

function TXorFilter.FingerPrint(AKey: UInt64): UInt32;
var
  LH: UInt64;
begin
  LH := 14695981039346656037;
  LH := (LH xor AKey) * 1099511628211;
  Result := UInt32(LH) and XOR_FINGERPRINT_MASK;
  if Result = 0 then Result := 1;
end;

procedure TXorFilter.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TXorFilter.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TXorFilter.Contains(AKey: UInt64): Boolean;
var
  LF: UInt32;
  LH0, LH1, LH2: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LF := FingerPrint(AKey);
  LH0 := Int32(Hash(AKey, FSeed + 0) mod UInt32(FCapacity));
  LH1 := Int32(Hash(AKey, FSeed + 1) mod UInt32(FCapacity));
  LH2 := Int32(Hash(AKey, FSeed + 2) mod UInt32(FCapacity));
  Result := (FFilters[LH0] xor FFilters[LH1] xor FFilters[LH2]) = LF;
end;

function TXorFilter.GetCount: Int32;
begin
  Result := FCount;
end;

function TXorFilter.GetCapacity: Int32;
begin
  Result := FCapacity;
end;

procedure TXorFilter.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TXorFilter.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TXorFilter.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
