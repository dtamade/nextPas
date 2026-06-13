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
function platform_path_is_root(const APath: PAnsiChar): Boolean;
function platform_path_normalize(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_relative(const ABase, ATarget: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_resolve(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_ensure_sep(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_trim_sep(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
function platform_path_same_file_name(const ALeft, ARight: PAnsiChar): Boolean;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;
{$ENDIF}

type
  TPlatformPathRootKind = (
    prkNone,
    prkPosixRoot,
    prkWindowsDriveAbsolute,
    prkWindowsDriveRelative,
    prkWindowsRootedRelative,
    prkWindowsUncShare,
    prkWindowsExtendedUncShare,
    prkWindowsExtendedDriveAbsolute,
    prkWindowsDeviceRoot
  );

  TPlatformPathRoot = record
    Kind: TPlatformPathRootKind;
    Len: Int32;
  end;

  TPathPart = record
    Pos: Int32;
    Len: Int32;
  end;

  TPathPartArray = array of TPathPart;

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

function IsAsciiDriveLetter(C: AnsiChar): Boolean; inline;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := ((C >= 'A') and (C <= 'Z')) or ((C >= 'a') and (C <= 'z'));
{$ELSE}
  Result := False;
{$ENDIF}
end;

function MakePathRoot(AKind: TPlatformPathRootKind; ALen: Int32): TPlatformPathRoot; inline;
begin
  Result.Kind := AKind;
  Result.Len := ALen;
end;

{$IFDEF NEXTPAS_WINDOWS}
function PathSliceEqualsText(const APath: PAnsiChar; const AStart, ALen: Int32;
  const AText: PAnsiChar): Boolean;
var
  I: Int32;
  LLeft, LRight: AnsiChar;
begin
  for I := 0 to ALen - 1 do
  begin
    if AText[I] = #0 then
      Exit(False);
    LLeft := APath[AStart + I];
    LRight := AText[I];
    if (LLeft >= 'A') and (LLeft <= 'Z') then
      LLeft := AnsiChar(Ord(LLeft) + Ord('a') - Ord('A'));
    if (LRight >= 'A') and (LRight <= 'Z') then
      LRight := AnsiChar(Ord(LRight) + Ord('a') - Ord('A'));
    if LLeft <> LRight then
      Exit(False);
  end;
  Result := AText[ALen] = #0;
end;

function ClassifyWindowsUncShareRoot(const APath: PAnsiChar; const ALen,
  APrefixLen: Int32; const ARootKind: TPlatformPathRootKind): TPlatformPathRoot;
var
  I, LShareStart: Int32;
begin
  Result := MakePathRoot(prkNone, 0);
  I := APrefixLen;
  while (I < ALen) and not IsSep(APath[I]) do
    Inc(I);
  if (I > APrefixLen) and (I < ALen - 1) then
  begin
    Inc(I);
    LShareStart := I;
    while (I < ALen) and not IsSep(APath[I]) do
      Inc(I);
    if I > LShareStart then
      Result := MakePathRoot(ARootKind, I);
  end;
end;
{$ENDIF}

function ClassifyPathRoot(const APath: PAnsiChar; ALen: Int32): TPlatformPathRoot;
{$IFDEF NEXTPAS_WINDOWS}
var
  I: Int32;
{$ENDIF}
begin
  Result := MakePathRoot(prkNone, 0);
  if (APath = nil) or (ALen <= 0) then
    Exit;
{$IFDEF NEXTPAS_WINDOWS}
  if (ALen >= 4) and IsSep(APath[0]) and IsSep(APath[1]) and
    ((APath[2] = '?') or (APath[2] = '.')) and IsSep(APath[3]) then
  begin
    if (APath[2] = '?') and (ALen >= 8) and
      PathSliceEqualsText(APath, 4, 3, 'UNC') and IsSep(APath[7]) then
    begin
      Result := ClassifyWindowsUncShareRoot(APath, ALen, 8,
        prkWindowsExtendedUncShare);
      if Result.Kind <> prkNone then
        Exit;
    end;
    if (APath[2] = '?') and (ALen >= 7) and
      IsAsciiDriveLetter(APath[4]) and (APath[5] = ':') and IsSep(APath[6]) then
      Exit(MakePathRoot(prkWindowsExtendedDriveAbsolute, 7));
    if APath[2] = '.' then
    begin
      I := 4;
      while (I < ALen) and not IsSep(APath[I]) do
        Inc(I);
      if I > 4 then
        Exit(MakePathRoot(prkWindowsDeviceRoot, I));
    end;
  end;

  if (ALen >= 2) and IsAsciiDriveLetter(APath[0]) and (APath[1] = ':') then
  begin
    if (ALen >= 3) and IsSep(APath[2]) then
      Exit(MakePathRoot(prkWindowsDriveAbsolute, 3));
    Exit(MakePathRoot(prkWindowsDriveRelative, 2));
  end;

  if IsSep(APath[0]) then
  begin
    if (ALen >= 2) and IsSep(APath[1]) and (ALen > 2) and
      not IsSep(APath[2]) then
    begin
      Result := ClassifyWindowsUncShareRoot(APath, ALen, 2,
        prkWindowsUncShare);
      if Result.Kind <> prkNone then
        Exit;
    end;
    Exit(MakePathRoot(prkWindowsRootedRelative, 1));
  end;
{$ELSE}
  if IsSep(APath[0]) then
    Exit(MakePathRoot(prkPosixRoot, 1));
{$ENDIF}
end;

function PathRootBlocksDotDot(const ARoot: TPlatformPathRoot): Boolean; inline;
begin
  case ARoot.Kind of
    prkPosixRoot,
    prkWindowsDriveAbsolute,
    prkWindowsRootedRelative,
    prkWindowsUncShare,
    prkWindowsExtendedUncShare,
    prkWindowsExtendedDriveAbsolute,
    prkWindowsDeviceRoot:
      Result := True;
  else
    Result := False;
  end;
end;

function PathRootNeedsSepBeforePart(const ARoot: TPlatformPathRoot;
  const APath: PAnsiChar): Boolean; inline;
begin
  if (ARoot.Len <= 0) or (APath = nil) or IsSep(APath[ARoot.Len - 1]) then
    Exit(False);
  Result := ARoot.Kind <> prkWindowsDriveRelative;
end;

function PathRootIsAbsolute(const ARoot: TPlatformPathRoot): Boolean; inline;
begin
  case ARoot.Kind of
    prkPosixRoot,
    prkWindowsDriveAbsolute,
    prkWindowsUncShare,
    prkWindowsExtendedUncShare,
    prkWindowsExtendedDriveAbsolute,
    prkWindowsDeviceRoot:
      Result := True;
  else
    Result := False;
  end;
end;

function AsciiLower(C: AnsiChar): AnsiChar; inline;
begin
  if (C >= 'A') and (C <= 'Z') then
    Result := AnsiChar(Ord(C) + Ord('a') - Ord('A'))
  else
    Result := C;
end;

function PathCharEqual(A, B: AnsiChar): Boolean; inline;
begin
{$IFDEF NEXTPAS_WINDOWS}
  if IsSep(A) and IsSep(B) then
    Exit(True);
  Result := AsciiLower(A) = AsciiLower(B);
{$ELSE}
  Result := A = B;
{$ENDIF}
end;

function PathSliceEqual(const ALeft: PAnsiChar; const ALeftLen: Int32;
  const ARight: PAnsiChar; const ARightLen: Int32): Boolean;
var
  I: Int32;
begin
  if ALeftLen <> ARightLen then
    Exit(False);
  for I := 0 to ALeftLen - 1 do
    if not PathCharEqual(ALeft[I], ARight[I]) then
      Exit(False);
  Result := True;
end;

function PathRootsCompatible(const ABase: PAnsiChar; const ABaseRoot: TPlatformPathRoot;
  const ATarget: PAnsiChar; const ATargetRoot: TPlatformPathRoot): Boolean;
begin
  if ABaseRoot.Kind <> ATargetRoot.Kind then
    Exit(False);
  Result := PathSliceEqual(ABase, ABaseRoot.Len, ATarget, ATargetRoot.Len);
end;

function PathNameLenWithoutTrailingSeparators(const APath: PAnsiChar): Int32;
var
  LRoot: TPlatformPathRoot;
begin
  Result := StrLen(APath);
  while (Result > 1) and IsSep(APath[Result - 1]) do
  begin
    LRoot := ClassifyPathRoot(APath, Result);
    if (LRoot.Len > 0) and (LRoot.Len = Result) then
      Break;
    Dec(Result);
  end;
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

function PathJoinChildStart(const AChild: PAnsiChar; AChildLen: Int32): Int32;
{$IFDEF NEXTPAS_WINDOWS}
var
  LRoot: TPlatformPathRoot;
{$ENDIF}
begin
  Result := 0;
{$IFDEF NEXTPAS_WINDOWS}
  LRoot := ClassifyPathRoot(AChild, AChildLen);
  if LRoot.Kind = prkWindowsRootedRelative then
  begin
    Result := LRoot.Len;
    while (Result < AChildLen) and IsSep(AChild[Result]) do
      Inc(Result);
  end;
{$ENDIF}
end;

function platform_path_join(const ABase, AChild: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LBaseLen, LChildLen, LChildStart, LTotal: Int32;
  LNeedSep: Boolean;
  LTmp: array[0..1023] of AnsiChar;
  LPos: Int32;
begin
  LBaseLen := StrLen(ABase);
  LChildLen := StrLen(AChild);
  LChildStart := 0;
  if LBaseLen = 0 then
    Exit(CopyToBuf(AChild, LChildLen, ABuf, ABufLen));
  if LChildLen = 0 then
    Exit(CopyToBuf(ABase, LBaseLen, ABuf, ABufLen));
  if platform_path_is_absolute(AChild) then
    Exit(CopyToBuf(AChild, LChildLen, ABuf, ABufLen));
{$IFDEF NEXTPAS_WINDOWS}
  LChildStart := PathJoinChildStart(AChild, LChildLen);
  if LChildStart > 0 then
  begin
    Dec(LChildLen, LChildStart);
    if LChildLen = 0 then
      Exit(CopyToBuf(ABase, LBaseLen, ABuf, ABufLen));
  end;
{$ENDIF}

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
    Move(AChild[LChildStart], LTmp[LPos], LChildLen);
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
      if LChildLen > StrLen(AChild) - LChildStart then
        LChildLen := StrLen(AChild) - LChildStart;
      Move(AChild[LChildStart], ABuf[LPos], LChildLen);
      Inc(LPos, LChildLen);
    end;
    ABuf[LPos] := #0;
    Result := LTotal;
  end;
end;

function platform_path_join3(const A, B, C: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LStack: array[0..1023] of AnsiChar;
  LHeap: array of AnsiChar;
  LNeed: Int32;
  LJoined: PAnsiChar;
begin
  LNeed := platform_path_join(A, B, @LStack[0], Length(LStack));
  if LNeed < 0 then
    Exit(LNeed);
  if LNeed < Length(LStack) then
    LJoined := @LStack[0]
  else
  begin
    SetLength(LHeap, LNeed + 1);
    LNeed := platform_path_join(A, B, @LHeap[0], Length(LHeap));
    if LNeed < 0 then
      Exit(LNeed);
    if LNeed >= Length(LHeap) then
    begin
      SetLength(LHeap, LNeed + 1);
      LNeed := platform_path_join(A, B, @LHeap[0], Length(LHeap));
      if LNeed < 0 then
        Exit(LNeed);
      if LNeed >= Length(LHeap) then
        Exit(-1);
    end;
    LJoined := @LHeap[0];
  end;
  Result := platform_path_join(LJoined, C, ABuf, ABufLen);
end;

function platform_path_dirname(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I: Int32;
  LRoot: TPlatformPathRoot;
begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(APath, 0, ABuf, ABufLen));
  LRoot := ClassifyPathRoot(APath, LLen);
  if (LRoot.Len > 0) and (LRoot.Len = PathNameLenWithoutTrailingSeparators(APath)) then
    Exit(CopyToBuf(APath, LRoot.Len, ABuf, ABufLen));
  I := LLen - 1;
  while (I > 0) and not IsSep(APath[I]) do
    Dec(I);
  if (LRoot.Len > 0) and (I < LRoot.Len) then
    Exit(CopyToBuf(APath, LRoot.Len, ABuf, ABufLen));
  if I = 0 then
  begin
    if IsSep(APath[0]) then
      Exit(CopyToBuf(APath, 1, ABuf, ABufLen))
    else
      Exit(CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen));
  end;
  // Strip trailing separators from dirname (unless root)
  while (I > 1) and IsSep(APath[I - 1]) and
    not ((LRoot.Len > 0) and (I <= LRoot.Len)) do
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
  LLen := PathNameLenWithoutTrailingSeparators(APath);
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
  LLen := PathNameLenWithoutTrailingSeparators(APath);
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
  LCopyLen, LPos, LRemaining: Int32;
begin
  LLen := PathNameLenWithoutTrailingSeparators(APath);
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
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(LTotal);

  LCopyLen := LExtPos;
  if LCopyLen >= ABufLen then
    LCopyLen := ABufLen - 1;
  if LCopyLen > 0 then
    Move(APath^, ABuf^, LCopyLen);
  LPos := LCopyLen;
  LRemaining := ABufLen - 1 - LPos;
  if LRemaining > 0 then
  begin
    LCopyLen := LNewExtLen;
    if LCopyLen > LRemaining then
      LCopyLen := LRemaining;
    if LCopyLen > 0 then
      Move(ANewExt^, ABuf[LPos], LCopyLen);
    Inc(LPos, LCopyLen);
  end;
  ABuf[LPos] := #0;
  Result := LTotal;
end;

function platform_path_is_absolute(const APath: PAnsiChar): Boolean;
var
  LRoot: TPlatformPathRoot;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(False);
  LRoot := ClassifyPathRoot(APath, StrLen(APath));
  Result := PathRootIsAbsolute(LRoot);
end;

function platform_path_is_root(const APath: PAnsiChar): Boolean;
var
  LRoot: TPlatformPathRoot;
  LLen: Int32;
begin
  if (APath = nil) or (APath[0] = #0) then
    Exit(False);
  LLen := PathNameLenWithoutTrailingSeparators(APath);
  LRoot := ClassifyPathRoot(APath, LLen);
  Result := (LRoot.Len > 0) and (LRoot.Len = LLen) and
    PathRootIsAbsolute(LRoot);
end;

function platform_path_normalize(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, I, LStart: Int32;
  LParts: array of TPathPart;
  LPartCount, J, LPrefixLen, LRequired, LBufPos, LCopyLen: Int32;
  LRoot: TPlatformPathRoot;
  LSep: AnsiChar;

  function IsDotDotPart(const APart: TPathPart): Boolean;
  begin
    Result := (APart.Len = 2) and (APath[APart.Pos] = '.') and
      (APath[APart.Pos + 1] = '.');
  end;

  procedure AddPart(const APos, ALen: Int32);
  begin
    if LPartCount >= Length(LParts) then
      SetLength(LParts, LPartCount + 32);
    LParts[LPartCount].Pos := APos;
    LParts[LPartCount].Len := ALen;
    Inc(LPartCount);
  end;

  function NeedsSepBeforePart(const AIndex: Int32): Boolean;
  begin
    Result := (AIndex > 0) or
      ((AIndex = 0) and PathRootNeedsSepBeforePart(LRoot, APath));
  end;

  procedure CopyChunk(const ASrc: PAnsiChar; const ALen: Int32);
  var
    LRoom: Int32;
  begin
    if (ABuf = nil) or (ABufLen <= 0) or (ALen <= 0) then
      Exit;
    LRoom := ABufLen - 1 - LBufPos;
    if LRoom <= 0 then
      Exit;
    LCopyLen := ALen;
    if LCopyLen > LRoom then
      LCopyLen := LRoom;
    Move(ASrc^, ABuf[LBufPos], LCopyLen);
    Inc(LBufPos, LCopyLen);
  end;

begin
  LLen := StrLen(APath);
  if LLen = 0 then
    Exit(CopyToBuf(PAnsiChar(''), 0, ABuf, ABufLen));

  LRoot := ClassifyPathRoot(APath, LLen);
  LPartCount := 0;
  LPrefixLen := LRoot.Len;
  LSep := PLATFORM_PATH_SEP;
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
      if (LPartCount > 0) and not IsDotDotPart(LParts[LPartCount - 1]) then
        Dec(LPartCount)
      else if not PathRootBlocksDotDot(LRoot) then
        AddPart(LStart, 2);
    end
    else
      AddPart(LStart, I - LStart);
  end;

  if LPrefixLen > 0 then
    LRequired := LPrefixLen
  else if LPartCount = 0 then
    LRequired := 1
  else
    LRequired := 0;
  for J := 0 to LPartCount - 1 do
  begin
    if NeedsSepBeforePart(J) then
      Inc(LRequired);
    Inc(LRequired, LParts[J].Len);
  end;

  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(LRequired);

  LBufPos := 0;
  if LPrefixLen > 0 then
    CopyChunk(APath, LPrefixLen)
  else if LPartCount = 0 then
    CopyChunk(PAnsiChar('.'), 1);
  for J := 0 to LPartCount - 1 do
  begin
    if NeedsSepBeforePart(J) then
      CopyChunk(@LSep, 1);
    CopyChunk(@APath[LParts[J].Pos], LParts[J].Len);
  end;
  ABuf[LBufPos] := #0;
  Result := LRequired;
end;

function platform_path_relative(const ABase, ATarget: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LBaseNorm, LTargetNorm, LRel: array of AnsiChar;
  LBaseLen, LTargetLen, LBaseCount, LTargetCount, LCommon: Int32;
  LUpCount, LDownCount, LTotalParts, LRequired, LPos, I, LPartIndex: Int32;
  LBaseRoot, LTargetRoot: TPlatformPathRoot;
  LBaseParts, LTargetParts: TPathPartArray;

  procedure CollectParts(const APath: PAnsiChar; const ALen, AStart: Int32;
    var AParts: TPathPartArray; out ACount: Int32);
  var
    LI, LStart: Int32;
  begin
    ACount := 0;
    LI := AStart;
    while LI < ALen do
    begin
      while (LI < ALen) and IsSep(APath[LI]) do
        Inc(LI);
      if LI >= ALen then
        Break;
      LStart := LI;
      while (LI < ALen) and not IsSep(APath[LI]) do
        Inc(LI);
      if ((LI - LStart) = 1) and (APath[LStart] = '.') then
        Continue;
      if ACount >= Length(AParts) then
        SetLength(AParts, ACount + 16);
      AParts[ACount].Pos := LStart;
      AParts[ACount].Len := LI - LStart;
      Inc(ACount);
    end;
  end;

  function PartEqual(const ALeftPath: PAnsiChar; const ALeftPart: TPathPart;
    const ARightPath: PAnsiChar; const ARightPart: TPathPart): Boolean;
  begin
    Result := PathSliceEqual(@ALeftPath[ALeftPart.Pos], ALeftPart.Len,
      @ARightPath[ARightPart.Pos], ARightPart.Len);
  end;

  procedure AppendSepIfNeeded;
  begin
    if LPos > 0 then
    begin
      LRel[LPos] := PLATFORM_PATH_SEP;
      Inc(LPos);
    end;
  end;

  procedure AppendDotDot;
  begin
    AppendSepIfNeeded;
    LRel[LPos] := '.';
    LRel[LPos + 1] := '.';
    Inc(LPos, 2);
  end;

  procedure AppendTargetPart(const APart: TPathPart);
  begin
    AppendSepIfNeeded;
    Move(LTargetNorm[APart.Pos], LRel[LPos], APart.Len);
    Inc(LPos, APart.Len);
  end;

begin
  LBaseLen := platform_path_normalize(ABase, nil, 0);
  LTargetLen := platform_path_normalize(ATarget, nil, 0);
  if (LBaseLen < 0) or (LTargetLen < 0) then
    Exit(CopyToBuf(ATarget, StrLen(ATarget), ABuf, ABufLen));

  SetLength(LBaseNorm, LBaseLen + 1);
  SetLength(LTargetNorm, LTargetLen + 1);
  LBaseLen := platform_path_normalize(ABase, @LBaseNorm[0], Length(LBaseNorm));
  LTargetLen := platform_path_normalize(ATarget, @LTargetNorm[0], Length(LTargetNorm));
  if (LBaseLen < 0) or (LTargetLen < 0) then
    Exit(CopyToBuf(ATarget, StrLen(ATarget), ABuf, ABufLen));

  LBaseRoot := ClassifyPathRoot(@LBaseNorm[0], LBaseLen);
  LTargetRoot := ClassifyPathRoot(@LTargetNorm[0], LTargetLen);
  if not PathRootsCompatible(@LBaseNorm[0], LBaseRoot, @LTargetNorm[0], LTargetRoot) then
    Exit(CopyToBuf(@LTargetNorm[0], LTargetLen, ABuf, ABufLen));

  CollectParts(@LBaseNorm[0], LBaseLen, LBaseRoot.Len, LBaseParts, LBaseCount);
  CollectParts(@LTargetNorm[0], LTargetLen, LTargetRoot.Len, LTargetParts, LTargetCount);

  LCommon := 0;
  while (LCommon < LBaseCount) and (LCommon < LTargetCount) and
    PartEqual(@LBaseNorm[0], LBaseParts[LCommon], @LTargetNorm[0], LTargetParts[LCommon]) do
    Inc(LCommon);

  LUpCount := LBaseCount - LCommon;
  LDownCount := LTargetCount - LCommon;
  LTotalParts := LUpCount + LDownCount;
  if LTotalParts = 0 then
    Exit(CopyToBuf(PAnsiChar('.'), 1, ABuf, ABufLen));

  LRequired := 0;
  for I := 0 to LUpCount - 1 do
  begin
    if LRequired > 0 then
      Inc(LRequired);
    Inc(LRequired, 2);
  end;
  for I := 0 to LDownCount - 1 do
  begin
    if LRequired > 0 then
      Inc(LRequired);
    LPartIndex := LCommon + I;
    Inc(LRequired, LTargetParts[LPartIndex].Len);
  end;

  SetLength(LRel, LRequired + 1);
  LPos := 0;
  for I := 0 to LUpCount - 1 do
    AppendDotDot;
  for I := 0 to LDownCount - 1 do
  begin
    LPartIndex := LCommon + I;
    AppendTargetPart(LTargetParts[LPartIndex]);
  end;
  LRel[LPos] := #0;
  Result := CopyToBuf(@LRel[0], LRequired, ABuf, ABufLen);
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
  LPath: UnicodeString;
  LBuf: array of WideChar;
  LLen: DWORD;
  LUtf8: AnsiString;
begin
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  if not platform_windows_utf8_to_wide_checked(APath, LPath) then
    Exit(-1);

  LLen := GetFullPathNameW(PWideChar(LPath), 0, nil, nil);
  if LLen = 0 then
    Exit(-1);
  SetLength(LBuf, LLen + 1);
  LLen := GetFullPathNameW(PWideChar(LPath), DWORD(Length(LBuf)),
    @LBuf[0], nil);
  if (LLen = 0) or (LLen >= DWORD(Length(LBuf))) then
    Exit(-1);
  LBuf[LLen] := #0;
  if not platform_windows_wide_to_utf8_checked(@LBuf[0], LUtf8) then
    Exit(-1);
  Result := platform_windows_copy_utf8_to_buffer(LUtf8, ABuf, ABufLen);
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

function platform_path_ensure_sep(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen, LTotal: Int32;
  LTmp: array of AnsiChar;
begin
  LLen := StrLen(APath);
  if (LLen > 0) and IsSep(APath[LLen - 1]) then
    Exit(CopyToBuf(APath, LLen, ABuf, ABufLen));

  LTotal := LLen + 1;
  if (ABuf = nil) or (ABufLen <= 0) then
    Exit(LTotal);
  if LTotal >= ABufLen then
  begin
    if (LLen > 0) and (ABufLen > 1) then
      Move(APath^, ABuf^, ABufLen - 1);
    ABuf[ABufLen - 1] := #0;
    Exit(LTotal);
  end;

  SetLength(LTmp, LTotal + 1);
  if LLen > 0 then
    Move(APath^, LTmp[0], LLen);
  LTmp[LLen] := PLATFORM_PATH_SEP;
  LTmp[LTotal] := #0;
  Result := CopyToBuf(@LTmp[0], LTotal, ABuf, ABufLen);
end;

function platform_path_trim_sep(const APath: PAnsiChar;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
var
  LLen: Int32;
  LRoot: TPlatformPathRoot;
begin
  LLen := StrLen(APath);
  while LLen > 0 do
  begin
    LRoot := ClassifyPathRoot(APath, LLen);
    if (LRoot.Len > 0) and (LLen <= LRoot.Len) then
      Break;
    if not IsSep(APath[LLen - 1]) then
      Break;
    Dec(LLen);
  end;
  Result := CopyToBuf(APath, LLen, ABuf, ABufLen);
end;

function platform_path_same_file_name(const ALeft, ARight: PAnsiChar): Boolean;
var
  LLeftLen, LRightLen, I: Int32;
begin
  LLeftLen := StrLen(ALeft);
  LRightLen := StrLen(ARight);
  if LLeftLen <> LRightLen then
    Exit(False);
  for I := 0 to LLeftLen - 1 do
    if not PathCharEqual(ALeft[I], ARight[I]) then
      Exit(False);
  Result := True;
end;

end.
