unit nextpas.core.fs.glob;
{**
 * @desc Glob 模式匹配：纯字符串匹配 + 文件系统 glob 遍历。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{**
 * @desc 检查文件名是否匹配 glob 模式
 *
 * @params
 *   APattern  glob 模式（支持 *, ?, [abc], [a-z], [^abc], [!abc], **）
 *   AName     待匹配的字符串（可含路径分隔符）
 *
 * @return 是否匹配
 *
 * @note 大小写敏感；* 不跨路径分隔符；** 匹配任意目录层级
 *}
function GlobMatch(const APattern, AName: string): Boolean;

{**
 * @desc 在指定目录下匹配 glob 模式
 *
 * @params
 *   ADir      根目录
 *   APattern  glob 模式（可含路径分隔符和 **）
 *
 * @return 匹配的文件路径数组（排序）
 *}
function FsGlob(const ADir, APattern: string): TStringArray; overload;

{**
 * @desc 在当前目录下匹配 glob 模式
 *
 * @desc 等同于 FsGlob('.', APattern)
 *}
function FsGlob(const APattern: string): TStringArray; overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.dir,
  nextpas.core.fs.path;

{ GlobMatch internals — recursive descent }

type
  TPathSepSet = set of AnsiChar;

const
  PATH_SEPARATORS: TPathSepSet = ['/', '\'];

function IsPathSep(C: AnsiChar): Boolean; inline;
begin
  Result := C in PATH_SEPARATORS;
end;

{ Match a character class starting at AP.
  On entry AP^ must be '['. On success AP points past ']'.
  Returns whether AN^ matches the class. }
function MatchCharClass(var AP, AN: PChar): Boolean;
var
  LNegate: Boolean;
  LMatched: Boolean;
  LC: AnsiChar;
begin
  Result := False;
  if AP^ <> '[' then
    Exit;
  Inc(AP);

  LNegate := False;
  if (AP^ = '^') or (AP^ = '!') then
  begin
    LNegate := True;
    Inc(AP);
  end;

  { Empty class — matches nothing }
  if AP^ = ']' then
  begin
    { skip to closing ] }
    Inc(AP);
    while (AP^ <> #0) and (AP^ <> ']') do
      Inc(AP);
    if AP^ = ']' then
      Inc(AP);
    Exit(False);
  end;

  LMatched := False;
  while (AP^ <> #0) and (AP^ <> ']') do
  begin
    if (AP^ <> #0) and ((AP + 1)^ = '-') and ((AP + 2)^ <> ']') then
    begin
      { Range: c1-c2 }
      LC := AP^;
      Inc(AP, 2); { skip c1 and - }
      if (AnsiChar(AN^) >= LC) and (AnsiChar(AN^) <= AP^) then
        LMatched := True;
      Inc(AP);
    end
    else
    begin
      if AN^ = AP^ then
        LMatched := True;
      Inc(AP);
    end;
  end;

  { skip closing ] }
  if AP^ = ']' then
    Inc(AP);

  if LNegate then
    Result := not LMatched
  else
    Result := LMatched;
end;

{ Core recursive match. AP = pattern pointer, AN = name pointer. }
function GlobMatchInternal(AP, AN: PChar): Boolean;
begin
  while True do
  begin
    case AP^ of
      #0:
        Exit(AN^ = #0);
      '*':
      begin
        if (AP + 1)^ = '*' then
        begin
          { ** — matches any number of directory levels }
          Inc(AP, 2);
          { Skip optional separator after ** }
          if AP^ = '/' then
            Inc(AP)
          else if AP^ = '\' then
            Inc(AP);
          { Try matching remaining pattern at every position }
          while True do
          begin
            if GlobMatchInternal(AP, AN) then
              Exit(True);
            if AN^ = #0 then
              Exit(False);
            Inc(AN);
          end;
        end
        else
        begin
          { * — matches any chars except path separators }
          Inc(AP);
          { Try matching zero characters first (* can match empty) }
          if GlobMatchInternal(AP, AN) then
            Exit(True);
          while True do
          begin
            if (AN^ = #0) or IsPathSep(AnsiChar(AN^)) then
              Exit(False);
            Inc(AN);
            if GlobMatchInternal(AP, AN) then
              Exit(True);
          end;
        end;
      end;
      '?':
      begin
        if (AN^ = #0) or IsPathSep(AnsiChar(AN^)) then
          Exit(False);
        Inc(AP);
        Inc(AN);
      end;
      '[':
      begin
        if AN^ = #0 then
          Exit(False);
        if not MatchCharClass(AP, AN) then
          Exit(False);
        Inc(AN);
      end;
    else
      { Literal character }
      if AP^ <> AN^ then
        Exit(False);
      Inc(AP);
      Inc(AN);
    end;
  end;
end;

function GlobMatch(const APattern, AName: string): Boolean;
var
  LP, LN: PChar;
  LNameBuf: AnsiChar;
begin
  if Length(APattern) = 0 then
    Exit(AName = '');
  LP := @APattern[1];
  if Length(AName) > 0 then
    LN := @AName[1]
  else
  begin
    { Empty name: point to a #0 character so pointer is valid }
    LNameBuf := #0;
    LN := @LNameBuf;
  end;
  Result := GlobMatchInternal(LP, LN);
end;

{ FsGlob — file system glob }

var
  { Unit-level context used by the walk callback.
    Safe because FsGlob is single-threaded and not re-entrant. }
  GGlobDir: string;
  GGlobDirLen: Integer;
  GGlobPattern: string;
  GGlobResults: TStringArray;
  GGlobResultCount: Integer;

procedure FsGlobGrow;
begin
  if Length(GGlobResults) = 0 then
    SetLength(GGlobResults, 16)
  else
    SetLength(GGlobResults, Length(GGlobResults) * 2);
end;

function FsGlobWalkCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception): Boolean;
var
  LRelPath: string;
begin
  Result := True;
  if AErr <> nil then
    Exit;
  if AInfo.IsDir then
    Exit;
  { Compute relative path from the root dir }
  if Length(APath) > GGlobDirLen then
    LRelPath := Copy(APath, GGlobDirLen + 1, MaxInt)
  else
    LRelPath := APath;
  if GlobMatch(GGlobPattern, LRelPath) then
  begin
    if GGlobResultCount >= Length(GGlobResults) then
      FsGlobGrow;
    GGlobResults[GGlobResultCount] := APath;
    Inc(GGlobResultCount);
  end;
end;

procedure SortStrings(var A: TStringArray; ACount: Integer);
var
  LI, LJ: Integer;
  LTmp: string;
begin
  for LI := 1 to ACount - 1 do
  begin
    LTmp := A[LI];
    LJ := LI;
    while (LJ > 0) and (A[LJ - 1] > LTmp) do
    begin
      A[LJ] := A[LJ - 1];
      Dec(LJ);
    end;
    A[LJ] := LTmp;
  end;
end;

function FsGlob(const ADir, APattern: string): TStringArray;
var
  LDirWithSep: string;
begin
  LDirWithSep := FsPathTrimSep(ADir) + '/';
  GGlobDir := LDirWithSep;
  GGlobDirLen := Length(LDirWithSep);
  GGlobPattern := APattern;
  GGlobResults := nil;
  GGlobResultCount := 0;

  FsWalk(ADir, @FsGlobWalkCallback);

  SortStrings(GGlobResults, GGlobResultCount);
  SetLength(GGlobResults, GGlobResultCount);
  Result := GGlobResults;
end;

function FsGlob(const APattern: string): TStringArray;
begin
  Result := FsGlob('.', APattern);
end;

end.
