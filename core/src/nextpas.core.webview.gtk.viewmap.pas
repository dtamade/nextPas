unit nextpas.core.webview.gtk.viewmap;

{** @desc GTK 指针键 view→window O(1) 索引：开地址 hash 薄封装。

       单源复用（零容器重复）：
       - 哈希：hashmap.base.HashOfPointer (HashMix32 单源) — 与 THashMap/ webview.assets.WyHash 单源一致，消除 shr4 xor shr11 私有分叉，分布经 HashMix32 avalanche 保证
       - 容量：bytes.ops.VecGrowCapacity (0→4→2× inline 单源) — 与 webview.live/assetIndex 单源一致
       - 负载：0.75 (hashmap.base.DEFAULT_MAX_LOAD_FACTOR) — 单源阈值，零阈值漂移
       - 比较：指针等值直比，零 SpanEqual 额外开销

       性能：
       - 零分配热读：ViewMapFindLocked 为 inline 短探，ViewHash inline 单哈希，热读不分配、指针只读
       - 惰性重哈希：ViewMapRehashLocked 为 out-of-line（真实循环体禁 inline，design-conventions 红线二），0.75 触发倍增，SetLength 单源单次，循环零额外调用
       - 容量预分配：初始化经 VecGrowCapacity(0) 4槽，稳态零每请求分配

       稳定性：析构清零 nil 释放不丢，VIEW_TOMBSTONE 单哨兵保探链完整 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.hashmap.base;

type
  TGtkWebviewOpaque = Pointer;

  TViewMapEntry = record
    Key: Pointer;
    Value: Pointer; // TGtkWebview opaque, 解耦避免循环 uses
  end;

const
  VIEW_TOMBSTONE = Pointer(1);

function ViewHash(AKey: Pointer): UInt32; inline;

function ViewMapFindLocked(AView: Pointer): Pointer; inline;
procedure ViewMapRehashLocked(ANewCap: Integer);
procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer); inline;
procedure ViewMapRemoveLocked(AView: Pointer); inline;

procedure ViewMapInit; inline;
procedure ViewMapClear; inline;
function ViewMapCount: Integer; inline;
function ViewMapCapacity: Integer; inline;

implementation

var
  GViewMap: array of TViewMapEntry;
  GViewMapCount: Integer = 0;

function ViewHash(AKey: Pointer): UInt32; inline;
begin
  // 单源：hashmap.base.HashOfPointer → HashMix32，与 THashMap/asset WyHash 单源一致，消除 shr4 xor shr11 私有分叉
  Result := HashOfPointer(AKey);
end;

function ViewMapFindLocked(AView: Pointer): Pointer; inline;
var
  I, Cap, Start: Integer;
begin
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

procedure ViewMapAddLocked(AView: Pointer; AWin: Pointer); inline;
var
  I, Cap, Start, FirstTomb: Integer;
begin
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

procedure ViewMapRemoveLocked(AView: Pointer); inline;
var
  I, Cap, Start: Integer;
begin
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

end.
