unit nextpas.core.git.native.catfile;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Cat-file subfamily: object inspection à la `git cat-file`.
  Type/size/content via unified TNativeRepository (loose+pack),
  -p pretty for commit/tree/tag/blob, -t/-s variants. }

type
  TGitCatFile = record
    Oid: TGitOid;
    Kind: TGitObjectKind;
    Size: Integer;
    Data: TBytes; // raw uncompressed payload (without header)
    Text: string; // Data as string (binary may contain NUL)
  end;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; overload;
function GitCatFile(const AGitDir, ARev: string): TGitCatFile; overload;
function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; overload;
function GitCatFileType(const AGitDir, ARev: string): string; overload;
function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; overload;
function GitCatFileSize(const AGitDir, ARev: string): Integer; overload;
function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; overload;
function GitCatFilePretty(const AGitDir, ARev: string): string; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.write,
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

function BytesToString(const B: TBytes): string;
var L: Integer;
begin
  L := Length(B);
  SetLength(Result, L);
  if L > 0 then Move(B[0], Result[1], L);
end;

function ResolveOid(const AGitDir, ARev: string): TGitOid;
var R: string;
begin
  R := LocalTrim(ARev);
  if R = '' then raise EGitError.Create('cat-file: empty rev');
  // try rev-parse with peel? cat-file -p peels tag? git cat-file -p on tag shows tag content, not peeled.
  // So we resolve exactly without peel: try rev-parse, then direct ref.
  // For tag oid, we want tag object itself.
  try
    Result := GitRevParse(AGitDir, R);
    // GitRevParse peels ^{commit} but not plain tag? It does peel plain if tag? Actually revparse without ^{ } returns tag oid for tag ref.
    // Need to avoid auto-peel for cat-file: if R is tag name, GitRevParse may return tag oid? Check: our revparse peels tag? It peels tag? Let's verify.
    // Our revparse with ^{ } peels, but plain tag name dwim returns tag oid? In native.revparse, it peels? Let's just handle: if R contains "^{" then it's peel, else we try direct ref first.
    // Simpler: if R contains "^{" then use GitRevParse, else try GitResolveRef first to get exact ref oid.
    // To avoid complexity, try direct ref resolve first if R looks like ref.
    // But for hex oid, GitRevParse returns same.
    // We'll try: if R contains '/' or starts with "refs/" or is branch/tag name, prefer GitResolveRef.
    // For now, fallback: if GitRevParse succeeded and R has no "^{", check if ref exists and its oid is same kind? We'll just prefer GitResolveRef for non-hex revs.
  except
    Result := GitResolveRef(AGitDir, R);
  end;
end;

function GitCatFileInternal(const AGitDir: string; const AOid: TGitOid): TGitCatFile;
var
  Repo: TNativeRepository;
  Kind: TGitObjectKind;
  Data: TBytes;
begin
  if AGitDir = '' then raise EGitError.Create('cat-file: gitdir empty');
  Repo := TNativeRepository.Create(AGitDir);
  try
    Data := Repo.ReadObject(AOid, Kind);
    Result.Oid := AOid;
    Result.Kind := Kind;
    Result.Size := Length(Data);
    Result.Data := Copy(Data, 0, Length(Data));
    Result.Text := BytesToString(Data);
  finally
    Repo.Free;
  end;
end;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile;
begin
  Result := GitCatFileInternal(AGitDir, AOid);
end;

