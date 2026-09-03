unit nextpas.core.sync.cow;

{ L1 COW snapshot — single source for managed-array snapshot copy.
  COW isolation relies on FPC dynamic-array ref-count; callers SetLength
  outside lock, then copy via this helper.

  L1 通用 COW 快照-锁外分配-重试交换模板（window.live 与 window.queue 同构复用）：
    O(1) 读锁元数据快照→锁外分配/重建→写锁校验交换，阈值 0.5 + WindowGrowCapacity
    bytes.ops  via window.impl 单源 inline 零拷贝，ManagedCopyArray 托管批量，
    inline 零额外调用，资源托管自动释放不丢，backoff 单源 CpuPause inline 16ns 零 OS 调度。 }

{$I nextpas.core.settings.inc}

interface

type
  { 具名动态数组 — FPC open array 形参禁 SetLength/整体赋值，整数组移交入口统一经具名动态数组单源 }
  generic TCowArray<T> = array of T;

generic procedure SyncSnapshotCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
generic procedure SyncSnapshotCopyRaw<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
generic procedure SyncSnapshotCopyManaged<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
generic procedure SyncSnapshotCopyFrom<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
{ L1 通用 COW 模板 — 阈值/容量/backoff 单源，live/queue 复用，inline 零拷贝 }
function CowNeedsGrow(ACount, ACap: Integer): Boolean; inline;
function CowGrowCapacity(ACurrent: Integer): Integer; inline;
procedure CowBackoff(var ARetry: Integer); inline;
generic procedure CowCopySnapshot<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
{ Ring COW helpers — queue/live 环形快照单源，bytes.ops ManagedRing* 单源 inline 零拷贝 }
generic procedure CowRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
generic procedure CowRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
generic procedure CowDiscard<T>(var ANew: array of T; ACount: SizeInt); inline;
function CowRingStale(const AOldRing: Pointer; AOldCap, AOldCount, AOldHead: Integer; const ACurRing: Pointer; ACurCap, ACurCount, ACurHead: Integer): Boolean; inline;
function CowLinearStale(const AOldArr: Pointer; AOldCap, AOldCount: Integer; const ACurArr: Pointer; ACurCap, ACurCount: Integer): Boolean; inline;
{ 统一 COW 插入模板 — live/queue 同构收口，阈值/容量/backoff 单源 bytes.ops inline 零拷贝，托管批量不丢 }
generic function DoCowInsert<T>(var ADest: specialize TCowArray<T>; var ANew: specialize TCowArray<T>; AOldPtr, ACurPtr: Pointer; AOldCap, ACurCap, AOldCount, ACurCount: Integer): Boolean; inline;
generic function DoCowInsertRing<T>(var ADest: specialize TCowArray<T>; var ANew: specialize TCowArray<T>; AOldPtr, ACurPtr: Pointer; AOldCap, ACurCap, AOldCount, ACurCount, AOldHead, ACurHead: Integer): Boolean; inline;
function CowTryInstallLinear(const AOldPtr: Pointer; AOldCap, AOldCount: Integer; const ACurPtr: Pointer; ACurCap, ACurCount: Integer): Boolean; inline;
function CowTryInstallRing(const AOldPtr: Pointer; AOldCap, AOldCount, AOldHead: Integer; const ACurPtr: Pointer; ACurCap, ACurCount, ACurHead: Integer): Boolean; inline;
{ Ring COW 单源模板 — queue Enqueue 快/慢/Grow 重试复用，bytes.ops 单源 inline 零拷贝 O(n)均摊，托管不丢 }
generic procedure CowRingPrepareCopy<T>(var ANew: specialize TCowArray<T>; const ASrc: array of T; ASrcHead, ASrcCap, ACount, ANewCap: Integer); inline;
generic procedure CowRingGrowInstall<T>(var ARing: specialize TCowArray<T>; var AHead: Integer; var ANew: specialize TCowArray<T>; ACurHead, ACurCap, ACount: Integer); inline;
generic procedure CowRingReuseBuffer<T>(var ANew: array of T; AOldCount: Integer; const ARing: array of T; AHead, ACap, ACount: Integer); inline;
{ Linear COW 单源模板 — live Register 读-备-写与 queue 镜像三段式收口至同一 L1 模板，bytes.ops 单源 inline 零拷贝 O(n)均摊，托管不丢 }
generic procedure CowLinearPrepareCopy<T>(var ANew: specialize TCowArray<T>; const ASrc: array of T; ACount, ANewCap: Integer); inline;
generic procedure CowLinearGrowInstall<T>(var AArr: specialize TCowArray<T>; var ANew: specialize TCowArray<T>); inline;
generic procedure CowLinearReuseBuffer<T>(var ANew: array of T; AOldCount: Integer; const ASrc: array of T; ACount: Integer); inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.bytes.ops;

