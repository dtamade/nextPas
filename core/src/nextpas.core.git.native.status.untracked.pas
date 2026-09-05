unit nextpas.core.git.native.status.untracked;

{$I nextpas.core.settings.inc}

{ status 未跟踪域: 忽略栈 + 未跟踪目录扫描 + 全局排除.
  依赖: base (status.*) + L0-L1 owner + ignore/config. }

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.status.base,
  nextpas.core.git.native.ignore;

function CompareString(const A, B: string; AData: Pointer): SizeInt;
procedure SortStrings(var AList: TStringArray);
function SortedHasString(const ASorted: TStringArray; const AValue: string): Boolean;
function GetIgnoreTextCached(const APath: string): string;
procedure CollectUntracked(const AWorkTree, ADirRel: string;
  const ATrackedSorted: TStringArray; AIgnore: TGitIgnoreMatcher;
  var AOut: TStringArray);
procedure PushInfoAndGlobalExcludes(AIgnore: TGitIgnoreMatcher; const AGitDir: string);
procedure AppendUntrackedGroup(var AResult: TGitNativeStatusArray;
  const AExtra: TGitNativeStatusArray);

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.collections.algorithms,
  nextpas.core.collections.arr.sort,
  nextpas.core.os.env,
  nextpas.core.git.native.config;

function CompareString(const A, B: string; AData: Pointer): SizeInt;
var
  LA, LB: TByteSpan;
begin
  if A = B then Exit(0);
  if A = '' then LA := TByteSpan.Empty
  else LA := TByteSpan.Create(PByte(@A[1]), SizeUInt(Length(A)));
  if B = '' then LB := TByteSpan.Empty
  else LB := TByteSpan.Create(PByte(@B[1]), SizeUInt(Length(B)));
  Result := SpanCompare(LA, LB);
end;

procedure SortStrings(var AList: TStringArray);
begin
  if Length(AList) < 2 then Exit;
  specialize Sort<string>(AList, @CompareString, nil);
end;

function SortedHasString(const ASorted: TStringArray; const AValue: string): Boolean;
var
  Idx: SizeInt;
begin
  Result := specialize BinarySearch<string>(ASorted, AValue, @CompareString, nil, Idx);
end;

var
  GIgnoreCache: array of record Path: string; Text: string; end;

function GetIgnoreTextCached(const APath: string): string;
var
  I: Integer;
begin
  for I := 0 to High(GIgnoreCache) do
    if GIgnoreCache[I].Path = APath then Exit(GIgnoreCache[I].Text);
  if not Exists(APath) then Exit('');
  try
    Result := ReadFileText(APath);
  except
    Result := '';
  end;
  I := Length(GIgnoreCache);
  SetLength(GIgnoreCache, I + 1);
  GIgnoreCache[I].Path := APath;
  GIgnoreCache[I].Text := Result;
end;

procedure CollectUntracked(const AWorkTree, ADirRel: string;
  const ATrackedSorted: TStringArray; AIgnore: TGitIgnoreMatcher;
  var AOut: TStringArray);
var
  DirAbs, Rel, IgnoreFile: string;
  Items: TDirEntryArray;
  HaveIgnore: Boolean;
  I: SizeInt;
  LCount, LCap: SizeInt;
  IgnoreText: string;
begin
  if ADirRel = '' then DirAbs := AWorkTree else DirAbs := PathJoin([AWorkTree, ADirRel]);
  IgnoreFile := PathJoin([DirAbs, '.gitignore']);
  HaveIgnore := Exists(IgnoreFile);
  if HaveIgnore then
  begin
    IgnoreText := GetIgnoreTextCached(IgnoreFile);
    if IgnoreText <> '' then
      AIgnore.PushSource(ADirRel, IgnoreText)
    else if Exists(IgnoreFile) then
      AIgnore.PushSource(ADirRel, '')
    else
      HaveIgnore := False;
    if (IgnoreText = '') and HaveIgnore then
      if not Exists(IgnoreFile) then HaveIgnore := False;
  end;
  LCount := Length(AOut);
  LCap := LCount;
  try
    Items := ReadDir(DirAbs);
    for I := 0 to High(Items) do
    begin
      if Items[I].Name = '.git' then Continue;
      if ADirRel = '' then Rel := Items[I].Name else Rel := PathJoin([ADirRel, Items[I].Name]);
      if Items[I].IsDir then
      begin
        if AIgnore.IsIgnored(Rel, True) then Continue;
        if Length(AOut) <> LCount then SetLength(AOut, LCount);
        CollectUntracked(AWorkTree, Rel, ATrackedSorted, AIgnore, AOut);
        LCount := Length(AOut);
        LCap := LCount;
      end
      else if (not SortedHasString(ATrackedSorted, Rel)) and (not AIgnore.IsIgnored(Rel, False)) then
      begin
        if LCount = LCap then
        begin
          LCap := SizeInt(GrowArrayCapacity(SizeUInt(LCap), SizeUInt(LCount + 1)));
          SetLength(AOut, LCap);
        end;
        AOut[LCount] := Rel;
        Inc(LCount);
      end;
    end;
    if LCap <> LCount then SetLength(AOut, LCount);
  finally
    if Length(AOut) <> LCount then SetLength(AOut, LCount);
    if HaveIgnore then AIgnore.PopSource;
  end;
end;

procedure AppendUntrackedGroup(var AResult: TGitNativeStatusArray;
  const AExtra: TGitNativeStatusArray);
var
  OldLen, I: Integer;
begin
  OldLen := Length(AResult);
  SetLength(AResult, OldLen + Length(AExtra));
  for I := 0 to High(AExtra) do
    AResult[OldLen + I] := AExtra[I];
end;

procedure PushInfoAndGlobalExcludes(AIgnore: TGitIgnoreMatcher; const AGitDir: string);
var
  ExcludeFile: string;
  Cfg: TGitConfig;
  GlobalPath: string;
  Expanded: string;
  LHome: string;
begin
  ExcludeFile := PathJoin([AGitDir, 'info', 'exclude']);
  if Exists(ExcludeFile) then
  begin
    try
      AIgnore.PushSource('', ReadFileText(ExcludeFile));
    except
      on E: ENotFoundError do ;
      on E: EIOError do ;
      else raise;
    end;
  end;
  try
    Cfg := GitReadConfig(AGitDir);
    GlobalPath := Trim(GitConfigGet(Cfg, 'core.excludesfile'));
  except
    GlobalPath := '';
  end;
  if GlobalPath = '' then Exit;
  if (Length(GlobalPath) > 0) and (GlobalPath[1] = '~') then
  begin
    LHome := UserHomeDir;
    if GlobalPath = '~' then Expanded := LHome
    else if (Length(GlobalPath) >= 2) and (GlobalPath[2] = '/') then
      Expanded := PathJoin([LHome, Copy(GlobalPath, 3, MaxInt)])
    else Expanded := GlobalPath;
    GlobalPath := Expanded;
  end;
  if Exists(GlobalPath) then
  begin
    try
      AIgnore.PushSource('', ReadFileText(GlobalPath));
    except
      on E: ENotFoundError do ;
      on E: EIOError do ;
      else raise;
    end;
  end;
end;

end.
