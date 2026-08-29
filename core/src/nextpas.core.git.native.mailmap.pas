unit nextpas.core.git.native.mailmap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Mailmap subfamily: `.mailmap` identity mapping.

  Format per `gitmailmap(5)` / `mailmap.c`:
    [proper-name] [<proper-email>] [commit-name] [<commit-email>]
  Names are trimmed; emails are inside `<>` (case-insensitive match).
  Lines starting with `#` or `;` outside, empty lines skipped.
  Supports 1 or 2 emails; if 1 email, it is both proper and commit email
  when a proper name is present (canonical). }

type
  TGitMailmapEntry = record
    ProperName: string;
    ProperEmail: string;
    CommitName: string;
    CommitEmail: string;
  end;
  TGitMailmap = array of TGitMailmapEntry;

function GitParseMailmap(const AText: string): TGitMailmap; overload;
function GitParseMailmap(const AData: TBytes): TGitMailmap; overload;
function GitLoadMailmap(const AGitDir: string): TGitMailmap;
function GitMailmapResolve(const AMailmap: TGitMailmap; const AName, AEmail: string; out AOutName, AOutEmail: string): Boolean;
function GitMailmapResolveName(const AMailmap: TGitMailmap; const AName, AEmail: string): string;
function GitMailmapResolveEmail(const AMailmap: TGitMailmap; const AName, AEmail: string): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse;

