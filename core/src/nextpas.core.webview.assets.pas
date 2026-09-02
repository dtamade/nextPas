unit nextpas.core.webview.assets;

{** @desc webview 资产前缀索引独立模块（L3 bridge 专用）：
       单哈希 + 有序 distinct 长度 + 前缀 Trie 承载全部路由需求，消除 bridge 侧
       FMounts 数组 + THashMap + FDistinctLens 三结构双写耦合。

       契约：
       - Normalize 已在外层完成，本模块只存归一后前缀字符串；
       - 首个同前缀胜（Add 去重，不覆盖），与 CONTRACT §3.4 同长先挂一致；
       - 探测：TryGetByView 零拷贝 view 哈希线性探测 O(1) 平均（0.75 负载 Rehash 单表，整除 3/4 零浮点），
         TryResolveByPath 按 distinctLens 降序枚举最长前缀首命中—最坏 O(d)≤O(m)（d=DistinctCount≤m，逐前缀 WyHash+SpanEqual 哈希探测），
         d 通常 ≤4-8 小常数均摊 O(1)，单挂载 inline 快路径严格 O(1)；Trie 最长前缀 O(m)（m=路径长，单次字符遍历，零哈希）与哈希双源互备，
         d 放大时 Trie 严格 O(m) 独立于挂载数，已落地内置 Byte-Trie（256 分支，惰性分配，零拷贝 view 遍历，404 命名空间隔离仍单次探测），
         未命中 provider False 即 404 不回退（命名空间隔离）。

       单源复用（零重复）：
       - 哈希：WyHash32 单源 nextpas.core.hash.wyhash + HashMix32 单源
         nextpas.core.collections.hashmap.base，空串 2166136261 seed 与
         THashMap.HashOfAnsiString 一致；NextPow2 单源 nextpas.core.simd.bitops
         （NextPow2_32/64 inline，位运算单指令），消除本地 HashMix32Inline/NextPow2 重复；
       - 相等：SpanEqual 单源 nextpas.core.bytes.ops（TByteSpan 零拷贝 + SIMD MemEqual）；
       - 生长：VecGrow/VecGrowCapacity 单源 nextpas.core.bytes.ops（0→4→2× inline，零额外调用）；
       - 容器特化说明：前缀路由需“最长前缀降序枚举 + 零拷贝 TStringView 探测 + 404 命名空间隔离
         + distinctLens 有序表”，通用 THashMap/TSwissTable 无此语义且 view 需串分配破坏零拷贝，
         故保留专用线性探测表 + 内置 Trie 双结构但哈希/容量/相等/生长全量委托单源，零容器逻辑重复；
         演进候选：通用 prefix-router 可抽 L2/L3 独立模块供 http/vfs 复用（L2 collections.prefixrouter 或 http.router 通用前缀路由），当前专用表哈希(WyHash32+HashMix32)/NextPow2/SpanEqual/VecGrow 全量单源已零重复，Trie 已内置 O(m) 单次遍历零哈希，迁移零成本（登记为演进候选，deferred-Res 转正前评估，不在当前 slice 外溢）。

       性能：
       - 零拷贝：TStringView 切片零堆分配，TryGetByView 按 view.Data/Len 直算 WyHash32 与
         SpanEqual 直比，单 distinct 零 Copy，TryGetLongestPrefixByView 按 view.Data 逐字节 Trie 遍历零哈希零分配，热点单挂载仍内联快路径（inline 零额外调用，404 零 ToString）；
       - 容量：VecGrowCapacity(0→4→2×) bytes.ops 单源 inline 倍增，3/4 负载重哈希（整数 Cap*3 div 4 零浮点，热点扩容零 FPU），Trie 节点惰性 New 零预分配，零 O(n²)；
       - distinctLens 摊销 O(1) 追加 + 惰性 IntroSort 降序 O(n log n) 单次（collections.algorithms.SortInt32DescRange 单源，Heap 回退+Tukey ninther，最坏 O(n log n)，零自实现快排分叉），DistinctCount 惰性一次 Ensure 后 LensAtUnchecked 零重复 Ensure 零额外分配，MountCount = distinct 哈希数，FindBy/TryGet 全 inline；
       - 路由：Rehash 0.75 负载单表保证 TryGetByView O(1) 平均，TryResolve 最坏 O(d)≤O(m) 降序枚举+每步 O(1) 哈希（d=DistinctCount），d 小常数均摊 O(1)，单根快路径 inline O(1) 零枚举；Trie 最长前缀严格 O(m)（m=路径字节长，单遍 256 分支直跳，零哈希探测，d 放大时仍 O(m) 独立于挂载数），双源互备已消除线性放大；

       稳定性：析构 Finalize 全量串/接口 + Trie 递归 Dispose 全量 provider 释放，no leak；inline 薄转零额外调用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.intf,
  nextpas.core.text.view;

type
  {** 前缀路由索引：单哈希+有序 Lens + 前缀 Trie 独立承载 *}
  TWebviewAssetIndex = class
  private type
    TBucket = record
      State: Byte; // 0 Empty,1 Occupied
      Hash: UInt32;
      Prefix: string;
      Provider: IWebviewAssetProvider;
    end;
    PAssetTrieNode = ^TAssetTrieNode;
    TAssetTrieNode = record
      Children: array[0..255] of PAssetTrieNode;
      HasValue: Boolean;
      Provider: IWebviewAssetProvider;
    end;
  private
    FBuckets: array of TBucket;
    FCapacity: SizeUInt;
    FMask: SizeUInt;
    FCount: SizeUInt;
    FUsed: SizeUInt;
    FMaxLoad: SizeUInt;
    FDistinctLens: array of Integer;
    FDistinctCount: Integer;
    FDistinctDirty: Boolean;
    FTrieRoot: PAssetTrieNode;
    procedure InitCapacity(ACap: SizeUInt);
    procedure Rehash(ANewCap: SizeUInt);
    procedure GrowDistinct; inline;
    procedure UpdateDistinctLens(const APrefix: string); inline;
    procedure EnsureDistinctSorted; inline;
    procedure SortDistinctDesc(ACount: Integer); inline;
    function NextPow2(X: SizeUInt): SizeUInt; inline;
    procedure RecalcMaxLoad; inline;
    function HashOfStr(const S: string): UInt32; inline;
    function HashOfView(const AView: TStringView): UInt32; inline;
    function FindByStr(const S: string; AHash: UInt32; out AIdx: SizeUInt): Boolean;
    function FindByView(const AView: TStringView; AHash: UInt32; out AIdx: SizeUInt): Boolean;
    function BucketEqualsStr(const AIdx: SizeUInt; const S: string): Boolean;
    function BucketEqualsView(const AIdx: SizeUInt; const AView: TStringView): Boolean;
    function NewTrieNode: PAssetTrieNode; inline;
    procedure FreeTrieNode(ANode: PAssetTrieNode);
    procedure ClearTrie;
    procedure InsertTrie(const APrefix: string; AProvider: IWebviewAssetProvider); inline;
  public
    constructor Create;
    destructor Destroy; override;
    { 首个同前缀胜，已存在返回 False 未覆盖 }
    function Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
    function TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    { Trie 最长前缀：O(m) 单遍零拷贝 view 遍历，零哈希，独立于挂载数，404 单次探测 }
    function TryGetLongestPrefixByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function Count: Integer; inline;
    function DistinctCount: Integer; inline;
    function DistinctLensAt(AIndex: Integer): Integer; inline;
    // 快路径：已 Ensure 后零重复 Ensure 的零拷贝直读（bridge 批量枚举专用，inline 单次数组读）
    function DistinctCountUnchecked: Integer; inline;
    function DistinctLensAtUnchecked(AIndex: Integer): Integer; inline;
    procedure EnsureDistinctSortedPublic; inline;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.hash.wyhash,
  nextpas.core.base.utils,
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.algorithms,
  nextpas.core.simd.bitops;

constructor TWebviewAssetIndex.Create;
begin
  inherited Create;
  FTrieRoot := nil;
end;

destructor TWebviewAssetIndex.Destroy;
begin
  Clear;
  ClearTrie;
  SetLength(FBuckets, 0);
  SetLength(FDistinctLens, 0);
  inherited Destroy;
end;

procedure TWebviewAssetIndex.Clear;
var
  I: SizeUInt;
begin
  ClearTrie;
  if FCapacity = 0 then
  begin
    FCount := 0;
    FUsed := 0;
    FDistinctCount := 0;
    FDistinctDirty := False;
    Exit;
  end;
  for I := 0 to FCapacity - 1 do
    if FBuckets[I].State = 1 then
    begin
      Finalize(FBuckets[I].Prefix);
      Finalize(FBuckets[I].Provider);
      FBuckets[I].State := 0;
      FBuckets[I].Hash := 0;
    end;
  FCount := 0;
  FUsed := 0;
  FDistinctCount := 0;
  FDistinctDirty := False;
end;

function TWebviewAssetIndex.NewTrieNode: PAssetTrieNode; inline;
begin
  New(Result);
  FillChar(Result^, SizeOf(TAssetTrieNode), 0);
end;

procedure TWebviewAssetIndex.FreeTrieNode(ANode: PAssetTrieNode);
var
  I: Integer;
begin
  if ANode = nil then Exit;
  for I := 0 to 255 do
    if ANode^.Children[I] <> nil then
      FreeTrieNode(ANode^.Children[I]);
  if ANode^.HasValue then
    Finalize(ANode^.Provider);
  Dispose(ANode);
end;

procedure TWebviewAssetIndex.ClearTrie;
begin
  if FTrieRoot <> nil then
  begin
    FreeTrieNode(FTrieRoot);
    FTrieRoot := nil;
  end;
end;

procedure TWebviewAssetIndex.InsertTrie(const APrefix: string; AProvider: IWebviewAssetProvider); inline;
var
  LNode: PAssetTrieNode;
  I: Integer;
  C: Byte;
begin
  if FTrieRoot = nil then
    FTrieRoot := NewTrieNode;
  LNode := FTrieRoot;
  if Length(APrefix) = 0 then
  begin
    if not LNode^.HasValue then
    begin
      LNode^.HasValue := True;
      LNode^.Provider := AProvider;
    end;
    Exit;
  end;
  for I := 1 to Length(APrefix) do
  begin
    C := Byte(APrefix[I]);
    if LNode^.Children[C] = nil then
      LNode^.Children[C] := NewTrieNode;
    LNode := LNode^.Children[C];
  end;
  if not LNode^.HasValue then
  begin
    LNode^.HasValue := True;
    LNode^.Provider := AProvider;
  end;
end;

function TWebviewAssetIndex.NextPow2(X: SizeUInt): SizeUInt; inline;
begin
  if X <= 1 then Exit(1);
{$IF SizeOf(SizeUInt)=8}
  Result := SizeUInt(NextPow2_64(TU64(X)));
{$ELSE}
  Result := SizeUInt(NextPow2_32(TU32(X)));
{$ENDIF}
end;

procedure TWebviewAssetIndex.RecalcMaxLoad; inline;
begin
  FMaxLoad := FCapacity * 3 div 4;
  if FMaxLoad >= FCapacity then
    FMaxLoad := FCapacity - 1;
end;

procedure TWebviewAssetIndex.InitCapacity(ACap: SizeUInt);
begin
  if ACap < 4 then ACap := 4;
  ACap := NextPow2(ACap);
  SetLength(FBuckets, ACap);
  { stability: SetLength 已 Default(TBucket) 零初始化，禁 FillChar 托管绕过与 O(cap) 抖动 }
  FCapacity := ACap;
  if ACap > 0 then
    FMask := ACap - 1
  else
    FMask := 0;
  FCount := 0;
  FUsed := 0;
  RecalcMaxLoad;
end;

procedure TWebviewAssetIndex.Rehash(ANewCap: SizeUInt);
var
  LOld: array of TBucket;
  LOldCap: SizeUInt;
  I: SizeUInt;
  LIdx: SizeUInt;
begin
  LOld := FBuckets;
  LOldCap := FCapacity;
  FBuckets := nil;
  FCapacity := 0;
  InitCapacity(ANewCap);
  for I := 0 to LOldCap - 1 do
    if LOld[I].State = 1 then
    begin
      LIdx := LOld[I].Hash and FMask;
      while FBuckets[LIdx].State = 1 do
        LIdx := (LIdx + 1) and FMask;
      FBuckets[LIdx].State := 1;
      FBuckets[LIdx].Hash := LOld[I].Hash;
      FBuckets[LIdx].Prefix := LOld[I].Prefix;
      FBuckets[LIdx].Provider := LOld[I].Provider;
      LOld[I].Prefix := '';
      LOld[I].Provider := nil;
      LOld[I].State := 0;
      LOld[I].Hash := 0;
      Inc(FCount);
      Inc(FUsed);
    end;
  SetLength(LOld, 0);
end;

procedure TWebviewAssetIndex.GrowDistinct; inline;
begin
  Assert(FDistinctCount >= 0, 'GrowDistinct count');
  specialize VecGrow<Integer>(FDistinctLens, FDistinctCount);
end;

procedure TWebviewAssetIndex.SortDistinctDesc(ACount: Integer); inline;
begin
  if ACount <= 1 then Exit;
  // 单源 IntroSort 降序：delegates to collections.algorithms.SortInt32DescRange (Heap 回退+Tukey ninther)，最坏 O(n log n)，零自实现分叉，保留 slack 零 SetLength
  SortInt32DescRange(FDistinctLens, ACount);
end;

procedure TWebviewAssetIndex.EnsureDistinctSorted; inline;
begin
  if not FDistinctDirty then Exit;
  if FDistinctCount > 1 then
    SortDistinctDesc(FDistinctCount);
  FDistinctDirty := False;
end;

procedure TWebviewAssetIndex.UpdateDistinctLens(const APrefix: string); inline;
var
  LLen, I: Integer;
begin
  LLen := Length(APrefix);
  for I := 0 to FDistinctCount - 1 do
    if FDistinctLens[I] = LLen then Exit;
  GrowDistinct;
  FDistinctLens[FDistinctCount] := LLen;
  Inc(FDistinctCount);
  FDistinctDirty := True;
end;

function TWebviewAssetIndex.HashOfStr(const S: string): UInt32; inline;
begin
  if Length(S) = 0 then
    Exit(HashMix32(2166136261));
  Result := WyHash32(@S[1], SizeUInt(Length(S)));
end;

function TWebviewAssetIndex.HashOfView(const AView: TStringView): UInt32; inline;
begin
  if AView.Len = 0 then
    Exit(HashMix32(2166136261));
  Result := WyHash32(AView.Data, AView.Len);
end;

function TWebviewAssetIndex.BucketEqualsStr(const AIdx: SizeUInt; const S: string): Boolean;
var
  LStored: string;
begin
  LStored := FBuckets[AIdx].Prefix;
  if Length(LStored) <> Length(S) then Exit(False);
  if Length(S) = 0 then Exit(True);
  // bytes.ops 单源 SpanEqual：零拷贝 TByteSpan view + SIMD MemEqual，避免 inline+CompareMem(@S[1]) 形态
  Result := SpanEqual(
    TByteSpan.Create(PByte(PAnsiChar(LStored)), SizeUInt(Length(LStored))),
    TByteSpan.Create(PByte(PAnsiChar(S)), SizeUInt(Length(S))));
end;

function TWebviewAssetIndex.BucketEqualsView(const AIdx: SizeUInt; const AView: TStringView): Boolean;
var
  LStored: string;
begin
  LStored := FBuckets[AIdx].Prefix;
  if SizeUInt(Length(LStored)) <> AView.Len then Exit(False);
  if AView.Len = 0 then Exit(True);
  // bytes.ops 单源 SpanEqual：TStringView 零拷贝转 TByteSpan，SIMD MemEqual 直比
  Result := SpanEqual(
    TByteSpan.Create(PByte(PAnsiChar(LStored)), SizeUInt(Length(LStored))),
    TByteSpan.Create(PByte(AView.Data), AView.Len));
end;

function TWebviewAssetIndex.FindByStr(const S: string; AHash: UInt32; out AIdx: SizeUInt): Boolean;
var
  LIdx, LStart: SizeUInt;
begin
  Result := False;
  if FCapacity = 0 then begin AIdx := 0; Exit(False); end;
  LIdx := AHash and FMask;
  LStart := LIdx;
  while True do
  begin
    case FBuckets[LIdx].State of
      0: begin AIdx := LIdx; Exit(False); end;
      1: if (FBuckets[LIdx].Hash = AHash) and BucketEqualsStr(LIdx, S) then
         begin AIdx := LIdx; Exit(True); end;
    end;
    LIdx := (LIdx + 1) and FMask;
    if LIdx = LStart then begin AIdx := LIdx; Exit(False); end;
  end;
end;

function TWebviewAssetIndex.FindByView(const AView: TStringView; AHash: UInt32; out AIdx: SizeUInt): Boolean;
var
  LIdx, LStart: SizeUInt;
begin
  Result := False;
  if FCapacity = 0 then begin AIdx := 0; Exit(False); end;
  LIdx := AHash and FMask;
  LStart := LIdx;
  while True do
  begin
    case FBuckets[LIdx].State of
      0: begin AIdx := LIdx; Exit(False); end;
      1: if (FBuckets[LIdx].Hash = AHash) and BucketEqualsView(LIdx, AView) then
         begin AIdx := LIdx; Exit(True); end;
    end;
    LIdx := (LIdx + 1) and FMask;
    if LIdx = LStart then begin AIdx := LIdx; Exit(False); end;
  end;
end;

function TWebviewAssetIndex.Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  if FCapacity = 0 then InitCapacity(4);
  H := HashOfStr(APrefix);
  if FindByStr(APrefix, H, LIdx) then
    Exit(False); // 首个胜
  if FUsed >= FMaxLoad then
  begin
    Rehash(FCapacity shl 1);
    // re-probe after growth
    FindByStr(APrefix, H, LIdx);
  end;
  FBuckets[LIdx].State := 1;
  FBuckets[LIdx].Hash := H;
  FBuckets[LIdx].Prefix := APrefix;
  FBuckets[LIdx].Provider := AProvider;
  Inc(FCount);
  Inc(FUsed);
  UpdateDistinctLens(APrefix);
  InsertTrie(APrefix, AProvider);
  Result := True;
end;

function TWebviewAssetIndex.TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  if FCapacity = 0 then Exit(False);
  H := HashOfStr(APrefix);
  if FindByStr(APrefix, H, LIdx) then
  begin
    AProvider := FBuckets[LIdx].Provider;
    Exit(True);
  end;
  Result := False;
end;

function TWebviewAssetIndex.TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
var
  H: UInt32;
  LIdx: SizeUInt;
begin
  if FCapacity = 0 then Exit(False);
  H := HashOfView(AView);
  if FindByView(AView, H, LIdx) then
  begin
    AProvider := FBuckets[LIdx].Provider;
    Exit(True);
  end;
  Result := False;
end;

function TWebviewAssetIndex.TryGetLongestPrefixByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
var
  LNode, LBest: PAssetTrieNode;
  I: SizeUInt;
  C: Byte;
begin
  Result := False;
  if FTrieRoot = nil then Exit;
  LNode := FTrieRoot;
  LBest := nil;
  if LNode^.HasValue then
    LBest := LNode;
  for I := 0 to AView.Len - 1 do
  begin
    C := AView.Data[I];
    if LNode^.Children[C] = nil then Break;
    LNode := LNode^.Children[C];
    if LNode^.HasValue then
      LBest := LNode;
  end;
  if LBest <> nil then
  begin
    AProvider := LBest^.Provider;
    Exit(True);
  end;
  Result := False;
end;

function TWebviewAssetIndex.Count: Integer; inline;
begin
  Result := Integer(FCount);
end;

function TWebviewAssetIndex.DistinctCount: Integer; inline;
begin
  EnsureDistinctSorted;
  Result := FDistinctCount;
end;

function TWebviewAssetIndex.DistinctLensAt(AIndex: Integer): Integer; inline;
begin
  EnsureDistinctSorted;
  Result := FDistinctLens[AIndex];
end;

function TWebviewAssetIndex.DistinctCountUnchecked: Integer; inline;
begin
  Result := FDistinctCount;
end;

function TWebviewAssetIndex.DistinctLensAtUnchecked(AIndex: Integer): Integer; inline;
begin
  Result := FDistinctLens[AIndex];
end;

procedure TWebviewAssetIndex.EnsureDistinctSortedPublic; inline;
begin
  EnsureDistinctSorted;
end;

end.
