unit nextpas.core.git.native.push;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base;

type
  TGitPushUpdate = record
    RefName: string;
    OldOid: TGitOid;
    NewOid: TGitOid;
  end;
  TGitPushUpdateArray = array of TGitPushUpdate;

function GitOidZero: TGitOid; inline;
function GitOidIsZero(const AOid: TGitOid): Boolean; inline;

function GitPush(const ALocalGitDir, ARemoteGitDir, ARefName: string;
  const AOldOid, ANewOid: TGitOid): Boolean; overload;
function GitPush(const ALocalGitDir, ARemoteGitDir: string;
  const AUpdates: array of TGitPushUpdate): Boolean; overload;
function GitPushBranch(const ALocalGitDir, ARemoteGitDir,
  ABranchName: string): Boolean;
{ Push ABranchName to the remote registered as ARemoteName in ALocalGitDir
  (local transport; network URLs raise the transport EGitError).
  Returns True when the remote ref moved, False when already up-to-date. }
function GitPushRemote(const ALocalGitDir, ARemoteName, ABranchName: string): Boolean;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.text.conv,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.remote,
  nextpas.core.git.native.util;

function GitOidZero: TGitOid; inline;
begin
  // single source via base.GitOidZero (FillChar, inline, zero-copy), base owns primitive (base←impl), push delegates
  Result := nextpas.core.git.native.base.GitOidZero;
end;

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
begin
  // single source via base.GitOidIsZero -> bytes.ops IsZeroBytes (zero-copy TByteSpan, inline), base owns primitive
  Result := nextpas.core.git.native.base.GitOidIsZero(AOid);
end;

function BuildPack(const ALocalGitDir: string; const AUpdates: array of TGitPushUpdate): TBytes;
var RevInput: string;
    I: Integer;
    Out_: TProcessOutput;
