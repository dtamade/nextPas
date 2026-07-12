{******************************************************************************
  nextpas.core.lockfree.counting_bloom

  Counting Bloom Filter — supports deletion unlike standard bloom filter.

  Design:
  - Multiple hash functions, each maps to a counter array
  - Add: increment all hash positions
  - Remove: decrement all hash positions
  - Contains: check if all hash positions > 0
  - False positives are possible
  - No false negatives only when Remove is called for known-added occurrences
  - Per-counter increments/decrements are atomic; a whole key update is not

  2026-07-06  Phase 4
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.counting_bloom;

interface

uses
  SysUtils;

const
  CBF_DEFAULT_WIDTH = 65536;
  CBF_DEFAULT_DEPTH = 4;

type
  TCBFResult = (
    cbfOk,
    cbfExists,
    cbfNotFound
  );

  {**
   * Counting Bloom Filter — 支持删除的布隆过滤器。
   *
   * @constraints
   *   - 宽度和深度在创建时固定
   *   - 宽度必须是 2 的幂（用于位运算取模）
   *   - 线程安全：原子计数器
   *   - 仅删除已成功添加且尚未删除的元素；删除误报键会破坏保证
   *}
  {** @desc 计数布隆过滤器
    @details 支持删除的布隆过滤器。
      - 多个哈希函数，每个映射到计数器数组
      - Add: 递增所有哈希位置
      - Remove: 递减所有哈希位置
      - Contains: 检查所有哈希位置是否 > 0
      - 可能有假阳性，无假阴性
      - 适用场景：成员测试、去重、基数估计
   * @concurrency Thread-safe (see source for details). }
  TCountingBloomFilter = class
  private
    FWidth: Int32;
    FDepth: Int32;
    FWidthMask: Int32;
    FCounters: array of Int32;
    FCount: Int64;

    function HashN(const AKey: AnsiString; ASeed: Int32): Int32;

  public
    constructor Create(AWidth: Int32 = CBF_DEFAULT_WIDTH;
      ADepth: Int32 = CBF_DEFAULT_DEPTH);
    destructor Destroy; override;

    { 添加元素 }
    function Add(const AKey: AnsiString): TCBFResult;

    { 移除元素 }
    function Remove(const AKey: AnsiString): TCBFResult;

    { 检查是否存在（可能有误报） }
    function Contains(const AKey: AnsiString): Boolean;

    { 已添加的元素计数 }
    function Count: Int64; inline;

    { 重置所有计数器 }
    procedure Reset;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors;

constructor TCountingBloomFilter.Create(AWidth, ADepth: Int32);
var
  LWidth: Int32;
begin
  inherited Create;
  if AWidth <= 0 then
    raise EArgumentError.Create('TCountingBloomFilter: width must be > 0');
  if ADepth <= 0 then
    raise EArgumentError.Create('TCountingBloomFilter: depth must be > 0');
  { Round up to power of 2 }
  LWidth := 1;
  while LWidth < AWidth do
    LWidth := LWidth shl 1;
  FWidth := LWidth;
  FWidthMask := LWidth - 1;
  FDepth := ADepth;
  SetLength(FCounters, LWidth * ADepth);
  FCount := 0;
end;

destructor TCountingBloomFilter.Destroy;
begin
  SetLength(FCounters, 0);
  inherited Destroy;
end;

function TCountingBloomFilter.HashN(const AKey: AnsiString; ASeed: Int32): Int32;
var
  I, LHash: Int32;
begin
  { FNV-1a variant with seed }
  LHash := Int32(2166136261) xor ASeed;
  for I := 1 to Length(AKey) do
  begin
    LHash := LHash xor Ord(AKey[I]);
    LHash := LHash * 16777619;
  end;
  Result := LHash and FWidthMask;
end;

function TCountingBloomFilter.Add(const AKey: AnsiString): TCBFResult;
var
  I, LIdx: Int32;
begin
  for I := 0 to FDepth - 1 do
  begin
    LIdx := HashN(AKey, I) * FDepth + I;
    AtomicFetchAdd32(FCounters[LIdx], 1);
  end;
  AtomicFetchAdd64(FCount, 1);
  Result := cbfOk;
end;

function TCountingBloomFilter.Remove(const AKey: AnsiString): TCBFResult;
var
  I, LIdx, LOld, LDecremented: Int32;
begin
  LDecremented := 0;
  for I := 0 to FDepth - 1 do
  begin
    LIdx := HashN(AKey, I) * FDepth + I;
    repeat
      LOld := AtomicLoad32(FCounters[LIdx]);
      if LOld <= 0 then
      begin
        { Counter already 0 — element not present or already removed.
          Roll back previously decremented counters. }
        for LDecremented := LDecremented - 1 downto 0 do
        begin
          LIdx := HashN(AKey, LDecremented) * FDepth + LDecremented;
          AtomicFetchAdd32(FCounters[LIdx], 1);
        end;
        Exit(cbfNotFound);
      end;
    until AtomicCompareExchange32(FCounters[LIdx], LOld, LOld - 1) = LOld;
    Inc(LDecremented);
  end;
  AtomicFetchSub64(FCount, 1);
  Result := cbfOk;
end;

function TCountingBloomFilter.Contains(const AKey: AnsiString): Boolean;
var
  I, LIdx: Int32;
begin
  Result := True;
  for I := 0 to FDepth - 1 do
  begin
    LIdx := HashN(AKey, I) * FDepth + I;
    if AtomicLoad32(FCounters[LIdx]) <= 0 then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function TCountingBloomFilter.Count: Int64; inline;
begin
  Result := AtomicLoad64(FCount);
end;

procedure TCountingBloomFilter.Reset;
var
  I: Int32;
begin
  for I := 0 to Length(FCounters) - 1 do
    AtomicStore32(FCounters[I], 0);
  AtomicStore64(FCount, 0);
end;

end.
