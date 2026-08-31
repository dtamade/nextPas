unit nextpas.core.git.native.bundle;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

type
  TGitBundleRef = record
    Oid: TGitOid;
    Name: string;
  end;
  TGitBundleRefArray = array of TGitBundleRef;
  TGitBundlePrereq = record
    Oid: TGitOid;
    Comment: string;
  end;
  TGitBundlePrereqArray = array of TGitBundlePrereq;
  TGitBundleHeader = record
    Prerequisites: TGitBundlePrereqArray;
    Refs: TGitBundleRefArray;
    PackOffset: SizeInt;
  end;

function GitBundleCreate(const AGitDir, ARef, ABundlePath: string): TGitOid; overload;
function GitBundleCreateFromRevs(const AGitDir: string; const ARevs: array of string; const ABundlePath: string): Integer; overload;
function GitBundleCreateRange(const AGitDir, AFromRev, AToRev, ABundlePath: string): Integer; overload;

function GitBundleVerify(const ABundlePath: string): Boolean;
function GitBundleList(const ABundlePath: string): TGitBundleRefArray;
function GitBundleParseHeader(const ABundlePath: string): TGitBundleHeader;
function GitBundleParseHeaderBytes(const AData: TBytes): TGitBundleHeader;

function GitBundleUnbundle(const ABundlePath, ATargetGitDir: string): Integer;

implementation

uses
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.hash.sha1,
  nextpas.core.hash.intf,
  nextpas.core.text.conv,
  nextpas.core.git.native.util,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.indexer;

function BytesOfString(const S: string): TBytes;
var L: Integer;
begin
  L := Length(S);
  SetLength(Result, L);
  if L > 0 then Move(S[1], Result[0], L);
end;

function StringOfBytes(const B: TBytes): string;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then Move(B[0], Result[1], Length(B));
end;

function ConcatBytes(const A, B: TBytes): TBytes;
begin
  SetLength(Result, Length(A) + Length(B));
  if Length(A) > 0 then Move(A[0], Result[0], Length(A));
  if Length(B) > 0 then Move(B[0], Result[Length(A)], Length(B));
end;

