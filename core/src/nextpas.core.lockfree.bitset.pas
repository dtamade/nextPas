unit nextpas.core.lockfree.bitset;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeBitSetResult = (
    bsOk,
    bsIndexOutOfRange,
    bsClosed
  );

  {** @desc 并发位集合
    @details 使用原子 CAS 操作每一位的并发位集合。
      - Set/Clear/Flip/Test 单个位
      - TestAndSet/TestAndClear 原子操作
      - 自动扩容
      - 适用场景：布隆过滤器、位图、标志位管理
  }
  TConcurrentBitSet = class
  private
    FBits: array of Int64;
    FWordCount: Int32;
    FLock: Int32;

    procedure EnsureCapacity(AIndex: Int32);
  public
    constructor Create(ABitCount: Int32 = 64);
    destructor Destroy; override;

    {** 设置指定位为 1 }
    function SetBit(AIndex: Int32): TLockFreeBitSetResult;
    {** 清除指定位为 0 }
    function ClearBit(AIndex: Int32): TLockFreeBitSetResult;
    {** 翻转指定位 }
    function FlipBit(AIndex: Int32): TLockFreeBitSetResult;
    {** 测试指定位是否为 1 }
    function TestBit(AIndex: Int32): Boolean;
    {** 原子设置并返回旧值 }
    function TestAndSet(AIndex: Int32): Boolean;
    {** 原子清除并返回旧值 }
    function TestAndClear(AIndex: Int32): Boolean;
    {** 获取大致位数 }
    function BitCount: Int32;
    {** 统计设置为 1 的位数（近似） }
    function PopCount: Int64;
    {** 清除所有位 }
    procedure Clear;
  end;

implementation

constructor TConcurrentBitSet.Create(ABitCount: Int32);
var
  I: Int32;
begin
  inherited Create;
  if ABitCount < 64 then
    ABitCount := 64;
  FWordCount := (ABitCount + 63) div 64;
  SetLength(FBits, FWordCount);
  for I := 0 to FWordCount - 1 do
    FBits[I] := 0;
  FLock := 0;
end;

destructor TConcurrentBitSet.Destroy;
begin
  SetLength(FBits, 0);
  inherited Destroy;
end;

procedure TConcurrentBitSet.EnsureCapacity(AIndex: Int32);
var
  LNeeded, LOldCount, I, LSpin: Int32;
begin
  LSpin := 0;
  LNeeded := (AIndex div 64) + 1;
  if LNeeded <= FWordCount then
    Exit;
  while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
  begin
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
  if LNeeded <= FWordCount then
  begin
    AtomicStore32(FLock, 0, moRelease);
    Exit;
  end;
  LOldCount := FWordCount;
  FWordCount := LNeeded * 2;
  SetLength(FBits, FWordCount);
  for I := LOldCount to FWordCount - 1 do
    FBits[I] := 0;
  AtomicStore32(FLock, 0, moRelease);
end;

function TConcurrentBitSet.SetBit(AIndex: Int32): TLockFreeBitSetResult;
var
  LWordIdx, LBitIdx: Int32;
  LOld, LNew: Int64;
begin
  if AIndex < 0 then
    Exit(bsIndexOutOfRange);
  EnsureCapacity(AIndex);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  repeat
    LOld := AtomicLoad64(FBits[LWordIdx], moAcquire);
    LNew := LOld or (Int64(1) shl LBitIdx);
  until AtomicCompareExchange64(FBits[LWordIdx], LOld, LNew, moAcqRel) = LOld;
  Result := bsOk;
end;

function TConcurrentBitSet.ClearBit(AIndex: Int32): TLockFreeBitSetResult;
var
  LWordIdx, LBitIdx: Int32;
  LOld, LNew: Int64;
begin
  if AIndex < 0 then
    Exit(bsIndexOutOfRange);
  if (AIndex div 64) >= FWordCount then
    Exit(bsIndexOutOfRange);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  repeat
    LOld := AtomicLoad64(FBits[LWordIdx], moAcquire);
    LNew := LOld and (not (Int64(1) shl LBitIdx));
  until AtomicCompareExchange64(FBits[LWordIdx], LOld, LNew, moAcqRel) = LOld;
  Result := bsOk;
end;

function TConcurrentBitSet.FlipBit(AIndex: Int32): TLockFreeBitSetResult;
var
  LWordIdx, LBitIdx: Int32;
  LOld, LNew: Int64;
begin
  if AIndex < 0 then
    Exit(bsIndexOutOfRange);
  EnsureCapacity(AIndex);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  repeat
    LOld := AtomicLoad64(FBits[LWordIdx], moAcquire);
    LNew := LOld xor (Int64(1) shl LBitIdx);
  until AtomicCompareExchange64(FBits[LWordIdx], LOld, LNew, moAcqRel) = LOld;
  Result := bsOk;
end;

function TConcurrentBitSet.TestBit(AIndex: Int32): Boolean;
var
  LWordIdx, LBitIdx: Int32;
begin
  if AIndex < 0 then
    Exit(False);
  if (AIndex div 64) >= FWordCount then
    Exit(False);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  Result := (AtomicLoad64(FBits[LWordIdx], moAcquire) and (Int64(1) shl LBitIdx)) <> 0;
end;

function TConcurrentBitSet.TestAndSet(AIndex: Int32): Boolean;
var
  LWordIdx, LBitIdx: Int32;
  LOld, LNew: Int64;
begin
  if AIndex < 0 then
    Exit(False);
  EnsureCapacity(AIndex);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  repeat
    LOld := AtomicLoad64(FBits[LWordIdx], moAcquire);
    LNew := LOld or (Int64(1) shl LBitIdx);
  until AtomicCompareExchange64(FBits[LWordIdx], LOld, LNew, moAcqRel) = LOld;
  Result := (LOld and (Int64(1) shl LBitIdx)) <> 0;
end;

function TConcurrentBitSet.TestAndClear(AIndex: Int32): Boolean;
var
  LWordIdx, LBitIdx: Int32;
  LOld, LNew: Int64;
begin
  if AIndex < 0 then
    Exit(False);
  if (AIndex div 64) >= FWordCount then
    Exit(False);
  LWordIdx := AIndex div 64;
  LBitIdx := AIndex mod 64;
  repeat
    LOld := AtomicLoad64(FBits[LWordIdx], moAcquire);
    LNew := LOld and (not (Int64(1) shl LBitIdx));
  until AtomicCompareExchange64(FBits[LWordIdx], LOld, LNew, moAcqRel) = LOld;
  Result := (LOld and (Int64(1) shl LBitIdx)) <> 0;
end;

function TConcurrentBitSet.BitCount: Int32;
begin
  Result := FWordCount * 64;
end;

function TConcurrentBitSet.PopCount: Int64;
var
  I: Int32;
  LVal: Int64;
begin
  Result := 0;
  for I := 0 to FWordCount - 1 do
  begin
    LVal := AtomicLoad64(FBits[I], moRelaxed);
    while LVal <> 0 do
    begin
      LVal := LVal and (LVal - 1);
      Inc(Result);
    end;
  end;
end;

procedure TConcurrentBitSet.Clear;
var
  I: Int32;
begin
  for I := 0 to FWordCount - 1 do
    AtomicStore64(FBits[I], 0, moRelease);
end;

end.
