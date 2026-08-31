unit nextpas.core.git.native.archive;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base;

{ Archive subfamily: `git archive --format=tar` pure-Pascal.
  Tree/commit/tag → flat file set → USTAR tar (512-byte blocks).
  Symlink stored as typeflag '2' with linkname; gitlink skipped;
  exec bit preserved (0755 vs 0644). }

function GitArchive(const AGitDir: string; const ATreeOid: TGitOid): TBytes; overload;
function GitArchive(const AGitDir: string; const ACommitOid: TGitOid; APeelCommit: Boolean): TBytes; overload;
function GitArchiveRef(const AGitDir, ARef: string): TBytes;
function GitArchiveToFile(const AGitDir, ARef, AOutPath: string): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.common;

// PeelToTree reused from nextpas.core.git.native.common (single source)

type
  TFlatFile = record
    Path: string;
    Mode: Cardinal;
    Oid: TGitOid;
  end;
  TFlatFileArray = array of TFlatFile;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatFileArray);
var Kind: TGitObjectKind; Data: TBytes; Entries: TGitTreeEntryArray; I: Integer; Full: string;
begin
  if GitOidIsZero(ATreeOid) then Exit;
  Data := ARepo.ReadObject(ATreeOid, Kind);
  if Kind <> gokTree then raise EGitError.CreateFmt('archive: object %s is not a tree', [GitOidToHex(ATreeOid)]);
  Entries := GitParseTree(Data);
  for I := 0 to High(Entries) do
  begin
    Full := APrefix + Entries[I].Name;
    if Entries[I].Mode = $4000 then
      CollectFlat(ARepo, Entries[I].Oid, Full + '/', AOut)
    else if Entries[I].Mode = $E000 then Continue // gitlink skipped
    else
    begin SetLength(AOut, Length(AOut)+1);
      AOut[High(AOut)].Path := Full;
      AOut[High(AOut)].Mode := Entries[I].Mode;
      AOut[High(AOut)].Oid := Entries[I].Oid;
    end;
  end;
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatFileArray;
var Repo: TNativeRepository;
begin
  Result := nil;
  if GitOidIsZero(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try CollectFlat(Repo, ATreeOid, '', Result);
  finally Repo.Free; end;
end;

function LocalCompareStr(const A, B: string): Integer;
var I, L: Integer;
begin
  L := Length(A); if Length(B) < L then L := Length(B);
  for I := 1 to L do if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

procedure SortFlat(var A: TFlatFileArray);
var I, J: Integer; T: TFlatFile;
begin
  for I := 1 to High(A) do
  begin J := I;
    while (J > 0) and (LocalCompareStr(A[J-1].Path, A[J].Path) > 0) do
    begin T := A[J-1]; A[J-1] := A[J]; A[J] := T; Dec(J); end;
  end;
end;

function OctalString(AValue: Int64; AWidth: Integer): string;
var S: string; I: Integer;
begin
  S := ''; if AValue = 0 then S := '0' else while AValue > 0 do begin S := Chr(Ord('0') + (AValue and 7)) + S; AValue := AValue shr 3; end;
  if Length(S) > AWidth then raise EGitError.Create('tar octal overflow');
  Result := '';
  for I := 1 to AWidth - Length(S) do Result := Result + '0';
  Result := Result + S;
end;

procedure WriteStringTo(var ABuf: TBytes; AOffset: Integer; const S: string; AFieldLen: Integer);
var I, L: Integer;
begin
  L := Length(S); if L > AFieldLen then L := AFieldLen;
  for I := 1 to L do ABuf[AOffset + I - 1] := Byte(Ord(S[I]));
end;

procedure AppendBytes(var ADest: TBytes; const ASrc: TBytes);
var Old: SizeInt;
begin
  Old := Length(ADest); SetLength(ADest, Old + Length(ASrc));
  if Length(ASrc) > 0 then Move(ASrc[0], ADest[Old], Length(ASrc));
end;

procedure AppendTarEntry(var ATar: TBytes; ARepo: TNativeRepository; const AFile: TFlatFile);
var Header: TBytes; Kind: TGitObjectKind; Data: TBytes; LinkTarget: string; SizeVal: Int64; ModeStr: string; Chk: Integer; I: Integer; ContentPadded: TBytes; PadLen: Integer;
begin
  if AFile.Mode = $A000 then // symlink 0120000
  begin
    Data := ARepo.ReadObject(AFile.Oid, Kind);
    if Kind <> gokBlob then raise EGitError.Create('symlink not blob');
    SetLength(LinkTarget, Length(Data));
    if Length(Data) > 0 then Move(Data[0], LinkTarget[1], Length(Data));
    SizeVal := 0;
  end else
  begin
    Data := ARepo.ReadObject(AFile.Oid, Kind);
    if Kind <> gokBlob then raise EGitError.Create('archive file not blob');
    LinkTarget := '';
    SizeVal := Length(Data);
  end;

  SetLength(Header, 512);
  FillChar(Header[0], 512, 0);
  if AFile.Mode = $A000 then ModeStr := '0000777'
  else if AFile.Mode = $81ED then ModeStr := '0000755'
  else ModeStr := '0000644';
  // USTAR: 0:100 name, 100:8 mode, 108:8 uid, 116:8 gid, 124:12 size, 136:12 mtime, 148:8 chksum, 156:1 typeflag
  WriteStringTo(Header, 0, AFile.Path, 100);
  WriteStringTo(Header, 100, ModeStr, 7);
  WriteStringTo(Header, 108, '0000000', 7);
  WriteStringTo(Header, 116, '0000000', 7);
  WriteStringTo(Header, 124, OctalString(SizeVal, 11), 11);
  WriteStringTo(Header, 136, OctalString(0, 11), 11); // mtime 0 for determinism
  // chksum initially spaces
  for I := 148 to 155 do Header[I] := 32;
  if AFile.Mode = $A000 then Header[156] := Ord('2') else Header[156] := Ord('0');
  if AFile.Mode = $A000 then WriteStringTo(Header, 157, LinkTarget, 100);
  WriteStringTo(Header, 257, 'ustar', 5);
  WriteStringTo(Header, 263, '00', 2);
  // compute chksum: sum of all 512 bytes unsigned
  Chk := 0; for I := 0 to 511 do Chk := Chk + Header[I];
  WriteStringTo(Header, 148, OctalString(Chk, 6), 6);
  Header[154] := 0; Header[155] := 32;
  AppendBytes(ATar, Header);
  if (AFile.Mode <> $A000) and (SizeVal > 0) then
  begin
    PadLen := (512 - (Length(Data) mod 512)) mod 512;
    AppendBytes(ATar, Data);
    if PadLen > 0 then
    begin SetLength(ContentPadded, PadLen); FillChar(ContentPadded[0], PadLen, 0); AppendBytes(ATar, ContentPadded); end;
  end;
end;

function BuildTar(const AGitDir: string; const AFlat: TFlatFileArray): TBytes;
var Repo: TNativeRepository; I: Integer; Zero: TBytes;
begin
  Result := nil;
  if Length(AFlat) = 0 then
  begin SetLength(Zero, 1024); FillChar(Zero[0], 1024, 0); Result := Zero; Exit; end;
  Repo := TNativeRepository.Create(AGitDir);
  try
    for I := 0 to High(AFlat) do AppendTarEntry(Result, Repo, AFlat[I]);
  finally Repo.Free; end;
  SetLength(Zero, 1024); FillChar(Zero[0], 1024, 0); AppendBytes(Result, Zero);
end;

function GitArchive(const AGitDir: string; const ATreeOid: TGitOid): TBytes;
var Flat: TFlatFileArray;
begin
  if AGitDir = '' then raise EGitError.Create('archive: gitdir empty');
  if GitOidIsZero(ATreeOid) then raise EGitError.Create('archive: empty tree');
  Flat := BuildFlat(AGitDir, ATreeOid);
  SortFlat(Flat);
  Result := BuildTar(AGitDir, Flat);
end;

function GitArchive(const AGitDir: string; const ACommitOid: TGitOid; APeelCommit: Boolean): TBytes;
var Repo: TNativeRepository; TreeOid: TGitOid;
begin
  if not APeelCommit then Exit(GitArchive(AGitDir, ACommitOid));
  Repo := TNativeRepository.Create(AGitDir);
  try TreeOid := GitPeelToTree(Repo, ACommitOid);
  finally Repo.Free; end;
  Result := GitArchive(AGitDir, TreeOid);
end;

function GitArchiveRef(const AGitDir, ARef: string): TBytes;
var Oid: TGitOid; Repo: TNativeRepository; TreeOid: TGitOid;
begin
  if ARef = '' then raise EGitError.Create('archive: empty ref');
  try Oid := GitRevParse(AGitDir, ARef);
  except Oid := GitResolveRef(AGitDir, ARef); end;
  Repo := TNativeRepository.Create(AGitDir);
  try TreeOid := GitPeelToTree(Repo, Oid);
  finally Repo.Free; end;
  Result := GitArchive(AGitDir, TreeOid);
end;

function LocalDirOf(const APath: string): string;
var P: Integer;
begin
  P := Length(APath);
  while (P > 0) and (APath[P] <> '/') do Dec(P);
  if P <= 0 then Result := '' else Result := Copy(APath, 1, P);
end;

function GitArchiveToFile(const AGitDir, ARef, AOutPath: string): string;
var Data: TBytes; Dir: string;
begin
  Data := GitArchiveRef(AGitDir, ARef);
  Dir := LocalDirOf(AOutPath);
  if Dir <> '' then ForceDirectories(Dir);
  WriteAtomic(AOutPath, Data);
  Result := AOutPath;
end;

end.
