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
  nextpas.core.bytes.ops,
  nextpas.core.fs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.util;

function LowerEmail(const S: string): string; inline;
begin Result:=LowerCase(S); end;

// Parse one mailmap line into entry. Returns False if empty/comment/invalid.
function TryParseMailmapLine(const ALine: string; out AEntry: TGitMailmapEntry): Boolean;
var L: string; Emails: array of string; EmailPos: array of Integer; EmailEnd: array of Integer;
    I,P,Q: Integer; NameSegs: array of string; SegStart: Integer;
    ProperName, ProperEmail, CommitName, CommitEmail: string;
    LCount, LCap, LNewCap: SizeUInt;
begin
  AEntry.ProperName:=''; AEntry.ProperEmail:=''; AEntry.CommitName:=''; AEntry.CommitEmail:='';
  L:=GitTrimSpaces(ALine);
  if L='' then Exit(False);
  if (L[1]='#') or (L[1]=';') then Exit(False);
  // extract emails inside <>
  Emails:=nil; EmailPos:=nil; EmailEnd:=nil; LCount:=0; LCap:=0;
  P:=1;
  while P<=Length(L) do
  begin
    if L[P]='<' then
    begin
      Q:=P+1;
      while (Q<=Length(L)) and (L[Q]<>'>') do Inc(Q);
      if Q>Length(L) then Break; // unclosed
      // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (small array ≤2 but keep single source discipline)
      if LCount >= LCap then
      begin
        LNewCap := GrowArrayCapacity(LCap, LCount + 1);
        SetLength(Emails, LNewCap);
        SetLength(EmailPos, LNewCap);
        SetLength(EmailEnd, LNewCap);
        LCap := LNewCap;
      end;
      Emails[LCount]:=Copy(L, P+1, Q-P-1);
      EmailPos[LCount]:=P;
      EmailEnd[LCount]:=Q;
      Inc(LCount);
      P:=Q+1;
    end else Inc(P);
  end;
  // shrink to exact count before validation
  if SizeUInt(Length(Emails)) <> LCount then
  begin
    SetLength(Emails, LCount);
    SetLength(EmailPos, LCount);
    SetLength(EmailEnd, LCount);
  end;
  if Length(Emails)=0 then Exit(False);
  if Length(Emails)>2 then Exit(False); // invalid
  // name segments: before first email, between emails, after last (ignore after)
  SetLength(NameSegs, Length(Emails)+1);
  for I:=0 to High(Emails) do
  begin
    if I=0 then SegStart:=1 else SegStart:=EmailEnd[I-1]+1;
    NameSegs[I]:=GitTrimSpaces(Copy(L, SegStart, EmailPos[I]-SegStart));
  end;
  // after last email
  NameSegs[High(NameSegs)]:=GitTrimSpaces(Copy(L, EmailEnd[High(EmailEnd)]+1, MaxInt));
  // extra commit name is the segment between emails (if 2 emails) or after email (if 1 email with trailing name?)
  // git spec: proper-name <proper-email> commit-name <commit-email>
  // So: properName = seg0, properEmail = email0, commitName = seg1, commitEmail = email1 (if 2)
  // If 1 email: could be "Proper Name <proper@email> <commit@email>" -> but that would be 2 emails.
  // If 1 email and trailing text contains no <>, then single email case: properName=seg0, properEmail=email0, commitName='', commitEmail=email0 when seg1 empty? Actually git treats single email with proper name as canonical for that email.
  // We handle 1 email: ProperName=seg0, ProperEmail=email0, CommitName=NameSegs[1], CommitEmail=email0 if NameSegs[1]<>'' then commitName else commitEmail same.
  if Length(Emails)=1 then
  begin
    ProperName:=NameSegs[0];
    ProperEmail:=GitTrimSpaces(Emails[0]);
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
    ProperEmail:=GitTrimSpaces(Emails[0]);
    CommitName:=NameSegs[1];
    CommitEmail:=GitTrimSpaces(Emails[1]);
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
    LCnt, LCap, LNewCap: SizeUInt;
begin
  Result:=nil;
  LCnt:=0; LCap:=0;
  Lines:=GitSplitLines(AText);
  for I:=0 to High(Lines) do
  begin
    L:=GitStripCR(Lines[I]);
    if TryParseMailmapLine(L, E) then
    begin
      // perf: amortized geometric growth via bytes.ops GrowArrayCapacity single source (BYTES_BUILDER_MIN_GROW + *2), O(1) amortized, zero-copy Move
      if LCnt >= LCap then
      begin
        LNewCap := GrowArrayCapacity(LCap, LCnt + 1);
        SetLength(Result, LNewCap);
        LCap := LNewCap;
      end;
      Result[LCnt]:=E;
      Inc(LCnt);
    end;
  end;
  if SizeUInt(Length(Result)) <> LCnt then
    SetLength(Result, LCnt);
end;

function GitParseMailmap(const AData: TBytes): TGitMailmap; inline;
begin
  { single-source bytes.ops.BytesToString: inline + single SetLength + single Move via PByte/PChar^ zero-copy, no duplicate hand Move }
  if Length(AData)=0 then Exit(nil);
  Result:=GitParseMailmap(BytesToString(AData));
end;



function GitLoadMailmap(const AGitDir: string): TGitMailmap;
var WDir, F: string; Data: TBytes; Repo: TNativeRepository; Oid, TreeOid, BlobOid: TGitOid; Kind: TGitObjectKind;
begin
  Result:=nil;
  // 1) worktree .mailmap
  WDir:=GitWorktreeDir(AGitDir);
  F:=PathJoin2(WDir, '.mailmap');
  if FileExists(F) then
  begin Data:=ReadFile(F); Exit(GitParseMailmap(Data)); end;
  // 2) HEAD:.mailmap
  try
    Oid:=GitRevParse(AGitDir, 'HEAD');
  except Exit(nil); end;
  Repo:=TNativeRepository.Create(AGitDir);
  try
    try TreeOid:=GitPeelToTree(Repo, Oid);
    except Exit(nil); end;
    if not GitFindBlobInTree(Repo, TreeOid, '.mailmap', BlobOid) then Exit(nil);
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
