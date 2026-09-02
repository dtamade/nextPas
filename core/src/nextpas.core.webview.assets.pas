unit nextpas.core.webview.assets;

{** @desc webview 资产前缀索引独立模块（L3 bridge 专用）：
       单哈希 + 有序 distinct 长度承载全部路由需求，消除 bridge 侧
       FMounts 数组 + THashMap + FDistinctLens 三结构双写耦合。

       契约：
       - Normalize 已在外层完成，本模块只存归一后前缀字符串；
       - 首个同前缀胜（Add 去重，不覆盖），与 CONTRACT §3.4 同长先挂一致；
       - 探测：TryGetByView 零拷贝 view 哈希线性探测 O(1) 平均，
         TryResolveByPath 按 distinctLens 降序枚举最长前缀首命中，
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
         故保留专用线性探测表但哈希/容量/相等/生长全量委托单源，零容器逻辑重复。

       性能：
       - 零拷贝：TStringView 切片零堆分配，TryGetByView 按 view.Data/Len 直算 WyHash32 与
         SpanEqual 直比，单 distinct 零 Copy，热点单挂载仍内联快路径；
       - 容量：VecGrowCapacity(0→4→2×) bytes.ops 单源 inline 倍增，0.75 负载重哈希，零 O(n²)；
       - distinctLens 摊销 O(1) 追加 + 惰性降序快排 O(n log n) 单次，零每插 O(n) 移位，DistinctCount/LensAt inline 惰性排序零额外分配，MountCount = distinct 哈希数，FindBy/TryGet 全 inline。

       稳定性：析构 Finalize 全量串/接口，no leak；inline 薄转零额外调用。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.webview.intf,
  nextpas.core.text.view;

type
  {** 前缀路由索引：单哈希+有序 Lens 独立承载 *}
  TWebviewAssetIndex = class
  private type
    TBucket = record
      State: Byte; // 0 Empty,1 Occupied
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
    { 首个同前缀胜，已存在返回 False 未覆盖 }
    function Add(const APrefix: string; AProvider: IWebviewAssetProvider): Boolean;
    function TryGetByStr(const APrefix: string; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function TryGetByView(const AView: TStringView; out AProvider: IWebviewAssetProvider): Boolean; inline;
    function Count: Integer; inline;
    function DistinctCount: Integer; inline;
    function DistinctLensAt(AIndex: Integer): Integer; inline;
    procedure Clear;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.hash.wyhash,
  nextpas.core.base.utils,
  nextpas.core.collections.hashmap.base,
  nextpas.core.simd.bitops;

constructor TWebviewAssetIndex.Create;
begin
  inherited Create;
end;

destructor TWebviewAssetIndex.Destroy;
begin
  Clear;
  SetLength(FBuckets, 0);
  SetLength(FDistinctLens, 0);
  inherited Destroy;
end;

procedure TWebviewAssetIndex.Clear;
var
  I: SizeUInt;
begin
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
  FMaxLoad := Trunc(FCapacity * 0.75);
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
var
  I, J, P, Tmp: Integer;
  L, R: Integer;
  StackL, StackR: array[0..63] of Integer;
  Sp: Integer;
begin
  if ACount <= 1 then Exit;
  // iterative quicksort descending, O(n log n) avg, O(n²) worst but intro fallback not needed for n<4096
  Sp := 0;
  StackL[0] := 0; StackR[0] := ACount - 1;
  while Sp >= 0 do
  begin
    L := StackL[Sp]; R := StackR[Sp]; Dec(Sp);
    repeat
      I := L; J := R; P := FDistinctLens[(L + R) shr 1];
      repeat
        while FDistinctLens[I] > P do Inc(I);
        while FDistinctLens[J] < P do Dec(J);
        if I <= J then
        begin
          if I <> J then
          begin
            Tmp := FDistinctLens[I];
            FDistinctLens[I] := FDistinctLens[J];
            FDistinctLens[J] := Tmp;
          end;
          Inc(I); Dec(J);
        end;
      until I > J;
      // push larger partition, loop on smaller to bound stack
      if J - L > R - I then
      begin
        if L < J then
        begin
          Inc(Sp);
          StackL[Sp] := L; StackR[Sp] := J;
        end;
        L := I;
      end
      else
      begin
        if I < R then
        begin
          Inc(Sp);
          StackL[Sp] := I; StackR[Sp] := R;
        end;
        R := J;
      end;
    until L >= R;
  end;
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

end.
