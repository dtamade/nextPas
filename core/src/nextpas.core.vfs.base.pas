unit nextpas.core.vfs.base;

{** @desc vfs 基座：条目 record、规范路径语法（Go io/fs.ValidPath 对等语义，
  权威文本见 core/docs/respack/FORMAT.md「路径规范」）。路径校验委托
  nextpas.core.bytes.pathvalid 单一事实源，不再本地重复实现。L2 仅依赖
  L0-L1（bytes.ops/base.utils 零拷贝单源），解压上限单源收敛于
  vfs.compressed/vfs.transform (GZIP_MAX 32MiB)，base 仅字面量薄别名避 L2→L2。 }

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
  { 32 MiB 薄别名：canonical 单源 nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES
    经 vfs.compressed/vfs.transform 承载，base 保留字面量以守 L2→L1 依赖纪律，禁 L2→L2。 }
  VFS_DECOMPRESS_MAX_BYTES = 32 * 1024 * 1024;

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;

function VfsIsRoot(const APath: string): Boolean; inline;

{ 零分配前缀判定：APath 是否以 APrefix 开头（空前缀恒真，规避 FPC Pos('',S)=0 陷阱）。
  HasParent：AChild 是否严格位于 AParent 子树下（AParent+'/' 前缀且更长）。
  非 inline：向 CompareMem/CompareBytesOrdered 喂 @S[1] 时禁 inline（FPC 字面量传播陷阱）。 }
function VfsPathHasPrefix(const APath, APrefix: string): Boolean;
function VfsIsParentPath(const AParent, AChild: string): Boolean;

{ 路径字节序比较（'/' 分隔语义下与逐字节一致）；三后端共用同一序定义
  复用 bytes.ops 单源 SpanCompare（zero-copy TByteSpan + CompareBytesOrdered），非 inline 避 @S[1] 陷阱。 }
function VfsNameCompare(const AA, AB: string): Integer;

{ ETag 单源：strong "hexSize-hexModTime" 与 fnv "fnv-hex8"，供 embedded/http 共用
  避免两处字面量漂移；本地十六进制保证大小写/位宽一致，base 保持 L0 纯度（仅 L0 依赖）。
  非 inline：保持与前缀/比较族一致的高级感，避免 untyped 参 inline 风险。 }
function VfsETagStrong(const ASize, AModTime: Int64): string;
function VfsETagFNV(const AHash: UInt32): string;

{ 就地按 Name 字节序升序（INV-V8）；经 collections 单源 Sort（IntroSort+小区间插入） }
procedure VfsSortEntries(var AItems: TEntryArray);

{ 从字节序有序的完整路径清单推导某目录的直接子项完整路径（有序、去重）。
  输入只含文件路径（memtree/respack 均不存目录条目）；ADirPrefix 为
  'dir/' 形式，根传 ''。O(log n + k) 有序区间扫描：LowerBound 二分定位 +
  前缀连续段 Early-Break（k=子树扇出），零分配 CompareMem 前缀判定，热路径
  友好（embedded 零拷贝已收敛，base 基础实现同构 Early-Break，规模化无 O(n) 张力）。 }
function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;

implementation

uses
  nextpas.core.collections.algorithms;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
begin
  Result := BytesValidPath(APath, AAllowRoot);
end;

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := APath = '.';
end;

function VfsPathHasPrefix(const APath, APrefix: string): Boolean;
begin
  if Length(APrefix) = 0 then Exit(True);
  if Length(APath) < Length(APrefix) then Exit(False);
  Result := CompareMem(@APath[1], @APrefix[1], SizeUInt(Length(APrefix)));
end;

function VfsIsParentPath(const AParent, AChild: string): Boolean;
begin
  if Length(AChild) <= Length(AParent) then Exit(False);
  if AChild[Length(AParent) + 1] <> '/' then Exit(False);
  if Length(AParent) = 0 then Exit(True);
  Result := CompareMem(@AChild[1], @AParent[1], SizeUInt(Length(AParent)));
end;

function VfsNameCompare(const AA, AB: string): Integer;
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

procedure VfsSortEntries(var AItems: TEntryArray);
begin
  if Length(AItems) > 1 then
    specialize Sort<TEntryInfo>(AItems, @CompareEntryInfo, nil);
end;

function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
var
  N, OutN, PrefixLen, PathLen, SegPos, J: SizeInt;
  Lo, Hi, Mid: SizeInt;
  I: SizeInt;
  Child: string;
begin
  Result := nil;
  N := Length(ASortedPaths);
  if N = 0 then Exit;
  PrefixLen := Length(ADirPrefix);
  { 有序区间定位：LowerBound 将全量 O(n) 收敛至 O(log n + k)，大目录亦 Early-Break
    前缀判定零分配：CompareMem 直比首段，规避 Pos 分配；失配即 Break（有序连续段）。 }
  Lo := 0;
  Hi := N;
  if PrefixLen > 0 then
  begin
    while Lo < Hi do
    begin
      Mid := Lo + (Hi - Lo) div 2;
      if VfsNameCompare(ASortedPaths[Mid], ADirPrefix) < 0 then
        Lo := Mid + 1
      else
        Hi := Mid;
    end;
  end;
  SetLength(Result, N - Lo);
  OutN := 0;
  for I := Lo to N - 1 do
  begin
    PathLen := Length(ASortedPaths[I]);
    if PathLen <= PrefixLen then Continue;
    if PrefixLen > 0 then
    begin
      if not CompareMem(@ASortedPaths[I][1], @ADirPrefix[1], SizeUInt(PrefixLen)) then
        Break;
    end;
    { 尾段 '/' 扫描零分配：直接在原串后缀区间线性扫描，省去 Tail:=Copy 的每项堆分配 }
    SegPos := 0;
    for J := PrefixLen + 1 to PathLen do
      if ASortedPaths[I][J] = '/' then
      begin
        SegPos := J;
        Break;
      end;
    if SegPos > 0 then
      Child := Copy(ASortedPaths[I], 1, SegPos - 1)
    else
      Child := ASortedPaths[I];
    if (OutN = 0) or (Result[OutN - 1] <> Child) then
    begin
      Result[OutN] := Child;
      Inc(OutN);
    end;
  end;
  SetLength(Result, OutN);
end;

end.
