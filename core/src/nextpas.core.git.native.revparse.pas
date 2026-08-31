unit nextpas.core.git.native.revparse;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Pure-Pascal rev-parse for the native subfamily.

  Counterpart of `revision.c` / `refs.c` dwim plus `sha1_name.c`
  suffix handling, covering the subset needed for reset/checkout
  and general tooling:

    <rev>                 := HEAD | <ref> | <40-hex>
    <rev>~<n>             := first-parent walk <n> steps (empty <n> => 1)
    <rev>^<n>             := <n>-th parent (empty <n> => 1)
    <rev>^{<type>}        := peel tag chain to <type> (empty | commit|tree|blob|tag)
    <rev>^{}              := peel to non-tag (deref)

  Parent steps are left-to-right: HEAD~2^1 means (HEAD~2)^1.
  Base ref dwim tries literal, refs/heads/<name>, refs/tags/<name>
  after the HEAD special case. Hex oids are verified to exist.
  Peel walks tag objects via objmodel until the requested kind is
  reached; 40-hex chains like <hex>~1 are supported.

  Errors surface as EGitError, matching git's --verify failure. }

function GitRevParse(const AGitDir, ARev: string): TGitOid;
function GitRevParseCommit(const AGitDir, ARev: string): TGitOid;

implementation

uses
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel;

function IsAllHex(const S: string): Boolean;
var I: Integer;
begin
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9','a'..'f','A'..'F']) then Exit(False);
  Result := True;
end;

function PeelOid(ARepo: TNativeRepository; AOid: TGitOid; const AExpect: string): TGitOid;
var Kind: TGitObjectKind;
    Data: TBytes;
    TagInfo: TGitTagInfo;
    ExpectKind: TGitObjectKind;
    HasExpect: Boolean;
begin
  Result := AOid;
  HasExpect := AExpect <> '';
  if HasExpect then
    ExpectKind := GitKindFromString(AExpect)
  else
    ExpectKind := gokCommit; // dummy, not used when not HasExpect

  Data := ARepo.ReadObject(Result, Kind);
  if not HasExpect then
  begin
    // ^{} : peel until non-tag
    while Kind = gokTag do
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Data := ARepo.ReadObject(Result, Kind);
    end;
    Exit;
  end;

  // ^{commit|tree|blob|tag}
  // handle commit->tree dereference for ^{tree}
  if (ExpectKind = gokTree) and (Kind = gokCommit) then
  begin
    Result := GitParseCommit(Data).Tree;
    Exit;
  end;
  while True do
  begin
    if Kind = ExpectKind then Exit;
    if Kind = gokTag then
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Data := ARepo.ReadObject(Result, Kind);
      if (ExpectKind = gokTree) and (Kind = gokCommit) then
      begin
        Result := GitParseCommit(Data).Tree;
        Exit;
      end;
      Continue;
    end;
    if (ExpectKind = gokTree) and (Kind = gokCommit) then
    begin
      Result := GitParseCommit(Data).Tree;
      Exit;
    end;
    raise EGitError.CreateFmt('rev-parse: cannot peel %s to %s', [GitOidToHex(AOid), AExpect]);
  end;
end;

function ResolveTilde(ARepo: TNativeRepository; AOid: TGitOid; ACount: Integer): TGitOid;
var I: Integer;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
begin
  Result := AOid;
  for I := 1 to ACount do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin
      Result := PeelOid(ARepo, Result, 'commit');
      Data := ARepo.ReadObject(Result, Kind);
    end;
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('rev-parse: object %s is not a commit', [GitOidToHex(Result)]);
    Info := GitParseCommit(Data);
    if Length(Info.Parents) = 0 then
      raise EGitError.CreateFmt('rev-parse: commit %s has no parents', [GitOidToHex(Result)]);
    Result := Info.Parents[0];
  end;
end;

