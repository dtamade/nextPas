unit nextpas.core.bytes.pathvalid;

{** @desc 路径规范校验共享基座（Go io/fs.ValidPath 对等语义）。
  L1 位置：归属 bytes 域，复用 bytes.ops 单源（TByteSpan/CompareMem 语义）与
  text.utf8 UTF8IsValid 单源（SIMD 加速），被 respack.base / vfs.base 共同复用；
  inline/零拷贝：字符串不落地 Copy，段扫描在原串内存上直接索引。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  整串 '.' 仅在 AAllowRoot=True 时合法。 }
function BytesValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
function BytesValidPathView(const AView: TStringView; const AAllowRoot: Boolean): Boolean; inline;
{ 零拷贝视图版：TByteSpan 直验零分配，单源复用 text.utf8 UTF8IsValid + 段扫描，
  供 respack.reader Open 校验 10k 条目零堆分配；非 inline 守红线 2（真实扫描循环禁内联） }
function BytesValidSpan(const ASpan: TByteSpan; const AAllowRoot: Boolean): Boolean;
function BaseValidSpan(const ASpan: TByteSpan; const AAllowRoot: Boolean): Boolean; inline;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.view;

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

function BytesValidPathView(const AView: TStringView; const AAllowRoot: Boolean): Boolean; inline;
var
  N, Start, I, SegLen: SizeInt;
  P: PAnsiChar;
begin
  Result := False;
  N := SizeInt(AView.Len);
  P := AView.Data;
  if N = 0 then
    Exit(False);
  if not UTF8IsValid(PByte(P), SizeUInt(N)) then
    Exit(False);
  if (N = 1) and (P[0] = '.') then
    Exit(AAllowRoot);
  if (P[0] = '/') or (P[N - 1] = '/') then
    Exit(False);
  Start := 0;
  for I := 0 to N do
  begin
    if (I = N) or (P[I] = '/') then
    begin
      SegLen := I - Start;
      if SegLen = 0 then
        Exit(False);
      if SegLen = 1 then
      begin
        if P[Start] = '.' then
          Exit(False);
      end
      else if SegLen = 2 then
      begin
        if (P[Start] = '.') and (P[Start + 1] = '.') then
          Exit(False);
      end;
      Start := I + 1;
    end;
  end;
  Result := True;
end;


function BytesValidSpan(const ASpan: TByteSpan; const AAllowRoot: Boolean): Boolean;
var
  N, Start, I, SegLen: SizeInt;
  P: PByte;
begin
  Result := False;
  N := SizeInt(ASpan.Len);
  P := ASpan.Data;
  if N = 0 then
    Exit(False);
  if P = nil then
    Exit(False);
  if not UTF8IsValid(P, SizeUInt(N)) then
    Exit(False);
  if (N = 1) and (P[0] = Byte('.')) then
    Exit(AAllowRoot);
  if (P[0] = Byte('/')) or (P[N - 1] = Byte('/')) then
    Exit(False);
  Start := 0;
  for I := 0 to N do
  begin
    if (I = N) or (P[I] = Byte('/')) then
    begin
      SegLen := I - Start;
      if SegLen = 0 then
        Exit(False);
      if SegLen = 1 then
      begin
        if P[Start] = Byte('.') then
          Exit(False);
      end
      else if SegLen = 2 then
      begin
        if (P[Start] = Byte('.')) and (P[Start + 1] = Byte('.')) then
          Exit(False);
      end;
      Start := I + 1;
    end;
  end;
  Result := True;
end;

function BaseValidSpan(const ASpan: TByteSpan; const AAllowRoot: Boolean): Boolean; inline;
begin
  Result := BytesValidSpan(ASpan, AAllowRoot);
end;

end.
