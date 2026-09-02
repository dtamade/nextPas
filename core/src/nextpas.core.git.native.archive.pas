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
  nextpas.core.bytes.ops,
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

{ CollectFlat: amortized O(n) via bytes.ops GrowArrayCapacity single source.
  Previously SetLength(AOut,Length+1) per entry → O(n²) copies.
  Zero-copy: string assignment is refcounted move, TGitOid 20B inline copy via direct assignment. }
procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatFileArray; var ACount, ACap: SizeUInt); overload; inline;
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
      CollectFlat(ARepo, Entries[I].Oid, Full + '/', AOut, ACount, ACap)
    else if Entries[I].Mode = $E000 then Continue // gitlink skipped
    else
    begin
      if ACount >= ACap then
      begin
        // perf: amortized geometric growth single source via bytes.ops GrowArrayCapacity (BYTES_BUILDER_MIN_GROW + *2), inline, O(1) amortized per append, zero-copy TGitOid Move via direct assignment, avoids O(n²) SetLength(Length+1) churn
        ACap := GrowArrayCapacity(ACap, ACount + 1);
        SetLength(AOut, ACap);
      end;
      AOut[ACount].Path := Full;
      AOut[ACount].Mode := Entries[I].Mode;
      AOut[ACount].Oid := Entries[I].Oid;
      Inc(ACount);
    end;
  end;
end;

procedure CollectFlat(ARepo: TNativeRepository; const ATreeOid: TGitOid; const APrefix: string; var AOut: TFlatFileArray); overload; inline;
var Cnt, Cap: SizeUInt;
begin
  Cnt := SizeUInt(Length(AOut)); Cap := Cnt;
  CollectFlat(ARepo, ATreeOid, APrefix, AOut, Cnt, Cap);
  SetLength(AOut, Cnt);
end;

function BuildFlat(const AGitDir: string; const ATreeOid: TGitOid): TFlatFileArray;
var Repo: TNativeRepository; Cnt, Cap: SizeUInt;
begin
  Result := nil;
  if GitOidIsZero(ATreeOid) then Exit;
  Repo := TNativeRepository.Create(AGitDir);
  try
    Cnt := 0; Cap := 0;
    CollectFlat(Repo, ATreeOid, '', Result, Cnt, Cap);
    SetLength(Result, Cnt);
  finally Repo.Free; end;
end;

function LocalCompareStr(const A, B: string): Integer; inline;
var I, L: Integer;
begin
  L := Length(A); if Length(B) < L then L := Length(B);
  for I := 1 to L do if A[I] <> B[I] then Exit(Ord(A[I]) - Ord(B[I]));
  Result := Length(A) - Length(B);
end;

procedure SortFlat(var A: TFlatFileArray);
  procedure MergeSort(var AItems: TFlatFileArray; var ATemp: TFlatFileArray; ALo, AHi: Integer); inline;
  var Mid, I, J, K: Integer;
  begin
    if ALo >= AHi then Exit;
    Mid := (ALo + AHi) div 2;
    MergeSort(AItems, ATemp, ALo, Mid);
    MergeSort(AItems, ATemp, Mid + 1, AHi);
    I := ALo; J := Mid + 1;
    for K := ALo to AHi do
    begin
      if (I <= Mid) and ((J > AHi) or (LocalCompareStr(AItems[I].Path, AItems[J].Path) <= 0)) then
      begin ATemp[K] := AItems[I]; Inc(I); end
      else
      begin ATemp[K] := AItems[J]; Inc(J); end;
    end;
    for K := ALo to AHi do AItems[K] := ATemp[K];
  end;
var Temp: TFlatFileArray;
begin
  if Length(A) < 2 then Exit;
  SetLength(Temp, Length(A));
  MergeSort(A, Temp, 0, High(A));
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

procedure WriteStringTo(var ABuf: TBytes; AOffset: Integer; const S: string; AFieldLen: Integer); inline;
var I, L: Integer;
begin
  L := Length(S); if L > AFieldLen then L := AFieldLen;
  for I := 1 to L do ABuf[AOffset + I - 1] := Byte(Ord(S[I]));
