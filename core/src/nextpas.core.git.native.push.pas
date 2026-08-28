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

implementation

uses
  nextpas.core.fs,
  nextpas.core.process,
  nextpas.core.text.conv,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.refs;

function GitOidZero: TGitOid;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do Result.Bytes[I] := 0;
end;

function GitOidIsZero(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do if AOid.Bytes[I] <> 0 then Exit(False);
  Result := True;
end;

function ConcatBytes(const A, B: TBytes): TBytes;
begin
  SetLength(Result, Length(A) + Length(B));
  if Length(A) > 0 then Move(A[0], Result[0], Length(A));
  if Length(B) > 0 then Move(B[0], Result[Length(A)], Length(B));
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
    GitStringToBytes(RevInput));
  if not ProcessSucceeded(Out_) then
    raise EGitError.CreateFmt('pack-objects failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr + Out_.StdOut)]);
  Result := GitStringToBytes(Out_.StdOut);
  if (Length(Result) > 0) and ((Length(Result) < 12) or (Result[0] <> Ord('P'))) then
    raise EGitError.Create('push: pack-objects produced invalid pack');
end;

function BuildRequest(const AUpdates: array of TGitPushUpdate; const APack: TBytes): TBytes;
var I: Integer;
    Line: string;
    Pkt: TBytes;
begin
  Result := nil;
  for I := 0 to High(AUpdates) do
  begin
    Line := GitOidToHex(AUpdates[I].OldOid) + ' ' + GitOidToHex(AUpdates[I].NewOid) + ' ' + AUpdates[I].RefName;
    if I = 0 then
      Line := Line + #0 + 'report-status ofs-delta delete-refs';
    Line := Line + #10;
    Pkt := GitPktEncodeStr(Line);
    Result := ConcatBytes(Result, Pkt);
  end;
  Result := ConcatBytes(Result, GitPktEncodeFlush);
  if Length(APack) > 0 then
    Result := ConcatBytes(Result, APack);
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
      S := GitBytesToString(Copy(Pkts[I].Data, 1, Length(Pkts[I].Data) - 1));
      if Pkts[I].Data[0] = 3 then
        Msg := Msg + Trim(S) + LineEnding;
      Continue;
    end;
    S := GitBytesToString(Pkts[I].Data);
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
    Resp := GitStringToBytes(Out_.StdOut + Out_.StdErr);
    if Length(Resp) = 0 then
      raise EGitError.CreateFmt('receive-pack failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr)]);
    ParsePushResponse(GitStringToBytes(Out_.StdOut));
    raise EGitError.CreateFmt('receive-pack failed (%d): %s', [Out_.ExitCode, Trim(Out_.StdErr + Out_.StdOut)]);
  end;
  Resp := GitStringToBytes(Out_.StdOut);
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

end.
