unit nextpas.core.git.native.loose;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.zlib;

{ Content-addressed object layer: "<kind> <size>\0<payload>" hashed with SHA-1,
  zlib-wrapped, stored at objects/<xx>/<38 hex>. }

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes;
function GitHashObject(AKind: TGitObjectKind; const AData: TBytes): TGitOid;
function GitLoosePath(const AGitDir: string; const AOid: TGitOid): string;
function GitLooseExists(const AGitDir: string; const AOid: TGitOid): Boolean;
function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid;
function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes;

implementation

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes;
var
  S: string;
begin
  Result := nil;
  S := GitKindToString(AKind) + ' ' + IntToStr(ASize);
  SetLength(Result, Length(S) + 1);
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
  Result[Length(S)] := 0;
end;

function GitHashObject(AKind: TGitObjectKind; const AData: TBytes): TGitOid;
var
  Header: TBytes;
  H: IHasher;
begin
  Header := GitObjectHeader(AKind, Length(AData));
  H := NewSHA1;
  H.Write(Header[0], SizeUInt(Length(Header)));
  if Length(AData) > 0 then
    H.Write(AData[0], SizeUInt(Length(AData)));
  Move(H.SumBytes[0], Result.Bytes[0], GitOidRawLen);
end;

function GitLoosePath(const AGitDir: string; const AOid: TGitOid): string;
var
  Hex: string;
begin
  Hex := GitOidToHex(AOid);
  Result := PathJoin([AGitDir, 'objects', Copy(Hex, 1, 2), Copy(Hex, 3, 38)]);
end;

function GitLooseExists(const AGitDir: string; const AOid: TGitOid): Boolean;
begin
  Result := FileExists(GitLoosePath(AGitDir, AOid));
end;

function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid;
var
  Path, DirPart: string;
  Body, Payload: TBytes;
begin
  Result := GitHashObject(AKind, AData);
  Path := GitLoosePath(AGitDir, Result);
  if FileExists(Path) then
    Exit;
  Body := GitObjectHeader(AKind, Length(AData));
  if Length(AData) > 0 then
  begin
    SetLength(Body, Length(Body) + Length(AData));
    Move(AData[0], Body[Length(Body) - Length(AData)], Length(AData));
  end;
  Payload := GitZlibCompress(Body);
  DirPart := PathDir(Path);
  if not DirectoryExists(DirPart) then
    MkdirAll(DirPart, PermDirDefault);
  WriteAtomic(Path, Payload, PermDefault);
end;

function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes;
var
  Plain: TBytes;
  EndPos: SizeUInt;
  Nul, Sp, Declared: SizeInt;
  I, Limit: SizeInt;
  HeadText: string;
  KindName, SizeText: string;
begin
  Result := nil;
  // decompress first: the "<kind> <size>\0" header lives inside the payload
  Plain := GitZlibDecompress(ReadFile(GitLoosePath(AGitDir, AOid)), 0, EndPos);
  Limit := Length(Plain);
  if Limit > 64 then
    Limit := 64;
  Nul := -1;
  for I := 0 to Limit - 1 do
    if Plain[I] = 0 then
    begin
      Nul := I;
      Break;
    end;
  if Nul < 0 then
    raise EGitError.Create('corrupt loose object: missing header terminator');
  Sp := -1;
  for I := 0 to Nul - 1 do
    if Plain[I] = Ord(' ') then
    begin
      Sp := I;
      Break;
    end;
  if Sp <= 0 then
    raise EGitError.Create('corrupt loose object header');
  SetLength(HeadText, Nul);
  Move(Plain[0], HeadText[1], Nul);
  // Sp is the 0-based index of the space inside the header text
  KindName := Copy(HeadText, 1, Sp);
  SizeText := Copy(HeadText, Sp + 2, Nul - Sp - 1);
  Declared := StrToInt64Def(SizeText, -1);
  if Declared < 0 then
    raise EGitError.CreateFmt('corrupt loose object size "%s"', [SizeText]);
  if SizeInt(Length(Plain)) - (Nul + 1) <> Declared then
    raise EGitError.Create('loose object payload size mismatch');
  AKind := GitKindFromString(KindName);
  SetLength(Result, Declared);
  if Declared > 0 then
    Move(Plain[Nul + 1], Result[0], Declared);
end;

end.
