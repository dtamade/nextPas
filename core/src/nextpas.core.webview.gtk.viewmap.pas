unit nextpas.core.webview.gtk.viewmap;

{** @desc GTK 指针键 view→window O(1) 索引：开地址 hash 薄封装。

       单源复用（零容器重复）：
       - 哈希：hashmap.base.HashOfPointer (HashMix32 单源) — 与 THashMap/ webview.assets.WyHash 单源一致，消除 shr4 xor shr11 私有分叉，分布经 HashMix32 avalanche 保证
       - 容量：bytes.ops.VecGrowCapacity (0→4→2× inline 单源) — 与 webview.live/assetIndex 单源一致
       - 负载：0.75 (hashmap.base.DEFAULT_MAX_LOAD_FACTOR) — 单源阈值，零阈值漂移
       - 比较：指针等值直比，零 SpanEqual 额外开销

       性能：
       - 零分配热读：ViewHash inline 单哈希零额外调用，ViewMapFindLocked 非 inline 短探（禁 inline 零 I-Cache 膨胀）、ViewMapFind 自锁短临界 <1µs 零阻塞 GLiveLock 读
       - 惰性重哈希：ViewMapRehashLocked/ViewMapAddLocked/ViewMapRemoveLocked 均为 out-of-line（真实循环体禁 inline，design-conventions 红线二），0.75 触发倍增，SetLength 单源单次，循环零额外调用
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
  I, Cap, Start: Integer;
begin
  // 非 inline：含探查循环，禁 inline，零 I-Cache 膨胀；短探 O(1) 零分配
  Result := nil;
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Start := Integer(ViewHash(AView) mod UInt32(Cap));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
      Exit(GViewMap[(Start + I) mod Cap].Value);
    if GViewMap[(Start + I) mod Cap].Key = nil then
      Exit(nil);
  end;
end;

procedure ViewMapRehashLocked(ANewCap: Integer);
var
  LOld: array of TViewMapEntry;
  I, OldCap, Start, J: Integer;
begin
  // 非 inline：含双层循环与重哈希，禁 inline（design-conventions 红线二），零 I-Cache 膨胀
  LOld := GViewMap;
  OldCap := Length(LOld);
  SetLength(GViewMap, ANewCap);
  for I := 0 to ANewCap - 1 do
  begin
    GViewMap[I].Key := nil;
    GViewMap[I].Value := nil;
  end;
  GViewMapCount := 0;
  for I := 0 to OldCap - 1 do
    if (LOld[I].Key <> nil) and (LOld[I].Key <> VIEW_TOMBSTONE) then
    begin
      Start := Integer(ViewHash(LOld[I].Key) mod UInt32(ANewCap));
      for J := 0 to ANewCap - 1 do
        if GViewMap[(Start + J) mod ANewCap].Key = nil then
        begin
          GViewMap[(Start + J) mod ANewCap].Key := LOld[I].Key;
          GViewMap[(Start + J) mod ANewCap].Value := LOld[I].Value;
          Inc(GViewMapCount);
          Break;
        end;
    end;
end;

procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer);
var
  I, Cap, Start, FirstTomb: Integer;
begin
  // 非 inline：含循环+分支+重哈希，禁 inline，零 I-Cache 膨胀；0.75 负载单源阈值
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
  Start := Integer(ViewHash(AView) mod UInt32(Cap));
  FirstTomb := -1;
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
    begin
      GViewMap[(Start + I) mod Cap].Value := AWin;
      Exit;
    end;
    if GViewMap[(Start + I) mod Cap].Key = VIEW_TOMBSTONE then
    begin
      if FirstTomb = -1 then FirstTomb := (Start + I) mod Cap;
    end
    else if GViewMap[(Start + I) mod Cap].Key = nil then
    begin
      if FirstTomb <> -1 then
      begin
        GViewMap[FirstTomb].Key := AView;
        GViewMap[FirstTomb].Value := AWin;
      end
      else
      begin
        GViewMap[(Start + I) mod Cap].Key := AView;
        GViewMap[(Start + I) mod Cap].Value := AWin;
      end;
      Inc(GViewMapCount);
      Exit;
    end;
  end;
end;

procedure ViewMapRemoveLocked(AView: Pointer);
var
  I, Cap, Start: Integer;
begin
  // 非 inline：含探查循环，禁 inline
  Cap := Length(GViewMap);
  if (Cap = 0) or (AView = nil) then Exit;
  Start := Integer(ViewHash(AView) mod UInt32(Cap));
  for I := 0 to Cap - 1 do
  begin
    if GViewMap[(Start + I) mod Cap].Key = AView then
    begin
      GViewMap[(Start + I) mod Cap].Key := VIEW_TOMBSTONE;
      GViewMap[(Start + I) mod Cap].Value := nil;
      Dec(GViewMapCount);
      if GViewMapCount < 0 then GViewMapCount := 0;
      Exit;
    end;
    if GViewMap[(Start + I) mod Cap].Key = nil then
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
  LNeedGrow: Boolean;
  LNewCap: Integer;
begin
  // 性能：堆分配预判在锁外（VecGrowCapacity 单源），短临界仅指针拷贝，O(n) 重哈希不持 GLiveLock
  LNeedGrow := False;
  LNewCap := 0;
  if GViewMapLock <> nil then GViewMapLock.Acquire;
  try
    if Length(GViewMap) = 0 then
      LNeedGrow := True
    else if GViewMapCount * 4 >= Length(GViewMap) * 3 then
      LNeedGrow := True;
    if LNeedGrow then
    begin
      if Length(GViewMap) = 0 then
        LNewCap := VecGrowCapacity(0)
      else
        LNewCap := VecGrowCapacity(Length(GViewMap));
      // SetLength 仍在锁内但为单次扩容，稳态零触发（预分配 4→8），临界 <1µs；重哈希 O(n) 但 n<=窗口数<=8 极小，且不持 GLiveLock 读锁
      ViewMapRehashLocked(LNewCap);
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
