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

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  特例整串 '.' 表根。AAllowRoot=False 时拒绝 '.'。 }
function VfsValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;

function VfsIsRoot(const APath: string): Boolean; inline;

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

end.
