unit nextpas.core.fs.path;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.path,
  nextpas.core.fs.util;

const
  PathDelim = PLATFORM_PATH_SEP;
  PathSep = PathDelim;

function FsPathJoin(const AParts: array of string): string;
function FsPathDir(const APath: string): string;
function FsPathBase(const APath: string): string;
procedure FsPathSplit(const APath: string; out ADir, ABase: string);
function FsPathExt(const APath: string): string;
function FsPathClean(const APath: string): string;
function FsPathAbs(const APath: string): string;
function FsPathIsAbs(const APath: string): Boolean;
function FsPathRelative(const ABase, ATarget: string): string;
function FsPathEnsureSep(const APath: string): string;
function FsPathTrimSep(const APath: string): string;
function FsPathChangeExt(const APath, ANewExt: string): string;
function FsPathWithoutExt(const APath: string): string;
function FsSameFileName(const A, B: string): Boolean;
function FsPathMatch(const APattern, AName: string): Boolean;

implementation

const
  FS_PATH_STACK_BUF_SIZE = 1024;

{ P2-1: Helper to eliminate repeated stack/heap buffer pattern }
type
  TPlatformPathOp = function(const APath: PAnsiChar; AOutBuf: PAnsiChar;
    AOutBufSize: Int32): Int32;

