unit nextpas.core.lockfree.bloom;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.math;

const
  BLOOM_FNV1A_OFFSET_BASIS: PtrUInt = PtrUInt($CBF29CE484222325);
  BLOOM_FNV1A_PRIME: PtrUInt = PtrUInt($00000100000001B3);

type
  {** @desc 并发布隆过滤器
    @details 基于多个哈希函数的概率数据结构。
      支持 Add/Contains/Clear/Count。
      适用于快速成员检查、去重等场景。
      注意：可能存在假阳性；仅执行 Add/Contains 且不并发 Clear 时不会有假阴性。
  }
  generic TConcurrentBloomFilterImpl<T> = class
  private
    FBits: array of Int64;
    FBitCount: PtrUInt;
    FBitMask: PtrUInt;
    FHashCount: Integer;
    FCount: Int64;
    FClosed: Int32;
    function GetBitIndex(const AValue: T; AHashIndex: Integer): PtrUInt;
    procedure SetBit(AIndex: PtrUInt);
    function GetBit(AIndex: PtrUInt): Boolean;
  public
    constructor Create(const AExpectedItems: PtrUInt = 10000; const AFalsePositiveRate: Double = 0.01);
    destructor Destroy; override;
    function Add(const AValue: T): Boolean;
    function Contains(const AValue: T): Boolean;
    procedure Clear;
    procedure Close;
    function IsClosed: Boolean; inline;
    function Count: PtrUInt; inline;
    function BitCount: PtrUInt; inline;
    function HashCount: Integer; inline;
  end;

  generic TConcurrentBloomFilter<T> = class(specialize TConcurrentBloomFilterImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TConcurrentBloomFilterImpl.Create(const AExpectedItems: PtrUInt; const AFalsePositiveRate: Double);
var
  LRequiredBitCount: Double;
  LBitCount: PtrUInt;
  LHashCount: Integer;
  LWords: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TConcurrentBloomFilter: T must be unmanaged (no string/interface/dynarray)');
  if AExpectedItems = 0 then
    raise EArgumentError.Create('TConcurrentBloomFilter: expected items must be > 0');
  if (AFalsePositiveRate <= 0) or (AFalsePositiveRate >= 1) then
    raise EArgumentError.Create('TConcurrentBloomFilter: false positive rate must be between 0 and 1');
  inherited Create;
  // Calculate minimum bit count: m = ceil(-n * ln(p) / ln(2)^2)
  LRequiredBitCount := -Double(AExpectedItems) * Ln(AFalsePositiveRate) /
    (Ln(2) * Ln(2));
  if LRequiredBitCount > Double(High(PtrUInt)) then
    raise EArgumentError.Create('TConcurrentBloomFilter: requested capacity is too large');
  LBitCount := PtrUInt(Trunc(LRequiredBitCount));
  if Double(LBitCount) < LRequiredBitCount then
    Inc(LBitCount);
  // Round up to power of 2
  LBitCount := LockFreeNextPow2(LBitCount);
  if LBitCount < 64 then
    LBitCount := 64;
  // Calculate optimal hash count: k = (m/n) * ln(2)
  LHashCount := Integer(Round(Double(LBitCount) / Double(AExpectedItems) * Ln(2)));
  if LHashCount < 1 then
    LHashCount := 1;
  if LHashCount > 16 then
    LHashCount := 16;
  FBitCount := LBitCount;
  FBitMask := LBitCount - 1;
  FHashCount := LHashCount;
  // Allocate bits (packed as Int64 array)
  LWords := (LBitCount + 63) div 64;
  SetLength(FBits, LWords);
  FCount := 0;
  FClosed := 0;
end;

destructor TConcurrentBloomFilterImpl.Destroy;
begin
  SetLength(FBits, 0);
  inherited Destroy;
end;

function TConcurrentBloomFilterImpl.GetBitIndex(const AValue: T; AHashIndex: Integer): PtrUInt;
var
  LPtr: PByte;
  LI: PtrUInt;
  LH: PtrUInt;
begin
  // Use FNV-1a with different seeds for different hash functions
  LPtr := @AValue;
  LH := BLOOM_FNV1A_OFFSET_BASIS + PtrUInt(AHashIndex) * BLOOM_FNV1A_PRIME;
  for LI := 0 to SizeOf(T) - 1 do
    LH := (LH xor PtrUInt(LPtr[LI])) * BLOOM_FNV1A_PRIME;
  Result := LH and FBitMask;
end;

procedure TConcurrentBloomFilterImpl.SetBit(AIndex: PtrUInt);
var
  LWordIndex: PtrUInt;
  LBitMask: Int64;
  LOld, LNew: Int64;
begin
  LWordIndex := AIndex div 64;
  LBitMask := Int64(1) shl (AIndex mod 64);
  repeat
    LOld := atomic_load_64(FBits[LWordIndex], mo_relaxed);
    if (LOld and LBitMask) <> 0 then
      Exit; // Already set
    LNew := LOld or LBitMask;
  until atomic_compare_exchange_strong_64(FBits[LWordIndex], LOld, LNew, mo_relaxed, mo_relaxed);
end;

function TConcurrentBloomFilterImpl.GetBit(AIndex: PtrUInt): Boolean;
var
  LWordIndex: PtrUInt;
  LBitMask: Int64;
begin
  LWordIndex := AIndex div 64;
  LBitMask := Int64(1) shl (AIndex mod 64);
  Result := (atomic_load_64(FBits[LWordIndex], mo_acquire) and LBitMask) <> 0;
end;

function TConcurrentBloomFilterImpl.Add(const AValue: T): Boolean;
var
  LI: Integer;
  LIndex: PtrUInt;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  for LI := 0 to FHashCount - 1 do
  begin
    LIndex := GetBitIndex(AValue, LI);
    SetBit(LIndex);
  end;
  atomic_fetch_add_64(FCount, 1, mo_relaxed);
  Result := True;
end;

function TConcurrentBloomFilterImpl.Contains(const AValue: T): Boolean;
var
  LI: Integer;
  LIndex: PtrUInt;
begin
  for LI := 0 to FHashCount - 1 do
  begin
    LIndex := GetBitIndex(AValue, LI);
    if not GetBit(LIndex) then
      Exit(False);
  end;
  Result := True;
end;

procedure TConcurrentBloomFilterImpl.Clear;
var
  LI: PtrUInt;
begin
  for LI := 0 to High(FBits) do
    atomic_store_64(FBits[LI], 0, mo_relaxed);
  atomic_store_64(FCount, 0, mo_relaxed);
end;

procedure TConcurrentBloomFilterImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TConcurrentBloomFilterImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentBloomFilterImpl.Count: PtrUInt; inline;
begin
  Result := PtrUInt(atomic_load_64(FCount, mo_acquire));
end;

function TConcurrentBloomFilterImpl.BitCount: PtrUInt; inline;
begin
  Result := FBitCount;
end;

function TConcurrentBloomFilterImpl.HashCount: Integer; inline;
begin
  Result := FHashCount;
end;

end.
