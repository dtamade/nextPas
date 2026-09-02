unit nextpas.core.vfs.base;

{** @desc vfs 基座：条目 record、规范路径语法（Go io/fs.ValidPath 对等语义，
  权威文本见 core/docs/respack/FORMAT.md「路径规范」）。路径校验委托
  nextpas.core.bytes.pathvalid 单一事实源，不再本地重复实现。L2 仅依赖
  L0-L1（bytes.ops/base.utils），解压上限 canonical 寄居
  vfs.compressed（compress.base GZIP_MAX 32MiB），base 以字面量数值对齐
  守 L0 纯度与无 L2→L2，漂移由 source-contract 数值一致性断言锁定。 }

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
  { 数值对齐：与 compress.base GZIP_MAX_DECOMPRESS_BYTES (32MiB) 同值，
    canonical 单源寄居 vfs.compressed；base 以字面量守 L0 纯度与无 L2→L2
    （四件套底座仅 L0-L1），漂移由 source-contract 数值一致性断言锁定。 }
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

{ 路径字节序比较（'/' 分隔语义下与逐字节一致）；三后端共用同一序定义
  复用 bytes.ops 单源 SpanCompare（zero-copy TByteSpan + CompareBytesOrdered），inline。 }
function VfsNameCompare(const AA, AB: string): Integer; inline;

{ ETag 单源：strong "hexSize-hexModTime" 与 fnv "fnv-hex8"，供 embedded/http 共用
  避免两处字面量漂移；本地十六进制保证大小写/位宽一致，base 保持 L0 纯度（仅 L0 依赖）。
  非 inline：保持与前缀/比较族一致的高级感，避免 untyped 参 inline 风险。 }
function VfsETagStrong(const ASize, AModTime: Int64): string;
function VfsETagFNV(const AHash: UInt32): string;

{ 就地按 Name 字节序升序（INV-V8）；经 collections 单源 Sort（IntroSort+小区间插入） }
procedure VfsSortEntries(var AItems: TEntryArray);

{ 已排序去重：单源 Unique（Name 字节序），消除 mount/overlay 手写 dedup 重复 }
procedure VfsDedupSortedEntries(var AItems: TEntryArray);

{ 从字节序有序的完整路径清单推导某目录的直接子项完整路径（有序、去重）。
  输入只含文件路径（memtree/respack 均不存目录条目）；ADirPrefix 为
  'dir/' 形式，根传 ''。O(log n + k) 有序区间扫描：LowerBound 二分定位 +
  前缀连续段 Early-Break（k=子树扇出），零分配 SpanStartsWith 前缀判定，
  Child 去重经 TByteSpan 视图 SpanEqual 零拷贝（仅唯一子项时 Move 物化零 Copy），热路径
  零小堆分配（embedded 零拷贝已收敛，base 基础实现同构 Early-Break）。 }
function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
{ 零拷贝 Span 版本：ASpans 已为有序 TByteSpan（直指 FRp/字符串存储），ADirPrefix 同上；
  与 string 版同模板单源，embedded 零拷贝路径直接复用，无额外 string 落地与并行 Move 维护 }
function VfsDeriveChildNamesFromSpans(const ASpans: array of TByteSpan;
  const ADirPrefix: string): TVfsNameArray;

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

function VfsDeriveChildNamesFromSpans(const ASpans: array of TByteSpan;
  const ADirPrefix: string): TVfsNameArray;
var
  N, OutN, PrefixLen, SegPos, J: SizeInt;
  Lo, Hi, Mid: SizeInt;
  I: SizeInt;
  Cap: SizeInt;
  ChildSpan, PrevSpan: TByteSpan;
  NeedAdd: Boolean;
  PrefixSpan: TByteSpan;