end;


function BuildTar(const AGitDir: string; const AFlat: TFlatFileArray): TBytes;
var Repo: TNativeRepository; I, J, Pos: Integer; Total: SizeInt; Chk: Integer; SizeVal: Int64; ModeStr: string; LinkTarget: string; Kind: TGitObjectKind; Data: TBytes; Datas: array of TBytes; Links: array of string; Sizes: array of SizeInt; PadLen: SizeInt;
begin
  Result := nil;
  if Length(AFlat) = 0 then
  begin SetLength(Result, 1024); FillChar(Result[0], 1024, 0); Exit; end;
  Repo := TNativeRepository.Create(AGitDir);
  try
    SetLength(Datas, Length(AFlat));
    SetLength(Links, Length(AFlat));
    SetLength(Sizes, Length(AFlat));
    Total := 0;
    for I := 0 to High(AFlat) do
    begin
      if AFlat[I].Mode = $A000 then
      begin
        Data := Repo.ReadObject(AFlat[I].Oid, Kind);
        if Kind <> gokBlob then raise EGitError.Create('symlink not blob');
        SetLength(LinkTarget, Length(Data));
        if Length(Data) > 0 then Move(Data[0], LinkTarget[1], Length(Data));
        Links[I] := LinkTarget;
        Sizes[I] := 0;
        Datas[I] := nil;
        Total := Total + 512;
      end else
      begin
        Data := Repo.ReadObject(AFlat[I].Oid, Kind);
        if Kind <> gokBlob then raise EGitError.Create('archive file not blob');
        Datas[I] := Data;
        Links[I] := '';
        Sizes[I] := Length(Data);
        Total := Total + 512 + ((Sizes[I] + 511) and not SizeInt(511));
      end;
    end;
    Total := Total + 1024;
    SetLength(Result, Total);
    Pos := 0;
    for I := 0 to High(AFlat) do
    begin
      FillChar(Result[Pos], 512, 0);
      if AFlat[I].Mode = $A000 then ModeStr := '0000777'
      else if AFlat[I].Mode = $81ED then ModeStr := '0000755'
      else ModeStr := '0000644';
      SizeVal := Sizes[I];
      WriteStringTo(Result, Pos + 0, AFlat[I].Path, 100);
      WriteStringTo(Result, Pos + 100, ModeStr, 7);
      WriteStringTo(Result, Pos + 108, '0000000', 7);
      WriteStringTo(Result, Pos + 116, '0000000', 7);
      WriteStringTo(Result, Pos + 124, OctalString(SizeVal, 11), 11);
      WriteStringTo(Result, Pos + 136, OctalString(0, 11), 11);
      for J := 148 to 155 do Result[Pos + J] := 32;
      if AFlat[I].Mode = $A000 then Result[Pos + 156] := Ord('2') else Result[Pos + 156] := Ord('0');
      if AFlat[I].Mode = $A000 then WriteStringTo(Result, Pos + 157, Links[I], 100);
      WriteStringTo(Result, Pos + 257, 'ustar', 5);
      WriteStringTo(Result, Pos + 263, '00', 2);
      Chk := 0; for J := 0 to 511 do Chk := Chk + Result[Pos + J];
      WriteStringTo(Result, Pos + 148, OctalString(Chk, 6), 6);
      Result[Pos + 154] := 0; Result[Pos + 155] := 32;
      Inc(Pos, 512);
      if (AFlat[I].Mode <> $A000) and (Sizes[I] > 0) then
      begin
        Move(Datas[I][0], Result[Pos], Sizes[I]);
        PadLen := ((Sizes[I] + 511) and not SizeInt(511)) - Sizes[I];
        Inc(Pos, Sizes[I] + PadLen);
      end;
    end;
    FillChar(Result[Pos], 1024, 0);
  finally Repo.Free; end;
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