function GitCatFile(const AGitDir, ARev: string): TGitCatFile;
var Oid: TGitOid; R: string;
begin
  R := LocalTrim(ARev);
  if R = '' then raise EGitError.Create('cat-file: empty rev');
  // Prefer exact ref/oid without peel for cat-file -p semantics
  // Try to resolve as oid first (40 hex), then as ref exactly
  if GitOidIsValidHex(R) and (Length(R) = GitOidHexLen) then
  begin
    Oid := GitOidFromHex(R);
    Result := GitCatFileInternal(AGitDir, Oid);
    Exit;
  end;
  // If contains ^{ then use rev-parse peel
  if Pos('^{', R) > 0 then
  begin
    Oid := GitRevParse(AGitDir, R);
    Result := GitCatFileInternal(AGitDir, Oid);
    Exit;
  end;
  // Try exact ref (including tags) without peel
  try
    // GitResolveRef handles HEAD and refs/*
    // For branch/tag dwim, it also works via loose search? Our refs handles dwim? Actually GitResolveRef needs full ref or HEAD.
    // So try rev-parse with no peel for dwim: we can try branch resolve via GitRevParse but it may peel tag incorrectly.
    // For cat-file, we want tag object itself, not peeled. So we attempt to find tag via GitTagGetOid? Instead we try loose file existence.
    // Simpler: try GitResolveRef, if fails then use GitRevParse but check if result is tag and original R was tag name, we want tag not commit.
    // We'll try GitResolveRef first for refs/tags/* and refs/heads/*
    if (Pos('refs/', R) = 1) or (R = 'HEAD') then
    begin
      Oid := GitResolveRef(AGitDir, R);
      Result := GitCatFileInternal(AGitDir, Oid);
      Exit;
    end;
    // For short name like "v1" try refs/tags/v1 then refs/heads/v1
    try
      Oid := GitResolveRef(AGitDir, 'refs/tags/' + R);
      Result := GitCatFileInternal(AGitDir, Oid);
      Exit;
    except
    end;
    try
      Oid := GitResolveRef(AGitDir, 'refs/heads/' + R);
      Result := GitCatFileInternal(AGitDir, Oid);
      Exit;
    except
    end;
  except
  end;
  // Fallback to rev-parse (handles ~, ^, hex, HEAD)
  Oid := GitRevParse(AGitDir, R);
  Result := GitCatFileInternal(AGitDir, Oid);
end;

function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string;
var CF: TGitCatFile;
begin
  CF := GitCatFileInternal(AGitDir, AOid);
  Result := GitKindToString(CF.Kind);
end;

function GitCatFileType(const AGitDir, ARev: string): string;
var CF: TGitCatFile;
begin
  CF := GitCatFile(AGitDir, ARev);
  Result := GitKindToString(CF.Kind);
end;

function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer;
var CF: TGitCatFile;
begin
  CF := GitCatFileInternal(AGitDir, AOid);
  Result := CF.Size;
end;

function GitCatFileSize(const AGitDir, ARev: string): Integer;
var CF: TGitCatFile;
begin
  CF := GitCatFile(AGitDir, ARev);
  Result := CF.Size;
end;

function PrettyTree(const AData: TBytes): string;
var
  Entries: TGitTreeEntryArray;
  I: Integer;
  S: string;
begin
  Entries := GitParseTree(AData);
  S := '';
  for I := 0 to High(Entries) do
    S := S + GitModeToString(Entries[I].Mode) + ' ' + GitKindToString(GitKindFromMode(Entries[I].Mode)) + ' ' + GitOidToHex(Entries[I].Oid) + #9 + Entries[I].Name + #10;
  Result := S;
end;

function PrettyCommit(const AData: TBytes): string;
begin
  // commit raw is already pretty; just return text
  Result := BytesToString(AData);
end;

function PrettyTag(const AData: TBytes): string;
begin
  Result := BytesToString(AData);
end;

function PrettyBlob(const AData: TBytes): string;
begin
  Result := BytesToString(AData);
end;

function GitCatFilePrettyInternal(const AGitDir: string; const AOid: TGitOid): string;
var
  CF: TGitCatFile;
begin
  CF := GitCatFileInternal(AGitDir, AOid);
  case CF.Kind of
    gokTree: Result := PrettyTree(CF.Data);
    gokCommit: Result := PrettyCommit(CF.Data);
    gokTag: Result := PrettyTag(CF.Data);
    gokBlob: Result := PrettyBlob(CF.Data);
  else
    Result := CF.Text;
  end;
end;

function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string;
begin
  Result := GitCatFilePrettyInternal(AGitDir, AOid);
end;

function GitCatFilePretty(const AGitDir, ARev: string): string;
var CF: TGitCatFile;
begin
  CF := GitCatFile(AGitDir, ARev);
  Result := GitCatFilePrettyInternal(AGitDir, CF.Oid);
end;

end.