function ResolveCaret(ARepo: TNativeRepository; AOid: TGitOid; AIndex: Integer): TGitOid;
var Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    TagInfo: TGitTagInfo;
begin
  // caret may peel tag first if needed? git allows HEAD^{tag}^ etc.
  Data := ARepo.ReadObject(AOid, Kind);
  if Kind = gokTag then
  begin
    AOid := PeelOid(ARepo, AOid, 'commit');
    Data := ARepo.ReadObject(AOid, Kind);
  end;
  if Kind <> gokCommit then
    raise EGitError.CreateFmt('rev-parse: object %s is not a commit', [GitOidToHex(AOid)]);
  Info := GitParseCommit(Data);
  if (AIndex < 1) or (AIndex > Length(Info.Parents)) then
    raise EGitError.CreateFmt('rev-parse: commit %s has no parent %d', [GitOidToHex(AOid), AIndex]);
  Result := Info.Parents[AIndex - 1];
end;

function ResolveRefDwim(const AGitDir, AName: string): TGitOid;
var TryNames: array[0..3] of string;
    I: Integer;
begin
  if AName = 'HEAD' then
    Exit(GitResolveHead(AGitDir));
  // exact first
  try
    Result := GitResolveRef(AGitDir, AName);
    Exit;
  except
    on E: EGitError do ;
  end;
  TryNames[0] := 'refs/heads/' + AName;
  TryNames[1] := 'refs/tags/' + AName;
  TryNames[2] := 'refs/remotes/origin/' + AName;
  TryNames[3] := 'refs/heads/' + AName; // duplicate to keep 4 slots
  for I := 0 to 2 do
  begin
    try
      Result := GitResolveRef(AGitDir, TryNames[I]);
      Exit;
    except
      on E: EGitError do ;
    end;
  end;
  raise EGitError.CreateFmt('rev-parse: cannot resolve "%s"', [AName]);
end;

function TryStripPeel(const ARev: string; out ABase, AExpect: string): Boolean;
var P: Integer;
    Inside: string;
    EndPos: Integer;
begin
  Result := False;
  ABase := '';
  AExpect := '';
  if Length(ARev) < 3 then Exit;
  if ARev[Length(ARev)] <> '}' then Exit;
  P := Pos('^{', ARev);
  if P = 0 then Exit;
  // ensure ^{ is the last occurrence before }
  EndPos := Length(ARev);
  // find last ^{
  P := 0;
  for EndPos := Length(ARev) - 2 downto 1 do
    if (ARev[EndPos] = '^') and (ARev[EndPos + 1] = '{') then
    begin P := EndPos; Break; end;
  if P = 0 then Exit;
  Inside := Copy(ARev, P + 2, Length(ARev) - P - 2);
  // Inside ends with }, we already know last char is }, so strip it
  if (Length(Inside) > 0) and (Inside[Length(Inside)] = '}') then
    SetLength(Inside, Length(Inside) - 1);
  // Inside may be '' for ^{}
  if (Inside <> '') and (Inside <> 'commit') and (Inside <> 'tree') and (Inside <> 'blob') and (Inside <> 'tag') then
    Exit; // unknown peel type, let caller treat as no suffix -> will fail later as base
  ABase := Copy(ARev, 1, P - 1);
  AExpect := LowerCase(Inside);
  Result := True;
end;

function TryStripTildeCaret(const ARev: string; out ABase, AOp, AArg: string): Boolean;
var I, NumStart, NumEnd: Integer;
    NumStr: string;
