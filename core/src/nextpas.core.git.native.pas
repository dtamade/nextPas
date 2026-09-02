unit nextpas.core.git.native;

{$I nextpas.core.settings.inc}

{**
 * @desc Pure-Pascal git subfamily object-layer facade — stable gateway.
 *  Owner boundary: `nextpas.core.git.native.objects` owns 6 subdomains
 *  (oid/zlib/loose/pack/refs/objmodel/write); `native` re-exports only
 *  object types/consts for BC and inline gateway (<350 lines, fan-in = 1 + base)
 *  keeping base←intf←impl←facade traceability. Extended domains are shard
 *  facades (staging/history/branches/transport/extensions) and must be used
 *  directly (`uses nextpas.core.git.native.staging` etc.); legacy
 *  `uses nextpas.core.git.native` for those domains is deprecated.
 *  Perf: all forwards `inline` thin wrappers; zero-copy via Move/PByte+Len
 *  /TByteSpan single source bytes.ops (oid hex 20B Move, zlib PByte+Len
 *  Deflate*, loose/pack/objmodel/write via TByteSpan). Stability:
 *  TNativeRepository/TPackFile are classes; TPackFile owns IMappedFile
 *  (refcounted, auto released on Free/destructor); TBytes results are
 *  refcounted and exception-safe (no manual free leak).
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.objects;

type
  { Re-export core object types (single source via objects shard) }
  TGitObjectKind = nextpas.core.git.native.objects.TGitObjectKind;
  TGitOid = nextpas.core.git.native.objects.TGitOid;
  EGitError = nextpas.core.git.native.objects.EGitError;
  TPackFile = nextpas.core.git.native.objects.TPackFile;
  TNativeRepository = nextpas.core.git.native.objects.TNativeRepository;
  TGitTreeEntry = nextpas.core.git.native.objects.TGitTreeEntry;
  TGitTreeEntryArray = nextpas.core.git.native.objects.TGitTreeEntryArray;
  TGitSignature = nextpas.core.git.native.objects.TGitSignature;
  TGitCommitInfo = nextpas.core.git.native.objects.TGitCommitInfo;
  TGitTagInfo = nextpas.core.git.native.objects.TGitTagInfo;
  TGitCommitBuilder = nextpas.core.git.native.objects.TGitCommitBuilder;
  TGitTagBuilder = nextpas.core.git.native.objects.TGitTagBuilder;

const
  GitOidHexLen = nextpas.core.git.native.objects.GitOidHexLen;
  GitOidRawLen = nextpas.core.git.native.objects.GitOidRawLen;
  GitMaxDeltaDepth = nextpas.core.git.native.objects.GitMaxDeltaDepth;

{ Core object-layer inline gateway (zero-copy via bytes.ops / PByte+Len) }
function GitOidFromHex(const AHex: string): TGitOid; inline;
function GitOidToHex(const AOid: TGitOid): string; inline;
function GitOidIsValidHex(const AHex: string): Boolean; inline;
function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
function GitKindToString(AKind: TGitObjectKind): string; inline;
function GitKindFromString(const AName: string): TGitObjectKind; inline;
function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;

function GitZlibAdler32(const AData: TBytes): UInt32; inline;
function GitZlibCompress(const AData: TBytes): TBytes; inline;
function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes; inline;
function GitHashObject(AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
function GitLoosePath(const AGitDir: string;
  const AOid: TGitOid): string; inline;
function GitLooseExists(const AGitDir: string;
  const AOid: TGitOid): Boolean; inline;
function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes; inline;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes; inline;

function IsGitDirShape(const APath: string): Boolean; inline;
function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean; inline;
function GitDiscoverGitDir(const AStartDir: string): string; inline;
function GitHeadRefName(const AGitDir: string): string; inline;
function GitResolveHead(const AGitDir: string): TGitOid; inline;
function GitResolveRef(const AGitDir: string;
  const ARefName: string): TGitOid; inline;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
function GitParseSignature(const ALine: string): TGitSignature; inline;
function GitParseCommit(const AData: TBytes): TGitCommitInfo; inline;
function GitParseTag(const AData: TBytes): TGitTagInfo; inline;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray); inline;
function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer; inline;
function GitModeToString(AMode: Cardinal): string; inline;
function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes; inline;
function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid; inline;
function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid; inline;
function GitBuildCommitBytes(
  const ABuilder: TGitCommitBuilder): TBytes; inline;
function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid; inline;
function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes; inline;
function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid; inline;

implementation

function GitOidFromHex(const AHex: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitOidFromHex(AHex);
end;

function GitOidToHex(const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitOidToHex(AOid);
end;

function GitOidIsValidHex(const AHex: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.objects.GitOidIsValidHex(AHex);
end;

function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.objects.GitOidSame(AA, AB);
end;

function GitKindToString(AKind: TGitObjectKind): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitKindToString(AKind);
end;

function GitKindFromString(const AName: string): TGitObjectKind; inline;
begin
  Result := nextpas.core.git.native.objects.GitKindFromString(AName);
end;

function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;
begin
  Result := nextpas.core.git.native.objects.GitKindFromMode(AMode);
end;

function GitZlibAdler32(const AData: TBytes): UInt32; inline;
begin
  Result := nextpas.core.git.native.objects.GitZlibAdler32(AData);
end;

function GitZlibCompress(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitZlibCompress(AData);
end;

function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitZlibDecompress(AData, AStart, AEndPos);
end;

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitObjectHeader(AKind, ASize);
end;

function GitHashObject(AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitHashObject(AKind, AData);
end;

function GitLoosePath(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitLoosePath(AGitDir, AOid);
end;

function GitLooseExists(const AGitDir: string; const AOid: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.objects.GitLooseExists(AGitDir, AOid);
end;

function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitLooseWrite(AGitDir, AKind, AData);
end;

function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitLooseRead(AGitDir, AOid, AKind);
end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitApplyDelta(ABase, ADelta);
end;

function IsGitDirShape(const APath: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.objects.IsGitDirShape(APath);
end;

function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.objects.GitTryDiscoverGitDir(AStartDir, AGitDir);
end;

function GitDiscoverGitDir(const AStartDir: string): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitDiscoverGitDir(AStartDir);
end;

function GitHeadRefName(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitHeadRefName(AGitDir);
end;

function GitResolveHead(const AGitDir: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitResolveHead(AGitDir);
end;

function GitResolveRef(const AGitDir: string;
  const ARefName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitResolveRef(AGitDir, ARefName);
end;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
begin
  Result := nextpas.core.git.native.objects.GitParseTree(AData);
end;

function GitParseSignature(const ALine: string): TGitSignature; inline;
begin
  Result := nextpas.core.git.native.objects.GitParseSignature(ALine);
end;

function GitParseCommit(const AData: TBytes): TGitCommitInfo; inline;
begin
  Result := nextpas.core.git.native.objects.GitParseCommit(AData);
end;

function GitParseTag(const AData: TBytes): TGitTagInfo; inline;
begin
  Result := nextpas.core.git.native.objects.GitParseTag(AData);
end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray); inline;
begin
  nextpas.core.git.native.objects.GitSortTreeEntries(AEntries);
end;

function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer; inline;
begin
  Result := nextpas.core.git.native.objects.GitEntryCompare(AA, AB);
end;

function GitModeToString(AMode: Cardinal): string; inline;
begin
  Result := nextpas.core.git.native.objects.GitModeToString(AMode);
end;

function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitSerializeTree(AEntries);
end;

function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitWriteBlob(AGitDir, AContent);
end;

function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitWriteTree(AGitDir, AEntries);
end;

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitBuildCommitBytes(ABuilder);
end;

function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitWriteCommit(AGitDir, ABuilder);
end;

function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes; inline;
begin
  Result := nextpas.core.git.native.objects.GitBuildTagBytes(ABuilder);
end;

function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid; inline;
begin
  Result := nextpas.core.git.native.objects.GitWriteTag(AGitDir, ABuilder);
end;

end.
