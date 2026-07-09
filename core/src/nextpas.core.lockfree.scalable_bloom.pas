unit nextpas.core.lockfree.scalable_bloom;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  Math;

const
  SCALABLE_BLOOM_DEFAULT_ITEMS = 10000;
  SCALABLE_BLOOM_DEFAULT_FPR = 0.01;
  SCALABLE_BLOOM_TIGHTENING_RATIO = 0.5;
  SCALABLE_BLOOM_GROWTH_FACTOR = 2;
  FNV64_OFFSET = 14695981039346656037;
  FNV64_PRIME = 1099511628211;

type
  {** @desc 可扩容布隆过滤器层 }
  TBloomLayer = record
    Bits: array of UInt64;
    BitCount: Int64;
    HashCount: Int32;
    Count: Int64;
    Capacity: Int64;
  end;

  {** @desc 可扩容并发布隆过滤器
    @details 底层维护多个标准布隆过滤器层。
      当当前层 FPR 超过阈值时自动添加新层。
      每层递增容量、递减 FPR。
      只支持 Add + Contains（标准布隆语义）。
  }
  generic TScalableBloomFilterImpl<T> = class
  private
    FLayers: array of TBloomLayer;
    FLayerCount: Int32;
    FExpectedItems: Int64;
    FFPR: Double;
    FClosed: Int32;
    FLock: Int32;
    procedure Lock;
    procedure Unlock;
    function HashValue(const AValue: T; ASeed: UInt64): UInt64;
    procedure AddToLayer(ALayerIdx: Int32; const AValue: T);
    function ContainsInLayer(ALayerIdx: Int32; const AValue: T): Boolean;
    procedure GrowIfNeeded;
  public
    constructor Create(const AExpectedItems: Int64 = SCALABLE_BLOOM_DEFAULT_ITEMS;
      const AFPR: Double = SCALABLE_BLOOM_DEFAULT_FPR);
    destructor Destroy; override;
    procedure Add(const AValue: T);
    function Contains(const AValue: T): Boolean;
    function GetLayerCount: Int32;
    function GetTotalCount: Int64;
    function GetEstimatedFPR: Double;
    procedure Close;
    function IsClosed: Boolean;
  end;

  generic TScalableBloomFilter<T> = class(specialize TScalableBloomFilterImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TScalableBloomFilterImpl.Create(const AExpectedItems: Int64; const AFPR: Double);
var
  LBitCount: Int64;
  LHashCount: Int32;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TScalableBloomFilter: T must be unmanaged');
  if AExpectedItems <= 0 then
    raise EArgumentError.Create('TScalableBloomFilter: expected items must be > 0');
  if (AFPR <= 0) or (AFPR >= 1) then
    raise EArgumentError.Create('TScalableBloomFilter: FPR must be in (0, 1)');
  inherited Create;
  FExpectedItems := AExpectedItems;
  FFPR := AFPR;
  FClosed := 0;
  FLock := 0;
  FLayerCount := 1;
  SetLength(FLayers, 1);
  LBitCount := -Round(AExpectedItems * Ln(AFPR) / (Ln(2) * Ln(2)));
  if LBitCount < 64 then
    LBitCount := 64;
  LHashCount := Round(Double(LBitCount) / Double(AExpectedItems) * Ln(2));
  if LHashCount < 1 then
    LHashCount := 1;
  FLayers[0].BitCount := LBitCount;
  FLayers[0].HashCount := LHashCount;
  FLayers[0].Count := 0;
  FLayers[0].Capacity := AExpectedItems;
  SetLength(FLayers[0].Bits, (LBitCount + 63) div 64);
end;

destructor TScalableBloomFilterImpl.Destroy;
begin
  FLayers := nil;
  inherited Destroy;
end;

function TScalableBloomFilterImpl.HashValue(const AValue: T; ASeed: UInt64): UInt64;
var
  LBytes: array[0..SizeOf(T) - 1] of Byte;
  LI: Integer;
begin
  Move(AValue, LBytes, SizeOf(T));
  Result := FNV64_OFFSET xor ASeed;
  for LI := 0 to SizeOf(T) - 1 do
  begin
    Result := Result xor LBytes[LI];
    Result := Result * FNV64_PRIME;
  end;
end;

procedure TScalableBloomFilterImpl.Lock;
var
  LSpin: Integer;
begin
  LSpin := 0;
  while AtomicCompareExchange32(FLock, 1, 0) <> 0 do
  begin
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end;
  end;
end;

procedure TScalableBloomFilterImpl.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TScalableBloomFilterImpl.AddToLayer(ALayerIdx: Int32; const AValue: T);
var
  LI: Int32;
  LHash, LBitIdx: UInt64;
begin
  for LI := 0 to FLayers[ALayerIdx].HashCount - 1 do
  begin
    LHash := HashValue(AValue, UInt64(LI + 1) * UInt64(ALayerIdx + 1) * 2654435761);
    LBitIdx := LHash mod UInt64(FLayers[ALayerIdx].BitCount);
    FLayers[ALayerIdx].Bits[LBitIdx shr 6] := FLayers[ALayerIdx].Bits[LBitIdx shr 6] or (UInt64(1) shl (LBitIdx and 63));
  end;
  AtomicFetchAdd64(FLayers[ALayerIdx].Count, 1, moRelaxed);
end;

function TScalableBloomFilterImpl.ContainsInLayer(ALayerIdx: Int32; const AValue: T): Boolean;
var
  LI: Int32;
  LHash, LBitIdx: UInt64;
begin
  for LI := 0 to FLayers[ALayerIdx].HashCount - 1 do
  begin
    LHash := HashValue(AValue, UInt64(LI + 1) * UInt64(ALayerIdx + 1) * 2654435761);
    LBitIdx := LHash mod UInt64(FLayers[ALayerIdx].BitCount);
    if (FLayers[ALayerIdx].Bits[LBitIdx shr 6] and (UInt64(1) shl (LBitIdx and 63))) = 0 then
      Exit(False);
  end;
  Result := True;
end;

procedure TScalableBloomFilterImpl.GrowIfNeeded;
var
  LNewIdx: Int32;
  LNewItems: Int64;
  LNewFPR: Double;
  LBitCount: Int64;
  LHashCount: Int32;
  LI: Int32;
begin
  if FLayers[FLayerCount - 1].Count < FLayers[FLayerCount - 1].Capacity then
    Exit;
  LNewIdx := FLayerCount;
  Inc(FLayerCount);
  if LNewIdx >= Length(FLayers) then
    SetLength(FLayers, LNewIdx + 1);
  LNewItems := FLayers[0].Capacity;
  for LI := 1 to LNewIdx do
    LNewItems := LNewItems * SCALABLE_BLOOM_GROWTH_FACTOR;
  LNewFPR := FFPR;
  for LI := 1 to LNewIdx do
    LNewFPR := LNewFPR * SCALABLE_BLOOM_TIGHTENING_RATIO;
  LBitCount := -Round(LNewItems * Ln(LNewFPR) / (Ln(2) * Ln(2)));
  if LBitCount < 64 then
    LBitCount := 64;
  LHashCount := Round(Double(LBitCount) / Double(LNewItems) * Ln(2));
  if LHashCount < 1 then
    LHashCount := 1;
  FLayers[LNewIdx].BitCount := LBitCount;
  FLayers[LNewIdx].HashCount := LHashCount;
  FLayers[LNewIdx].Count := 0;
  FLayers[LNewIdx].Capacity := LNewItems;
  SetLength(FLayers[LNewIdx].Bits, (LBitCount + 63) div 64);
end;

procedure TScalableBloomFilterImpl.Add(const AValue: T);
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  Lock;
  GrowIfNeeded;
  AddToLayer(FLayerCount - 1, AValue);
  Unlock;
end;

function TScalableBloomFilterImpl.Contains(const AValue: T): Boolean;
var
  LI: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  for LI := FLayerCount - 1 downto 0 do
  begin
    if ContainsInLayer(LI, AValue) then
      Exit(True);
  end;
  Result := False;
end;

function TScalableBloomFilterImpl.GetLayerCount: Int32;
begin
  Result := AtomicLoad32(FLayerCount, moRelaxed);
end;

function TScalableBloomFilterImpl.GetTotalCount: Int64;
var
  LI: Int32;
begin
  Result := 0;
  for LI := 0 to FLayerCount - 1 do
    Result := Result + AtomicLoad64(FLayers[LI].Count, moRelaxed);
end;

function TScalableBloomFilterImpl.GetEstimatedFPR: Double;
var
  LI: Int32;
  LFPR, LLayerFPR: Double;
begin
  LFPR := 1.0;
  LLayerFPR := FFPR;
  for LI := 0 to FLayerCount - 1 do
  begin
    LFPR := LFPR * LLayerFPR;
    LLayerFPR := LLayerFPR * SCALABLE_BLOOM_TIGHTENING_RATIO;
  end;
  Result := LFPR;
end;

procedure TScalableBloomFilterImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TScalableBloomFilterImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
