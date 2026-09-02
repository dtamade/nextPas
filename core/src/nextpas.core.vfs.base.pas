unit nextpas.core.vfs.base;

{** @desc vfs 基座：TEntryInfo/TStatInfo 与路径语法（ValidPath 单源 bytes.pathvalid）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.pathvalid,
  nextpas.core.bytes.ops,
  nextpas.core.base.utils;

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
  { 单源对齐 compress.base GZIP_MAX (32MiB)，base 唯一字面量。 }
  VFS_DECOMPRESS_MAX_BYTES = 32 * 1024 * 1024;

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;

function VfsIsRoot(const APath: string): Boolean; inline;

{ 零分配前缀判定：APath 是否以 APrefix 开头（空前缀恒真，规避 FPC Pos('',S)=0 陷阱）。
  HasParent：AChild 是否严格位于 AParent 子树下（AParent+'/' 前缀且更长）。
  单源收口 bytes.ops SpanStartsWith（零拷贝 TByteSpan + MemEqual），inline 热路径。 }
function VfsPathHasPrefix(const APath, APrefix: string): Boolean; inline;
function VfsIsParentPath(const AParent, AChild: string): Boolean; inline;

{ 路径字节序比较：三后端共用同一序定义（bytes.ops 单源，见上）。 }
function VfsNameCompare(const AA, AB: string): Integer; inline;

{ ETag 单源：strong "hexSize-hexModTime" 与 fnv "fnv-hex8"，供 embedded/http 共用
  避免两处字面量漂移；本地十六进制保证大小写/位宽一致，base 保持 L0 纯度。
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

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := APath = '.';
end;

function VfsPathHasPrefix(const APath, APrefix: string): Boolean; inline;
var
  SPath, SPrefix: TByteSpan;
begin
  if Length(APrefix) = 0 then Exit(True);
  if Length(APath) < Length(APrefix) then Exit(False);
  // 零拷贝视图：TByteSpan 直指 string 存储，无 Copy；单源 SpanStartsWith → MemEqual
  if Length(APath) = 0 then SPath := TByteSpan.Empty else SPath := TByteSpan.Create(PByte(@APath[1]), SizeUInt(Length(APath)));
  if Length(APrefix) = 0 then SPrefix := TByteSpan.Empty else SPrefix := TByteSpan.Create(PByte(@APrefix[1]), SizeUInt(Length(APrefix)));
  Result := SpanStartsWith(SPath, SPrefix);
end;

function VfsIsParentPath(const AParent, AChild: string): Boolean; inline;
var
  SChild, SParent: TByteSpan;
begin
  if Length(AChild) <= Length(AParent) then Exit(False);
  if AChild[Length(AParent) + 1] <> '/' then Exit(False);
  if Length(AParent) = 0 then Exit(True);
  // 单源 SpanStartsWith 零拷贝前缀判定，替代 CompareMem 双路径
  if Length(AChild) = 0 then SChild := TByteSpan.Empty else SChild := TByteSpan.Create(PByte(@AChild[1]), SizeUInt(Length(AChild)));
  if Length(AParent) = 0 then SParent := TByteSpan.Empty else SParent := TByteSpan.Create(PByte(@AParent[1]), SizeUInt(Length(AParent)));
  Result := SpanStartsWith(SChild, SParent);
end;

function VfsNameCompare(const AA, AB: string): Integer; inline;
var
  SA, SB: TByteSpan;
begin
  if Length(AA) = 0 then SA := TByteSpan.Empty else SA := TByteSpan.Create(PByte(@AA[1]), SizeUInt(Length(AA)));
  if Length(AB) = 0 then SB := TByteSpan.Empty else SB := TByteSpan.Create(PByte(@AB[1]), SizeUInt(Length(AB)));
  Result := SpanCompare(SA, SB);
end;

const
  HEX_DIGITS: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

function VfsHex(const AValue: UInt64; const ADigits: Integer): string; inline;
var
  I: Integer;
  V: UInt64;
begin
  SetLength(Result, ADigits);
  V := AValue;
  for I := ADigits - 1 downto 0 do
  begin
    Result[I + 1] := HEX_DIGITS[V and $F];
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
    if Length(PS^) = 0 then Result := TByteSpan.Empty
    else Result := TByteSpan.Create(PByte(@PS^[1]), SizeUInt(Length(PS^)));
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

{ 单源：LowerBound + UpperBound + '/' 分段 + 去重；O(log n + k) 有序区间，资源释放不丢。 }
procedure VfsEnumerateChildSpans(const ACount: SizeInt; AGetter: TVfsSpanGetter;
  AGetterData: Pointer; const ADirPrefix: string; AHandler: TVfsChildHandler;
  AHandlerData: Pointer);
var
  PrefixLen, Lo, Hi, Mid, I, SegPos, J: SizeInt;
  PrefixSpan, UpperSpan, CurSpan, ChildSpan, PrevSpan: TByteSpan;
  Successor: string;
  UpperLo, UpperHi: SizeInt;
  IsFirst: Boolean;
begin
  if ACount <= 0 then Exit;
  if not Assigned(AGetter) or not Assigned(AHandler) then Exit;
  PrefixLen := Length(ADirPrefix);
  if PrefixLen > 0 then
    PrefixSpan := TByteSpan.Create(PByte(@ADirPrefix[1]), SizeUInt(PrefixLen))
  else
    PrefixSpan := TByteSpan.Empty;
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
    // 上界截断：prefix 以 '/' 结尾，successor 将 '/' 递增为 '0'，区间 [Lo, HiUpper) 即 prefix 子树
    Successor := Copy(ADirPrefix, 1, PrefixLen - 1) + Chr(Ord('/') + 1);
    if Length(Successor) > 0 then
      UpperSpan := TByteSpan.Create(PByte(@Successor[1]), SizeUInt(Length(Successor)))
    else
      UpperSpan := TByteSpan.Empty;
    UpperLo := Lo;
    UpperHi := ACount;
    while UpperLo < UpperHi do
    begin
      Mid := UpperLo + (UpperHi - UpperLo) div 2;
      CurSpan := AGetter(Mid, AGetterData);
      if SpanCompare(CurSpan, UpperSpan) < 0 then
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
