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
function platform_path_join3(const A, B, C: PAnsiChar;
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
function platform_path_resolve(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

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

function platform_path_join3(const A, B, C: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LTmp: array[0..1023] of AnsiChar;
begin
  platform_path_join(A, B, @LTmp[0], 1024);
  Result := platform_path_join(@LTmp[0], C, ABuf, ABufLen);
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
  LLen, I, LNameStart: Int32;
begin
  LLen := StrLen(APath);
  LNameStart := 0;
  for I := LLen - 1 downto 0 do
    if IsSep(APath[I]) then
    begin
      LNameStart := I + 1;
      Break;
    end;
  I := LLen - 1;
  while I > LNameStart do
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
  LLen, I, LNameStart: Int32;
begin
  AStart := nil;
  ALen := 0;
  LLen := StrLen(APath);
  LNameStart := 0;
  for I := LLen - 1 downto 0 do
    if IsSep(APath[I]) then
    begin
      LNameStart := I + 1;
      Break;
    end;
  I := LLen - 1;
  while I > LNameStart do
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
  LLen, I, LExtPos, LNewExtLen, LTotal, LNameStart: Int32;
  LTmp: array[0..1023] of AnsiChar;
begin
  LLen := StrLen(APath);
  LNewExtLen := StrLen(ANewExt);
  LExtPos := LLen;
  LNameStart := 0;
  for I := LLen - 1 downto 0 do
    if IsSep(APath[I]) then
    begin
      LNameStart := I + 1;
      Break;
    end;
  I := LLen - 1;
  while I > LNameStart do
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
  LPartCount, J, LPrefixLen: Int32;
  LAbsolute: Boolean;
begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen));

  LAbsolute := platform_path_is_absolute(APath);
  LPartCount := 0;
  LPrefixLen := 0;

  if LAbsolute then
  begin
  {$IFDEF NEXTPAS_WINDOWS}
    if (LLen >= 3) and (APath[1] = ':') and IsSep(APath[2]) then
      LPrefixLen := 3
    else if (LLen >= 2) and IsSep(APath[0]) and IsSep(APath[1]) then
      LPrefixLen := 2
    else
      LPrefixLen := 1;
  {$ELSE}
    LPrefixLen := 1;
  {$ENDIF}
  end;
  I := LPrefixLen;

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
        if LPartCount >= 128 then Break;
        LParts[LPartCount].Pos := LStart;
        LParts[LPartCount].Len := 2;
        Inc(LPartCount);
      end;
    end
    else
    begin
      if LPartCount >= 128 then Break;
      LParts[LPartCount].Pos := LStart;
      LParts[LPartCount].Len := I - LStart;
      Inc(LPartCount);
    end;
  end;

  LOut := 0;
  if LAbsolute then
  begin
    if LPrefixLen <= 1020 then
    begin
      Move(APath^, LTmp[0], LPrefixLen);
      LOut := LPrefixLen;
    {$IFDEF NEXTPAS_WINDOWS}
      if (LOut > 0) and not IsSep(LTmp[LOut-1]) then
      begin
        LTmp[LOut] := PLATFORM_PATH_SEP;
        Inc(LOut);
      end;
    {$ENDIF}
    end;
  end;
  for J := 0 to LPartCount - 1 do
  begin
    if LOut >= 1020 then Break;
    if (J > 0) or (LAbsolute and (J = 0) and (LOut > 0) and not IsSep(LTmp[LOut-1])) then
    begin
      LTmp[LOut] := PLATFORM_PATH_SEP;
      Inc(LOut);
    end;
    if LOut + LParts[J].Len > 1023 then Break;
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

{$IFDEF NEXTPAS_UNIX}
function platform_path_resolve(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LResolved: array[0..4095] of AnsiChar;
  LResult: PAnsiChar;
  LLen, I: Int32;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LResult := nextpas.core.platform.posix.ffi.realpath(APath, @LResolved[0]);
  if LResult = nil then
    Exit(-1);
  LLen := 0;
  while LResolved[LLen] <> #0 do Inc(LLen);
  I := LLen;
  if I >= ABufLen then I := ABufLen - 1;
  if I > 0 then Move(LResolved[0], ABuf^, I);
  ABuf[I] := #0;
  Result := LLen;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_path_resolve(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: DWORD;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LLen := GetFullPathNameA(APath, DWORD(ABufLen), ABuf, nil);
  if LLen = 0 then
    Exit(-1);
  if Int32(LLen) >= ABufLen then
  begin
    ABuf[ABufLen - 1] := #0;
    Exit(Int32(LLen));
  end;
  Result := Int32(LLen);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_path_resolve(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
begin
  if ABuf <> nil then ABuf[0] := #0;
  Result := -1;
end;
{$ENDIF}

end.
