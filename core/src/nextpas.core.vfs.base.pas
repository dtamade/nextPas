unit nextpas.core.vfs.base;

{** @desc vfs 基座：TEntryInfo/TStatInfo 与路径语法（ValidPath 单源 bytes.pathvalid）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.pathvalid,
  nextpas.core.bytes.ops,
  nextpas.core.base.utils,
  nextpas.core.compress.base,
  nextpas.core.text.view;

type
  TEntryInfo = record
    Name: string;      { 规范虚拟路径；根目录为 '.' }
    Size: Int64;
    ModTime: Int64;    { Unix 秒；0 = 未知 }
    IsDir: Boolean;
  end;

  TEntryArray = array of TEntryInfo;

  TStatInfo = record
    Info: TEntryInfo;
    ContentHash: UInt32;   { FNV-1a 32；0 = 后端未提供 }
  end;

  TVfsNameArray = array of string;

const
  { 单源 compress.base GZIP_MAX (32MiB) canonical via alias，无字面量漂移。 }
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES;

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;

function VfsIsRoot(const APath: string): Boolean; inline;
function VfsIsRootView(const AView: TStringView): Boolean; inline;

function VfsSpanFromString(const S: string): TByteSpan; inline;

{ 零分配前缀判定：APath 是否以 APrefix 开头（空前缀恒真，规避 FPC Pos('',S)=0 陷阱）。
  HasParent：AChild 是否严格位于 AParent 子树下（AParent+'/' 前缀且更长）。
  单源收口 bytes.ops SpanStartsWith（零拷贝 TByteSpan + MemEqual），inline 热路径。 }
function VfsPathHasPrefix(const APath, APrefix: string): Boolean; inline;
function VfsIsParentPath(const AParent, AChild: string): Boolean; inline;

{ 路径字节序比较：三后端共用同一序定义（bytes.ops 单源，见上）。 }
function VfsNameCompare(const AA, AB: string): Integer; inline;
{ 零拷贝视图比较：单源 bytes.ops CompareBytesOrdered，inline 零额外调用，TStringView 零堆分配 }
function VfsNameCompareView(const AView: TStringView; const AB: string): Integer; inline;
function VfsNameCompareViews(const AA, AB: TStringView): Integer; inline;
function VfsValidPathView(const AView: TStringView; const AAllowRoot: Boolean): Boolean; inline;
function VfsPathHasPrefixView(const AView: TStringView; const APrefix: string): Boolean; inline;

{ ETag 单源：strong "hexSize-hexModTime" 与 fnv "fnv-hex8"，供 embedded/http 共用
  避免两处字面量漂移；bytes.ops BytesHexUInt64 单源 inline 零拷贝 HEX_UPPER 保证大小写/位宽一致，base 保持 L0 纯度。
  非 inline 权衡：前缀/比较族已 inline（见上），ETag 含堆分配主导开销不 inline 以稳尺寸。 }
function VfsETagStrong(const ASize, AModTime: Int64): string;
function VfsETagFNV(const AHash: UInt32): string;

{ 就地按 Name 字节序升序（INV-V8）；经 collections 单源 Sort（IntroSort+小区间插入） }
procedure VfsSortEntries(var AItems: TEntryArray);

{ 已排序去重：单源 Unique（Name 字节序），消除 mount/overlay 手写 dedup 重复 }
procedure VfsDedupSortedEntries(var AItems: TEntryArray);

{ 从字节序有序的完整路径清单推导某目录的直接子项完整路径（有序、去重）。
  输入只含文件路径；ADirPrefix 为 'dir/' 形式，根传 ''。O(log n + k) 有序区间扫描。
  单源 VfsEnumerateChildSpans，VfsDeriveChildNames* 为适配薄壳。 }
function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
{ 零拷贝 Span 版本：ASpans 有序直指存储，ADirPrefix 同上；单源 VfsEnumerateChildSpans。 }
function VfsDeriveChildNamesFromSpans(const ASpans: array of TByteSpan;
  const ADirPrefix: string): TVfsNameArray;

{ 有序区间扫描通用模板：供 memtree/embedded List 复用，VfsDerive* 经同一单源委托，资源释放不丢。 }
type
  TVfsSpanGetter = function(AIdx: SizeInt; AUserData: Pointer): TByteSpan;
  TVfsChildHandler = procedure(const AChildSpan: TByteSpan; const AFullSpan: TByteSpan;
    ASourceIdx: SizeInt; AUserData: Pointer);
procedure VfsEnumerateChildSpans(const ACount: SizeInt; AGetter: TVfsSpanGetter;
  AGetterData: Pointer; const ADirPrefix: string; AHandler: TVfsChildHandler;
  AHandlerData: Pointer);

implementation

uses
  nextpas.core.collections.algorithms;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
begin
  Result := BytesValidPath(APath, AAllowRoot);
end;

function VfsValidPathView(const AView: TStringView; const AAllowRoot: Boolean): Boolean; inline;
begin
  Result := BytesValidPathView(AView, AAllowRoot);
end;

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := APath = '.';
end;

function VfsIsRootView(const AView: TStringView): Boolean; inline;
begin
  Result := (AView.Len = 1) and (AView.Data[0] = '.');
end;

{ 单源 FromString 助手：收口三处手写空串判空+TByteSpan.Create，inline 零拷贝 via TByteSpan.FromStr。 }
function VfsSpanFromString(const S: string): TByteSpan; inline;
begin
  Result := TByteSpan.FromStr(S);
end;

function VfsPathHasPrefix(const APath, APrefix: string): Boolean; inline;
var
  SPath, SPrefix: TByteSpan;
begin
  if Length(APrefix) = 0 then Exit(True);
  if Length(APath) < Length(APrefix) then Exit(False);
  SPath := VfsSpanFromString(APath); // 单源 FromString 零拷贝 inline
  SPrefix := VfsSpanFromString(APrefix);
  Result := SpanStartsWith(SPath, SPrefix);
end;

function VfsIsParentPath(const AParent, AChild: string): Boolean; inline;
var
  SChild, SParent: TByteSpan;
begin
  if Length(AChild) <= Length(AParent) then Exit(False);
  if AChild[Length(AParent) + 1] <> '/' then Exit(False);
  if Length(AParent) = 0 then Exit(True);
  SChild := VfsSpanFromString(AChild); // 单源 FromString 零拷贝
  SParent := VfsSpanFromString(AParent);
  Result := SpanStartsWith(SChild, SParent);
end;

function VfsNameCompare(const AA, AB: string): Integer; inline;
var
  SA, SB: TByteSpan;
begin
  SA := VfsSpanFromString(AA); // 单源 FromString 零拷贝
  SB := VfsSpanFromString(AB);
  Result := SpanCompare(SA, SB);
end;

function VfsNameCompareView(const AView: TStringView; const AB: string): Integer; inline;
var
  PB: Pointer;
begin
  if Length(AB) = 0 then PB := nil else PB := @AB[1];
  Result := CompareBytesOrdered(Pointer(AView.Data), PB, AView.Len, SizeUInt(Length(AB)));
end;

function VfsNameCompareViews(const AA, AB: TStringView): Integer; inline;
begin
  Result := CompareBytesOrdered(Pointer(AA.Data), Pointer(AB.Data), AA.Len, AB.Len);
end;

function VfsPathHasPrefixView(const AView: TStringView; const APrefix: string): Boolean; inline;
begin
  if Length(APrefix) = 0 then Exit(True);
  if AView.Len < SizeUInt(Length(APrefix)) then Exit(False);
  Result := CompareMem(AView.Data, @APrefix[1], SizeUInt(Length(APrefix)));
end;

const
  HEX_DIGITS: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

function VfsHex(const AValue: UInt64; const ADigits: Integer): string; inline;
var
  I: Integer;
  V: UInt64;
const
  HEX: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
begin
  SetLength(Result, ADigits);
  V := AValue;
  for I := ADigits downto 1 do
  begin
    Result[I] := HEX[V and $F];
    V := V shr 4;
  end;
end;

function VfsETagStrong(const ASize, AModTime: Int64): string;
begin
  Result := '"' + VfsHex(UInt64(ASize), 16) + '-' + VfsHex(UInt64(AModTime), 16) + '"';
end;

function VfsETagFNV(const AHash: UInt32): string;
begin
  Result := '"fnv-' + VfsHex(UInt64(AHash), 8) + '"';
end;

{ 排序收口至 collections 单源：复用 nextpas.core.collections.algorithms.Sort，
  消除与 memtree/respack 三处同构 QuickSort 重复；SizeInt 天然防回绕。 }
function CompareEntryInfo(const A, B: TEntryInfo; Data: Pointer): SizeInt;
begin
  Result := VfsNameCompare(A.Name, B.Name);
end;

{ Name-only 比较：供 Unique 去重单源（零拷贝 SpanCompare），与 Sort 同序 }
function VfsCompareEntryName(const A, B: TEntryInfo; Data: Pointer): SizeInt; inline;
begin
  Result := VfsNameCompare(A.Name, B.Name);
end;

procedure VfsSortEntries(var AItems: TEntryArray);
begin
  if Length(AItems) > 1 then
    specialize Sort<TEntryInfo>(AItems, @CompareEntryInfo, nil);
end;

{ 已排序去重：单源 Unique（Name 字节序），消除 mount/overlay 手写 dedup 重复 }
procedure VfsDedupSortedEntries(var AItems: TEntryArray);
var
  L: SizeInt;
begin
  if Length(AItems) <= 1 then Exit;
  L := specialize Unique<TEntryInfo>(AItems, @VfsCompareEntryName, nil);
  SetLength(AItems, L);
end;

type
  PStrArray = ^TStrArray;
  TStrArray = array[0..(MaxInt div SizeOf(string)) - 1] of string;
  PSpanArray = ^TSpanArray;
  TSpanArray = array[0..(MaxInt div SizeOf(TByteSpan)) - 1] of TByteSpan;
  PDeriveCollectCtx = ^TDeriveCollectCtx;
  TDeriveCollectCtx = record
    ResultPtr: ^TVfsNameArray;
    OutN: SizeInt;
    N: SizeInt;
  end;
  { 统一 Span 视图工厂：单一 getter 经 Kind 分发，收口双适配层，零拷贝 inline }
  TDeriveSrcKind = (dskSpans, dskStrs);
  PDeriveSrc = ^TDeriveSrc;
  TDeriveSrc = record
    Kind: TDeriveSrcKind;
    Spans: PSpanArray;
    Strs: PStrArray;
  end;

function DeriveGetterUnified(AIdx: SizeInt; AUserData: Pointer): TByteSpan; inline;
var
  Src: PDeriveSrc;
  PS: ^string;
begin
  Src := PDeriveSrc(AUserData);
  if Src^.Kind = dskSpans then
    Result := Src^.Spans^[AIdx]
  else
  begin
    PS := @Src^.Strs^[AIdx];
    Result := VfsSpanFromString(PS^); { 单源 FromString 复用 }
  end;
end;

procedure DeriveCollectHandler(const AChildSpan: TByteSpan; const AFullSpan: TByteSpan;
  ASourceIdx: SizeInt; AUserData: Pointer); inline;
var
  Ctx: PDeriveCollectCtx;
  Cap: SizeInt;
  Res: ^TVfsNameArray;
begin
  Ctx := PDeriveCollectCtx(AUserData);
  Res := Ctx^.ResultPtr;
  if Ctx^.OutN >= Length(Res^) then
  begin
    Cap := SizeInt(BytesNextCapacity(SizeUInt(Length(Res^)), SizeUInt(Ctx^.OutN + 1)));
    if Cap > Ctx^.N then Cap := Ctx^.N;
    SetLength(Res^, Cap);
  end;
  Res^[Ctx^.OutN] := SpanToString(AChildSpan); { bytes.ops 单源 inline 零拷贝视图+单 Move 物化，批量池化外层 BytesNextCapacity }
  Inc(Ctx^.OutN);
end;

{ 零堆 Successor 判定：Succ = prefix[1..len-1]+'0'，inline 字节序比较免 Copy/Chr 堆分配，热点重复 List 零 GC。 }
function SpanLessThanSuccessor(const ACur: TByteSpan; const APrefix: string; APrefixLen: SizeInt): Boolean; inline;
var P: PByte; I: SizeInt; SuccB: Byte;
begin
  if ACur.Len = 0 then Exit(True);
  P := PByte(@APrefix[1]);
  if SizeInt(ACur.Len) < APrefixLen then
  begin
    for I := 0 to SizeInt(ACur.Len) - 1 do
    begin
      if I = APrefixLen - 1 then SuccB := Byte(Ord('/') + 1) else SuccB := P[I];
      if ACur.Data[I] < SuccB then Exit(True);
      if ACur.Data[I] > SuccB then Exit(False);
    end;
    Exit(True);
  end
  else
  begin
    for I := 0 to APrefixLen - 1 do
    begin
      if I = APrefixLen - 1 then SuccB := Byte(Ord('/') + 1) else SuccB := P[I];
      if ACur.Data[I] < SuccB then Exit(True);
      if ACur.Data[I] > SuccB then Exit(False);
    end;
    Exit(False);
  end;
end;

{ 单源：LowerBound + UpperBound + '/' 分段 + 去重；O(log n + k) 有序区间，资源释放不丢。 }
procedure VfsEnumerateChildSpans(const ACount: SizeInt; AGetter: TVfsSpanGetter;
  AGetterData: Pointer; const ADirPrefix: string; AHandler: TVfsChildHandler;
  AHandlerData: Pointer);
var
  PrefixLen, Lo, Hi, Mid, I, SegPos, J: SizeInt;
  PrefixSpan, CurSpan, ChildSpan, PrevSpan: TByteSpan;
  UpperLo, UpperHi: SizeInt;
  IsFirst: Boolean;
begin
  if ACount <= 0 then Exit;
  if not Assigned(AGetter) or not Assigned(AHandler) then Exit;
  PrefixLen := Length(ADirPrefix);
  PrefixSpan := VfsSpanFromString(ADirPrefix); { 单源 FromString 零拷贝 inline }
  Lo := 0;
  Hi := ACount;
  if PrefixLen > 0 then
  begin
    while Lo < Hi do
    begin
      Mid := Lo + (Hi - Lo) div 2;
      CurSpan := AGetter(Mid, AGetterData);
      if SpanCompare(CurSpan, PrefixSpan) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
    // 上界截断：succ = prefix[1..len-1]+'0'，零堆 inline 比较免 Copy/Chr 堆分配，热点 List 零 GC
    UpperLo := Lo;
    UpperHi := ACount;
    while UpperLo < UpperHi do
    begin
      Mid := UpperLo + (UpperHi - UpperLo) div 2;
      CurSpan := AGetter(Mid, AGetterData);
      if SpanLessThanSuccessor(CurSpan, ADirPrefix, PrefixLen) then
        UpperLo := Mid + 1
      else
        UpperHi := Mid;
    end;
    Hi := UpperLo;
  end;
  IsFirst := True;
  PrevSpan := TByteSpan.Empty;
  for I := Lo to Hi - 1 do
  begin
    CurSpan := AGetter(I, AGetterData);
    if SizeInt(CurSpan.Len) <= PrefixLen then Continue;
    if PrefixLen > 0 then
      if not SpanStartsWith(CurSpan, PrefixSpan) then Continue;
    SegPos := 0;
    for J := PrefixLen to SizeInt(CurSpan.Len) - 1 do
      if CurSpan.Data[J] = Ord('/') then
      begin
        SegPos := J + 1;
        Break;
      end;
    if SegPos > 0 then
      ChildSpan := TByteSpan.Create(CurSpan.Data, SizeUInt(SegPos - 1))
    else
      ChildSpan := CurSpan;
    if not IsFirst then
      if SpanEqual(PrevSpan, ChildSpan) then Continue;
    AHandler(ChildSpan, CurSpan, I, AHandlerData);
    PrevSpan := ChildSpan;
    IsFirst := False;
  end;
end;

function VfsDeriveChildNamesFromSpans(const ASpans: array of TByteSpan;
  const ADirPrefix: string): TVfsNameArray;
var
  Ctx: TDeriveCollectCtx;
  Src: TDeriveSrc;
begin
  Result := nil;
  if Length(ASpans) = 0 then Exit;
  Ctx.ResultPtr := @Result;
  Ctx.OutN := 0;
  Ctx.N := Length(ASpans);
  SetLength(Result, 0);
  Src.Kind := dskSpans;
  Src.Spans := PSpanArray(@ASpans[0]);
  Src.Strs := nil;
  VfsEnumerateChildSpans(Ctx.N, @DeriveGetterUnified, @Src, ADirPrefix, @DeriveCollectHandler, @Ctx);
  SetLength(Result, Ctx.OutN);
end;

function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
var
  Ctx: TDeriveCollectCtx;
  Src: TDeriveSrc;
begin
  Result := nil;
  if Length(ASortedPaths) = 0 then Exit;
  Ctx.ResultPtr := @Result;
  Ctx.OutN := 0;
  Ctx.N := Length(ASortedPaths);
  SetLength(Result, 0);
  Src.Kind := dskStrs;
  Src.Strs := PStrArray(@ASortedPaths[0]);
  Src.Spans := nil;
  VfsEnumerateChildSpans(Ctx.N, @DeriveGetterUnified, @Src, ADirPrefix, @DeriveCollectHandler, @Ctx);
  SetLength(Result, Ctx.OutN);
end;

end.
