unit nextpas.core.lockfree.scalable_bloom;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.math;

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
    function LayerFalsePositiveRate(ALayerIdx: Int32): Double;
    procedure InitializeLayer(var ALayer: TBloomLayer; ACapacity: Int64;
      const AFalsePositiveRate: Double);
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
  InitializeLayer(FLayers[0], AExpectedItems, LayerFalsePositiveRate(0));
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
    end;
  end;
end;

procedure TScalableBloomFilterImpl.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TScalableBloomFilterImpl.LayerFalsePositiveRate(ALayerIdx: Int32): Double;
begin
  Result := FFPR * (1.0 - SCALABLE_BLOOM_TIGHTENING_RATIO) *
    Power(SCALABLE_BLOOM_TIGHTENING_RATIO, ALayerIdx);
end;

procedure TScalableBloomFilterImpl.InitializeLayer(var ALayer: TBloomLayer;
  ACapacity: Int64; const AFalsePositiveRate: Double);
var
  LRequiredBitCount: Double;
  LBitCount: Int64;
  LHashCount: Int32;
begin
  LRequiredBitCount := -Double(ACapacity) * Ln(AFalsePositiveRate) /
    (Ln(2) * Ln(2));
  if LRequiredBitCount > Double(High(Int64) - 63) then
    raise EArgumentError.Create('TScalableBloomFilter: layer is too large');
  LBitCount := Trunc(LRequiredBitCount);
  if Double(LBitCount) < LRequiredBitCount then
    Inc(LBitCount);
  if LBitCount < 64 then
    LBitCount := 64;
  LHashCount := Round(Double(LBitCount) / Double(ACapacity) * Ln(2));
  if LHashCount < 1 then
    LHashCount := 1;

  ALayer := Default(TBloomLayer);
  ALayer.BitCount := LBitCount;
  ALayer.HashCount := LHashCount;
  ALayer.Count := 0;
  ALayer.Capacity := ACapacity;
  SetLength(ALayer.Bits, (LBitCount + 63) div 64);
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
  atomic_fetch_add_64(FLayers[ALayerIdx].Count, 1, mo_relaxed);
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
  LNewLayer: TBloomLayer;
begin
  if FLayers[FLayerCount - 1].Count < FLayers[FLayerCount - 1].Capacity then
    Exit;
  LNewIdx := FLayerCount;
  if FLayers[LNewIdx - 1].Capacity > High(Int64) div SCALABLE_BLOOM_GROWTH_FACTOR then
    raise EArgumentError.Create('TScalableBloomFilter: layer capacity overflow');
  LNewItems := FLayers[LNewIdx - 1].Capacity * SCALABLE_BLOOM_GROWTH_FACTOR;
  LNewFPR := LayerFalsePositiveRate(LNewIdx);
  InitializeLayer(LNewLayer, LNewItems, LNewFPR);
  SetLength(FLayers, LNewIdx + 1);
  FLayers[LNewIdx] := LNewLayer;
  FLayerCount := LNewIdx + 1;
end;

procedure TScalableBloomFilterImpl.Add(const AValue: T);
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit;
  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    GrowIfNeeded;
    AddToLayer(FLayerCount - 1, AValue);
  finally
    Unlock;
  end;
end;

function TScalableBloomFilterImpl.Contains(const AValue: T): Boolean;
var
  LI: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    for LI := FLayerCount - 1 downto 0 do
    begin
      if ContainsInLayer(LI, AValue) then
        Exit(True);
    end;
    Result := False;
  finally
    Unlock;
  end;
end;

function TScalableBloomFilterImpl.GetLayerCount: Int32;
begin
  Lock;
  try
    Result := FLayerCount;
  finally
    Unlock;
  end;
end;

function TScalableBloomFilterImpl.GetTotalCount: Int64;
var
  LI: Int32;
begin
  Lock;
  try
    Result := 0;
    for LI := 0 to FLayerCount - 1 do
      Result := Result + atomic_load_64(FLayers[LI].Count, mo_relaxed);
  finally
    Unlock;
  end;
end;

function TScalableBloomFilterImpl.GetEstimatedFPR: Double;
var
  LI: Int32;
  LNoFalsePositive: Double;
  LLayerFPR: Double;
begin
  Lock;
  try
    LNoFalsePositive := 1.0;
    for LI := 0 to FLayerCount - 1 do
    begin
      LLayerFPR := LayerFalsePositiveRate(LI);
      LNoFalsePositive := LNoFalsePositive * (1.0 - LLayerFPR);
    end;
    Result := 1.0 - LNoFalsePositive;
  finally
    Unlock;
  end;
end;

procedure TScalableBloomFilterImpl.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

function TScalableBloomFilterImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
