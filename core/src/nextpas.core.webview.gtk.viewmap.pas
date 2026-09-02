unit nextpas.core.webview.gtk.viewmap; // 仅gtk uses — L1候选未提升：私为gtk后端专用，CONTRACT §1.2可抽L1 hashmap指针特化

{** @desc GTK 指针键 view→window O(1) 索引：开地址 hash 薄封装。私为gtk后端专用，未提升通用 — CONTRACT §1.2登记可抽L1 hashmap指针特化候选（L1: unit nextpas.core.webview.gtk.viewmap; // 仅gtk uses），当前滞留家族内私有。

       单源复用（零容器重复）：
       - 哈希：hashmap.base.HashOfPointer (HashMix32 单源) — 与 THashMap/ webview.assets.WyHash 单源一致，消除 shr4 xor shr11 私有分叉，分布经 HashMix32 avalanche 保证
       - 容量：bytes.ops.VecGrowCapacity (0→4→2× inline 单源) — 与 webview.live/assetIndex 单源一致
       - 负载：0.75 (hashmap.base.DEFAULT_MAX_LOAD_FACTOR) — 单源阈值，零阈值漂移
       - 比较：指针等值直比，零 SpanEqual 额外开销
       可抽通用指针哈希模块候选：与 window.live/通用指针哈希重复已评估—当前自建开地址桶仍滞留家族内私有；哈希/容量/负载全量单源（HashOfPointer→HashMix32 / VecGrowCapacity 0→4→2× inline / 0.75 阈值）已零重复，容器未直接复用 L1 THashMap generic（avoid allocator/bitmap/VTable 开销，blittable Pointer 数组 inline 零分配热读），抽取需反哺 L1 collections/hashmap.base 通用指针哈希特化 owner 并经设计评审不自行外溢（CONTRACT §1.2 登记，L0-L3 守恒），当前 VIEW_TOMBSTONE 单哨兵保探链完整

       性能：
       - 零分配热读：ViewHash inline 单哈希零额外调用，ViewMapFindLocked 非 inline 短探（禁 inline 零 I-Cache 膨胀）、ViewMapFind 自锁短临界 <1µs 零阻塞 GLiveLock 读，探测 and Mask 位掩码与 assets FMask 单源一致热读零除法
       - 惰性重哈希：ViewMapRehashLocked/ViewMapAddLocked/ViewMapRemoveLocked 均为 out-of-line（真实循环体禁 inline，design-conventions 红线二），0.75 触发倍增，SetLength 单源单次，循环 and Mask 零额外调用零除法；ViewMapAdd 堆分配在锁外预分配（SetLength LNewMap 先于二次加锁），二次临界仅指针拷贝与 O(n) 桶迁移（n<=窗口数<=8，无堆分配，零阻塞读路径）
       - 容量预分配：初始化经 VecGrowCapacity(0) 4槽，稳态零每请求分配；扩容预判在锁外，短临界仅指针拷贝

       稳定性：析构清零 nil 释放不丢，VIEW_TOMBSTONE 单哨兵保探链完整 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.hashmap.base,
  nextpas.core.sync.mutex;

type
  TGtkWebviewOpaque = Pointer;

  TViewMapEntry = record
    Key: Pointer;
    Value: Pointer; // TGtkWebview opaque, 解耦避免循环 uses
  end;

const
  VIEW_TOMBSTONE = Pointer(1);

function ViewHash(AKey: Pointer): UInt32; inline;

// ViewMapFind/Add/Remove Locked 含循环/重哈希，禁 inline（design-conventions 红线二），零 I-Cache 膨胀
function ViewMapFindLocked(AView: Pointer): Pointer;
procedure ViewMapRehashLocked(ANewCap: Integer);
procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer);
procedure ViewMapRemoveLocked(AView: Pointer);

// 非 Locked 包装：自持 GViewMapLock，堆分配在锁外预判、短临界仅指针拷贝，零阻塞 GLiveLock 读
function ViewMapFind(AView: Pointer): Pointer;
procedure ViewMapAdd(AView: Pointer; AWin: Pointer);
procedure ViewMapRemove(AView: Pointer): Boolean;

procedure ViewMapInit; inline;
procedure ViewMapClear; inline;
function ViewMapCount: Integer; inline;
function ViewMapCapacity: Integer; inline;
procedure ViewMapLockInit;
procedure ViewMapLockFini;

implementation

var
  GViewMap: array of TViewMapEntry;
  GViewMapCount: Integer = 0;
  GViewMapLock: TMutex = nil;

