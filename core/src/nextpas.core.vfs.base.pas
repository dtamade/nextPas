unit nextpas.core.vfs.base;

{** @desc vfs 基座：条目 record、规范路径语法（Go io/fs.ValidPath 对等语义，
  权威文本见 core/docs/respack/FORMAT.md「路径规范」）。UTF-8 校验为本地实现——
  本模块仅依赖 L0，与 respack.base 的同名实现属文档化重复，待 L1 收敛点合并。 }

{$I nextpas.core.settings.inc}

interface

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

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;

function VfsIsRoot(const APath: string): Boolean; inline;

{ 路径字节序比较（'/' 分隔语义下与逐字节一致）；三后端共用同一序定义 }
function VfsNameCompare(const AA, AB: string): Integer;

{ 就地按 Name 字节序升序（INV-V8）；quick(Int64 下标)+小区间插入混合排序 }
procedure VfsSortEntries(var AItems: TEntryArray);

{ 从字节序有序的完整路径清单推导某目录的直接子项完整路径（有序、去重）。
  输入只含文件路径（memtree/respack 均不存目录条目）；ADirPrefix 为
  'dir/' 形式，根传 ''。O(n) 全量扫描：List 非热路径，换取调用方零预处理。 }
function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;

implementation

function VfsUtf8Valid(const S: string): Boolean;
var
  I, N, Need: Integer;
  B, K: Byte;
begin
  Result := False;
  N := Length(S);
  if N = 0 then
    Exit(True);
  I := 1;
  while I <= N do
  begin
    B := Byte(S[I]);
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end
    else if (B and $E0) = $C0 then
    begin
      Need := 1;
      if (B and $1E) = 0 then Exit(False);
    end
    else if (B and $F0) = $E0 then
      Need := 2
    else if (B and $F8) = $F0 then
      Need := 3
    else
      Exit(False);
    if B > $F4 then Exit(False);
    if I + Need > N then
      Exit(False);
    for K := 1 to Need do
      if (Byte(S[I + K]) and $C0) <> $80 then
        Exit(False);
    if (Need = 2) and (B = $E0) and (Byte(S[I + 1]) < $A0) then
      Exit(False);
    if (Need = 3) and ((B = $F0) and (Byte(S[I + 1]) < $90)) then
      Exit(False);
    if (Need = 3) and (B = $F4) and (Byte(S[I + 1]) >= $90) then
      Exit(False);
    Inc(I, Need + 1);
  end;
  Result := True;
end;

function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
var
  Start, I, N: Integer;
  Seg: string;
begin
  Result := False;
  if not VfsUtf8Valid(APath) then
    Exit;
  if APath = '.' then
    Exit(AAllowRoot);
  if Length(APath) = 0 then
    Exit;
  if (APath[1] = '/') or (APath[Length(APath)] = '/') then
    Exit;
  N := Length(APath);
  Start := 1;
  for I := 1 to N + 1 do
  begin
    if (I > N) or (APath[I] = '/') then
    begin
      Seg := Copy(APath, Start, I - Start);
      if (Seg = '') or (Seg = '.') or (Seg = '..') then
        Exit;
      Start := I + 1;
    end;
  end;
  Result := True;
end;

function VfsIsRoot(const APath: string): Boolean;
begin
  Result := APath = '.';
end;

function VfsNameCompare(const AA, AB: string): Integer;
var
  I, N: Integer;
begin
  N := Length(AA);
  if Length(AB) < N then
    N := Length(AB);
  for I := 1 to N do
  begin
    if Byte(AA[I]) < Byte(AB[I]) then Exit(-1);
    if Byte(AA[I]) > Byte(AB[I]) then Exit(1);
  end;
  if Length(AA) < Length(AB) then Exit(-1);
  if Length(AA) > Length(AB) then Exit(1);
  Result := 0;
end;

{ 排序下标一律 Int64：Hoare 分区边界在无符号类型上会回绕（S1/S2 实测陷阱，
  见 respack README「实现期发现的 FPC trunk 注意事项」）。 }
procedure VfsQuickSortEntries(var AItems: array of TEntryInfo;
  ALow, AHigh: Int64);
var
  L, R: Int64;
  PivotName: string;
  Tmp, Key: TEntryInfo;
begin
  while ALow < AHigh do
  begin
    if AHigh - ALow < 16 then
    begin
      { 小区间插入排序：稳定、无递归 }
      L := ALow + 1;
      while L <= AHigh do
      begin
        Key := AItems[L];
        R := L - 1;
        while (R >= ALow) and (VfsNameCompare(AItems[R].Name, Key.Name) > 0) do
        begin
          AItems[R + 1] := AItems[R];
          Dec(R);
        end;
        AItems[R + 1] := Key;
        Inc(L);
      end;
      Exit;
    end;
    PivotName := AItems[(ALow + AHigh) shr 1].Name;
    L := ALow;
    R := AHigh;
    while L <= R do
    begin
      while VfsNameCompare(AItems[L].Name, PivotName) < 0 do Inc(L);
      while VfsNameCompare(AItems[R].Name, PivotName) > 0 do Dec(R);
      if L <= R then
      begin
        if L < R then
        begin
          Tmp := AItems[L];
          AItems[L] := AItems[R];
          AItems[R] := Tmp;
        end;
        Inc(L);
        Dec(R);
      end;
    end;
    if ALow < R then
      VfsQuickSortEntries(AItems, ALow, R);
    ALow := L;
  end;
end;

procedure VfsSortEntries(var AItems: TEntryArray);
begin
  if SizeUInt(Length(AItems)) > 1 then
    VfsQuickSortEntries(AItems, 0, Int64(Length(AItems)) - 1);
end;

function VfsDeriveChildNames(const ASortedPaths: array of string;
  const ADirPrefix: string): TVfsNameArray;
var
  I, N, OutN: SizeUInt;
  Tail: string;
  SegEnd: SizeInt;
  Child: string;
begin
  Result := nil;
  SetLength(Result, SizeUInt(Length(ASortedPaths)));
  OutN := 0;
  N := SizeUInt(Length(ASortedPaths));
  I := 0;
  while I < N do
  begin
    { 前缀匹配显式处理空前缀（FPC Pos('',S)=0 陷阱）。
      全量扫描不提前 Break：调用方可能传未按前缀定位的完整清单 }
    if Length(ASortedPaths[I]) <= Length(ADirPrefix) then
    begin
      Inc(I);
      Continue;
    end;
    if (Length(ADirPrefix) > 0)
      and (Pos(ADirPrefix, ASortedPaths[I]) <> 1) then
    begin
      Inc(I);
      Continue;
    end;
    Tail := Copy(ASortedPaths[I], Length(ADirPrefix) + 1,
      Length(ASortedPaths[I]) - Length(ADirPrefix));
    SegEnd := Pos('/', Tail);
    if SegEnd > 0 then
      Child := Copy(ASortedPaths[I], 1, Length(ADirPrefix) + SegEnd - 1)
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