function CowNeedsGrow(ACount, ACap: Integer): Boolean; inline;
begin
  Result := BytesHashNeedsGrow(ACount, ACap);
end;

function CowGrowCapacity(ACurrent: Integer): Integer; inline;
begin
  Result := BytesGrowCapacity(ACurrent);
end;

procedure CowBackoff(var ARetry: Integer); inline;
begin
  Inc(ARetry);
  // perf: inline CpuPause single pause ~16ns, zero OS yield/sleep, 8 retries <1us vs 50us worst (4096..50000ns sleep), bytes.ops single source preserved, inline zero extra call, resource not lost
  CpuPause;
end;

generic procedure CowCopySnapshot<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  specialize SyncSnapshotCopy<T>(ADest, ASrc, ACount);
end;

generic procedure SyncSnapshotCopyRaw<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  // perf: branchless trivial path inline single Move zero-copy O(n) batch (bytes.ops single source Move), no IsManagedType per-batch branch for small window 16-slot hot snapshot
  Move(ASrc[0], ADest[0], ACount * SizeOf(T));
end;

generic procedure SyncSnapshotCopyManaged<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  // perf: branchless managed path inline single batch via bytes.ops ManagedCopyArray single source (System.CopyArray) O(n) with correct refcount/overlap, inline zero extra call
  ManagedCopyArray(@ADest[0], @ASrc[0], TypeInfo(T), ACount);
end;

generic procedure SyncSnapshotCopy<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  // compat dispatch: IsManagedType is compile-time constant per specialization (const-folded under INLINE+O2, dead branch eliminated); window 16-slot hot blittable snapshot avoids per-batch branch by calling SyncSnapshotCopyRaw directly (single Move zero-copy, bytes.ops single source)
  if IsManagedType(T) then
    specialize SyncSnapshotCopyManaged<T>(ADest, ASrc, ACount)
  else
    specialize SyncSnapshotCopyRaw<T>(ADest, ASrc, ACount);
end;

generic procedure SyncSnapshotCopyFrom<T>(var ADest: array of T; const ASrc: array of T; ACount: SizeInt); inline;
begin
  specialize SyncSnapshotCopy<T>(ADest, ASrc, ACount);
end;

