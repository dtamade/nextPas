unit nextpas.core.git.native.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

type
  { Object kinds as encoded in loose headers and pack entry type bits }
  TGitObjectKind = (gokCommit, gokTree, gokBlob, gokTag);

  { Raw 160-bit object id }
  TGitOid = record
    Bytes: array[0..19] of Byte;
  end;

  { Family-level error for the git family (single source; backend re-exports) }
  EGitError = class(Exception)
  private
    FErrorCode: Integer;
    FErrorClass: Integer;
  public
    constructor Create(const AMsg: string); overload;
    constructor Create(AErrorCode: Integer; const AOperation: string = ''); overload;
    constructor Create(AErrorCode: Integer; AErrorClass: Integer; const AMessage: string); overload;
    property ErrorCode: Integer read FErrorCode;
    property ErrorClass: Integer read FErrorClass;
  end;

const
  GitOidHexLen = 40;
  GitOidRawLen = 20;

function GitOidFromHex(const AHex: string): TGitOid;
function GitOidToHex(const AOid: TGitOid): string;
function GitOidIsValidHex(const AHex: string): Boolean; inline;
function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
function GitKindToString(AKind: TGitObjectKind): string;
function GitKindFromString(const AName: string): TGitObjectKind;
function GitKindFromMode(AMode: Cardinal): TGitObjectKind;

{ Shared helpers single-sourced for git native subfamily: suffix test and
  worktree-dir derivation. Zero-copy scan, inline. }
function GitEndsWith(const S, Suffix: string): Boolean; inline;
function GitWorktreeDir(const AGitDir: string): string; inline;

implementation

constructor EGitError.Create(const AMsg: string);
begin
  inherited Create(AMsg);
  FErrorCode := 0;
  FErrorClass := 0;
end;

constructor EGitError.Create(AErrorCode: Integer; const AOperation: string);
begin
  if AOperation <> '' then
    inherited CreateFmt('%s (git error %d)', [AOperation, AErrorCode])
  else
    inherited CreateFmt('git error %d', [AErrorCode]);
  FErrorCode := AErrorCode;
  FErrorClass := 0;
end;

constructor EGitError.Create(AErrorCode: Integer; AErrorClass: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FErrorClass := AErrorClass;
end;

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

function GitOidFromHex(const AHex: string): TGitOid;
var
  I: Integer;
begin
  if not GitOidIsValidHex(AHex) then
    raise EGitError.CreateFmt('invalid git oid hex "%s"', [AHex]);
  for I := 0 to GitOidRawLen - 1 do
    Result.Bytes[I] := Byte((HexVal(AHex[I * 2 + 1]) shl 4)
      or HexVal(AHex[I * 2 + 2]));
end;

function GitOidToHex(const AOid: TGitOid): string;
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
var
  I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do
    if AA.Bytes[I] <> AB.Bytes[I] then
      Exit(False);
  Result := True;
end;

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
var
  I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do
    if AOid.Bytes[I] <> 0 then
      Exit(False);
  Result := True;
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

function GitEndsWith(const S, Suffix: string): Boolean; inline;
var LS, LSu, I: Integer;
begin
  LS:=Length(S); LSu:=Length(Suffix);
  if LSu=0 then Exit(True);
  if LS<LSu then Exit(False);
  // zero-copy: compare suffix in place, no Copy allocation
  for I:=1 to LSu do if S[LS-LSu+I]<>Suffix[I] then Exit(False);
  Result:=True;
end;

function GitWorktreeDir(const AGitDir: string): string; inline;
var P: Integer;
begin
  if GitEndsWith(AGitDir,'/.git') then Result:=Copy(AGitDir,1,Length(AGitDir)-5)
  else if GitEndsWith(AGitDir,'.git') then
  begin
    P:=Length(AGitDir);
    while (P>0) and (AGitDir[P]<>'/') do Dec(P);
    if P>0 then Result:=Copy(AGitDir,1,P-1) else Result:='.';
  end else Result:=AGitDir;
end;

end.
