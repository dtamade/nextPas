unit nextpas.core.webview.assets;

{** @desc webview 资产前缀索引：单哈希 + 有序 distinct 长度 + 前缀 Trie。
       契约：
       - Normalize 已在外层完成，本模块只存归一后前缀；
       - 首个同前缀胜（Add 去重，不覆盖），与 CONTRACT §3.4 同长先挂一致；
       - 探测：TryGetByView O(1) 平均（0.75 负载单表），Trie 最长前缀 O(m)
         零哈希单遍（稀疏小表，独立于挂载数），404 单次探测不回退。

       单源复用：
       - 哈希/NextPow2/HashMix32：wyhash + hashmap.base + simd.bitops 单源；
       - 相等/生长：bytes.ops SpanEqual/VecGrow 单源；
       - 前缀 Trie：L2 nextpas.core.collections.prefixrouter 单源
         （稀疏子节点小表 + bytes.ops VecGrow + TStringView 零拷贝，
         供 http/vfs 复用，已反哺落地）。

       性能：TStringView 零拷贝 view 哈希/Trie 遍历，VecGrowCapacity 0→4→2×
       inline，distinctLens 惰性 IntroSort 降序；TryGetLongestPrefixByView
       inline 薄转发至 L2 前缀路由，零额外调用。
       稳定性：Finalize 全量串/接口 + 前缀路由 Clear 递归 Dispose 不丢。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.intf,
  nextpas.core.text.view;

type
  TWebviewAssetIndex = class
  private type
    TBucket = record
      State: Byte;
      Hash: UInt32;
      Prefix: string;
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
    FTrie: specialize TPrefixRouter<IWebviewAssetProvider>;
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
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
    function TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetLongestPrefixByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function Count: Integer; inline;
    function DistinctCount: Integer; inline;
    function DistinctLensAt(AIndex: Integer): Integer; inline;
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
  nextpas.core.collections.prefixrouter,
  nextpas.core.simd.bitops;

constructor TWebviewAssetIndex.Create;
begin
  inherited Create;
  FTrie := specialize TPrefixRouter<IWebviewAssetProvider>.Create;
end;

destructor TWebviewAssetIndex.Destroy;
begin
  Clear;
  FreeAndNil(FTrie);
  SetLength(FBuckets, 0);
  SetLength(FDistinctLens, 0);
  inherited Destroy;
end;

procedure TWebviewAssetIndex.Clear;
var
  I: SizeUInt;
begin
  if Assigned(FTrie) then
    FTrie.Clear;
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
    Exit(False);
  if FUsed >= FMaxLoad then
  begin
    Rehash(FCapacity shl 1);
    FindByStr(APrefix, H, LIdx);
  end;
  FBuckets[LIdx].State := 1;
  FBuckets[LIdx].Hash := H;
  FBuckets[LIdx].Prefix := APrefix;
  FBuckets[LIdx].Provider := AProvider;
  Inc(FCount);
  Inc(FUsed);
  UpdateDistinctLens(APrefix);
  FTrie.Add(APrefix, AProvider);
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
begin
  Result := FTrie.TryGetLongestPrefixView(AView, AProvider);
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
