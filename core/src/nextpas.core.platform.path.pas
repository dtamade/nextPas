unit nextpas.core.platform.path;

{$I nextpas.core.settings.inc}

interface

const
{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_PATH_SEP = '\';
  PLATFORM_PATH_ALT_SEP = '/';
{$ELSE}
  PLATFORM_PATH_SEP = '/';
  PLATFORM_PATH_ALT_SEP = '/';
{$ENDIF}
  PLATFORM_EXT_SEP = '.';

function platform_path_join(const ABase, AChild: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_dirname(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_basename(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_basename_ptr(const APath: PAnsiChar;
  out AStart: PAnsiChar; out ALen: Int32): Int32;
function platform_path_extension(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_extension_ptr(const APath: PAnsiChar;
  out AStart: PAnsiChar; out ALen: Int32): Int32;
function platform_path_change_ext(const APath, ANewExt: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_is_absolute(const APath: PAnsiChar): Boolean;
function platform_path_normalize(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

function IsSep(C: AnsiChar): Boolean; inline;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := (C = '\') or (C = '/');
{$ELSE}
  Result := C = '/';
{$ENDIF}
end;

function StrLen(S: PAnsiChar): Int32;
begin
  Result := 0;
  if S <> nil then
    while S[Result] <> #0 do Inc(Result);
end;

function CopyToBuf(const ASrc: PAnsiChar; ASrcLen: Int32;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  L: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(ASrcLen);
  L := ASrcLen;
  if L >= ABufLen then
    L := ABufLen - 1;
  if L > 0 then
    Move(ASrc^, ABuf^, L);
  ABuf[L] := #0;
  Result := ASrcLen;
end;

function platform_path_join(const ABase, AChild: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LBaseLen, LChildLen, LTotal: Int32;
  LNeedSep: Boolean;
  LTmp: array[0..1023] of AnsiChar;
  LPos: Int32;
begin
  LBaseLen := StrLen(ABase);
  LChildLen := StrLen(AChild);
  if LBaseLen = 0 then
    Exit(CopyToBuf(AChild, LChildLen, ABuf, ABufLen));
  if LChildLen = 0 then
    Exit(CopyToBuf(ABase, LBaseLen, ABuf, ABufLen));
  if platform_path_is_absolute(AChild) then
    Exit(CopyToBuf(AChild, LChildLen, ABuf, ABufLen));

  LNeedSep := not IsSep(ABase[LBaseLen - 1]);
  if LNeedSep then
    LTotal := LBaseLen + 1 + LChildLen
  else
    LTotal := LBaseLen + LChildLen;

  if LTotal < 1024 then
  begin
    Move(ABase^, LTmp[0], LBaseLen);
    LPos := LBaseLen;
    if LNeedSep then
    begin
      LTmp[LPos] := PLATFORM_PATH_SEP;
      Inc(LPos);
    end;
    Move(AChild^, LTmp[LPos], LChildLen);
    LTmp[LTotal] := #0;
    Result := CopyToBuf(@LTmp[0], LTotal, ABuf, ABufLen);
  end
  else
  begin
    if (ABuf = nil) or (ABufLen <= 0) then
      Exit(LTotal);
    LPos := LBaseLen;
    if LPos >= ABufLen then LPos := ABufLen - 1;
    Move(ABase^, ABuf^, LPos);
    if LNeedSep and (LPos < ABufLen - 1) then
    begin
      ABuf[LPos] := PLATFORM_PATH_SEP;
      Inc(LPos);
    end;
    if LPos < ABufLen - 1 then
    begin
      LChildLen := ABufLen - 1 - LPos;
      if LChildLen > StrLen(AChild) then
        LChildLen := StrLen(AChild);
      Move(AChild^, ABuf[LPos], LChildLen);
      Inc(LPos, LChildLen);
    end;
    ABuf[LPos] := #0;
    Result := LTotal;
  end;
end;

function platform_path_dirname(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I: Int32;
begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(APath, 0, ABuf, ABufLen));
  I := LLen - 1;
  while (I > 0) and not IsSep(APath[I]) do
    Dec(I);
  if I = 0 then
  begin
    if IsSep(APath[0]) then
      Exit(CopyToBuf(APath, 1, ABuf, ABufLen))
    else
      Exit(CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen));
  end;
  // Strip trailing separators from dirname (unless root)
  while (I > 1) and IsSep(APath[I - 1]) do
    Dec(I);
  Result := CopyToBuf(APath, I, ABuf, ABufLen);
end;

function platform_path_basename(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I: Int32;
begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(APath, 0, ABuf, ABufLen));
  I := LLen - 1;
  // Skip trailing separators
  while (I > 0) and IsSep(APath[I]) do
    Dec(I);
  LLen := I + 1;
  while (I > 0) and not IsSep(APath[I - 1]) do
    Dec(I);
  Result := CopyToBuf(@APath[I], LLen - I, ABuf, ABufLen);
end;

function platform_path_basename_ptr(const APath: PAnsiChar;
  out AStart: PAnsiChar; out ALen: Int32): Int32;
var
  LLen, I: Int32;
begin
  AStart := nil;
  ALen := 0;
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(0);
  I := LLen - 1;
  while (I > 0) and IsSep(APath[I]) do
    Dec(I);
  LLen := I + 1;
  while (I > 0) and not IsSep(APath[I - 1]) do
    Dec(I);
  AStart := @APath[I];
  ALen := LLen - I;
  Result := ALen;
end;

function platform_path_extension(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I: Int32;
begin
  LLen := StrLen(APath);
  I := LLen - 1;
  while (I >= 0) and not IsSep(APath[I]) do
  begin
    if APath[I] = PLATFORM_EXT_SEP then
      Exit(CopyToBuf(@APath[I], LLen - I, ABuf, ABufLen));
    Dec(I);
  end;
  Result := CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen);
end;

function platform_path_extension_ptr(const APath: PAnsiChar;
  out AStart: PAnsiChar; out ALen: Int32): Int32;
var
  LLen, I: Int32;
begin
  AStart := nil;
  ALen := 0;
  LLen := StrLen(APath);
  I := LLen - 1;
  while (I >= 0) and not IsSep(APath[I]) do
  begin
    if APath[I] = PLATFORM_EXT_SEP then
    begin
      AStart := @APath[I];
      ALen := LLen - I;
      Exit(ALen);
    end;
    Dec(I);
  end;
  Result := 0;
end;

function platform_path_change_ext(const APath, ANewExt: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I, LExtPos, LNewExtLen, LTotal: Int32;
  LTmp: array[0..1023] of AnsiChar;
begin
  LLen := StrLen(APath);
  LNewExtLen := StrLen(ANewExt);
  LExtPos := LLen;
  I := LLen - 1;
  while (I >= 0) and not IsSep(APath[I]) do
  begin
    if APath[I] = PLATFORM_EXT_SEP then
    begin
      LExtPos := I;
      Break;
    end;
    Dec(I);
  end;
  LTotal := LExtPos + LNewExtLen;
  if LTotal < 1024 then
  begin
    if LExtPos > 0 then
      Move(APath^, LTmp[0], LExtPos);
    if LNewExtLen > 0 then
      Move(ANewExt^, LTmp[LExtPos], LNewExtLen);
    LTmp[LTotal] := #0;
    Result := CopyToBuf(@LTmp[0], LTotal, ABuf, ABufLen);
  end
  else
    Result := CopyToBuf(APath, LLen, ABuf, ABufLen);
end;

function platform_path_is_absolute(const APath: PAnsiChar): Boolean;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(False);
{$IFDEF NEXTPAS_WINDOWS}
  // Drive letter: C:\ or C:/
  if (APath[1] = ':') and IsSep(APath[2]) then
    Exit(True);
  // UNC: \\server or //server
  if IsSep(APath[0]) and IsSep(APath[1]) then
    Exit(True);
{$ENDIF}
  Result := APath[0] = '/';
end;

function platform_path_normalize(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I, LOut, LStart: Int32;
  LTmp: array[0..1023] of AnsiChar;
  LParts: array[0..127] of record Pos, Len: Int32; end;
  LPartCount, J: Int32;
  LAbsolute: Boolean;
begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen));

  LAbsolute := platform_path_is_absolute(APath);
  LPartCount := 0;
  I := 0;
  if LAbsolute then I := 1;

  while I < LLen do
  begin
    while (I < LLen) and IsSep(APath[I]) do Inc(I);
    if I >= LLen then Break;
    LStart := I;
    while (I < LLen) and not IsSep(APath[I]) do Inc(I);

    if (I - LStart = 1) and (APath[LStart] = '.') then
      Continue
    else if (I - LStart = 2) and (APath[LStart] = '.') and (APath[LStart+1] = '.') then
    begin
      if (LPartCount > 0) and not
         ((LParts[LPartCount-1].Len = 2) and (APath[LParts[LPartCount-1].Pos] = '.') and (APath[LParts[LPartCount-1].Pos+1] = '.')) then
        Dec(LPartCount)
      else if not LAbsolute then
      begin
        LParts[LPartCount].Pos := LStart;
        LParts[LPartCount].Len := 2;
        Inc(LPartCount);
      end;
    end
    else
    begin
      LParts[LPartCount].Pos := LStart;
      LParts[LPartCount].Len := I - LStart;
      Inc(LPartCount);
    end;
  end;

  LOut := 0;
  if LAbsolute then
  begin
    LTmp[0] := PLATFORM_PATH_SEP;
    LOut := 1;
  end;
  for J := 0 to LPartCount - 1 do
  begin
    if (J > 0) or (LAbsolute and (LPartCount > 0) and (J = 0)) then
    begin
      if (LOut > 0) and not IsSep(LTmp[LOut-1]) then
      begin
        LTmp[LOut] := PLATFORM_PATH_SEP;
        Inc(LOut);
      end;
    end;
    Move(APath[LParts[J].Pos], LTmp[LOut], LParts[J].Len);
    Inc(LOut, LParts[J].Len);
  end;
  if (LOut = 0) and not LAbsolute then
  begin
    LTmp[0] := '.';
    LOut := 1;
  end;
  LTmp[LOut] := #0;
  Result := CopyToBuf(@LTmp[0], LOut, ABuf, ABufLen);
end;

end.