function ViewHash(AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 THashMap/asset WyHash 单源一致，消除 shr4 xor shr11 私有分叉
  Result := HashOfPointer(AKey);
end;

function ViewMapFindLocked(AView: Pointer): Pointer;
var
  I, Cap, Start, Mask: Integer;
begin
  // 非 inline：含探查循环，禁 inline，零 I-Cache 膨胀；短探 O(1) 零分配，and Mask 与 assets 单源一致热读零除法
  Result := nil;
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Mask := Cap - 1;
  Start := Integer(ViewHash(AView) and UInt32(Mask));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) and Mask].Key = AView then
      Exit(GViewMap[(Start + I) and Mask].Value);
    if GViewMap[(Start + I) and Mask].Key = nil then
      Exit(nil);
  end;
end;

procedure ViewMapRehashLocked(ANewCap: Integer);
var
  LOld: array of TViewMapEntry;
  I, OldCap, Start, J, Mask: Integer;
begin
  // 非 inline：含双层循环与重哈希，禁 inline（design-conventions 红线二），零 I-Cache 膨胀，and Mask 与 assets 单源一致
  // 注意：此 Locked 形态仍含 SetLength（持 GViewMapLock 内堆分配），仅供 ViewMapAddLocked 直接持锁路径（n<=8 极小）；
  // ViewMapAdd 非 Locked 包装已改两阶段：堆分配在锁外 LNewMap 预分配，二次临界仅指针拷贝与迁移，零阻塞读路径
  LOld := GViewMap;
  OldCap := Length(LOld);
  SetLength(GViewMap, ANewCap);
  for I := 0 to ANewCap - 1 do
  begin
    GViewMap[I].Key := nil;
    GViewMap[I].Value := nil;
  end;
  GViewMapCount := 0;
  Mask := ANewCap - 1;
  for I := 0 to OldCap - 1 do
    if (LOld[I].Key <> nil) and (LOld[I].Key <> VIEW_TOMBSTONE) then
    begin
      Start := Integer(ViewHash(LOld[I].Key) and UInt32(Mask));
      for J := 0 to ANewCap - 1 do
        if GViewMap[(Start + J) and Mask].Key = nil then
        begin
          GViewMap[(Start + J) and Mask].Key := LOld[I].Key;
          GViewMap[(Start + J) and Mask].Value := LOld[I].Value;
          Inc(GViewMapCount);
          Break;
        end;
    end;
end;

procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer);
var
  I, Cap, Start, FirstTomb, Mask: Integer;
begin
  // 非 inline：含循环+分支+重哈希，禁 inline，零 I-Cache 膨胀；0.75 负载单源阈值，and Mask 与 assets 单源一致零除法
  if (AView = nil) or (AWin = nil) then Exit;
  Cap := Length(GViewMap);
  if Cap = 0 then
  begin
    SetLength(GViewMap, VecGrowCapacity(0));
    Cap := Length(GViewMap);
  end;
  if (GViewMapCount * 4 >= Cap * 3) then
  begin
    Cap := VecGrowCapacity(Cap);
    ViewMapRehashLocked(Cap);
    Cap := Length(GViewMap);
  end;
  Mask := Cap - 1;
  Start := Integer(ViewHash(AView) and UInt32(Mask));
  FirstTomb := -1;
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) and Mask].Key = AView then
    begin
      GViewMap[(Start + I) and Mask].Value := AWin;
      Exit;
    end;
    if GViewMap[(Start + I) and Mask].Key = VIEW_TOMBSTONE then
    begin
      if FirstTomb = -1 then FirstTomb := (Start + I) and Mask;
    end
    else if GViewMap[(Start + I) and Mask].Key = nil then
    begin
      if FirstTomb <> -1 then
      begin
        GViewMap[FirstTomb].Key := AView;
        GViewMap[FirstTomb].Value := AWin;
      end
      else
      begin
        GViewMap[(Start + I) and Mask].Key := AView;
        GViewMap[(Start + I) and Mask].Value := AWin;
      end;
      Inc(GViewMapCount);
      Exit;
    end;
  end;
end;

procedure ViewMapRemoveLocked(AView: Pointer);
var
  I, Cap, Start, Mask: Integer;
begin
  // 非 inline：含探查循环，禁 inline，and Mask 与 assets 单源一致热读零除法
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Mask := Cap - 1;
  Start := Integer(ViewHash(AView) and UInt32(Mask));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) and Mask].Key = AView then
    begin
      GViewMap[(Start + I) and Mask].Key := VIEW_TOMBSTONE;
      GViewMap[(Start + I) and Mask].Value := nil;
      Dec(GViewMapCount);
      if GViewMapCount < 0 then GViewMapCount := 0;
      Exit;
    end;
    if GViewMap[(Start + I) and Mask].Key = nil then
      Exit;
  end;