function FsPathOpWithFallback(const APath: string;
  const AOp: TPlatformPathOp; const ADefault: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  if APath = '' then
    Exit(ADefault);
  LNeed := AOp(PAnsiChar(APath), @LStack[0], FS_PATH_STACK_BUF_SIZE);
  if LNeed <= 0 then
    Exit(ADefault);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  AOp(PAnsiChar(APath), @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathJoin(const AParts: array of string): string;
var
  LI, LNeed: Integer;
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LBase: string;
begin
  if Length(AParts) = 0 then
    Exit('');
  Result := AParts[0];
  for LI := 1 to High(AParts) do
  begin
    LBase := Result;
    LNeed := platform_path_join(PAnsiChar(LBase), PAnsiChar(AParts[LI]),
      @LStack[0], FS_PATH_STACK_BUF_SIZE);
    if LNeed < 0 then
      Continue;
    if LNeed < FS_PATH_STACK_BUF_SIZE then
      SetString(Result, PAnsiChar(@LStack[0]), LNeed)
    else
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_join(PAnsiChar(LBase), PAnsiChar(AParts[LI]),
        @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    end;
  end;
end;

function FsPathDir(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_dirname, '.');
end;

function FsPathBase(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_basename, APath);
end;

procedure FsPathSplit(const APath: string; out ADir, ABase: string);
begin
  ADir := FsPathDir(APath);
  ABase := FsPathBase(APath);
end;

function FsPathExt(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_extension, '');
end;

function FsPathClean(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_normalize, '.');
end;

function FsPathAbs(const APath: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
  LCwd: string;
begin
  if APath = '' then Exit('');
  LNeed := platform_path_resolve(PAnsiChar(APath), @LStack[0],
    FS_PATH_STACK_BUF_SIZE);
  if LNeed > 0 then
  begin
    if LNeed < FS_PATH_STACK_BUF_SIZE then
    begin
      SetString(Result, PAnsiChar(@LStack[0]), LNeed);
      Exit;
    end;
    SetLength(LHeap, LNeed + 1);
    platform_path_resolve(PAnsiChar(APath), @LHeap[0], Length(LHeap));
    SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    Exit;
  end;
  if FsPathIsAbs(APath) then
    Result := FsPathClean(APath)
  else
  begin
    LCwd := FsGetCwd;
    Result := FsPathClean(LCwd + PLATFORM_PATH_SEP + APath);
  end;
end;

function FsPathIsAbs(const APath: string): Boolean;
begin
  Result := platform_path_is_absolute(PAnsiChar(APath));
end;

function FsPathRelative(const ABase, ATarget: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  LNeed := platform_path_relative(PAnsiChar(ABase), PAnsiChar(ATarget),
    @LStack[0], FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(FsPathClean(ATarget));
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_relative(PAnsiChar(ABase), PAnsiChar(ATarget),
    @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathEnsureSep(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_ensure_sep, APath);
end;

function FsPathTrimSep(const APath: string): string;
begin
  Result := FsPathOpWithFallback(APath, @platform_path_trim_sep, APath);
end;

function FsPathChangeExt(const APath, ANewExt: string): string;
var
  LStack: array[0..FS_PATH_STACK_BUF_SIZE - 1] of AnsiChar;
  LNeed: Int32;
  LHeap: array of AnsiChar;
begin
  if APath = '' then
    Exit('');
  LNeed := platform_path_change_ext(PAnsiChar(APath), PAnsiChar(ANewExt),
    @LStack[0], FS_PATH_STACK_BUF_SIZE);
  if LNeed < 0 then
    Exit(APath);
  if LNeed < FS_PATH_STACK_BUF_SIZE then
  begin
    SetString(Result, PAnsiChar(@LStack[0]), LNeed);
    Exit;
  end;
  SetLength(LHeap, LNeed + 1);
  platform_path_change_ext(PAnsiChar(APath), PAnsiChar(ANewExt),
    @LHeap[0], Length(LHeap));
  SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
end;

function FsPathWithoutExt(const APath: string): string;
begin
  Result := FsPathChangeExt(APath, '');
end;

function FsSameFileName(const A, B: string): Boolean;
begin
  Result := platform_path_same_file_name(PAnsiChar(A), PAnsiChar(B));
end;

function FsPathMatch(const APattern, AName: string): Boolean;
var
  PI, NI: Integer;
  LP, LN: Integer;
  LChar, LMin, LMax: Char;
  LMatched, LNegate: Boolean;
  LSavedP, LSavedN: Integer;
begin
  LP := Length(APattern);
  LN := Length(AName);
  PI := 1;
  NI := 1;
  LSavedP := 0;
  LSavedN := 0;

  while NI <= LN do
  begin
    if PI <= LP then
    begin
      LChar := APattern[PI];

      { Escape: backslash matches next pattern char literally }
      if (LChar = '\') and (PI < LP) then
      begin
        Inc(PI);
        if AName[NI] = APattern[PI] then
        begin
          Inc(PI);
          Inc(NI);
          Continue;
        end;
        { Mismatch: extend star if available }
        if LSavedP > 0 then
        begin
          Inc(LSavedN);
          if (LSavedN <= LN) and ((AName[LSavedN] = '/') or (AName[LSavedN] = '\')) then
            Exit(False);
          PI := LSavedP;
          NI := LSavedN;
          Continue;
        end;
        Exit(False);
      end;

      { Star: match any sequence of non-separator chars }
      if LChar = '*' then
      begin
        Inc(PI);
        while (PI <= LP) and (APattern[PI] = '*') do
          Inc(PI);
        { Star at end: rest of name must have no separators }
        if PI > LP then
        begin
          while NI <= LN do
          begin
            if (AName[NI] = '/') or (AName[NI] = '\') then
              Exit(False);
            Inc(NI);
          end;
          Exit(True);
        end;
        LSavedP := PI;
        LSavedN := NI;
        Continue;
      end;

      { Question mark: match one non-separator char }
      if LChar = '?' then
      begin
        if (AName[NI] = '/') or (AName[NI] = '\') then
        begin
          if LSavedP > 0 then
          begin
            Inc(LSavedN);
            if (LSavedN <= LN) and ((AName[LSavedN] = '/') or (AName[LSavedN] = '\')) then
              Exit(False);
            PI := LSavedP;
            NI := LSavedN;
            Continue;
          end;
          Exit(False);
        end;
        Inc(PI);
        Inc(NI);
        Continue;
      end;

      { Character class: [a-z], [abc], [!abc], [^abc] }
      if LChar = '[' then
      begin
        Inc(PI);
        LNegate := False;
        if (PI <= LP) and ((APattern[PI] = '!') or (APattern[PI] = '^')) then
        begin
          LNegate := True;
          Inc(PI);
        end;
        LMatched := False;
        LMin := #0;
        while (PI <= LP) and (APattern[PI] <> ']') do
        begin
          if (APattern[PI] = '\') and (PI < LP) then
            Inc(PI);
          if (PI + 2 <= LP) and (APattern[PI + 1] = '-') then
          begin
            LMin := APattern[PI];
            LMax := APattern[PI + 2];
            if (LMax = '\') and (PI + 3 <= LP) then
              LMax := APattern[PI + 3];
            if (AName[NI] >= LMin) and (AName[NI] <= LMax) then
              LMatched := True;
            Inc(PI, 3);
          end
          else
          begin
            if AName[NI] = APattern[PI] then
              LMatched := True;
            Inc(PI);
          end;
        end;
        if LNegate then LMatched := not LMatched;
        if not LMatched then
        begin
          if LSavedP > 0 then
          begin
            Inc(LSavedN);
            if (LSavedN <= LN) and ((AName[LSavedN] = '/') or (AName[LSavedN] = '\')) then
              Exit(False);
            PI := LSavedP;
            NI := LSavedN;
            Continue;
          end;
          Exit(False);
        end;
        if (PI <= LP) and (APattern[PI] = ']') then
          Inc(PI);
        Inc(NI);
        Continue;
      end;

      { Literal match }
      if AName[NI] <> LChar then
      begin
        if LSavedP > 0 then
        begin
          Inc(LSavedN);
          if (LSavedN <= LN) and ((AName[LSavedN] = '/') or (AName[LSavedN] = '\')) then
            Exit(False);
          PI := LSavedP;
          NI := LSavedN;
          Continue;
        end;
        Exit(False);
      end;
      Inc(PI);
      Inc(NI);
      Continue;
    end;
    { Pattern exhausted but name remains }
    Exit(False);
  end;

  { Name exhausted: skip any trailing stars }
  while (PI <= LP) and (APattern[PI] = '*') do
    Inc(PI);
  Result := (PI > LP);
end;

end.