begin
  Result := nil;
  N := Length(ASpans);
  if N = 0 then Exit;
  PrefixLen := Length(ADirPrefix);
  if PrefixLen > 0 then
    PrefixSpan := TByteSpan.Create(PByte(@ADirPrefix[1]), SizeUInt(PrefixLen))
  else
    PrefixSpan := TByteSpan.Empty;
  // 单源模板：LowerBound+SpanStartsWith+Early-Break 零拷贝，扇出限界 16 倍增，Cap≤N-Lo；bytes.ops 单源 inline 热路径
  Lo := 0;
  Hi := N;
  if PrefixLen > 0 then
  begin
    while Lo < Hi do
    begin
      Mid := Lo + (Hi - Lo) div 2;
      if SpanCompare(ASpans[Mid], PrefixSpan) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
  end;
  SetLength(Result, 0);
  OutN := 0;
  for I := Lo to N - 1 do
  begin
    if SizeInt(ASpans[I].Len) <= PrefixLen then Continue;
    if PrefixLen > 0 then
    begin
      if not SpanStartsWith(ASpans[I], PrefixSpan) then
        Break;
    end;
    SegPos := 0;
    for J := PrefixLen to SizeInt(ASpans[I].Len) - 1 do
      if ASpans[I].Data[J] = Ord('/') then
      begin
        SegPos := J + 1;
        Break;
      end;
    if SegPos > 0 then
      ChildSpan := TByteSpan.Create(ASpans[I].Data, SizeUInt(SegPos - 1))
    else
      ChildSpan := ASpans[I];
    if OutN = 0 then
      NeedAdd := True
    else
    begin
      if Length(Result[OutN - 1]) = 0 then PrevSpan := TByteSpan.Empty else PrevSpan := TByteSpan.Create(PByte(@Result[OutN - 1][1]), SizeUInt(Length(Result[OutN - 1])));
      NeedAdd := not SpanEqual(PrevSpan, ChildSpan);
    end;
    if NeedAdd then
    begin
      if OutN >= Length(Result) then
      begin
        Cap := Length(Result);
        if Cap = 0 then Cap := 16;
        while Cap <= OutN do Cap := Cap * 2;
        if Cap > N - Lo then Cap := N - Lo;
        SetLength(Result, Cap);
      end;
      SetLength(Result[OutN], ChildSpan.Len);
      if ChildSpan.Len > 0 then
        Move(ChildSpan.Data^, Result[OutN][1], ChildSpan.Len);
      Inc(OutN);
    end;
  end;
  SetLength(Result, OutN);
end;

function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
var
  N, OutN, PrefixLen, SegPos, J: SizeInt;
  Lo, Hi, Mid: SizeInt;
  I, Cap: SizeInt;
  ChildSpan, PrevSpan, PrefixSpan, CurSpan: TByteSpan;
  NeedAdd: Boolean;
begin
  Result := nil;
  N := Length(ASortedPaths);
  if N = 0 then Exit;
  PrefixLen := Length(ADirPrefix);
  if PrefixLen > 0 then
    PrefixSpan := TByteSpan.Create(PByte(@ADirPrefix[1]), SizeUInt(PrefixLen))
  else
    PrefixSpan := TByteSpan.Empty;
  // 零分配热点消除：不再分配 Spans 数组（原 O(n) 临时分配），按需零拷贝视图 TByteSpan.Create 复用 bytes.ops 单源 inline（SpanCompare/SpanStartsWith/SpanEqual + MemEqual/CompareBytesOrdered），仅结果 TVfsNameArray 按扇出限界 16 倍增分配
  Lo := 0;
  Hi := N;
  if PrefixLen > 0 then
  begin
    while Lo < Hi do
    begin
      Mid := Lo + (Hi - Lo) div 2;
      if Length(ASortedPaths[Mid]) = 0 then CurSpan := TByteSpan.Empty
      else CurSpan := TByteSpan.Create(PByte(@ASortedPaths[Mid][1]), SizeUInt(Length(ASortedPaths[Mid])));
      if SpanCompare(CurSpan, PrefixSpan) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
  end;
  SetLength(Result, 0);
  OutN := 0;
  for I := Lo to N - 1 do
  begin
    if Length(ASortedPaths[I]) = 0 then CurSpan := TByteSpan.Empty
    else CurSpan := TByteSpan.Create(PByte(@ASortedPaths[I][1]), SizeUInt(Length(ASortedPaths[I])));
    if SizeInt(CurSpan.Len) <= PrefixLen then Continue;
    if PrefixLen > 0 then
    begin
      if not SpanStartsWith(CurSpan, PrefixSpan) then
        Break;
    end;
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
    if OutN = 0 then
      NeedAdd := True
    else
    begin
      if Length(Result[OutN - 1]) = 0 then PrevSpan := TByteSpan.Empty else PrevSpan := TByteSpan.Create(PByte(@Result[OutN - 1][1]), SizeUInt(Length(Result[OutN - 1])));
      NeedAdd := not SpanEqual(PrevSpan, ChildSpan);
    end;
    if NeedAdd then
    begin
      if OutN >= Length(Result) then
      begin
        Cap := Length(Result);
        if Cap = 0 then Cap := 16;
        while Cap <= OutN do Cap := Cap * 2;
        if Cap > N - Lo then Cap := N - Lo;
        SetLength(Result, Cap);
      end;
      SetLength(Result[OutN], ChildSpan.Len);
      if ChildSpan.Len > 0 then
        Move(ChildSpan.Data^, Result[OutN][1], ChildSpan.Len);
      Inc(OutN);
    end;
  end;
  SetLength(Result, OutN);
end;

end.