begin
  RevInput := '';
  for I := 0 to High(AUpdates) do
    if not GitOidIsZero(AUpdates[I].NewOid) then
      RevInput := RevInput + GitOidToHex(AUpdates[I].NewOid) + #10;
  for I := 0 to High(AUpdates) do
    if not GitOidIsZero(AUpdates[I].OldOid) then
      RevInput := RevInput + '^' + GitOidToHex(AUpdates[I].OldOid) + #10;
  if Trim(RevInput) = '' then
  begin
    Result := nil;
    Exit;
  end;
  Out_ := RunWithInput('git', ['--git-dir=' + ALocalGitDir, 'pack-objects', '--stdout', '--revs', '--delta-base-offset'],
    StringToBytes(RevInput));
  if not ProcessSucceeded(Out_) then
    raise EGitError.CreateFmt('pack-objects failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr + Out_.StdOut)]);
  Result := StringToBytes(Out_.StdOut);
  if (Length(Result) > 0) and ((Length(Result) < 12) or (Result[0] <> Ord('P'))) then
    raise EGitError.Create('push: pack-objects produced invalid pack');
end;

function BuildRequest(const AUpdates: array of TGitPushUpdate; const APack: TBytes): TBytes;
var I: Integer;
    Line: string;
    Parts: array of TBytes;
begin
  SetLength(Parts, Length(AUpdates) + 1 + Ord(Length(APack) > 0));
  for I := 0 to High(AUpdates) do
  begin
    Line := GitOidToHex(AUpdates[I].OldOid) + ' ' + GitOidToHex(AUpdates[I].NewOid) + ' ' + AUpdates[I].RefName;
    if I = 0 then
      Line := Line + #0 + 'report-status ofs-delta delete-refs';
    Line := Line + #10;
    Parts[I] := GitPktEncodeStr(Line);
  end;
  Parts[Length(AUpdates)] := GitPktEncodeFlush;
  if Length(APack) > 0 then
    Parts[High(Parts)] := APack;
  Result := BytesConcatMany(Parts);
end;

function ParsePushResponse(const AStream: TBytes): Boolean;
var Pkts: TGitPktArray;
    I: Integer;
    S, Msg: string;
    HasUnpack: Boolean;
    UnpackOk: Boolean;
    NgRefs: TStringArray;
begin
  if Length(AStream) = 0 then
    raise EGitError.Create('push: empty response from receive-pack');
  Pkts := GitPktScan(AStream);
  HasUnpack := False;
  UnpackOk := False;
  SetLength(NgRefs, 0);
  Msg := '';
  for I := 0 to High(Pkts) do
  begin
    if Pkts[I].Kind = gpkFlush then Continue;
    if Pkts[I].Kind = gpkDelim then Continue;
    if Pkts[I].Kind <> gpkData then Continue;
    if Length(Pkts[I].Data) = 0 then Continue;
    if (Length(Pkts[I].Data) > 0) and (Pkts[I].Data[0] in [1, 2, 3]) then
    begin
      if Length(Pkts[I].Data) <= 1 then Continue;
      S := BytesToString(Copy(Pkts[I].Data, 1, Length(Pkts[I].Data) - 1));
      if Pkts[I].Data[0] = 3 then
        Msg := Msg + Trim(S) + LineEnding;
      Continue;
    end;
    S := BytesToString(Pkts[I].Data);
    S := Trim(S);
    if S = '' then Continue;
    if Copy(S, 1, 7) = 'unpack ' then
    begin
      HasUnpack := True;
      if S = 'unpack ok' then UnpackOk := True
      else Msg := Msg + S + LineEnding;
    end
    else if Copy(S, 1, 3) = 'ok ' then
    begin
    end
    else if Copy(S, 1, 3) = 'ng ' then
    begin
      SetLength(NgRefs, Length(NgRefs) + 1);
      NgRefs[High(NgRefs)] := S;
    end;
  end;
  if HasUnpack and not UnpackOk then
    raise EGitError.Create('push: ' + Trim(Msg));
  if Length(NgRefs) > 0 then
  begin
    Msg := '';
    for I := 0 to High(NgRefs) do
    begin
      if Msg <> '' then Msg := Msg + '; ';
      Msg := Msg + NgRefs[I];
    end;
    raise EGitError.Create('push rejected: ' + Msg);
  end;
  if Msg <> '' then
  begin
    if Pos('unpack', Msg) > 0 then
      raise EGitError.Create('push: ' + Trim(Msg));
  end;
  Result := True;
end;

function GitPush(const ALocalGitDir, ARemoteGitDir: string;
  const AUpdates: array of TGitPushUpdate): Boolean;
var Pack, Req: TBytes;
    Out_: TProcessOutput;
    Resp: TBytes;
    I: Integer;
begin
  if Length(AUpdates) = 0 then
    raise EGitError.Create('push: empty update list');
  if not IsGitDirShape(ALocalGitDir) then
    raise EGitError.CreateFmt('push: not a git dir %s', [ALocalGitDir]);
  if not IsGitDirShape(ARemoteGitDir) then
    if not DirectoryExists(ARemoteGitDir) then
      raise EGitError.CreateFmt('push: remote not found %s', [ARemoteGitDir]);
  for I := 0 to High(AUpdates) do
    if AUpdates[I].RefName = '' then
      raise EGitError.Create('push: ref name empty');
  Pack := BuildPack(ALocalGitDir, AUpdates);
  Req := BuildRequest(AUpdates, Pack);
  Out_ := RunWithInput('git', ['receive-pack', '--stateless-rpc', ARemoteGitDir], Req);
  if not ProcessSucceeded(Out_) then
  begin
    Resp := StringToBytes(Out_.StdOut + Out_.StdErr);
    if Length(Resp) = 0 then
      raise EGitError.CreateFmt('receive-pack failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr)]);
    ParsePushResponse(StringToBytes(Out_.StdOut));
    raise EGitError.CreateFmt('receive-pack failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr + Out_.StdOut)]);
  end;
  Resp := StringToBytes(Out_.StdOut);
  Result := ParsePushResponse(Resp);
end;

function GitPush(const ALocalGitDir, ARemoteGitDir, ARefName: string;
  const AOldOid, ANewOid: TGitOid): Boolean;
var U: array[0..0] of TGitPushUpdate;
begin
  U[0].RefName := ARefName;
  U[0].OldOid := AOldOid;
  U[0].NewOid := ANewOid;
  Result := GitPush(ALocalGitDir, ARemoteGitDir, U);
end;

function GitPushBranch(const ALocalGitDir, ARemoteGitDir,
  ABranchName: string): Boolean;
var RefName: string;
    NewOid: TGitOid;
    OldOid: TGitOid;
    HasOld: Boolean;
begin
  if ABranchName = '' then
    raise EGitError.Create('push branch: name empty');
  RefName := 'refs/heads/' + ABranchName;
  if Copy(ABranchName, 1, 11) = 'refs/heads/' then
    RefName := ABranchName;
  NewOid := GitResolveRef(ALocalGitDir, RefName);
  HasOld := False;
  try
    OldOid := GitResolveRef(ARemoteGitDir, RefName);
    HasOld := True;
  except
    on E: EGitError do HasOld := False;
  end;
  if not HasOld then OldOid := GitOidZero;
  Result := GitPush(ALocalGitDir, ARemoteGitDir, RefName, OldOid, NewOid);
end;

function PushIsNetworkUrl(const AUrl: string): Boolean; inline;
var
  L: string;
begin
  L := LowerCase(Trim(AUrl));
  Result := (Copy(L, 1, 7) = 'http://') or (Copy(L, 1, 8) = 'https://') or
    (Copy(L, 1, 6) = 'ssh://') or (Copy(L, 1, 10) = 'git+ssh://') or
    (Copy(L, 1, 6) = 'git://') or (Copy(L, 1, 6) = 'ftp://') or
    (Copy(L, 1, 7) = 'ftps://') or
    (Pos('@', L) > 0) and (Pos(':', L) > Pos('@', L));
end;

function PushStripFileScheme(const AUrl: string): string; inline;
var
  L: string;
begin
  L := Trim(AUrl);
  if Copy(LowerCase(L), 1, 7) = 'file://' then
    Result := Copy(L, 8, MaxInt)
  else
    Result := L;
end;

function PushShortDisplay(const AUrl: string): string; inline;
begin
  if Length(AUrl) > 120 then
    Result := Copy(AUrl, 1, 120) + '...'
  else
    Result := AUrl;
end;

function GitPushRemote(const ALocalGitDir, ARemoteName, ABranchName: string): Boolean;
var
  RName: string;
  Rem: TGitRemote;
  Url, Clean, RemoteGitDir, Resolved, RefName: string;
  LocalOid, RemoteOid: TGitOid;
  HasRemote: Boolean;
begin
  RName := Trim(ARemoteName);
  if RName = '' then
    RName := 'origin';
  if Trim(ABranchName) = '' then
    raise EGitError.Create('push: branch empty');
  if not GitRemoteFind(ALocalGitDir, RName, Rem) then
    raise EGitError.CreateFmt('push: remote "%s" not found', [RName]);
  Url := Trim(Rem.Url);
  if Url = '' then
    raise EGitError.CreateFmt('push: remote "%s" has no url', [RName]);
  if PushIsNetworkUrl(Url) then
    raise EGitError.CreateFmt('push: network transport not supported in native backend: %s (use libgit2 backend or git CLI)', [PushShortDisplay(Url)]);
  Clean := PathClean(PushStripFileScheme(Url));
  RemoteGitDir := '';
  if IsGitDirShape(Clean) then
    RemoteGitDir := Clean
  else if DirectoryExists(PathJoin2(Clean, '.git')) then
    RemoteGitDir := PathJoin2(Clean, '.git')
  else if GitTryDiscoverGitDir(Clean, Resolved) then
    RemoteGitDir := Resolved
  else
    raise EGitError.CreateFmt('push: remote not found %s', [PushShortDisplay(Url)]);
  RefName := Trim(ABranchName);
  if Copy(RefName, 1, 11) <> 'refs/heads/' then
    RefName := 'refs/heads/' + RefName;
  LocalOid := GitResolveRef(ALocalGitDir, RefName);
  HasRemote := False;
  try
    RemoteOid := GitResolveRef(RemoteGitDir, RefName);
    HasRemote := True;
  except
    on E: EGitError do
      HasRemote := False;
  end;
  if HasRemote and GitOidSame(LocalOid, RemoteOid) then
    Exit(False);
  Result := GitPushBranch(ALocalGitDir, RemoteGitDir, RefName);
end;

end.
