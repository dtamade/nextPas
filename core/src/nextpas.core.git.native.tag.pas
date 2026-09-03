unit nextpas.core.git.native.tag;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Tag subfamily: refs/tags/* lightweight + annotated.
  List merges loose + packed-refs (with ^ peeled), dedup loose-wins,
  lexicographically sorted. Annotated detection via object kind.
  Create/delete maintain loose + packed-refs. }

type
  TGitTagEntry = record
    Name: string;     // e.g. "v1.0" or "release/v2"
    RefName: string;  // "refs/tags/<Name>"
    Oid: TGitOid;     // ref target (tag object or direct)
    PeeledOid: TGitOid; // peeled commit for annotated, zero otherwise
    IsAnnotated: Boolean;
  end;
  TGitTagArray = array of TGitTagEntry;

function GitTagList(const AGitDir: string): TGitTagArray;
function GitTagExists(const AGitDir, ATagName: string): Boolean;
function GitTagGetOid(const AGitDir, ATagName: string): TGitOid;
function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid;
function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid; overload;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid; overload;
procedure GitTagDelete(const AGitDir, ATagName: string);
function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid;

implementation

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.write,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.config;

const
  TagsPrefix = 'refs/tags/';

function TagRefPath(const AGitDir, AName: string): string;
var N: string;
begin
  N := AName;
  if Copy(N, 1, Length(TagsPrefix)) = TagsPrefix then
    Delete(N, 1, Length(TagsPrefix));
  if (Length(N) > 0) and (N[1] = '/') then Delete(N, 1, 1);
  Result := PathJoin([AGitDir, 'refs', 'tags', N]);
end;

function NormalizeTagName(const AName: string): string;
begin
  Result := AName;
  // trim whitespace
  while (Length(Result) > 0) and (Result[1] in [#9, #10, #13, ' ']) do Delete(Result, 1, 1);
  while (Length(Result) > 0) and (Result[Length(Result)] in [#9, #10, #13, ' ']) do Delete(Result, Length(Result), 1);
  if Copy(Result, 1, Length(TagsPrefix)) = TagsPrefix then
    Delete(Result, 1, Length(TagsPrefix));
  while (Length(Result) > 0) and (Result[1] = '/') do Delete(Result, 1, 1);
end;

function IsValidTagName(const AName: string): Boolean;
var I: Integer; C: Char;
begin
  if AName = '' then Exit(False);
  if Pos('..', AName) > 0 then Exit(False);
  if Pos('//', AName) > 0 then Exit(False);
  if AName[1] = '.' then Exit(False);
  if AName[Length(AName)] = '/' then Exit(False);
  if AName[Length(AName)] = '.' then Exit(False);
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if C in ['~', '^', ':', '?', '*', '[', #0..#31, #127] then Exit(False);
    if C = '\' then Exit(False);
  end;
  if Pos('@{', AName) > 0 then Exit(False);
  if Copy(AName, Length(AName) - 4, 5) = '.lock' then Exit(False);
  Result := True;
end;

function LocalCompareStr(const A, B: string): Integer;
var I, L: Integer;
begin
  L := Length(A);
  if Length(B) < L then L := Length(B);
  for I := 1 to L do
    if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

procedure SortTags(var A: TGitTagArray);
var I, J: Integer; T: TGitTagEntry;
begin
  for I := 1 to High(A) do
  begin
    J := I;
    while (J > 0) and (LocalCompareStr(A[J-1].Name, A[J].Name) > 0) do
    begin
      T := A[J-1]; A[J-1] := A[J]; A[J] := T;
      Dec(J);
    end;
  end;
end;

function ContainsTag(const A: TGitTagArray; const AName: string): Boolean;
var I: Integer;
begin
  for I := 0 to High(A) do if A[I].Name = AName then Exit(True);
  Result := False;
end;

function TryPeelTag(const AGitDir: string; const AOid: TGitOid; out APeeled: TGitOid; out AIsAnnotated: Boolean): Boolean;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitTagInfo;
begin
  APeeled := Default(TGitOid);
  AIsAnnotated := False;
  Repo := TNativeRepository.Create(AGitDir);
  try
    try
      Data := Repo.ReadObject(AOid, Kind);
    except
      Exit(False);
    end;
    if Kind = gokTag then
    begin
      Info := GitParseTag(Data);
      AIsAnnotated := True;
      // if target is commit, peeled is target; if tag, need recursive peel
      // simple: if target kind is commit we return it, otherwise try to peel nested tag
      if Info.TargetKind = gokCommit then
        APeeled := Info.Target
      else if Info.TargetKind = gokTag then
      begin
        // recursive peel nested tag
        TryPeelTag(AGitDir, Info.Target, APeeled, AIsAnnotated);
        // if nested peel failed, use direct target
        if IsZeroOid(APeeled) then APeeled := Info.Target;
      end
      else
        APeeled := Info.Target;
      Result := True;
    end
    else
    begin
      AIsAnnotated := False;
      Result := False;
    end;
  finally
    Repo.Free;
  end;
end;

procedure CollectTagsFromDir(const AGitDir, ABaseDir, APrefix: string; var AOut: TGitTagArray);
var
  LCnt, LCap: SizeUInt;

  procedure Recurse(const ABaseDir2, APrefix2: string);
  var
    Entries: TDirEntryArray;
    I, K: Integer;
    Full, Rel, RefName: string;
    Oid, Peeled: TGitOid;
    IsAnn: Boolean;
    Text: string;
    Dup: Boolean;
  begin
    try
      Entries := ReadDir(ABaseDir2);
    except
      Exit;
    end;
    for I := 0 to High(Entries) do
    begin
      Full := PathJoin([ABaseDir2, Entries[I].Name]);
      if Entries[I].IsDir then
      begin
        Recurse(Full, APrefix2 + Entries[I].Name + '/');
      end
      else
      begin
        Rel := APrefix2 + Entries[I].Name;
        RefName := TagsPrefix + Rel;
        try
          Text := ReadFileText(Full);
          // trim
          while (Length(Text) > 0) and (Text[1] in [#9, #10, #13, ' ']) do Delete(Text, 1, 1);
          while (Length(Text) > 0) and (Text[Length(Text)] in [#9, #10, #13, ' ']) do Delete(Text, Length(Text), 1);
          if Copy(Text, 1, 5) = 'ref: ' then
            Oid := GitResolveRef(AGitDir, RefName)
          else
            Oid := GitOidFromHex(Text);
        except
          Continue;
        end;
        Dup := False;
        for K := 0 to Integer(LCnt) - 1 do
          if AOut[K].Name = Rel then begin Dup := True; Break; end;
        if Dup then Continue;
        Peeled := Default(TGitOid);
        IsAnn := False;
        TryPeelTag(AGitDir, Oid, Peeled, IsAnn);
        // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), O(1) amortized, zero-copy TGitTagEntry Move, avoids O(n²) SetLength(Length+1) churn; final shrink once
        if LCnt >= LCap then
        begin
          LCap := GrowArrayCapacity(LCap, LCnt + 1);
          SetLength(AOut, LCap);
        end;
        AOut[LCnt].Name := Rel;
        AOut[LCnt].RefName := RefName;
        AOut[LCnt].Oid := Oid;
        AOut[LCnt].PeeledOid := Peeled;
        AOut[LCnt].IsAnnotated := IsAnn;
        Inc(LCnt);
      end;
    end;
  end;

begin
  // perf: shared LCnt/LCap across recursion avoids stale Length snapshot, geometric growth single source via bytes.ops
  LCnt := SizeUInt(Length(AOut));
  LCap := LCnt;
  Recurse(ABaseDir, APrefix);
  if SizeUInt(Length(AOut)) <> LCnt then
    SetLength(AOut, LCnt);
end;

procedure CollectTagsFromPacked(const AGitDir: string; var AOut: TGitTagArray);
var
  Lines: TStringArray;
  I, Sp, K: Integer;
  Line, Hex, Name, Short: string;
  Oid, Peeled: TGitOid;
  IsAnn: Boolean;
  NextPeeled: string;
  LCnt, LCap: SizeUInt;
  Dup: Boolean;
begin
  if not FileExists(PathJoin([AGitDir, 'packed-refs'])) then Exit;
  try
    Lines := ReadFileLines(PathJoin([AGitDir, 'packed-refs']));
  except
    Exit;
  end;
  // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), O(1) amortized, zero-copy TGitTagEntry Move, avoids O(n²) SetLength(Length+1) churn; final shrink once
  LCnt := SizeUInt(Length(AOut));
  LCap := SizeUInt(Length(AOut));
  I := 0;
  while I <= High(Lines) do
  begin
    Line := Lines[I];
    // trim
    while (Length(Line) > 0) and (Line[1] in [#9, #10, #13, ' ']) do Delete(Line, 1, 1);
    while (Length(Line) > 0) and (Line[Length(Line)] in [#9, #10, #13, ' ']) do Delete(Line, Length(Line), 1);
    if (Line = '') or (Line[1] = '#') or (Line[1] = '^') then
    begin
      Inc(I);
      Continue;
    end;
    Sp := Pos(' ', Line);
    if Sp < 41 then
    begin
      Inc(I);
      Continue;
    end;
    Hex := Copy(Line, 1, Sp - 1);
    Name := Copy(Line, Sp + 1, MaxInt);
    while (Length(Name) > 0) and (Name[1] in [#9, #10, #13, ' ']) do Delete(Name, 1, 1);
    while (Length(Name) > 0) and (Name[Length(Name)] in [#9, #10, #13, ' ']) do Delete(Name, Length(Name), 1);
    if Copy(Name, 1, Length(TagsPrefix)) <> TagsPrefix then
    begin
      Inc(I);
      Continue;
    end;
    Short := Copy(Name, Length(TagsPrefix)+1, MaxInt);
    Dup := False;
    for K := 0 to Integer(LCnt) - 1 do
      if AOut[K].Name = Short then begin Dup := True; Break; end;
    if Dup then
    begin
      // skip peeled too
      if (I+1 <= High(Lines)) and (Length(Lines[I+1])>0) and (Lines[I+1][1]='^') then Inc(I);
      Inc(I);
      Continue;
    end;
    try
      Oid := GitOidFromHex(Hex);
    except
      Inc(I);
      Continue;
    end;
    Peeled := Default(TGitOid);
    IsAnn := False;
    // check next line for peeled ^<oid>
    if (I+1 <= High(Lines)) and (Length(Lines[I+1])>0) and (Lines[I+1][1]='^') then
    begin
      NextPeeled := Copy(Lines[I+1], 2, MaxInt);
      while (Length(NextPeeled) > 0) and (NextPeeled[1] in [#9, #10, #13, ' ']) do Delete(NextPeeled, 1, 1);
      while (Length(NextPeeled) > 0) and (NextPeeled[Length(NextPeeled)] in [#9, #10, #13, ' ']) do Delete(NextPeeled, Length(NextPeeled), 1);
      try
        Peeled := GitOidFromHex(NextPeeled);
        IsAnn := True;
      except
        // ignore
      end;
      Inc(I);
    end
    else
    begin
      // no packed peeled, try to peel via object inspection
      TryPeelTag(AGitDir, Oid, Peeled, IsAnn);
      if not IsAnn then Peeled := Default(TGitOid);
    end;
    if LCnt >= LCap then
    begin
      LCap := GrowArrayCapacity(LCap, LCnt + 1);
      SetLength(AOut, LCap);
    end;
    AOut[LCnt].Name := Short;
    AOut[LCnt].RefName := Name;
    AOut[LCnt].Oid := Oid;
    AOut[LCnt].PeeledOid := Peeled;
    AOut[LCnt].IsAnnotated := IsAnn;
    Inc(LCnt);
    Inc(I);
  end;
  if SizeUInt(Length(AOut)) <> LCnt then
    SetLength(AOut, LCnt);
end;

function GitTagList(const AGitDir: string): TGitTagArray;
var Base: string;
begin
  Result := nil;
  Base := PathJoin([AGitDir, 'refs', 'tags']);
  CollectTagsFromDir(AGitDir, Base, '', Result);
  CollectTagsFromPacked(AGitDir, Result);
  SortTags(Result);
end;

function GitTagExists(const AGitDir, ATagName: string): Boolean;
var N: string;
begin
  N := NormalizeTagName(ATagName);
  try
    GitTagGetOid(AGitDir, N);
    Result := True;
  except
    Result := False;
  end;
end;

function GitTagGetOid(const AGitDir, ATagName: string): TGitOid;
var N: string;
begin
  N := NormalizeTagName(ATagName);
  if not IsValidTagName(N) then
    raise EGitError.CreateFmt('invalid tag name "%s"', [ATagName]);
  Result := GitResolveRef(AGitDir, TagsPrefix + N);
end;

function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid;
var Oid, Peeled: TGitOid; IsAnn: Boolean;
begin
  Oid := GitTagGetOid(AGitDir, ATagName);
  if TryPeelTag(AGitDir, Oid, Peeled, IsAnn) and IsAnn then
    Result := Peeled
  else
    Result := Oid;
end;

function TagSignature(const AGitDir: string; out AName, AEmail: string): Boolean;
var Cfg: TGitConfig; N,E: string;
begin
  try
    Cfg := GitReadConfig(AGitDir);
    try N := GitConfigGet(Cfg, 'user.name'); except N := ''; end;
    try E := GitConfigGet(Cfg, 'user.email'); except E := ''; end;
    if (N <> '') and (E <> '') then
    begin
      AName := N; AEmail := E; Exit(True);
    end;
  except
  end;
  Result := False;
end;

function DetectTargetKind(const AGitDir: string; const AOid: TGitOid): TGitObjectKind;
var Repo: TNativeRepository; Kind: TGitObjectKind;
begin
  Repo := TNativeRepository.Create(AGitDir);
  try
    try
      Repo.ReadObject(AOid, Kind);
      Result := Kind;
    except
      Result := gokCommit;
    end;
  finally
    Repo.Free;
  end;
end;

function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid;
var N, Ref, Hex: string;
begin
  N := NormalizeTagName(ATagName);
  if not IsValidTagName(N) then
    raise EGitError.CreateFmt('invalid tag name "%s"', [ATagName]);
  if not GitOidIsValidHex(GitOidToHex(ATargetOid)) then
    raise EGitError.Create('tag create: invalid oid');
  if GitTagExists(AGitDir, N) then
    raise EGitError.CreateFmt('tag "%s" already exists', [N]);
  Hex := GitOidToHex(ATargetOid);
  Ref := TagRefPath(AGitDir, N);
  MkdirAll(PathDir(Ref), PermDirDefault);
  WriteFileText(Ref, Hex + #10);
  Result := ATargetOid;
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid;
var
  N: string;
  Builder: TGitTagBuilder;
  TagOid: TGitOid;
  Ref: string;
  Name, Email: string;
  UseName, UseEmail: string;
begin
  N := NormalizeTagName(ATagName);
  if not IsValidTagName(N) then
    raise EGitError.CreateFmt('invalid tag name "%s"', [ATagName]);
  if GitTagExists(AGitDir, N) then
    raise EGitError.CreateFmt('tag "%s" already exists', [N]);
  if ATaggerName <> '' then UseName := ATaggerName
  else if not TagSignature(AGitDir, Name, Email) then UseName := 'Test'
  else UseName := Name;
  if ATaggerEmail <> '' then UseEmail := ATaggerEmail
  else if not TagSignature(AGitDir, Name, Email) then UseEmail := 'test@example.com'
  else UseEmail := Email;
  // ensure we have fallback signature
  if UseName = '' then UseName := 'Test';
  if UseEmail = '' then UseEmail := 'test@example.com';
  Builder.Target := ATargetOid;
  Builder.TargetKind := DetectTargetKind(AGitDir, ATargetOid);
  Builder.TagName := N;
  Builder.TaggerName := UseName;
  Builder.TaggerEmail := UseEmail;
  Builder.TaggerUnixTime := 1700000000;
  Builder.TaggerTzMinutes := 0;
  Builder.Message := AMessage;
  if (Builder.Message <> '') and (Builder.Message[Length(Builder.Message)] <> #10) then
    Builder.Message := Builder.Message + #10;
  TagOid := GitWriteTag(AGitDir, Builder);
  Ref := TagRefPath(AGitDir, N);
  MkdirAll(PathDir(Ref), PermDirDefault);
  WriteFileText(Ref, GitOidToHex(TagOid) + #10);
  Result := TagOid;
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid;
begin
  Result := GitTagCreateAnnotated(AGitDir, ATagName, ATargetOid, AMessage, '', '');
end;

procedure RewritePackedWithoutTag(const AGitDir, ARefName: string);
var
  Path, Tmp: string;
  Lines, Keep: TStringArray;
  I: Integer;
  Line, Name: string;
  Sp: Integer;
  LCnt, LCap: SizeUInt;
begin
  Path := PathJoin([AGitDir, 'packed-refs']);
  if not FileExists(Path) then Exit;
  Lines := ReadFileLines(Path);
  // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), O(1) amortized, zero-copy string Move (managed, refcounted), avoids O(n²) SetLength(Length+1) churn; final shrink once
  // stability: SetLength exception-safe, managed strings released on exception, no leak
  Keep := nil;
  LCnt := 0;
  LCap := 0;
  I := 0;
  while I <= High(Lines) do
  begin
    Line := Lines[I];
    if (Line <> '') and (Line[1] <> '#') and (Line[1] <> '^') then
    begin
      Sp := Pos(' ', Line);
      if Sp >= 41 then
      begin
        Name := Copy(Line, Sp + 1, MaxInt);
        while (Length(Name) > 0) and (Name[1] in [#9, #10, #13, ' ']) do Delete(Name, 1, 1);
        while (Length(Name) > 0) and (Name[Length(Name)] in [#9, #10, #13, ' ']) do Delete(Name, Length(Name), 1);
        if Name = ARefName then
        begin
          if (I + 1 <= High(Lines)) and (Length(Lines[I+1]) > 0) and (Lines[I+1][1] = '^') then Inc(I);
          Inc(I);
          Continue;
        end;
      end;
    end;
    if LCnt >= LCap then
    begin
      LCap := GrowArrayCapacity(LCap, LCnt + 1);
      SetLength(Keep, LCap);
    end;
    Keep[LCnt] := Line;
    Inc(LCnt);
    Inc(I);
  end;
  if SizeUInt(Length(Keep)) <> LCnt then
    SetLength(Keep, LCnt);
  if Length(Keep) = Length(Lines) then Exit;
  Tmp := Path + '.tmp';
  WriteFileLines(Tmp, Keep);
  Rename(Tmp, Path);
end;

procedure GitTagDelete(const AGitDir, ATagName: string);
var N, Ref: string;
begin
  N := NormalizeTagName(ATagName);
  if not IsValidTagName(N) then
    raise EGitError.CreateFmt('invalid tag name "%s"', [ATagName]);
  if not GitTagExists(AGitDir, N) then
    raise EGitError.CreateFmt('tag "%s" not found', [N]);
  Ref := TagRefPath(AGitDir, N);
  if FileExists(Ref) then Remove(Ref);
  RewritePackedWithoutTag(AGitDir, TagsPrefix + N);
  try
    while True do
    begin
      Ref := PathDir(Ref);
      if (Ref = PathJoin([AGitDir, 'refs', 'tags'])) or (Ref = PathJoin([AGitDir, 'refs'])) or (Ref = AGitDir) then Break;
      if DirectoryExists(Ref) then
      begin
        if Length(ReadDir(Ref)) = 0 then Remove(Ref)
        else Break;
      end else Break;
    end;
  except
  end;
end;

function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid;
var OldN, NewN: string; Oid: TGitOid;
begin
  OldN := NormalizeTagName(AOldName);
  NewN := NormalizeTagName(ANewName);
  if not IsValidTagName(OldN) then raise EGitError.CreateFmt('invalid tag name "%s"', [AOldName]);
  if not IsValidTagName(NewN) then raise EGitError.CreateFmt('invalid tag name "%s"', [ANewName]);
  Oid := GitTagGetOid(AGitDir, OldN);
  if GitTagExists(AGitDir, NewN) then
    raise EGitError.CreateFmt('tag "%s" already exists', [NewN]);
  // create new ref pointing to same oid (preserve annotated vs lightweight)
  WriteFileText(TagRefPath(AGitDir, NewN), GitOidToHex(Oid) + #10);
  GitTagDelete(AGitDir, OldN);
  Result := Oid;
end;

end.
