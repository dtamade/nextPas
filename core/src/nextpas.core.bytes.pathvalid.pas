unit nextpas.core.bytes.pathvalid;

{** @desc 路径规范校验共享基座（Go io/fs.ValidPath 对等语义）。
  L1 位置：归属 bytes 域，复用 bytes.ops 单源（TByteSpan/CompareMem 语义）与
  text.utf8 UTF8IsValid 单源（SIMD 加速），被 respack.base / vfs.base 共同复用；
  inline/零拷贝：字符串不落地 Copy，段扫描在原串内存上直接索引。 }

{$I nextpas.core.settings.inc}

interface

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  整串 '.' 仅在 AAllowRoot=True 时合法。 }
function BytesValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;

{ 归档名安全谓词单源（tar/zip 共用，L1）：非空、≤AMaxBytes、非'/'开头、无盘符、无'\'、
  无'//'/'.'/'..'段，尾随'/'合法。inline+零拷贝：原串索引扫描，无Copy/分配。 }
function IsSafeArchiveEntryName(const AName: string; const AMaxBytes: SizeInt): Boolean; inline;

implementation

uses
  nextpas.core.text.utf8;

function BytesValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
var
  N, Start, I, SegLen: SizeInt;
begin
  Result := False;
  N := Length(APath);
  if N = 0 then
    Exit(False);
  { 复用 text.utf8 UTF8IsValid 单源（SIMD dispatch），零拷贝：直接在原串内存上校验 }
  if not UTF8IsValid(PByte(@APath[1]), SizeUInt(N)) then
    Exit(False);
  if APath = '.' then
    Exit(AAllowRoot);
  if (APath[1] = '/') or (APath[N] = '/') then
    Exit(False);
  Start := 1;
  for I := 1 to N + 1 do
  begin
    if (I > N) or (APath[I] = '/') then
    begin
      SegLen := I - Start;
      if SegLen = 0 then
        Exit(False);
      if SegLen = 1 then
      begin
        if APath[Start] = '.' then
          Exit(False);
      end
      else if SegLen = 2 then
      begin
        if (APath[Start] = '.') and (APath[Start + 1] = '.') then
          Exit(False);
      end;
      Start := I + 1;
    end;
  end;
  Result := True;
end;

function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean;
begin
  Result := BytesValidPath(APath, AAllowRoot);
end;

function IsSafeArchiveEntryName(const AName: string; const AMaxBytes: SizeInt): Boolean; inline;
var
  LI, LSegStart: Integer;
begin
  Result := False;
  if AName = '' then
    Exit;
  if Length(AName) > AMaxBytes then
    Exit;
  if AName[1] = '/' then
    Exit;
  if (Length(AName) >= 2) and (AName[2] = ':') and
     (UpCase(AName[1]) in ['A'..'Z']) then
    Exit;
  LSegStart := 1;
  for LI := 1 to Length(AName) + 1 do
  begin
    if (LI <= Length(AName)) and (AName[LI] <> '/') then
    begin
      if AName[LI] = '\' then
        Exit;
      Continue;
    end;
    if LI - LSegStart = 0 then
    begin
      if LI <= Length(AName) then
        Exit;
    end
    else if LI - LSegStart = 1 then
    begin
      if AName[LSegStart] = '.' then
        Exit;
    end
    else if (LI - LSegStart = 2) and (AName[LSegStart] = '.') and
       (AName[LSegStart + 1] = '.') then
      Exit;
    LSegStart := LI + 1;
  end;
  Result := True;
end;

end.
