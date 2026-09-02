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
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.hash.sha1,
  nextpas.core.hash.intf,
  nextpas.core.text.conv,
  nextpas.core.text.builder,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.indexer;

function TrimLocal(const S: string): string;
var A, B: Integer;
begin
  A := 1; B := Length(S);
  while (A <= B) and (S[A] in [' ', #9, #10, #13]) do Inc(A);
  while (B >= A) and (S[B] in [' ', #9, #10, #13]) do Dec(B);
  if A > B then Exit('');
  Result := Copy(S, A, B - A + 1);
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
    LBuilder: TBufStringBuilder;
begin
  LBuilder.Init(256);
  try
    for I := 0 to High(AWants) do
    begin
      LBuilder.AppendStr(GitOidToHex(AWants[I]));
      LBuilder.AppendChar(#10);
    end;
    for I := 0 to High(AExcludes) do
    begin
      LBuilder.AppendChar('^');
      LBuilder.AppendStr(GitOidToHex(AExcludes[I]));
      LBuilder.AppendChar(#10);
    end;
    RevInput := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
  if TrimLocal(RevInput) = '' then
    raise EGitError.Create('bundle: empty rev list');
  Out_ := RunWithInput('git', ['--git-dir=' + AGitDir, 'pack-objects', '--stdout', '--revs', '--delta-base-offset'],
    StringToBytes(RevInput));
  if not ProcessSucceeded(Out_) then
    raise EGitError.CreateFmt('bundle pack-objects failed (%d): %s', [Out_.ExitCode, TrimLocal(Out_.StdErr + Out_.StdOut)]);
  Result := StringToBytes(Out_.StdOut);
  if Length(Result) = 0 then
    raise EGitError.Create('bundle: pack-objects produced empty pack');
  if (Length(Result) < 12) or (Result[0] <> Ord('P')) then
    raise EGitError.Create('bundle: invalid pack header from pack-objects');
end;

function LocalSplitLines(const S: string): TStringArray;
var I, Start, L: Integer;
    Cnt: Integer;
begin
  Result := nil;
  Start := 1; L := Length(S); Cnt := 0;
  for I := 1 to L do
    if S[I] = #10 then
    begin
      SetLength(Result, Cnt+1);
      Result[Cnt] := Copy(S, Start, I - Start);
      Inc(Cnt);
      Start := I + 1;
    end;
  if Start <= L + 1 then
  begin
    SetLength(Result, Cnt+1);
    Result[Cnt] := Copy(S, Start, L - Start + 1);
  end;
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
    PrereqCnt, PrereqCap, RefsCnt, RefsCap: SizeUInt;
    LNewCap: SizeUInt;
begin
  Result.Prerequisites := nil;
  Result.Refs := nil;
  Result.PackOffset := -1;
  APackOff := -1;
  PrereqCnt := 0; PrereqCap := 0; RefsCnt := 0; RefsCap := 0;
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
  // perf: bytes.ops BytesSliceToString single source (inline + single Move via Slice view, zero-copy, replaces hand-written SetLength+Move)
  HeaderStr := BytesSliceToString(AData, 0, SizeUInt(P+1));
  Lines := LocalSplitLines(HeaderStr);
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
      if not GitOidIsValidHex(OidHex) then
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
      // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), inline, O(1) amortized, zero-copy record Move
      if PrereqCnt >= PrereqCap then
      begin
        LNewCap := GrowArrayCapacity(PrereqCap, PrereqCnt + 1);
        SetLength(Result.Prerequisites, LNewCap);
        PrereqCap := LNewCap;
      end;
      Result.Prerequisites[PrereqCnt] := Prereq;
      Inc(PrereqCnt);
    end
    else
    begin
      // ref: "<40hex> <name>"
      if Length(Line) < 41 then
        raise EGitError.CreateFmt('bundle: bad ref line "%s"', [Line]);
      OidHex := Copy(Line, 1, 40);
      if not GitOidIsValidHex(OidHex) then
        raise EGitError.CreateFmt('bundle: bad ref oid "%s"', [Line]);
      if Line[41] <> ' ' then
        raise EGitError.CreateFmt('bundle: bad ref spacing "%s"', [Line]);
      Rest := Copy(Line, 42, MaxInt);
      if Rest = '' then
        raise EGitError.CreateFmt('bundle: empty ref name "%s"', [Line]);
      Oid := GitOidFromHex(LowerHex(OidHex));
      Ref.Oid := Oid;
      Ref.Name := Rest;
      // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source, O(1) amortized, zero-copy record Move
      if RefsCnt >= RefsCap then
      begin
        LNewCap := GrowArrayCapacity(RefsCap, RefsCnt + 1);
        SetLength(Result.Refs, LNewCap);
        RefsCap := LNewCap;
      end;
      Result.Refs[RefsCnt] := Ref;
      Inc(RefsCnt);
    end;
  end;
  // single shrink after loop: bytes.ops geometric growth -> one SetLength to exact, avoids O(n²) jitter, stability: managed strings trimmed, no leak
  if SizeUInt(Length(Result.Prerequisites)) <> PrereqCnt then
    SetLength(Result.Prerequisites, PrereqCnt);
  if SizeUInt(Length(Result.Refs)) <> RefsCnt then
    SetLength(Result.Refs, RefsCnt);
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
  // perf: single source OID trailer via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move), replaces scattered Move 20B, CONTRACT.objects inline zero-copy invariant
  SpanCopy(TByteSpan.Create(@Trail[0], GitOidRawLen), TByteSpan.Create(@Pack[Length(Pack)-GitOidRawLen], GitOidRawLen));
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
    OutBytes: TBytes;
    Comment: string;
    LHeader: TBufStringBuilder;
    LHeaderBytes: TBytes;
    WantsCnt, WantsCap, ExcludesCnt, ExcludesCap, WantNamesCnt, WantNamesCap, PrereqCommentsCnt, PrereqCommentsCap, LNewCap: SizeUInt;
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
  WantsCnt := 0; WantsCap := 0; ExcludesCnt := 0; ExcludesCap := 0;
  WantNamesCnt := 0; WantNamesCap := 0; PrereqCommentsCnt := 0; PrereqCommentsCap := 0;
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
      // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source, O(1) amortized, zero-copy Move
      if ExcludesCnt >= ExcludesCap then
      begin
        LNewCap := GrowArrayCapacity(ExcludesCap, ExcludesCnt + 1);
        SetLength(Excludes, LNewCap);
        ExcludesCap := LNewCap;
      end;
      Excludes[ExcludesCnt] := Oid;
      Inc(ExcludesCnt);
      // comment for header prereq: commit subject
      Comment := CommitFirstLine(AGitDir, Oid);
      if Comment = '' then Comment := GitOidToHex(Oid);
      if PrereqCommentsCnt >= PrereqCommentsCap then
      begin
        LNewCap := GrowArrayCapacity(PrereqCommentsCap, PrereqCommentsCnt + 1);
        SetLength(PrereqComments, LNewCap);
        PrereqCommentsCap := LNewCap;
      end;
      PrereqComments[PrereqCommentsCnt] := Comment;
      Inc(PrereqCommentsCnt);
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
          if ExcludesCnt >= ExcludesCap then
          begin
            LNewCap := GrowArrayCapacity(ExcludesCap, ExcludesCnt + 1);
            SetLength(Excludes, LNewCap);
            ExcludesCap := LNewCap;
          end;
          Excludes[ExcludesCnt] := Oid;
          Inc(ExcludesCnt);
          Comment := CommitFirstLine(AGitDir, Oid);
          if Comment = '' then Comment := GitOidToHex(Oid);
          if PrereqCommentsCnt >= PrereqCommentsCap then
          begin
            LNewCap := GrowArrayCapacity(PrereqCommentsCap, PrereqCommentsCnt + 1);
            SetLength(PrereqComments, LNewCap);
            PrereqCommentsCap := LNewCap;
          end;
          PrereqComments[PrereqCommentsCnt] := Comment;
          Inc(PrereqCommentsCnt);
        end;
        RevName := Copy(Raw, Pos('..', Raw)+2, MaxInt);
        if RevName = '' then RevName := 'HEAD';
        Oid := GitRevParse(AGitDir, RevName);
        if WantsCnt >= WantsCap then
        begin
          LNewCap := GrowArrayCapacity(WantsCap, WantsCnt + 1);
          SetLength(Wants, LNewCap);
          WantsCap := LNewCap;
        end;
        Wants[WantsCnt] := Oid;
        Inc(WantsCnt);
        if WantNamesCnt >= WantNamesCap then
        begin
          LNewCap := GrowArrayCapacity(WantNamesCap, WantNamesCnt + 1);
          SetLength(WantNames, LNewCap);
          WantNamesCap := LNewCap;
        end;
        WantNames[WantNamesCnt] := RevName;
        Inc(WantNamesCnt);
      end
      else
      begin
        Oid := GitRevParse(AGitDir, Raw);
        if WantsCnt >= WantsCap then
        begin
          LNewCap := GrowArrayCapacity(WantsCap, WantsCnt + 1);
          SetLength(Wants, LNewCap);
          WantsCap := LNewCap;
        end;
        Wants[WantsCnt] := Oid;
        Inc(WantsCnt);
        if WantNamesCnt >= WantNamesCap then
        begin
          LNewCap := GrowArrayCapacity(WantNamesCap, WantNamesCnt + 1);
          SetLength(WantNames, LNewCap);
          WantNamesCap := LNewCap;
        end;
        WantNames[WantNamesCnt] := Raw;
        Inc(WantNamesCnt);
      end;
    end;
  end;
  // single shrink after loop: geometric growth -> one SetLength to exact, avoids O(n²) jitter
  if SizeUInt(Length(Wants)) <> WantsCnt then SetLength(Wants, WantsCnt);
  if SizeUInt(Length(Excludes)) <> ExcludesCnt then SetLength(Excludes, ExcludesCnt);
  if SizeUInt(Length(WantNames)) <> WantNamesCnt then SetLength(WantNames, WantNamesCnt);
  if SizeUInt(Length(PrereqComments)) <> PrereqCommentsCnt then SetLength(PrereqComments, PrereqCommentsCnt);
  if Length(Wants) = 0 then
    raise EGitError.Create('bundle: no want refs resolved');
  Pack := BuildPackFromRevs(AGitDir, Wants, Excludes);
  LHeader.Init(256);
  try
    LHeader.AppendStr('# v2 git bundle'#10);
    for I := 0 to High(Excludes) do
    begin
      LHeader.AppendChar('-');
      LHeader.AppendStr(GitOidToHex(Excludes[I]));
      LHeader.AppendChar(' ');
      LHeader.AppendStr(PrereqComments[I]);
      LHeader.AppendChar(#10);
    end;
    for I := 0 to High(Wants) do
    begin
      LHeader.AppendStr(GitOidToHex(Wants[I]));
      LHeader.AppendChar(' ');
      LHeader.AppendStr(WantNames[I]);
      LHeader.AppendChar(#10);
    end;
    LHeader.AppendChar(#10);
    HeaderText := LHeader.ToString;
  finally
    LHeader.Done;
  end;
  LHeaderBytes := StringToBytes(HeaderText);
  // bytes.ops 单源流式一次分配，替代临拼 BytesConcat(OutBytes, PackBytes)
  OutBytes := BytesConcatMany([LHeaderBytes, Pack]);
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
  // perf: single source OID trailer via bytes.ops SpanCopy (inline, zero-copy TByteSpan view, single Move), replaces scattered Move 20B, CONTRACT.objects inline zero-copy invariant
  SpanCopy(TByteSpan.Create(@Trail[0], GitOidRawLen), TByteSpan.Create(@Pack[Length(Pack)-GitOidRawLen], GitOidRawLen));
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
