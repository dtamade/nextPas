unit nextpas.core.fs.glob;
{**
 * @desc Glob 模式匹配：纯字符串匹配 + 文件系统 glob 遍历。
 *}

{$I nextpas.core.settings.inc}

interface

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

implementation

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

end.
