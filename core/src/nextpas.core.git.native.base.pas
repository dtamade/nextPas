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

  { Single-source re-export: git family error is owned by nextpas.core.git.base (L2) }
  EGitError = nextpas.core.git.base.EGitError;

const
  GitOidHexLen = 40;
  GitOidRawLen = 20;

function GitOidFromHex(const AHex: string): TGitOid; inline;
function GitOidToHex(const AOid: TGitOid): string; inline;
function GitOidIsValidHex(const AHex: string): Boolean; inline;
function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
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

function GitOidIsValidHex(const AHex: string): Boolean; inline;
var
  I: Integer;
begin
  { perf: inline + zero-copy single-source HexVal scan (40× inline table lookup via encoding.hex.HexVal, no alloc);
    hot per-commit/refs path; single-source validation reused by FromHex }
  if Length(AHex) <> GitOidHexLen then
    Exit(False);
  for I := 1 to GitOidHexLen do
    if HexVal(AHex[I]) < 0 then
      Exit(False);
  Result := True;
end;

function GitOidFromHex(const AHex: string): TGitOid; inline;
var
  LBytes: TBytes;
begin
  { perf: inline hot path (refs lookup / commit parse per commit); reuses
    GitOidIsValidHex single source, then single-source encoding.hex.HexDecode (table-driven 20× lookup, single alloc+Move, zero-copy PByte scan) }
  if not GitOidIsValidHex(AHex) then
    raise EGitError.CreateFmt('invalid git oid hex "%s"', [AHex]);
  LBytes := HexDecode(AHex);
  Move(LBytes[0], Result.Bytes[0], GitOidRawLen);
end;

function GitOidToHex(const AOid: TGitOid): string; inline;
var
  LBytes: TBytes;
begin
  { perf: inline + single-source encoding.hex.HexEncode (20 bytes -> 40 hex, PByte+Len table lookup, single SetLength, zero-copy beyond result alloc);
    hot display/log path }
  SetLength(LBytes, GitOidRawLen);
  Move(AOid.Bytes[0], LBytes[0], GitOidRawLen);
  Result := HexEncode(LBytes);
end;

function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
begin
  { perf: inline + zero-copy TByteSpan view (Pointer+Len) single-source bytes.ops SpanEqual via MemEqual:
    20 bytes -> ~3×QWord compares, no alloc, no 20× byte loop, hot oid set/heap path }
  Result := SpanEqual(
    TByteSpan.Create(@AA.Bytes[0], GitOidRawLen),
    TByteSpan.Create(@AB.Bytes[0], GitOidRawLen));
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
  // Directory entries (040000) point at trees, gitlinks (160000) at commits,
  // everything else (100644/100755/120000 regular/symlink) is blob content.
  if AMode = $4000 then
    Exit(gokTree);
  if AMode = $E000 then
    Exit(gokCommit);
  Result := gokBlob;
end;

function GitBytesToString(const ABytes: TBytes): string; inline;
begin
  { perf: inline thin forward to bytes.ops.BytesToString single source;
    zero-copy via single SetLength+Move(PByte^→PChar^), inline-safe }
  Result := BytesToString(ABytes);
end;

function GitStringToBytes(const AText: string): TBytes; inline;
begin
  { perf: inline thin forward to bytes.ops.StringToBytes single source;
    zero-copy via single SetLength+Move(PChar^→PByte^), inline-safe }
  Result := StringToBytes(AText);
end;

end.