begin
  Result := False;
  ABase := '';
  AOp := '';
  AArg := '';
  if Length(ARev) = 0 then Exit;
  // scan from end for digits
  NumEnd := Length(ARev);
  NumStart := NumEnd;
  while (NumStart >= 1) and (ARev[NumStart] in ['0'..'9']) do Dec(NumStart);
  // NumStart is position before digits (or 0)
  // check if char at NumStart+1 is digit start, and char at NumStart is ~ or ^
  // three cases: ends with digits+op, ends with op only, ends with digits without op (no)
  if (NumStart >= 1) and (ARev[NumStart] in ['~','^']) then
  begin
    // has op with optional digits
    if NumStart < NumEnd then
      NumStr := Copy(ARev, NumStart + 1, NumEnd - NumStart)
    else
      NumStr := '1';
    ABase := Copy(ARev, 1, NumStart - 1);
    AOp := ARev[NumStart];
    AArg := NumStr;
    if ABase = '' then Exit(False); // bare ~1 not valid
    Result := True;
    Exit;
  end;
  // also handle single trailing ~ or ^ without digits already covered (NumStart = NumEnd)
  // the above already handles: when NumEnd = position of ~, NumStart = that position, NumStr = '1'
  // need to handle case where rev ends with ~ or ^ directly and NumStart points to op
  // Our logic above already did: for "HEAD~", NumStart initially = Length, but ARev[Length]='~', digits scan yields NumStart=Length, then we check ARev[NumStart]='~', NumStr='1' -> ok
  // But the earlier digit scan would have NumStart = Length because '~' not digit, so NumEnd=Length, NumStart=Length, then check ARev[NumStart]='~' -> true, so we already handled
  // So false path is when ends not with ~/^
end;

function GitRevParse(const AGitDir, ARev: string): TGitOid;
var Rev, Base, Op, Arg, Expect: string;
    HasPeel, HasOp: Boolean;
    Peeled, Tmp: TGitOid;
    Repo: TNativeRepository;
    Count, IndexNum: Integer;
begin
  Rev := Trim(ARev);
  if Rev = '' then
    raise EGitError.Create('rev-parse: empty revision');
  HasPeel := TryStripPeel(Rev, Base, Expect);
  if HasPeel then
  begin
    Tmp := GitRevParse(AGitDir, Base);
    Repo := TNativeRepository.Create(AGitDir);
    try
      Result := PeelOid(Repo, Tmp, Expect);
    finally
      Repo.Free;
    end;
    Exit;
  end;
  HasOp := TryStripTildeCaret(Rev, Base, Op, Arg);
  if HasOp then
  begin
    Tmp := GitRevParse(AGitDir, Base);
    Repo := TNativeRepository.Create(AGitDir);
    try
      if Op = '~' then
      begin
        Count := StrToIntDef(Arg, 1);
        if Count < 0 then raise EGitError.Create('rev-parse: negative count');
        Result := ResolveTilde(Repo, Tmp, Count);
      end
      else
      begin
        IndexNum := StrToIntDef(Arg, 1);
        if IndexNum < 1 then raise EGitError.Create('rev-parse: invalid parent index');
        Result := ResolveCaret(Repo, Tmp, IndexNum);
      end;
    finally
      Repo.Free;
    end;
    Exit;
  end;

  // base case: hex or ref
  if (Length(Rev) = 40) and IsAllHex(Rev) then
  begin
    Result := GitOidFromHex(LowerCase(Rev));
    Repo := TNativeRepository.Create(AGitDir);
    try
      if not Repo.HasObject(Result) then
        raise EGitError.CreateFmt('rev-parse: object %s not found', [Rev]);
    finally
      Repo.Free;
    end;
    Exit;
  end;

  // short hex? git allows abbreviated; we support 40 only for determinism.
  // If looks like hex and length >=4, try to resolve via object existence? For now require 40.
  // Fall through to ref dwim
  try
    Result := ResolveRefDwim(AGitDir, Rev);
  except
    on E: EGitError do
      raise EGitError.CreateFmt('rev-parse: cannot resolve "%s"', [Rev]);
  end;
end;

function GitRevParseCommit(const AGitDir, ARev: string): TGitOid;
var Oid: TGitOid;
    Repo: TNativeRepository;
    Kind: TGitObjectKind;
begin
  Oid := GitRevParse(AGitDir, ARev);
  Repo := TNativeRepository.Create(AGitDir);
  try
    try
      Oid := PeelOid(Repo, Oid, 'commit');
    except
      on E: EGitError do
        raise EGitError.CreateFmt('rev-parse: %s does not peel to commit', [ARev]);
    end;
    Result := Oid;
  finally
    Repo.Free;
  end;
end;

end.
