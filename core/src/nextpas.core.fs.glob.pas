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

{** @desc 非递归列出目录中匹配模式的文件名（门面 Glob 单源实现） *}
function Glob(const ADir, APattern: string): TStringArray;

implementation

uses
  nextpas.core.errors,
  nextpas.core.fs.base,
  nextpas.core.fs.dir,
  nextpas.core.fs.path;

{ GlobMatch internals — linear chunk matching (O(pat × name), no backtracking) }

type
  TPathSepSet = set of AnsiChar;

const
  PATH_SEPARATORS: TPathSepSet = ['/', '\'];

function IsPathSep(C: AnsiChar): Boolean; inline;
begin
  Result := C in PATH_SEPARATORS;
end;

{** @desc Check if character at pattern position AP matches character AN.
  Advances AP past the matched portion (char class, escape, or literal).
  Does NOT advance AP on failure — caller decides. }
function MatchOne(var AP: PChar; AN: PChar): Boolean;
var
  LNegate: Boolean;
  LMatched: Boolean;
  P: PChar;
begin
  case AP^ of
    '?':
    begin
      if (AN^ = #0) or IsPathSep(AnsiChar(AN^)) then
        Exit(False);
      Inc(AP);
      Result := True;
    end;
    '[':
    begin
      if AN^ = #0 then
        Exit(False);
      P := AP;
      Inc(P);
      LNegate := False;
      if (P^ = '^') or (P^ = '!') then
      begin
        LNegate := True;
        Inc(P);
      end;
      { Empty class: [] or [!] — glob semantics: scan to next ] and invert }
      if P^ = ']' then
      begin
        Inc(P);
        while (P^ <> #0) and (P^ <> ']') do
          Inc(P);
        if P^ = ']' then
          Inc(P);
        AP := P;
        Exit(LNegate);
      end;
      LMatched := False;
      while (P^ <> #0) and (P^ <> ']') do
      begin
        if ((P + 1)^ = '-') and ((P + 2)^ <> ']') and ((P + 2)^ <> #0) then
        begin
          if (AnsiChar(AN^) >= AnsiChar(P^)) and
             (AnsiChar(AN^) <= AnsiChar((P + 2)^)) then
            LMatched := True;
          Inc(P, 3);
        end
        else
        begin
          if AN^ = P^ then
            LMatched := True;
          Inc(P);
        end;
      end;
      if P^ = ']' then
        Inc(P);
      AP := P;
      if LNegate then
        Result := not LMatched
      else
        Result := LMatched;
    end;
  else
    { Literal character }
    Result := (AP^ <> #0) and (AN^ = AP^);
    if Result then
      Inc(AP);
  end;
end;

{** @desc Check if name contains any path separator character. }
function NameHasSep(AN: PChar): Boolean;
begin
  while AN^ <> #0 do
  begin
    if IsPathSep(AnsiChar(AN^)) then
      Exit(True);
    Inc(AN);
  end;
  Result := False;
end;

{** @desc Core iterative glob match with dual star tracking.
  Guarantees polynomial O(name × pattern) time — no exponential backtracking.

  Two independent trackers, because '*' and '**' have different reach:
    LSStar — most recent single '*' (segment-local: cannot eat a separator)
    LDStar — most recent '**'      (cross-segment: eats any character)

  On mismatch we first try to extend the single '*'; when it hits a separator
  (exhausted) we fall back to extending '**', which resets the single tracker
  so matching resumes from the '**' anchor. Each extension advances a name
  pointer that never rewinds past its anchor, bounding total work. }
function GlobMatchInternal(AP, AN: PChar): Boolean;
var
  LSStarP, LSStarN: PChar;   { single '*' : resume pattern / name anchor }
  LDStarP, LDStarN: PChar;   { double '**': resume pattern / name anchor }
  LIsDouble: Boolean;
begin
  if AP^ = #0 then
    Exit(AN^ = #0);

  LSStarP := nil; LSStarN := nil;
  LDStarP := nil; LDStarN := nil;

  while AN^ <> #0 do
  begin
    if AP^ = '*' then
    begin
      { Collapse consecutive stars; detect ** }
      LIsDouble := False;
      while AP^ = '*' do
      begin
        if (AP + 1)^ = '*' then
          LIsDouble := True;
        Inc(AP);
      end;
      if LIsDouble then
      begin
        { '**/' means "zero or more path segments" — the slash is optional }
        if (AP^ = '/') or (AP^ = '\') then
          Inc(AP);
        LDStarP := AP;
        LDStarN := AN;
        { A new '**' supersedes any pending single '*' (segment boundary) }
        LSStarP := nil;
        LSStarN := nil;
      end
      else
      begin
        LSStarP := AP;
        LSStarN := AN;
      end;
      Continue;
    end;

    if MatchOne(AP, AN) then
    begin
      Inc(AN);
      Continue;
    end;

    { Mismatch — extend single '*' first (segment-local) }
    if (LSStarP <> nil) and (not IsPathSep(AnsiChar(LSStarN^))) then
    begin
      Inc(LSStarN);
      AN := LSStarN;
      AP := LSStarP;
      Continue;
    end;

    { Single '*' exhausted or absent — fall back to '**' (cross-segment) }
    if LDStarP <> nil then
    begin
      Inc(LDStarN);
      AN := LDStarN;
      AP := LDStarP;
      LSStarP := nil;
      LSStarN := nil;
      Continue;
    end;

    Exit(False);
  end;

  { Name exhausted: skip any trailing stars (and their optional slash) }
  while AP^ = '*' do
  begin
    while AP^ = '*' do
      Inc(AP);
    if (AP^ = '/') or (AP^ = '\') then
      Inc(AP);
  end;

  Exit(AP^ = #0);
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

type
  TFsGlobState = record
    Dir: string;
    DirLen: Integer;
    Pattern: string;
    Results: TStringArray;
    Count: Integer;
  end;
  PFsGlobState = ^TFsGlobState;

function FsGlobWalkCallback(const APath: string; const AInfo: TFileInfo;
  const AErr: Exception; AUserData: Pointer): Boolean;
var
  LState: PFsGlobState;
  LRelPath: string;
begin
  LState := PFsGlobState(AUserData);
  Result := True;
  if AErr <> nil then
    Exit;
  if AInfo.IsDir then
    Exit;
  { Compute relative path from the root dir }
  if Length(APath) > LState^.DirLen then
    LRelPath := Copy(APath, LState^.DirLen + 1, MaxInt)
  else
    LRelPath := APath;
  if GlobMatch(LState^.Pattern, LRelPath) then
  begin
    if LState^.Count >= Length(LState^.Results) then
    begin
      if Length(LState^.Results) = 0 then
        SetLength(LState^.Results, 16)
      else
        SetLength(LState^.Results, Length(LState^.Results) * 2);
    end;
    LState^.Results[LState^.Count] := APath;
    Inc(LState^.Count);
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
  LState: TFsGlobState;
begin
  LState.Dir := FsPathTrimSep(ADir) + '/';
  LState.DirLen := Length(LState.Dir);
  LState.Pattern := APattern;
  LState.Results := nil;
  LState.Count := 0;

  FsWalkEx(ADir, @FsGlobWalkCallback, @LState);

  SortStrings(LState.Results, LState.Count);
  SetLength(LState.Results, LState.Count);
  Result := LState.Results;
end;

function FsGlob(const APattern: string): TStringArray;
begin
  Result := FsGlob('.', APattern);
end;

function Glob(const ADir, APattern: string): TStringArray;
var
  LEntries: TDirEntryArray;
  LCount, I: Integer;
begin
  Result := nil;
  try
    LEntries := FsReadDir(ADir);
  except
    on E: ENotFoundError do
      Exit;
  end;
  LCount := 0;
  for I := 0 to High(LEntries) do
  begin
    if FsPathMatch(APattern, LEntries[I].Name) then
    begin
      if LCount >= Length(Result) then
      begin
        if Length(Result) = 0 then
          SetLength(Result, 16)
        else
          SetLength(Result, Length(Result) * 2);
      end;
      Result[LCount] := FsPathJoin([ADir, LEntries[I].Name]);
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);
end;

end.
