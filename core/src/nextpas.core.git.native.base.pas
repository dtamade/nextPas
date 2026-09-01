unit nextpas.core.git.native.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.git.base,
  nextpas.core.bytes.ops;

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
function GitKindFromString(const AName: string): TGitObjectKind;
function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;

function GitBytesToString(const ABytes: TBytes): string;
function GitStringToBytes(const AText: string): TBytes;

implementation

uses
  nextpas.core.base.utils;

function HexVal(ACh: Char): Integer; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function GitOidIsValidHex(const AHex: string): Boolean; inline;
var
  I: Integer;
begin
  if Length(AHex) <> GitOidHexLen then
    Exit(False);
  for I := 1 to GitOidHexLen do
    if HexVal(AHex[I]) < 0 then
      Exit(False);
  Result := True;
end;

function GitOidFromHex(const AHex: string): TGitOid; inline;
var
  I: Integer;
begin
  if not GitOidIsValidHex(AHex) then
    raise EGitError.CreateFmt('invalid git oid hex "%s"', [AHex]);
  for I := 0 to GitOidRawLen - 1 do
    Result.Bytes[I] := Byte((HexVal(AHex[I * 2 + 1]) shl 4)
      or HexVal(AHex[I * 2 + 2]));
end;

function GitOidToHex(const AOid: TGitOid): string; inline;
const
  CHex: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, GitOidHexLen);
  for I := 0 to GitOidRawLen - 1 do
  begin
    Result[I * 2 + 1] := CHex[AOid.Bytes[I] shr 4];
    Result[I * 2 + 2] := CHex[AOid.Bytes[I] and $0F];
  end;
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

function GitBytesToString(const ABytes: TBytes): string;
begin
  Result := BytesToString(ABytes);
end;

function GitStringToBytes(const AText: string): TBytes;
begin
  Result := StringToBytes(AText);
end;

end.
