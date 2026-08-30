unit nextpas.core.vfs.base;

{** @desc vfs 基座：条目 record、规范路径语法（Go io/fs.ValidPath 对等语义，
  权威文本见 core/docs/respack/FORMAT.md「路径规范」）。路径校验委托
  nextpas.core.base.pathvalid 单一事实源，不再本地重复实现。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base.pathvalid,
  nextpas.core.base.utils,
  nextpas.core.compress.base;

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
  VFS_DECOMPRESS_MAX_BYTES = nextpas.core.compress.base.GZIP_MAX_DECOMPRESS_BYTES;

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;

function VfsIsRoot(const APath: string): Boolean; inline;

{ 零分配前缀判定：APath 是否以 APrefix 开头（空前缀恒真，规避 FPC Pos('',S)=0 陷阱）。
  HasParent：AChild 是否严格位于 AParent 子树下（AParent+'/' 前缀且更长）。 }
function VfsPathHasPrefix(const APath, APrefix: string): Boolean; inline;
function VfsIsParentPath(const AParent, AChild: string): Boolean; inline;

{ 路径字节序比较（'/' 分隔语义下与逐字节一致）；三后端共用同一序定义 }
function VfsNameCompare(const AA, AB: string): Integer; inline;

{ ETag 单源：strong "hexSize-hexModTime" 与 fnv "fnv-hex8"，供 embedded/http 共用
  避免两处字面量漂移；本地十六进制保证大小写/位宽一致，base 保持 L0 纯度（仅 L0 依赖）。 }
function VfsETagStrong(const ASize, AModTime: Int64): string; inline;
function VfsETagFNV(const AHash: UInt32): string; inline;

{ 就地按 Name 字节序升序（INV-V8）；经 collections 单源 Sort（IntroSort+小区间插入） }
procedure VfsSortEntries(var AItems: TEntryArray);

{ 从字节序有序的完整路径清单推导某目录的直接子项完整路径（有序、去重）。
  输入只含文件路径（memtree/respack 均不存目录条目）；ADirPrefix 为
  'dir/' 形式，根传 ''。O(n) 全量扫描：List 非热路径，换取调用方零预处理。 }
function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;

implementation

uses
  nextpas.core.collections.algorithms;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
begin
  Result := BaseValidPath(APath, AAllowRoot);
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

function VfsNameCompare(const AA, AB: string): Integer; inline;
var
  PA, PB: Pointer;
begin
  if Length(AA) = 0 then PA := nil else PA := @AA[1];
  if Length(AB) = 0 then PB := nil else PB := @AB[1];
  Result := CompareBytesOrdered(PA, PB, SizeUInt(Length(AA)), SizeUInt(Length(AB)));
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

function VfsETagStrong(const ASize, AModTime: Int64): string; inline;
begin
  Result := '"' + VfsHex(UInt64(ASize), 16) + '-' + VfsHex(UInt64(AModTime), 16) + '"';
end;

function VfsETagFNV(const AHash: UInt32): string; inline;
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
  I, N, OutN: SizeUInt;
  PathLen, PrefixLen, J: SizeInt;
  SegPos: SizeInt;
  Child: string;
begin
  Result := nil;
  SetLength(Result, SizeUInt(Length(ASortedPaths)));
  OutN := 0;
  N := SizeUInt(Length(ASortedPaths));
  PrefixLen := Length(ADirPrefix);
  I := 0;
  while I < N do
  begin
    PathLen := Length(ASortedPaths[I]);
    { 前缀匹配显式处理空前缀（FPC Pos('',S)=0 陷阱）。
      零分配：前缀比较走 CompareMem 直比首段，避免 Pos 的临时分配。
      全量扫描不提前 Break：调用方可能传未按前缀定位的完整清单 }
    if PathLen <= PrefixLen then
    begin
      Inc(I);
      Continue;
    end;
    if PrefixLen > 0 then
    begin
      if not CompareMem(@ASortedPaths[I][1], @ADirPrefix[1], SizeUInt(PrefixLen)) then
      begin
        Inc(I);
        Continue;
      end;
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
    Inc(I);
  end;
  SetLength(Result, OutN);
end;

end.