end;

function ViewMapFind(AView: Pointer): Pointer;
begin
  // 自持锁短临界：指针探查 O(1) 零堆分配，堆分配在锁外已预分配，短临界仅指针只读，零阻塞 GLiveLock 读
  if GViewMapLock <> nil then GViewMapLock.Acquire;
  try
    Result := ViewMapFindLocked(AView);
  finally
    if GViewMapLock <> nil then GViewMapLock.Release;
  end;
end;

procedure ViewMapAdd(AView: Pointer; AWin: Pointer);
var
  LCap, LCount, LNewCap, I, Mask, Start, J, LNewCount: Integer;
  LNeedGrow: Boolean;
  LNewMap, LOld: array of TViewMapEntry;
begin
  // 性能：堆分配在锁外预分配，短临界仅指针拷贝与 O(n) 迁移，零阻塞读路径（GLiveLock/Find 读不持堆锁）
  // 两阶段：阶段1短临界窥视是否需扩容并 fast-path 无扩容直插；需扩容则退锁在锁外 SetLength(LNewMap) 预分配，阶段2二次短临界安装并插入
  if (AView = nil) or (AWin = nil) then Exit;
  if GViewMapLock <> nil then GViewMapLock.Acquire;
  try
    LCap := Length(GViewMap);
    LCount := GViewMapCount;
    LNeedGrow := (LCap = 0) or (LCount * 4 >= LCap * 3);
    if not LNeedGrow then
    begin
      ViewMapAddLocked(AView, AWin);
      Exit;
    end;
    if LCap = 0 then
      LNewCap := VecGrowCapacity(0)
    else
      LNewCap := VecGrowCapacity(LCap);
  finally
    if GViewMapLock <> nil then GViewMapLock.Release;
  end;
  // 堆分配在锁外：bytes.ops.VecGrowCapacity 单源 0→4→2× inline 零额外调用，单次 SetLength 零持锁阻塞
  SetLength(LNewMap, LNewCap);
  for I := 0 to LNewCap - 1 do
  begin
    LNewMap[I].Key := nil;
    LNewMap[I].Value := nil;
  end;
  if GViewMapLock <> nil then GViewMapLock.Acquire;
  try
    // 双检：并发已扩容则复用现表，丢弃预分配 LNewMap（自动释放）
    if (Length(GViewMap) = 0) or (GViewMapCount * 4 >= Length(GViewMap) * 3) then
    begin
      if Length(GViewMap) < Length(LNewMap) then
      begin
        LOld := GViewMap;
        Mask := LNewCap - 1;
        LNewCount := 0;
        for I := 0 to Length(LOld) - 1 do
          if (LOld[I].Key <> nil) and (LOld[I].Key <> VIEW_TOMBSTONE) then
          begin
            Start := Integer(ViewHash(LOld[I].Key) and UInt32(Mask));
            for J := 0 to LNewCap - 1 do
              if LNewMap[(Start + J) and Mask].Key = nil then
              begin
                LNewMap[(Start + J) and Mask].Key := LOld[I].Key;
                LNewMap[(Start + J) and Mask].Value := LOld[I].Value;
                Inc(LNewCount);
                Break;
              end;
          end;
        GViewMap := LNewMap;
        GViewMapCount := LNewCount;
        LNewMap := nil;
      end;
    end;
    ViewMapAddLocked(AView, AWin);
  finally
    if GViewMapLock <> nil then GViewMapLock.Release;
  end;
end;

procedure ViewMapRemove(AView: Pointer): Boolean;
var
  LFound: Pointer;
begin
  Result := False;
  if GViewMapLock <> nil then GViewMapLock.Acquire;
  try
    LFound := ViewMapFindLocked(AView);
    if LFound <> nil then
    begin
      ViewMapRemoveLocked(AView);
      Result := True;
    end;
  finally
    if GViewMapLock <> nil then GViewMapLock.Release;
  end;
end;

procedure ViewMapInit; inline;
begin
  SetLength(GViewMap, VecGrowCapacity(0));
  GViewMapCount := 0;
end;

procedure ViewMapClear; inline;
begin
  SetLength(GViewMap, 0);
  GViewMapCount := 0;
end;

function ViewMapCount: Integer; inline;
begin
  Result := GViewMapCount;
end;

function ViewMapCapacity: Integer; inline;
begin
  Result := Length(GViewMap);
end;

procedure ViewMapLockInit;
begin
  if GViewMapLock = nil then
    GViewMapLock := TMutex.Create;
end;

procedure ViewMapLockFini;
begin
  FreeAndNil(GViewMapLock);
end;

end.