function TrimLocal(const S: string): string;
var A, B: Integer;
begin
  A := 1; B := Length(S);
  while (A <= B) and (S[A] in [' ', #9, #10, #13]) do Inc(A);
  while (B >= A) and (S[B] in [' ', #9, #10, #13]) do Dec(B);
  if A > B then Exit('');
  Result := Copy(S, A, B - A + 1);
end;

function IsHex(const S: string): Boolean;
var I: Integer;
begin
  if Length(S) <> 40 then Exit(False);
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9','a'..'f','A'..'F']) then Exit(False);
  Result := True;
end;

function LowerHex(const S: string): string;
begin
  Result := nextpas.core.text.conv.LowerCase(S);
end;

function BytesToHexLower(const B: TBytes): string;
const Hex: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');
var I: Integer;
begin
  SetLength(Result, Length(B)*2);
  for I := 0 to High(B) do
  begin
    Result[I*2+1] := Hex[(B[I] shr 4) and $F];
    Result[I*2+2] := Hex[B[I] and $F];
  end;
end;

function HexToBytes(const S: string): TBytes;
var I: Integer;
  V: Byte;
  function Nibble(C: Char): Byte;
  begin
    if C in ['0'..'9'] then Result := Byte(Ord(C)-Ord('0'))
    else if C in ['a'..'f'] then Result := Byte(Ord(C)-Ord('a')+10)
    else Result := Byte(Ord(C)-Ord('A')+10);
  end;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
  begin
    V := (Nibble(S[I*2+1]) shl 4) or Nibble(S[I*2+2]);
    Result[I] := V;
  end;
end;

function CommitFirstLine(const AGitDir: string; const AOid: TGitOid): string;
var Repo: TNativeRepository;
    Kind: TGitObjectKind;
    Data: TBytes;
    Info: TGitCommitInfo;
    Msg, Line: string;
    P: Integer;
begin
  Result := '';
  try
    Repo := TNativeRepository.Create(AGitDir);
    try
      Data := Repo.ReadObject(AOid, Kind);
      if Kind <> gokCommit then Exit('');
      Info := GitParseCommit(Data);
      Msg := Info.Message;
      // first line up to LF
      P := Pos(#10, Msg);
      if P > 0 then Line := Copy(Msg, 1, P-1) else Line := Msg;
      Line := TrimLocal(Line);
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line)-1);
      Result := TrimLocal(Line);
    finally
      Repo.Free;
    end;
  except
    Result := '';
  end;
end;

procedure EnsureGitDirShape(const AGitDir: string);
begin
  if not IsGitDirShape(AGitDir) then
    if not DirectoryExists(AGitDir) then
      raise EGitError.CreateFmt('bundle: not a git dir %s', [AGitDir]);
end;

function BuildPackFromRevs(const AGitDir: string; const AWants: array of TGitOid; const AExcludes: array of TGitOid): TBytes;
var RevInput: string;
    I: Integer;
    Out_: TProcessOutput;
begin
  RevInput := '';
  for I := 0 to High(AWants) do
    RevInput := RevInput + GitOidToHex(AWants[I]) + #10;
  for I := 0 to High(AExcludes) do
    RevInput := RevInput + '^' + GitOidToHex(AExcludes[I]) + #10;
  if TrimLocal(RevInput) = '' then
    raise EGitError.Create('bundle: empty rev list');
  Out_ := RunWithInput('git', ['--git-dir=' + AGitDir, 'pack-objects', '--stdout', '--revs', '--delta-base-offset'],
    BytesOfString(RevInput));
  if not ProcessSucceeded(Out_) then
    raise EGitError.CreateFmt('bundle pack-objects failed (%d): %s', [Out_.ExitCode, TrimLocal(Out_.StdErr + Out_.StdOut)]);
  Result := BytesOfString(Out_.StdOut);
  if Length(Result) = 0 then
    raise EGitError.Create('bundle: pack-objects produced empty pack');
  if (Length(Result) < 12) or (Result[0] <> Ord('P')) then
    raise EGitError.Create('bundle: invalid pack header from pack-objects');
end;

function ParseBundleHeaderBytesInternal(const AData: TBytes; out APackOff: SizeInt): TGitBundleHeader;
var P, I: SizeInt;
    HeaderStr, Line: string;
    Lines: TStringArray;
    Cnt: Integer;
    OidHex, Rest: string;
    Oid: TGitOid;
    Prereq: TGitBundlePrereq;
    Ref: TGitBundleRef;
begin
  Result.Prerequisites := nil;
  Result.Refs := nil;
  Result.PackOffset := -1;
  APackOff := -1;
  if Length(AData) < 10 then
    raise EGitError.Create('bundle: file too short');
  // find first "\n\n" (10,10)
  P := -1;
  for I := 0 to High(AData)-1 do
    if (AData[I] = 10) and (AData[I+1] = 10) then
    begin P := I; Break; end;
  if P < 0 then
    raise EGitError.Create('bundle: missing header terminator');
  // header bytes [0, P] inclusive first \n, but pack starts at P+2
  SetLength(HeaderStr, P+1);
  if P+1 > 0 then Move(AData[0], HeaderStr[1], P+1);
  Lines := GitSplitLines(HeaderStr);
  Cnt := Length(Lines);
  // SplitString includes last empty after trailing \n? Our header ends with \n before blank, so split yields last '' for the blank? Actually header ends with "ref\n" then we consumed up to P which is first \n of "\n\n", so headerStr ends with "\n", split yields last ''.
  // first line must be "# v2 git bundle"
  if Cnt = 0 then
    raise EGitError.Create('bundle: empty header');
  if TrimLocal(Lines[0]) <> '# v2 git bundle' then
    raise EGitError.CreateFmt('bundle: bad header "%s"', [Lines[0]]);
  for I := 1 to High(Lines) do
  begin
    Line := Lines[I];
    if Line = '' then Continue; // blank terminator, but we already split; ignore empty
    Line := TrimLocal(Line);
    if Line = '' then Continue;
    if (Length(Line) > 0) and (Line[1] = '-') then
    begin
      // prereq: "-<40hex> [comment]"
      if Length(Line) < 42 then
        raise EGitError.CreateFmt('bundle: bad prereq line "%s"', [Line]);
      OidHex := Copy(Line, 2, 40);
      if not IsHex(OidHex) then
        raise EGitError.CreateFmt('bundle: bad prereq oid "%s"', [Line]);
      Oid := GitOidFromHex(LowerHex(OidHex));
      Rest := '';
      if Length(Line) > 42 then
      begin
        if Line[42] <> ' ' then
          raise EGitError.CreateFmt('bundle: bad prereq spacing "%s"', [Line]);
        Rest := Copy(Line, 43, MaxInt);
      end;
      Prereq.Oid := Oid;
      Prereq.Comment := Rest;
      SetLength(Result.Prerequisites, Length(Result.Prerequisites)+1);
      Result.Prerequisites[High(Result.Prerequisites)] := Prereq;
    end
    else
    begin
      // ref: "<40hex> <name>"
      if Length(Line) < 41 then
        raise EGitError.CreateFmt('bundle: bad ref line "%s"', [Line]);
      OidHex := Copy(Line, 1, 40);
      if not IsHex(OidHex) then
        raise EGitError.CreateFmt('bundle: bad ref oid "%s"', [Line]);
      if Line[41] <> ' ' then
        raise EGitError.CreateFmt('bundle: bad ref spacing "%s"', [Line]);
      Rest := Copy(Line, 42, MaxInt);
      if Rest = '' then
        raise EGitError.CreateFmt('bundle: empty ref name "%s"', [Line]);
      Oid := GitOidFromHex(LowerHex(OidHex));
      Ref.Oid := Oid;
      Ref.Name := Rest;
      SetLength(Result.Refs, Length(Result.Refs)+1);
      Result.Refs[High(Result.Refs)] := Ref;
    end;
  end;
  Result.PackOffset := P + 2;
  APackOff := P + 2;
end;

function GitBundleParseHeaderBytes(const AData: TBytes): TGitBundleHeader;
var Off: SizeInt;
begin
  Result := ParseBundleHeaderBytesInternal(AData, Off);
end;

function GitBundleParseHeader(const ABundlePath: string): TGitBundleHeader;
var Data: TBytes;
    Off: SizeInt;
begin
  Data := ReadFile(ABundlePath);
  Result := ParseBundleHeaderBytesInternal(Data, Off);
end;

function GitBundleVerify(const ABundlePath: string): Boolean;
var Data, Pack: TBytes;
    Hdr: TGitBundleHeader;
    Off, I: SizeInt;
    Trail, Computed: TBytes;
    Hasher: IHasher;
begin
  Data := ReadFile(ABundlePath);
  Hdr := ParseBundleHeaderBytesInternal(Data, Off);
  if Length(Data) - Off < 12 + GitOidRawLen then
    raise EGitError.Create('bundle: pack too short');
  SetLength(Pack, Length(Data) - Off);
  Move(Data[Off], Pack[0], Length(Pack));
  if (Pack[0] <> Ord('P')) or (Pack[1] <> Ord('A')) or (Pack[2] <> Ord('C')) or (Pack[3] <> Ord('K')) then
    raise EGitError.Create('bundle: invalid pack signature');
  // trailer check
  SetLength(Trail, GitOidRawLen);
  Move(Pack[Length(Pack)-GitOidRawLen], Trail[0], GitOidRawLen);
  Hasher := NewSHA1;
  Hasher.Write(Pack[0], SizeUInt(Length(Pack)-GitOidRawLen));
  Computed := Hasher.SumBytes;
  for I := 0 to GitOidRawLen-1 do
    if Computed[I] <> Trail[I] then
      raise EGitError.Create('bundle: pack trailer mismatch');
  // try build index for deeper validation
  try
    Pack := GitBuildPackIndex(Pack);
  except
    on E: Exception do
      raise EGitError.Create('bundle: pack invalid: ' + E.Message);
  end;
  Hdr.PackOffset := Hdr.PackOffset; // suppress hint
  Result := True;
end;

function GitBundleList(const ABundlePath: string): TGitBundleRefArray;
var Hdr: TGitBundleHeader;
begin
  Hdr := GitBundleParseHeader(ABundlePath);
  Result := Hdr.Refs;
end;

function GitBundleCreateFromRevs(const AGitDir: string; const ARevs: array of string; const ABundlePath: string): Integer;
var Wants: array of TGitOid;
    Excludes: array of TGitOid;
    WantNames: TStringArray;
    PrereqComments: TStringArray;
    I: Integer;
    Raw: string;
    IsExclude: Boolean;
    RevName: string;
    Oid: TGitOid;
    Pack: TBytes;
    HeaderText: string;
    OutBytes, PackBytes: TBytes;
    Comment: string;
begin
  if ABundlePath = '' then
    raise EGitError.Create('bundle: empty bundle path');
  if Length(ARevs) = 0 then
    raise EGitError.Create('bundle: empty rev list');
  EnsureGitDirShape(AGitDir);
  SetLength(Wants, 0);
  SetLength(Excludes, 0);
  SetLength(WantNames, 0);
  SetLength(PrereqComments, 0);
  for I := 0 to High(ARevs) do
  begin
    Raw := TrimLocal(ARevs[I]);
    if Raw = '' then Continue;
    IsExclude := (Length(Raw) > 0) and (Raw[1] in ['^','-']);
    if IsExclude then
    begin
      RevName := Copy(Raw, 2, MaxInt);
      if RevName = '' then
        raise EGitError.CreateFmt('bundle: empty exclude "%s"', [Raw]);
      Oid := GitRevParse(AGitDir, RevName);
      SetLength(Excludes, Length(Excludes)+1);
      Excludes[High(Excludes)] := Oid;
      // comment for header prereq: commit subject
      Comment := CommitFirstLine(AGitDir, Oid);
      if Comment = '' then Comment := GitOidToHex(Oid);
      SetLength(PrereqComments, Length(PrereqComments)+1);
      PrereqComments[High(PrereqComments)] := Comment;
    end
    else
    begin
      // want: may be "HEAD", "refs/heads/main", "abc123..HEAD" not supported -> treat as single rev
      // support A..B shorthand? For range, git bundle uses rev-list semantics: "A..B" means B not A. Our IsExclude only handles ^ prefix, so range would be taken as want with name "A..B" which is not ideal.
      // Detect ".." in raw: split into from..to
      if Pos('..', Raw) > 0 then
      begin
        // simple handling: "X..Y" -> exclude X, want Y
        // Also supports "X...Y" (symmetric) not handled
        if Pos('...', Raw) > 0 then
          raise EGitError.CreateFmt('bundle: triple-dot range not supported "%s" (use ^ prefix)', [Raw]);
        // split at ..
        RevName := Copy(Raw, 1, Pos('..', Raw)-1);
        if RevName <> '' then
        begin
          Oid := GitRevParse(AGitDir, RevName);
          SetLength(Excludes, Length(Excludes)+1);
          Excludes[High(Excludes)] := Oid;
          Comment := CommitFirstLine(AGitDir, Oid);
          if Comment = '' then Comment := GitOidToHex(Oid);
          SetLength(PrereqComments, Length(PrereqComments)+1);
          PrereqComments[High(PrereqComments)] := Comment;
        end;
        RevName := Copy(Raw, Pos('..', Raw)+2, MaxInt);
        if RevName = '' then RevName := 'HEAD';
        Oid := GitRevParse(AGitDir, RevName);
        SetLength(Wants, Length(Wants)+1);
        Wants[High(Wants)] := Oid;
        SetLength(WantNames, Length(WantNames)+1);
        WantNames[High(WantNames)] := RevName;
      end
      else
      begin
        Oid := GitRevParse(AGitDir, Raw);
        SetLength(Wants, Length(Wants)+1);
        Wants[High(Wants)] := Oid;
        SetLength(WantNames, Length(WantNames)+1);
        WantNames[High(WantNames)] := Raw;
      end;
    end;
  end;
  if Length(Wants) = 0 then
    raise EGitError.Create('bundle: no want refs resolved');
  Pack := BuildPackFromRevs(AGitDir, Wants, Excludes);
  HeaderText := '# v2 git bundle' + #10;
  for I := 0 to High(Excludes) do
    HeaderText := HeaderText + '-' + GitOidToHex(Excludes[I]) + ' ' + PrereqComments[I] + #10;
  for I := 0 to High(Wants) do
    HeaderText := HeaderText + GitOidToHex(Wants[I]) + ' ' + WantNames[I] + #10;
  HeaderText := HeaderText + #10;
  OutBytes := BytesOfString(HeaderText);
  PackBytes := Pack;
  OutBytes := ConcatBytes(OutBytes, PackBytes);
  // ensure parent dir
  if PathDir(ABundlePath) <> '' then
    MkdirAll(PathDir(ABundlePath), PermDirDefault);
  WriteAtomic(ABundlePath, OutBytes);
  Result := Length(Wants);
end;

function GitBundleCreate(const AGitDir, ARef, ABundlePath: string): TGitOid;
var Revs: array[0..0] of string;
    Cnt: Integer;
    Oid: TGitOid;
begin
  if ARef = '' then Revs[0] := 'HEAD' else Revs[0] := ARef;
  Cnt := GitBundleCreateFromRevs(AGitDir, Revs, ABundlePath);
  if Cnt = 0 then
    raise EGitError.Create('bundle: create produced no refs');
  Oid := GitRevParse(AGitDir, Revs[0]);
  Result := Oid;
end;

function GitBundleCreateRange(const AGitDir, AFromRev, AToRev, ABundlePath: string): Integer;
var Revs: array of string;
begin
  SetLength(Revs, 2);
  Revs[0] := AToRev;
  Revs[1] := '^' + AFromRev;
  Result := GitBundleCreateFromRevs(AGitDir, Revs, ABundlePath);
end;

function GitBundleUnbundle(const ABundlePath, ATargetGitDir: string): Integer;
var Data, Pack: TBytes;
    Hdr: TGitBundleHeader;
    Off: SizeInt;
    I: Integer;
    PackHash, PackPath, IdxPath, RefPath, NeedMkdir: string;
    Idx: TBytes;
    Trail: TBytes;
begin
  Data := ReadFile(ABundlePath);
  Hdr := ParseBundleHeaderBytesInternal(Data, Off);
  if Length(Data) - Off < 12 + GitOidRawLen then
    raise EGitError.Create('bundle: pack too short for unbundle');
  SetLength(Pack, Length(Data) - Off);
  Move(Data[Off], Pack[0], Length(Pack));
  // validate pack trailer quickly
  SetLength(Trail, GitOidRawLen);
  Move(Pack[Length(Pack)-GitOidRawLen], Trail[0], GitOidRawLen);
  PackHash := BytesToHexLower(Trail);
  EnsureGitDirShape(ATargetGitDir);
  MkdirAll(PathJoin([ATargetGitDir, 'objects', 'pack']), PermDirDefault);
  Idx := GitBuildPackIndex(Pack);
  PackPath := PathJoin([ATargetGitDir, 'objects', 'pack', 'pack-' + PackHash + '.pack']);
  IdxPath := GitPackIndexPath(PackPath);
  WriteAtomic(PackPath, Pack);
  WriteAtomic(IdxPath, Idx);
  // write refs
  for I := 0 to High(Hdr.Refs) do
  begin
    if Hdr.Refs[I].Name = 'HEAD' then
    begin
      // store HEAD as detached? But writing HEAD file with oid may overwrite symref.
      // Check if HEAD is symref in target: preserve? For unbundle we write detached HEAD only if target has no HEAD.
      // Simpler: write refs/heads from bundle's HEAD is not a branch; store as HEAD oid if target HEAD missing.
      // We'll write refs/bundle/HEAD for inspection, and also update HEAD if it doesn't exist.
      if not FileExists(PathJoin([ATargetGitDir, 'HEAD'])) then
        WriteFileText(PathJoin([ATargetGitDir, 'HEAD']), GitOidToHex(Hdr.Refs[I].Oid) + #10);
      // also write a loose file for inspection
      RefPath := PathJoin([ATargetGitDir, 'refs', 'bundle', 'HEAD']);
      NeedMkdir := PathDir(RefPath);
      if NeedMkdir <> '' then MkdirAll(NeedMkdir, PermDirDefault);
      WriteFileText(RefPath, GitOidToHex(Hdr.Refs[I].Oid) + #10);
    end
    else
    begin
      RefPath := PathJoin([ATargetGitDir, Hdr.Refs[I].Name]);
      NeedMkdir := PathDir(RefPath);
      if NeedMkdir <> '' then MkdirAll(NeedMkdir, PermDirDefault);
      WriteFileText(RefPath, GitOidToHex(Hdr.Refs[I].Oid) + #10);
    end;
  end;
  // prerequisites are not written as refs
  Result := Length(Hdr.Refs);
end;

end.
