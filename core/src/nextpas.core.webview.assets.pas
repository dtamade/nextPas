unit nextpas.core.webview.assets;

{** @desc webview 资产前缀索引：单哈希 + 前缀 Trie 单源。
       契约：
       - Normalize 已在外层完成，本模块只存归一后前缀；
       - 首个同前缀胜（Add 去重，不覆盖），与 CONTRACT §3.4 同长先挂一致；
       - 探测：TryGetByStr O(1) 平均（0.75 负载单表 via L1 hashmap），Trie 最长前缀 O(m)
         零拷贝单遍（稀疏小表，独立于挂载数），404 单次探测不回退。

       单源复用：
       - 哈希/容量/探测：L1 collections.hashmap 单源（WyHash/HashMix32/NextPow2/Bitmap 0.75 负载，零自建桶/Find/Rehash 分叉）；
       - 相等/生长：bytes.ops SpanEqual/VecGrow 单源；
       - 前缀 Trie：L2 nextpas.core.collections.prefixrouter 单源
         （稀疏子节点小表 + bytes.ops VecGrow + TStringView 零拷贝，
         供 http/vfs 复用，已反哺落地）。

       单源收敛：前缀长度去重与最长匹配唯一由 Trie 承载，零 FDistinctLens 双轨
         （归一时序：外层 NormalizeWebviewAssetPath 先归一 → 本模块仅存归一后串，
         Add 时 FMap.Add 成功才 FTrie.Add 单源登记，探测统一 TryGetLongestPrefixByView O(m)
         Trie 单遍，零手工 Distinct 数组/懒排序/双轨维护）。

       性能：哈希/探测委托 L1 THashMap 内联单源（WyHash 单源 inline 零额外调用，容量 NextPow2 单源 via hashmap.base/simd.bitops，Bitmap CTZ 单指令）；
       TStringView 零拷贝 Trie 遍历，VecGrowCapacity 0→4→2× inline；TryGetLongestPrefixByView
       inline 薄转发至 L2 前缀路由，零额外调用，零 distinctLens 排序开销；Reserve 双预分配 FMap NextPow2 + FTrie VecGrowCapacity 双 inline 单源，零分裂双轨。
       稳定性：FMap.Clear 全量串/接口 Finalize + 前缀路由 Clear 递归 Dispose 不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.intf,
  nextpas.core.text.view;

type
  TWebviewAssetIndex = class
  private
    FMap: specialize THashMap<string, IWebviewAssetProvider>;
    FTrie: specialize TPrefixRouter<IWebviewAssetProvider>;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
    procedure Reserve(ACount: SizeUInt); inline;
    function TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetLongestPrefixByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function Count: Integer; inline;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.prefixrouter;

constructor TWebviewAssetIndex.Create;
begin
  inherited Create;
  FMap := specialize THashMap<string, IWebviewAssetProvider>.Create(4);
  FTrie := specialize TPrefixRouter<IWebviewAssetProvider>.Create;
end;

destructor TWebviewAssetIndex.Destroy;
begin
  Clear;
  FreeAndNil(FTrie);
  if FMap <> nil then
  begin
    FMap.Free;
    FMap := nil;
  end;
  inherited Destroy;
end;

procedure TWebviewAssetIndex.Clear;
begin
  if Assigned(FTrie) then
    FTrie.Clear;
  if FMap <> nil then
    FMap.Clear;
end;

function TWebviewAssetIndex.Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
begin
  // 单源 L1 THashMap：哈希 WyHash/HashMix32 + NextPow2 + 0.75 负载 + Bitmap 单源，O(1) 平均探测，零自建 Find/Rehash 分叉
  // 单源收敛：前缀去重与长度集合唯一由 Trie 承载，零 FDistinctLens 手工去重/懒排序双轨
  if not FMap.Add(APrefix, AProvider) then
    Exit(False);
  FTrie.Add(APrefix, AProvider);
  Result := True;
end;

procedure TWebviewAssetIndex.Reserve(ACount: SizeUInt); inline;
var
  LNeed: SizeUInt;
begin
  // 批量预分配：消除高频多前缀挂载的重复 NextPow2 重哈希（双写 FMap+FTrie 单源容量收敛）
  // 单源 L1 THashMap.Reserve (NextPow2 via hashmap.base/simd.bitops, 0.75 负载, Bitmap CTZ) + L2 TPrefixRouter.Reserve (bytes.ops VecGrowCapacity 0→4→2× 稀疏子节点单源) inline 双薄转发，零额外 Rehash/Find 分叉
  // 容量换算：期望条目 ACount → 桶数 ceil(ACount/0.75)+slack，整数算式避免浮点；Trie 稀疏节点经 bytes.ops VecGrow 单源预分配（ACount 上限 256 Byte 分支封顶），零分裂双轨
  // 性能 inline 零额外调用，零拷贝（无串拷贝）；稳定性 nil/0 早退不丢
  if (FMap = nil) or (FTrie = nil) or (ACount = 0) then Exit;
  LNeed := ACount + (ACount div 3) + 4;
  FMap.Reserve(LNeed);
  FTrie.Reserve(ACount);
end;

function TWebviewAssetIndex.TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
begin
  // perf: inline O(1) 平均哈希探测（L1 hashmap 单源 WyHash/HashMix32），hash 相等再字符串相等双筛，零额外调用
  if (FMap = nil) or (FMap.GetCount = 0) then Exit(False);
  Result := FMap.TryGetValue(APrefix, AProvider);
end;

function TWebviewAssetIndex.TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
begin
  // 性能：热路径最长前缀走 Trie O(m) 零拷贝 view 遍历（单遍，独立于挂载数），此精确 view 查单次 WyHash 单源 + 零拷贝探测（via THashMap.TryGetValueView 单源，零 ToString 堆分配，inline 薄转发，O(1) 平均）
  if (FMap = nil) or (FMap.GetCount = 0) then Exit(False);
  Result := FMap.TryGetValueView(AView.Data, AView.Len, AProvider);
end;

function TWebviewAssetIndex.TryGetLongestPrefixByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
begin
  Result := FTrie.TryGetLongestPrefixView(AView, AProvider);
end;

function TWebviewAssetIndex.Count: Integer; inline;
begin
  if FMap = nil then Exit(0);
  Result := Integer(FMap.GetCount);
end;

end.
