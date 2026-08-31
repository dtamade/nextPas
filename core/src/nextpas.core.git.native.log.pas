unit nextpas.core.git.native.log;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.objmodel;

{ Log subfamily: commit history listing over revwalk + object parsing.
  Date-order via GitCollectCommits, peeled start, first-line message.
  Oneline mirrors `git log --oneline --no-decorate`. }

type
  TGitLogEntry = record
    Oid: TGitOid;
    ShortOid: string; // 7-char
    Message: string;  // first line
    FullMessage: string;
    Author: TGitSignature;
    Committer: TGitSignature;
    Parents: array of TGitOid;
    Tree: TGitOid;
    UnixTime: Int64; // committer time
  end;
  TGitLogArray = array of TGitLogEntry;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray; overload;
function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray; overload;
function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray; overload;
function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray; overload;
function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry;
function GitLogFirstLine(const AMessage: string): string;

implementation

uses
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.revparse;

function LocalTrim(const S: string): string;
var I, J: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] in [#9, #10, #13, ' ']) do Inc(I);
  J := Length(S);
  while (J >= I) and (S[J] in [#9, #10, #13, ' ']) do Dec(J);
  if J < I then Result := '' else Result := Copy(S, I, J - I + 1);
end;

function GitLogFirstLine(const AMessage: string): string;
var I: Integer;
begin
  Result := '';
  for I := 1 to Length(AMessage) do
    if AMessage[I] in [#10, #13] then Break
    else Result := Result + AMessage[I];
  Result := LocalTrim(Result);
end;

function ShortHex(const AOid: TGitOid): string;
begin
  Result := Copy(GitOidToHex(AOid), 1, 7);
end;

function PeelToCommit(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var
  Kind: TGitObjectKind;
  Data: TBytes;
  TagInfo: TGitTagInfo;
  Depth: Integer;
begin
  Result := AOid;
  Depth := 0;
  while Depth < 16 do
  begin
    Data := ARepo.ReadObject(Result, Kind);
    if Kind = gokTag then
    begin
      TagInfo := GitParseTag(Data);
      Result := TagInfo.Target;
      Inc(Depth);
    end
    else if Kind = gokCommit then
      Exit
    else
      raise EGitError.CreateFmt('ref does not point to commit: %s', [GitOidToHex(AOid)]);
  end;
  raise EGitError.Create('tag peel too deep');
end;

function BuildLogFromOids(ARepo: TNativeRepository; const AOids: TGitOidArray): TGitLogArray;
var
  I: Integer;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  E: TGitLogEntry;
begin
  SetLength(Result, Length(AOids));
  for I := 0 to High(AOids) do
  begin
    Data := ARepo.ReadObject(AOids[I], Kind);
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(AOids[I])]);
    Info := GitParseCommit(Data);
    E.Oid := AOids[I];
    E.ShortOid := ShortHex(AOids[I]);
    E.FullMessage := Info.Message;
    E.Message := GitLogFirstLine(Info.Message);
    E.Author := Info.Author;
    E.Committer := Info.Committer;
    E.Parents := Copy(Info.Parents, 0, Length(Info.Parents));
    E.Tree := Info.Tree;
    E.UnixTime := Info.Committer.UnixTime;
    Result[I] := E;
  end;
end;

function ResolveStartOid(const AGitDir, ARef: string): TGitOid;
var
  R: string;
begin
  R := LocalTrim(ARef);
  if R = '' then
    Result := GitResolveHead(AGitDir)
  else
  begin
    try
      Result := GitRevParse(AGitDir, R);
    except
      // fallback to direct ref
      Result := GitResolveRef(AGitDir, R);
    end;
  end;
end;

function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray;
var
  Repo: TNativeRepository;
  StartOid, Peeled: TGitOid;
  Oids: TGitOidArray;
begin
  Result := nil;
  if AGitDir = '' then raise EGitError.Create('log: gitdir empty');
  StartOid := ResolveStartOid(AGitDir, ARef);
  Repo := TNativeRepository.Create(AGitDir);
  try
    Peeled := PeelToCommit(Repo, StartOid);
    Oids := GitCollectCommits(Repo, [Peeled], AMaxCount);
    Result := BuildLogFromOids(Repo, Oids);
  finally
    Repo.Free;
  end;
end;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray;
begin
  Result := GitLogList(AGitDir, '', AMaxCount);
end;

function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray;
var
  Logs: TGitLogArray;
  I: Integer;
begin
  Logs := GitLogList(AGitDir, ARef, AMaxCount);
  SetLength(Result, Length(Logs));
  for I := 0 to High(Logs) do
    Result[I] := Logs[I].ShortOid + ' ' + Logs[I].Message;
end;

function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray;
begin
  Result := GitLogOneline(AGitDir, '', AMaxCount);
end;

function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
  Info: TGitCommitInfo;
  Cur: TGitOid;
begin
  Cur := AOid;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(Cur, Kind);
    if Kind = gokTag then
    begin
      Cur := PeelToCommit(Repo, Cur);
      Data := Repo.ReadObject(Cur, Kind);
    end;
    if Kind <> gokCommit then
      raise EGitError.CreateFmt('object %s is not a commit', [GitOidToHex(Cur)]);
    Info := GitParseCommit(Data);
    Result.Oid := Cur;
    Result.ShortOid := ShortHex(Cur);
    Result.FullMessage := Info.Message;
    Result.Message := GitLogFirstLine(Info.Message);
    Result.Author := Info.Author;
    Result.Committer := Info.Committer;
    Result.Parents := Copy(Info.Parents, 0, Length(Info.Parents));
    Result.Tree := Info.Tree;
    Result.UnixTime := Info.Committer.UnixTime;
  finally
    Repo.Free;
  end;
end;

end.