function TrimSpaces(const S: string): string;
var A,B: Integer;
begin
  A:=1; B:=Length(S);
  while (A<=B) and (S[A] in [' ',#9,#10,#13]) do Inc(A);
  while (B>=A) and (S[B] in [' ',#9,#10,#13]) do Dec(B);
  if B<A then Exit('');
  Result:=Copy(S,A,B-A+1);
end;

function LowerEmail(const S: string): string;
begin Result:=LowerCase(S); end;

function IsZeroOid(const AOid: TGitOid): Boolean;
var I: Integer;
begin
  for I:=0 to GitOidRawLen-1 do if AOid.Bytes[I]<>0 then Exit(False);
  Result:=True;
end;

function LocalEndsWith(const S, Suffix: string): Boolean;
begin Result:=(Length(S)>=Length(Suffix)) and (Copy(S, Length(S)-Length(Suffix)+1, Length(Suffix))=Suffix); end;

function LocalSplitLines(const S: string): TStringArray;
var P,Start: Integer;
begin
  Result:=nil; Start:=1;
  for P:=1 to Length(S)+1 do if (P>Length(S)) or (S[P]=#10) then
  begin SetLength(Result, Length(Result)+1); Result[High(Result)]:=Copy(S, Start, P-Start); Start:=P+1; end;
end;

function StripCr(const S: string): string;
begin
  if (Length(S)>0) and (S[Length(S)]=#13) then Result:=Copy(S,1,Length(S)-1) else Result:=S;
end;

// Parse one mailmap line into entry. Returns False if empty/comment/invalid.
function TryParseMailmapLine(const ALine: string; out AEntry: TGitMailmapEntry): Boolean;
var L: string; Emails: array of string; EmailPos: array of Integer; EmailEnd: array of Integer;
    I,P,Q: Integer; NameSegs: array of string; SegStart: Integer;
    ProperName, ProperEmail, CommitName, CommitEmail: string;
begin
  AEntry.ProperName:=''; AEntry.ProperEmail:=''; AEntry.CommitName:=''; AEntry.CommitEmail:='';
  L:=TrimSpaces(ALine);
  if L='' then Exit(False);
  if (L[1]='#') or (L[1]=';') then Exit(False);
  // extract emails inside <>
  Emails:=nil; EmailPos:=nil; EmailEnd:=nil;
  P:=1;
  while P<=Length(L) do
  begin
    if L[P]='<' then
    begin
      Q:=P+1;
      while (Q<=Length(L)) and (L[Q]<>'>') do Inc(Q);
      if Q>Length(L) then Break; // unclosed
      SetLength(Emails, Length(Emails)+1);
      Emails[High(Emails)]:=Copy(L, P+1, Q-P-1);
      SetLength(EmailPos, Length(EmailPos)+1); EmailPos[High(EmailPos)]:=P;
      SetLength(EmailEnd, Length(EmailEnd)+1); EmailEnd[High(EmailEnd)]:=Q;
      P:=Q+1;
    end else Inc(P);
  end;
  if Length(Emails)=0 then Exit(False);
  if Length(Emails)>2 then Exit(False); // invalid
  // name segments: before first email, between emails, after last (ignore after)
  SetLength(NameSegs, Length(Emails)+1);
  for I:=0 to High(Emails) do
  begin
    if I=0 then SegStart:=1 else SegStart:=EmailEnd[I-1]+1;
    NameSegs[I]:=TrimSpaces(Copy(L, SegStart, EmailPos[I]-SegStart));
  end;
  // after last email
  NameSegs[High(NameSegs)]:=TrimSpaces(Copy(L, EmailEnd[High(EmailEnd)]+1, MaxInt));
  // extra commit name is the segment between emails (if 2 emails) or after email (if 1 email with trailing name?)
  // git spec: proper-name <proper-email> commit-name <commit-email>
  // So: properName = seg0, properEmail = email0, commitName = seg1, commitEmail = email1 (if 2)
  // If 1 email: could be "Proper Name <proper@email> <commit@email>" -> but that would be 2 emails.
  // If 1 email and trailing text contains no <>, then single email case: properName=seg0, properEmail=email0, commitName='', commitEmail=email0 when seg1 empty? Actually git treats single email with proper name as canonical for that email.
  // We handle 1 email: ProperName=seg0, ProperEmail=email0, CommitName=NameSegs[1], CommitEmail=email0 if NameSegs[1]<>'' then commitName else commitEmail same.
  if Length(Emails)=1 then
  begin
    ProperName:=NameSegs[0];
    ProperEmail:=TrimSpaces(Emails[0]);
    CommitName:=NameSegs[1];
    // If CommitName empty, then commitEmail is same as properEmail (canonical alias)
    // Keep commitEmail = ProperEmail so matching on email works
    CommitEmail:=ProperEmail;
    // If there is a commitName, keep commitEmail as properEmail (alias by email)
    // This matches git's "Proper Name <proper> Commit Name <commit>" with same? No, 1-email case has only one email.
    // For "New <new> Old <old>" we need 2 emails, so 1-email case is just canonical.
  end else
  begin
    ProperName:=NameSegs[0];
    ProperEmail:=TrimSpaces(Emails[0]);
    CommitName:=NameSegs[1];
    CommitEmail:=TrimSpaces(Emails[1]);
  end;
  // validation: at least proper email or proper name
  if (ProperEmail='') and (ProperName='') then Exit(False);
  AEntry.ProperName:=ProperName;
  AEntry.ProperEmail:=ProperEmail;
  AEntry.CommitName:=CommitName;
  AEntry.CommitEmail:=CommitEmail;
  Result:=True;
end;

function GitParseMailmap(const AText: string): TGitMailmap;
var Lines: TStringArray; I: Integer; L: string; E: TGitMailmapEntry;
begin
  Result:=nil;
  Lines:=LocalSplitLines(AText);
  for I:=0 to High(Lines) do
  begin
    L:=StripCr(Lines[I]);
    if TryParseMailmapLine(L, E) then
    begin SetLength(Result, Length(Result)+1); Result[High(Result)]:=E; end;
  end;
end;

function GitParseMailmap(const AData: TBytes): TGitMailmap;
var S: string;
begin
  if Length(AData)=0 then Exit(nil);
  SetLength(S, Length(AData));
  Move(AData[0], S[1], Length(AData));
  Result:=GitParseMailmap(S);
end;

function WorktreeDir(const AGitDir: string): string;
var P: Integer;
begin
  if LocalEndsWith(AGitDir, '/.git') then Result:=Copy(AGitDir,1,Length(AGitDir)-5)
  else if LocalEndsWith(AGitDir, '.git') then
  begin P:=Length(AGitDir); while (P>0) and (AGitDir[P]<>'/') do Dec(P); if P>0 then Result:=Copy(AGitDir,1,P-1) else Result:='.'; end
  else Result:=AGitDir;
end;

function FindBlobInTree(ARepo: TNativeRepository; const ATreeOid: TGitOid; const AName: string; out AOid: TGitOid): Boolean;
var Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; I: Integer;
begin
  Result:=False;
  if IsZeroOid(ATreeOid) then Exit;
  Data:=ARepo.ReadObject(ATreeOid, Kind);
  if Kind<>gokTree then Exit;
  Entries:=GitParseTree(Data);
  for I:=0 to High(Entries) do if Entries[I].Name=AName then
  begin AOid:=Entries[I].Oid; Result:=True; Exit; end;
end;

function PeelToTree(ARepo: TNativeRepository; AOid: TGitOid): TGitOid;
var Kind: TGitObjectKind; Data: TBytes; CInfo: TGitCommitInfo; TInfo: TGitTagInfo; Depth: Integer;
begin
  Result:=AOid; Depth:=0;
  while Depth<16 do
  begin
    Data:=ARepo.ReadObject(Result, Kind);
    case Kind of
      gokCommit: begin CInfo:=GitParseCommit(Data); Result:=CInfo.Tree; Exit; end;
      gokTree: Exit;
      gokTag: begin TInfo:=GitParseTag(Data); Result:=TInfo.Target; Inc(Depth); end;
    else raise EGitError.CreateFmt('mailmap: object %s is not a tree/commit/tag', [GitOidToHex(AOid)]);
    end;
  end;
  raise EGitError.Create('mailmap: tag peel too deep');
end;

function GitLoadMailmap(const AGitDir: string): TGitMailmap;
var WDir, F: string; Data: TBytes; Repo: TNativeRepository; Oid, TreeOid, BlobOid: TGitOid; Kind: TGitObjectKind;
begin
  Result:=nil;
  // 1) worktree .mailmap
  WDir:=WorktreeDir(AGitDir);
  F:=PathJoin2(WDir, '.mailmap');
  if FileExists(F) then
  begin Data:=ReadFile(F); Exit(GitParseMailmap(Data)); end;
  // 2) HEAD:.mailmap
  try
    Oid:=GitRevParse(AGitDir, 'HEAD');
  except Exit(nil); end;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    try TreeOid:=PeelToTree(Repo, Oid);
    except Exit(nil); end;
    if not FindBlobInTree(Repo, TreeOid, '.mailmap', BlobOid) then Exit(nil);
    Data:=Repo.ReadObject(BlobOid, Kind);
    if Kind<>gokBlob then Exit(nil);
    Result:=GitParseMailmap(Data);
  finally Repo.Free; end;
end;

function GitMailmapResolve(const AMailmap: TGitMailmap; const AName, AEmail: string; out AOutName, AOutEmail: string): Boolean;
var I: Integer; E: TGitMailmapEntry; EmailMatch, NameMatch: Boolean;
begin
  AOutName:=AName; AOutEmail:=AEmail;
  for I:=0 to High(AMailmap) do
  begin
    E:=AMailmap[I];
    // commit side matching
    if E.CommitEmail<>'' then EmailMatch:=LowerEmail(E.CommitEmail)=LowerEmail(AEmail) else EmailMatch:=False;
    if E.CommitName<>'' then NameMatch:=E.CommitName=AName else NameMatch:=True;
    // If commitName present, require both; if only commitEmail, require email
    // If entry has commitName but no commitEmail? then match by name.
    // Simplify: if CommitEmail<>'' then require EmailMatch; if CommitName<>'' then require NameMatch; if neither, skip
    if E.CommitEmail='' then EmailMatch:=True;
    if E.CommitName='' then NameMatch:=True;
    if (E.CommitEmail='') and (E.CommitName='') then Continue;
    if EmailMatch and NameMatch then
    begin
      if E.ProperName<>'' then AOutName:=E.ProperName;
      if E.ProperEmail<>'' then AOutEmail:=E.ProperEmail;
      Exit(True);
    end;
  end;
  Result:=False;
end;

function GitMailmapResolveName(const AMailmap: TGitMailmap; const AName, AEmail: string): string;
var N,E: string;
begin
  GitMailmapResolve(AMailmap, AName, AEmail, N, E);
  Result:=N;
end;

function GitMailmapResolveEmail(const AMailmap: TGitMailmap; const AName, AEmail: string): string;
var N,E: string;
begin
  GitMailmapResolve(AMailmap, AName, AEmail, N, E);
  Result:=E;
end;

end.
