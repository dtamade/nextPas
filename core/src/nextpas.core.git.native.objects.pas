unit nextpas.core.git.native.objects;

{$I nextpas.core.settings.inc}

{**
 * @desc Object-layer shard facade (oid/zlib/loose/pack/refs/objmodel/write)
 * Thin gateway: pure inline forwards, no logic duplication, <400 lines.
 * Fan-in control: interface imports only type-bearing shards
 *   (base/pack/repo/objmodel/write) for re-exported types/constants;
 *   func-only shards (zlib/loose/refs) are imported in implementation,
 *   reducing interface-visible fan-in from 9 to 6 while preserving
 *   base←impl←facade depth and L0-L3 layering (L2 git may use same-layer
 *   compress/hash per registry). Legacy `uses nextpas.core.git.native` stays
 *   compatible via this facade.
 * Perf: all forwards are `inline` thin wrappers; zero-copy via Move/PByte+Len/
 *   TByteSpan single source nextpas.core.bytes.ops (oid hex 20B Move,
 *   zlib PByte+Len Deflate*, loose/pack/objmodel/write via TByteSpan).
 * Stability: TNativeRepository/TPackFile are classes; TPackFile owns
 *   IMappedFile (refcounted, auto released on Free/destructor); TBytes
 *   results are refcounted and exception-safe (no manual free leak).
 * Bytes single source: no scattered Move/Copy; all byte moves via bytes.ops.
 *}
interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.pack,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.write;

type
  TGitObjectKind = nextpas.core.git.native.base.TGitObjectKind;
  TGitOid = nextpas.core.git.native.base.TGitOid;
  EGitError = nextpas.core.git.native.base.EGitError;
  TPackFile = nextpas.core.git.native.pack.TPackFile;
  TNativeRepository = nextpas.core.git.native.repo.TNativeRepository;
  TGitTreeEntry = nextpas.core.git.native.objmodel.TGitTreeEntry;
  TGitTreeEntryArray = nextpas.core.git.native.objmodel.TGitTreeEntryArray;
  TGitSignature = nextpas.core.git.native.objmodel.TGitSignature;
  TGitCommitInfo = nextpas.core.git.native.objmodel.TGitCommitInfo;
  TGitTagInfo = nextpas.core.git.native.objmodel.TGitTagInfo;
  TGitCommitBuilder = nextpas.core.git.native.write.TGitCommitBuilder;
  TGitTagBuilder = nextpas.core.git.native.write.TGitTagBuilder;

const
  GitOidHexLen = nextpas.core.git.native.base.GitOidHexLen;
  GitOidRawLen = nextpas.core.git.native.base.GitOidRawLen;
  GitMaxDeltaDepth = nextpas.core.git.native.pack.GitMaxDeltaDepth;

{ Oid helpers — inline + zero-copy 20B Move via base/bytes.ops (CompareMem) }
function GitOidFromHex(const AHex: string): TGitOid; inline;
function GitOidToHex(const AOid: TGitOid): string; inline;
function GitOidIsValidHex(const AHex: string): Boolean; inline;
function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
function GitKindToString(AKind: TGitObjectKind): string; inline;
function GitKindFromString(const AName: string): TGitObjectKind; inline;
function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;

{ Zlib — inline forward to compress.Deflate* via git.native.zlib, PByte+Len zero-copy }
function GitZlibAdler32(const AData: TBytes): UInt32; inline;
function GitZlibCompress(const AData: TBytes): TBytes; inline;
function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;

{ Loose objects — inline forward to git.native.loose via bytes.ops single source }
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

{ Pack delta — inline TByteSpan zero-copy via git.native.pack }
function GitApplyDelta(const ABase, ADelta: TBytes): TBytes; inline;

{ Refs/discovery — inline forward to git.native.refs }
function IsGitDirShape(const APath: string): Boolean; inline;
function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean; inline;
function GitDiscoverGitDir(const AStartDir: string): string; inline;
function GitHeadRefName(const AGitDir: string): string; inline;
function GitResolveHead(const AGitDir: string): TGitOid; inline;
function GitResolveRef(const AGitDir: string;
  const ARefName: string): TGitOid; inline;

{ Object model parsers — via git.native.objmodel, TByteSpan zero-copy }
function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
function GitParseSignature(const ALine: string): TGitSignature; inline;
function GitParseCommit(const AData: TBytes): TGitCommitInfo; inline;
function GitParseTag(const AData: TBytes): TGitTagInfo; inline;