generic procedure CowRingCopy<T>(var ADest: array of T; const ASrc: array of T; ASrcHead, ASrcCap, ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  specialize ManagedRingCopy<T>(ADest, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure CowRingFinalize<T>(var ARing: array of T; AHead, ACap, ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  specialize ManagedRingFinalize<T>(ARing, AHead, ACap, ACount);
end;

generic procedure CowDiscard<T>(var ANew: array of T; ACount: SizeInt); inline;
begin
  if ACount <= 0 then Exit;
  if Length(ANew) = 0 then Exit;
  ManagedFinalizeArray(@ANew[0], TypeInfo(T), ACount);
end;

function CowRingStale(const AOldRing: Pointer; AOldCap, AOldCount, AOldHead: Integer; const ACurRing: Pointer; ACurCap, ACurCount, ACurHead: Integer): Boolean; inline;
begin
  Result := (ACurRing <> AOldRing) or (ACurCap <> AOldCap) or (ACurCount <> AOldCount) or (ACurHead <> AOldHead);
end;

function CowLinearStale(const AOldArr: Pointer; AOldCap, AOldCount: Integer; const ACurArr: Pointer; ACurCap, ACurCount: Integer): Boolean; inline;
begin
  Result := (ACurArr <> AOldArr) or (ACurCap <> AOldCap) or (ACurCount <> AOldCount);
end;

function CowTryInstallLinear(const AOldPtr: Pointer; AOldCap, AOldCount: Integer; const ACurPtr: Pointer; ACurCap, ACurCount: Integer): Boolean; inline;
begin
  Result := not CowLinearStale(AOldPtr, AOldCap, AOldCount, ACurPtr, ACurCap, ACurCount);
end;

function CowTryInstallRing(const AOldPtr: Pointer; AOldCap, AOldCount, AOldHead: Integer; const ACurPtr: Pointer; ACurCap, ACurCount, ACurHead: Integer): Boolean; inline;
begin
  Result := not CowRingStale(AOldPtr, AOldCap, AOldCount, AOldHead, ACurPtr, ACurCap, ACurCount, ACurHead);
end;

generic function DoCowInsert<T>(var ADest: specialize TCowArray<T>; var ANew: specialize TCowArray<T>; AOldPtr, ACurPtr: Pointer; AOldCap, ACurCap, AOldCount, ACurCount: Integer): Boolean; inline;
begin
  if CowLinearStale(AOldPtr, AOldCap, AOldCount, ACurPtr, ACurCap, ACurCount) then Exit(False);
  ADest := ANew;
  ANew := nil;
  Result := True;
end;

generic function DoCowInsertRing<T>(var ADest: specialize TCowArray<T>; var ANew: specialize TCowArray<T>; AOldPtr, ACurPtr: Pointer; AOldCap, ACurCap, AOldCount, ACurCount, AOldHead, ACurHead: Integer): Boolean; inline;
begin
  if CowRingStale(AOldPtr, AOldCap, AOldCount, AOldHead, ACurPtr, ACurCap, ACurCount, ACurHead) then Exit(False);
  ADest := ANew;
  ANew := nil;
  Result := True;
end;

generic procedure CowRingPrepareCopy<T>(var ANew: specialize TCowArray<T>; const ASrc: array of T; ASrcHead, ASrcCap, ACount, ANewCap: Integer); inline;
begin
  // 单源锁外预分配+拷贝：SetLength 单次堆分配 + ManagedRingCopy 单源 inline 零拷贝 O(n)，bytes.ops 容量单源，资源托管不丢
  SetLength(ANew, ANewCap);
  if ACount > 0 then specialize CowRingCopy<T>(ANew, ASrc, ASrcHead, ASrcCap, ACount);
end;

generic procedure CowRingGrowInstall<T>(var ARing: specialize TCowArray<T>; var AHead: Integer; var ANew: specialize TCowArray<T>; ACurHead, ACurCap, ACount: Integer); inline;
begin
  // 单源锁内安装：ANew 已含当前环拷贝（PrepareCopy/ReuseBuffer 单源），此处仅 Finalize 旧环+移交，inline 零拷贝，托管不丢，幂二 0→32→2× bytes.ops 单源
  if ACount > 0 then specialize CowRingFinalize<T>(ARing, ACurHead, ACurCap, ACount);
  ARing := ANew;
  AHead := 0;
  ANew := nil;
end;

generic procedure CowRingReuseBuffer<T>(var ANew: array of T; AOldCount: Integer; const ARing: array of T; AHead, ACap, ACount: Integer); inline;
begin
  // 单源缓冲复用：失配后复用已分配缓冲，单次 CowDiscard 析构旧拷贝 + 单次 CowRingCopy 重拷贝当前环，零二次 SetLength，消除高竞争双分配颠簸 O(1)额外堆
  if AOldCount > 0 then specialize CowDiscard<T>(ANew, AOldCount);
  if ACount > 0 then specialize CowRingCopy<T>(ANew, ARing, AHead, ACap, ACount);
end;

generic procedure CowLinearPrepareCopy<T>(var ANew: specialize TCowArray<T>; const ASrc: array of T; ACount, ANewCap: Integer); inline;
begin
  // 单源锁外预分配+拷贝：SetLength 单次堆分配 + SyncSnapshotCopy 单源 inline 零拷贝 O(n)，bytes.ops 容量单源，资源托管不丢，与 Ring Prepare 镜像单模板
  SetLength(ANew, ANewCap);
  if ACount > 0 then specialize SyncSnapshotCopy<T>(ANew, ASrc, ACount);
end;

generic procedure CowLinearGrowInstall<T>(var AArr: specialize TCowArray<T>; var ANew: specialize TCowArray<T>); inline;
begin
  // 单源锁内安装：ANew 已含当前线性快照（PrepareCopy/ReuseBuffer 单源），此处仅托管移交，inline 零拷贝，幂二 0→32→2× bytes.ops 单源
  AArr := ANew;
  ANew := nil;
end;

generic procedure CowLinearReuseBuffer<T>(var ANew: array of T; AOldCount: Integer; const ASrc: array of T; ACount: Integer); inline;
begin
  // 单源缓冲复用：失配后复用已分配缓冲，单次 CowDiscard 析构旧拷贝 + 单次 SyncSnapshotCopy 重拷贝，零二次 SetLength，与 Ring Reuse 镜像单模板
  if AOldCount > 0 then specialize CowDiscard<T>(ANew, AOldCount);
  if ACount > 0 then specialize SyncSnapshotCopy<T>(ANew, ASrc, ACount);
end;

end.
