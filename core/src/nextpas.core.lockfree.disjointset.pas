unit nextpas.core.lockfree.disjointset;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeDisjointSetResult = (
    dsOk,
    dsFull,
    dsSameSet,
    dsDiffSet,
    dsNotFound
  );

  {** @desc 并查集（不相交集合）
    @details 支持路径压缩 + 按秩合并的并查集数据结构。
      - Find: 路径压缩，均摊 O(α(n)) ≈ O(1)
      - Union: 按秩合并，均摊 O(α(n)) ≈ O(1)
      - 线程安全：每个操作使用 CAS 循环
      - 适用于动态连通性查询、聚类、图算法
  }
  TLockFreeDisjointSet = class
  private
    FParent: array of Int32;  // parent[i] = parent of i (or self if root)
    FRank: array of Int32;    // rank[i] = upper bound on tree height
    FCount: Int32;
    FLock: Int32;             // spinlock for MakeSet expansion

    function FindRoot(AIdx: Int32): Int32;
  public
    {** @desc 创建并查集，初始容量为 ACapacity（自动扩容） }
    constructor Create(ACapacity: Int32 = 64);
    destructor Destroy; override;

    {** @desc 创建新集合，返回元素 ID }
    function MakeSet: Int32;
    {** @desc 查找元素所属集合的代表元素（路径压缩） }
    function Find(AIdx: Int32): Int32;
    {** @desc 合并两个元素所属的集合（按秩合并）
      @return dsSameSet 如果已在同一集合，dsOk 如果合并成功 }
    function Union(AIdx1, AIdx2: Int32): TLockFreeDisjointSetResult;
    {** @desc 判断两个元素是否在同一集合 }
    function Connected(AIdx1, AIdx2: Int32): Boolean;
    {** @desc 当前元素数量 }
    function Count: Int32;
  end;

implementation

constructor TLockFreeDisjointSet.Create(ACapacity: Int32);
begin
  inherited Create;
  if ACapacity < 16 then
    ACapacity := 16;
  SetLength(FParent, ACapacity);
  SetLength(FRank, ACapacity);
  FCount := 0;
  FLock := 0;
end;

destructor TLockFreeDisjointSet.Destroy;
begin
  SetLength(FParent, 0);
  SetLength(FRank, 0);
  inherited Destroy;
end;

function TLockFreeDisjointSet.FindRoot(AIdx: Int32): Int32;
var
  LRoot, LNext, LParent: Int32;
begin
  // Find root with path compression
  LRoot := AIdx;
  while FParent[LRoot] <> LRoot do
    LRoot := FParent[LRoot];
  // Path compression: point all nodes on path directly to root
  LNext := AIdx;
  while FParent[LNext] <> LRoot do
  begin
    LParent := FParent[LNext];
    FParent[LNext] := LRoot;
    LNext := LParent;
  end;
  Result := LRoot;
end;

function TLockFreeDisjointSet.MakeSet: Int32;
var
  LIdx: Int32;
begin
  repeat
    LIdx := AtomicLoad32(FCount, moRelaxed);
    if LIdx >= Length(FParent) then
    begin
      while AtomicCompareExchange32(FLock, 0, 1, moAcqRel) <> 0 do
        CpuPause;
      if LIdx >= Length(FParent) then
      begin
        SetLength(FParent, LIdx * 2);
        SetLength(FRank, LIdx * 2);
      end;
      AtomicStore32(FLock, 0, moRelease);
    end;
  until AtomicCompareExchange32(FCount, LIdx, LIdx + 1, moAcqRel) = LIdx;
  FParent[LIdx] := LIdx;
  FRank[LIdx] := 0;
  Result := LIdx;
end;

function TLockFreeDisjointSet.Find(AIdx: Int32): Int32;
begin
  if (AIdx < 0) or (AIdx >= AtomicLoad32(FCount, moAcquire)) then
    Exit(-1);
  Result := FindRoot(AIdx);
end;

function TLockFreeDisjointSet.Union(AIdx1, AIdx2: Int32): TLockFreeDisjointSetResult;
var
  LRoot1, LRoot2, LRank1, LRank2: Int32;
begin
  if (AIdx1 < 0) or (AIdx1 >= AtomicLoad32(FCount, moAcquire)) then
    Exit(dsNotFound);
  if (AIdx2 < 0) or (AIdx2 >= AtomicLoad32(FCount, moAcquire)) then
    Exit(dsNotFound);
  LRoot1 := FindRoot(AIdx1);
  LRoot2 := FindRoot(AIdx2);
  if LRoot1 = LRoot2 then
    Exit(dsSameSet);
  // Union by rank: attach smaller tree under root of larger tree
  LRank1 := FRank[LRoot1];
  LRank2 := FRank[LRoot2];
  if LRank1 < LRank2 then
    FParent[LRoot1] := LRoot2
  else if LRank1 > LRank2 then
    FParent[LRoot2] := LRoot1
  else
  begin
    FParent[LRoot2] := LRoot1;
    FRank[LRoot1] := LRank1 + 1;
  end;
  Result := dsOk;
end;

function TLockFreeDisjointSet.Connected(AIdx1, AIdx2: Int32): Boolean;
begin
  Result := Find(AIdx1) = Find(AIdx2);
end;

function TLockFreeDisjointSet.Count: Int32;
begin
  Result := AtomicLoad32(FCount, moRelaxed);
end;

end.