{ Write path — via git.native.write, bytes.ops single source }
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

uses
  nextpas.core.git.native.zlib,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.refs;

function GitOidFromHex(const AHex: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.base.GitOidFromHex(AHex);
end;

function GitOidToHex(const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.base.GitOidToHex(AOid);
end;

function GitOidIsValidHex(const AHex: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.base.GitOidIsValidHex(AHex);
end;

function GitOidSame(const AA, AB: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.base.GitOidSame(AA, AB);
end;

function GitKindToString(AKind: TGitObjectKind): string; inline;
begin
  Result := nextpas.core.git.native.base.GitKindToString(AKind);
end;

function GitKindFromString(const AName: string): TGitObjectKind; inline;
begin
  Result := nextpas.core.git.native.base.GitKindFromString(AName);
end;

function GitKindFromMode(AMode: Cardinal): TGitObjectKind; inline;
begin
  Result := nextpas.core.git.native.base.GitKindFromMode(AMode);
end;

function GitZlibAdler32(const AData: TBytes): UInt32; inline;
begin
  Result := nextpas.core.git.native.zlib.GitZlibAdler32(AData);
end;

function GitZlibCompress(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.zlib.GitZlibCompress(AData);
end;

function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes; inline;
begin
  Result := nextpas.core.git.native.zlib.GitZlibDecompress(
    AData, AStart, AEndPos);
end;

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes; inline;
begin
  Result := nextpas.core.git.native.loose.GitObjectHeader(AKind, ASize);
end;

function GitHashObject(AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.loose.GitHashObject(AKind, AData);
end;

function GitLoosePath(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.loose.GitLoosePath(AGitDir, AOid);
end;

function GitLooseExists(const AGitDir: string; const AOid: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.loose.GitLooseExists(AGitDir, AOid);
end;

function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.loose.GitLooseWrite(AGitDir, AKind, AData);
end;

function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes; inline;
begin
  Result := nextpas.core.git.native.loose.GitLooseRead(AGitDir, AOid, AKind);
end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.pack.GitApplyDelta(ABase, ADelta);
end;

function IsGitDirShape(const APath: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.refs.IsGitDirShape(APath);
end;

function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.refs.GitTryDiscoverGitDir(
    AStartDir, AGitDir);
end;

function GitDiscoverGitDir(const AStartDir: string): string; inline;
begin
  Result := nextpas.core.git.native.refs.GitDiscoverGitDir(AStartDir);
end;

function GitHeadRefName(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.refs.GitHeadRefName(AGitDir);
end;

function GitResolveHead(const AGitDir: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.refs.GitResolveHead(AGitDir);
end;

function GitResolveRef(const AGitDir: string;
  const ARefName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.refs.GitResolveRef(AGitDir, ARefName);
end;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray; inline;
begin
  Result := nextpas.core.git.native.objmodel.GitParseTree(AData);
end;

function GitParseSignature(const ALine: string): TGitSignature; inline;
begin
  Result := nextpas.core.git.native.objmodel.GitParseSignature(ALine);
end;

function GitParseCommit(const AData: TBytes): TGitCommitInfo; inline;
begin
  Result := nextpas.core.git.native.objmodel.GitParseCommit(AData);
end;

function GitParseTag(const AData: TBytes): TGitTagInfo; inline;
begin
  Result := nextpas.core.git.native.objmodel.GitParseTag(AData);
end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray); inline;
begin
  nextpas.core.git.native.write.GitSortTreeEntries(AEntries);
end;

function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer; inline;
begin
  Result := nextpas.core.git.native.write.GitEntryCompare(AA, AB);
end;

function GitModeToString(AMode: Cardinal): string; inline;
begin
  Result := nextpas.core.git.native.write.GitModeToString(AMode);
end;

function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.write.GitSerializeTree(AEntries);
end;

function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.write.GitWriteBlob(AGitDir, AContent);
end;

function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid; inline;
begin
  Result := nextpas.core.git.native.write.GitWriteTree(AGitDir, AEntries);
end;

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes; inline;
begin
  Result := nextpas.core.git.native.write.GitBuildCommitBytes(ABuilder);
end;

function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid; inline;
begin
  Result := nextpas.core.git.native.write.GitWriteCommit(AGitDir, ABuilder);
end;

function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes; inline;
begin
  Result := nextpas.core.git.native.write.GitBuildTagBytes(ABuilder);
end;

function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid; inline;
begin
  Result := nextpas.core.git.native.write.GitWriteTag(AGitDir, ABuilder);
end;

end.
