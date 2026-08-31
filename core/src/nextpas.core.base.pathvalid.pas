unit nextpas.core.base.pathvalid;

{** @desc 路径规范校验共享基座（Go io/fs.ValidPath 对等语义）。
  L0 位置：被 respack.base / vfs.base 共同复用，消除 120 行重复实现；
  同时收敛 UTF-8 校验与段语法检查为单一事实源。 }

{$I nextpas.core.settings.inc}

interface

{ Go ValidPath 语义：UTF-8、unrooted、段非空非'.'非'..'、反斜杠为普通字符；
  整串 '.' 仅在 AAllowRoot=True 时合法。 }
function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;

implementation

function BaseUtf8Valid(const S: string): Boolean;
var
  I, N: Integer;
  B, Cont: Byte;
  Need: Integer;
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
    begin
      Need := 3;
      if B > $F4 then Exit(False);
    end
    else
      Exit(False);
    if I + Need > N then
      Exit(False);
    for Cont := 1 to Need do
    begin
      if (Byte(S[I + Cont]) and $C0) <> $80 then
        Exit(False);
    end;
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

function BaseValidPath(const APath: string; const AAllowRoot: Boolean): Boolean; inline;
var
  Start, I, N, SegLen: Integer;
begin
  Result := False;
  if not BaseUtf8Valid(APath) then
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
      SegLen := I - Start;
      if SegLen = 0 then
        Exit;
      if SegLen = 1 then
      begin
        if APath[Start] = '.' then
          Exit;
      end
      else if SegLen = 2 then
      begin
        if (APath[Start] = '.') and (APath[Start + 1] = '.') then
          Exit;
      end;
      Start := I + 1;
    end;
  end;
  Result := True;
end;

end.
