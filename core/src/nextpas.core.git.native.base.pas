unit nextpas.core.git.native.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.git.base,
  nextpas.core.bytes.ops,
  nextpas.core.encoding.hex;

type
  { Object kinds as encoded in loose headers and pack entry type bits }
  TGitObjectKind = (gokCommit, gokTree, gokBlob, gokTag);

  { Raw 160-bit object id }
  TGitOid = record
    Bytes: array[0..19] of Byte;
  end;

  { Oid array single source for the git family (revwalk/commitgraph bases alias here) }
  TGitOidArray = array of TGitOid;

  { Single-source re-export: git family error is owned by nextpas.core.git.base (L2) }
  EGitError = nextpas.core.git.base.EGitError;

const
  GitOidHexLen = 40;
  GitOidRawLen = 20;

const
  GIT_MODE_DIR     = $4000;
  GIT_MODE_REGULAR = $81A4;
  GIT_MODE_EXEC    = $81ED;
  GIT_MODE_SYMLINK = $A000;
  GIT_MODE_GITLINK = $E000;

function GitOidFromHex(const AHex: string): TGitOid;
  { not inline: HexDecode alloc+table lookup (20 bytes), loop exceeds inline I-Cache benefit }
function GitOidToHex(const AOid: TGitOid): string;
  { not inline: HexEncode + 20B copy alloc, exceeds inline benefit }
function GitOidIsValidHex(const AHex: string): Boolean;
  { not inline: 40× HexVal loop exceeds inline benefit (red line 2) }
function GitOidHash(const AOid: TGitOid): UInt32; inline;
function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
function GitOidZero: TGitOid; inline;
function GitKindToString(AKind: TGitObjectKind): string;
  { not inline: branch+alloc+raise, cold path, exceeds inline benefit }
function GitKindFromString(const AName: string): TGitObjectKind;
  { not inline: string compare chain+raise, cold path }
function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;

function GitBytesToString(const ABytes: TBytes): string; inline;
function GitStringToBytes(const AText: string): TBytes; inline;

implementation

uses
  nextpas.core.base.utils;

function GitOidIsValidHex(const AHex: string): Boolean;
var
  I: Integer;
begin
  { 40× HexVal scan, reused by FromHex }
  if Length(AHex) <> GitOidHexLen then
    Exit(False);
  for I := 1 to GitOidHexLen do
    if HexVal(AHex[I]) < 0 then
      Exit(False);
  Result := True;
end;

function GitOidFromHex(const AHex: string): TGitOid;
var
  LBytes: TBytes;
begin
  { via GitOidIsValidHex + HexDecode + SpanCopy }
  if not GitOidIsValidHex(AHex) then
    raise EGitError.CreateFmt('invalid git oid hex "%s"', [AHex]);
  LBytes := HexDecode(AHex);
  SpanCopy(TByteSpan.Create(@Result.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@LBytes[0], GitOidRawLen));
end;

function GitOidToHex(const AOid: TGitOid): string;
var
  LBytes: TBytes;
begin
  { via SpanCopy + HexEncode }
  SetLength(LBytes, GitOidRawLen);
  SpanCopy(TByteSpan.Create(@LBytes[0], GitOidRawLen),
    TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
  Result := HexEncode(LBytes);
end;

function GitOidHash(const AOid: TGitOid): UInt32; inline;
begin
  { via bytes.ops SpanHashFNV1a }
  Result := SpanHashFNV1a(TByteSpan.Create(@AOid.Bytes[0], GitOidRawLen));
end;

function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
begin
  { via bytes.ops SpanEqual }
  Result := SpanEqual(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen));
end;

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
begin
  { via bytes.ops IsZeroBytes }
  Result := IsZeroBytes(TByteSpan.Create(PByte(@AOid.Bytes[0]), GitOidRawLen));
end;

function GitOidZero: TGitOid; inline;
begin
  { via bytes.ops SpanFill }
  SpanFill(TByteSpan.Create(@Result.Bytes[0], GitOidRawLen), 0);
end;

function GitKindToString(AKind: TGitObjectKind): string;
begin
  case AKind of
    gokCommit: Result := 'commit';
    gokTree: Result := 'tree';
    gokBlob: Result := 'blob';
    gokTag: Result := 'tag';
  else
    raise EGitError.Create('unknown git object kind');
  end;
end;

function GitKindFromString(const AName: string): TGitObjectKind;
begin
  if AName = 'commit' then
    Exit(gokCommit);
  if AName = 'tree' then
    Exit(gokTree);
  if AName = 'blob' then
    Exit(gokBlob);
  if AName = 'tag' then
    Exit(gokTag);
  raise EGitError.CreateFmt('unknown git object kind "%s"', [AName]);
end;

function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;
begin
  if AMode = GIT_MODE_DIR then
    Exit(gokTree);
  if AMode = GIT_MODE_GITLINK then
    Exit(gokCommit);
  Result := gokBlob;
end;

function GitBytesToString(const ABytes: TBytes): string; inline;
begin
  { via bytes.ops BytesToString }
  Result := BytesToString(ABytes);
end;

function GitStringToBytes(const AText: string): TBytes; inline;
begin
  { via bytes.ops StringToBytes }
  Result := StringToBytes(AText);
end;

end.
