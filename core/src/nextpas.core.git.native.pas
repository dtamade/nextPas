unit nextpas.core.git.native;

{$I nextpas.core.settings.inc}

{**
 * @desc Pure-Pascal git subfamily thin aggregator.
 *  Core object layer remains here (oid/zlib/loose/pack/refs/objmodel/write)
 *  for BC; extended domains are split into facade shards to keep each unit
 *  under the 800-line guidance:
 *    - nextpas.core.git.native.objects    : oid, zlib, loose/pack, refs, objmodel, write
 *    - nextpas.core.git.native.staging    : index, cachetree, status, worktree, lsfiles, clean
 *    - nextpas.core.git.native.history    : revwalk, commitgraph, reflog, revparse, log/diff/blame
 *    - nextpas.core.git.native.branches   : branch, tag, stash, notes
 *    - nextpas.core.git.native.transport  : config, pktline, remote, advertise, negotiate, sideband, indexer, fetch/clone/checkout/push/reset
 *    - nextpas.core.git.native.extensions : archive, submodule, mailmap, trailer, bundle, grep, bisect
 *  New code should `uses` the relevant shard directly; this unit re-exports
 *  all public types/consts for legacy `uses nextpas.core.git.native` and keeps
 *  the object-layer inline gateway (<400 lines) with zero-copy inline forwards.
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.objects,
  nextpas.core.git.native.staging,
  nextpas.core.git.native.history,
  nextpas.core.git.native.branches,
  nextpas.core.git.native.transport,
  nextpas.core.git.native.extensions;

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

  { Re-export staging types }
  TGitIndexEntry = nextpas.core.git.native.staging.TGitIndexEntry;
  TGitIndexFile = nextpas.core.git.native.staging.TGitIndexFile;
  TGitIndexEntryArray = nextpas.core.git.native.staging.TGitIndexEntryArray;
  TGitCacheTree = nextpas.core.git.native.staging.TGitCacheTree;
  TGitStatusCode = nextpas.core.git.native.staging.TGitStatusCode;
  TGitNativeStatusEntry = nextpas.core.git.native.staging.TGitNativeStatusEntry;
  TGitNativeStatusArray = nextpas.core.git.native.staging.TGitNativeStatusArray;
  TGitIgnoreMatcher = nextpas.core.git.native.staging.TGitIgnoreMatcher;
  TGitWorktree = nextpas.core.git.native.staging.TGitWorktree;
  TGitWorktreeArray = nextpas.core.git.native.staging.TGitWorktreeArray;
  TGitLsFilesOptions = nextpas.core.git.native.staging.TGitLsFilesOptions;
  TGitAttr = nextpas.core.git.native.staging.TGitAttr;
  TGitAttrArray = nextpas.core.git.native.staging.TGitAttrArray;
  TGitAttrEntry = nextpas.core.git.native.staging.TGitAttrEntry;
  TGitAttrEntries = nextpas.core.git.native.staging.TGitAttrEntries;
  TGitAttrKind = nextpas.core.git.native.staging.TGitAttrKind;

  { Re-export history types }
  TGitRevWalker = nextpas.core.git.native.history.TGitRevWalker;
  TGitOidArray = nextpas.core.git.native.history.TGitOidArray;
  TGitOidSet = nextpas.core.git.native.history.TGitOidSet;
  TGitRevEntry = nextpas.core.git.native.history.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.history.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.history.TGitRevOptions;
  TCommitGraph = nextpas.core.git.native.history.TCommitGraph;
  TCommitGraphEntry = nextpas.core.git.native.history.TCommitGraphEntry;
  TGitReflogEntry = nextpas.core.git.native.history.TGitReflogEntry;
  TGitReflog = nextpas.core.git.native.history.TGitReflog;
  TGitLogEntry = nextpas.core.git.native.history.TGitLogEntry;
  TGitLogArray = nextpas.core.git.native.history.TGitLogArray;
  TGitDiffStatus = nextpas.core.git.native.history.TGitDiffStatus;
  TGitDiffEntry = nextpas.core.git.native.history.TGitDiffEntry;
  TGitDiffArray = nextpas.core.git.native.history.TGitDiffArray;
  TGitBlameEntry = nextpas.core.git.native.history.TGitBlameEntry;
  TGitBlameArray = nextpas.core.git.native.history.TGitBlameArray;
  TGitShow = nextpas.core.git.native.history.TGitShow;
  TGitShortlogEntry = nextpas.core.git.native.history.TGitShortlogEntry;
  TGitShortlogArray = nextpas.core.git.native.history.TGitShortlogArray;
  TGitCatFile = nextpas.core.git.native.history.TGitCatFile;

  { Re-export branches types }
  TGitStashEntry = nextpas.core.git.native.branches.TGitStashEntry;
  TGitStashArray = nextpas.core.git.native.branches.TGitStashArray;
  TGitNoteEntry = nextpas.core.git.native.branches.TGitNoteEntry;
  TGitNoteArray = nextpas.core.git.native.branches.TGitNoteArray;
  TGitBranchEntry = nextpas.core.git.native.branches.TGitBranchEntry;
  TGitBranchArray = nextpas.core.git.native.branches.TGitBranchArray;
  TGitTagEntry = nextpas.core.git.native.branches.TGitTagEntry;
  TGitTagArray = nextpas.core.git.native.branches.TGitTagArray;

  { Re-export transport types }
  TGitConfig = nextpas.core.git.native.transport.TGitConfig;
  TGitConfigEntry = nextpas.core.git.native.transport.TGitConfigEntry;
  TGitPktKind = nextpas.core.git.native.transport.TGitPktKind;
  TGitPkt = nextpas.core.git.native.transport.TGitPkt;
  TGitPktArray = nextpas.core.git.native.transport.TGitPktArray;
  TGitRemote = nextpas.core.git.native.transport.TGitRemote;
  TGitRemoteArray = nextpas.core.git.native.transport.TGitRemoteArray;
  TGitAdvertisedRef = nextpas.core.git.native.transport.TGitAdvertisedRef;
  TGitAdvertisedRefArray = nextpas.core.git.native.transport.TGitAdvertisedRefArray;
  TGitAdvertised = nextpas.core.git.native.transport.TGitAdvertised;
  TGitAckStatus = nextpas.core.git.native.transport.TGitAckStatus;
  TGitAck = nextpas.core.git.native.transport.TGitAck;
  TGitAckArray = nextpas.core.git.native.transport.TGitAckArray;
  TGitSidebandKind = nextpas.core.git.native.transport.TGitSidebandKind;
  TGitSideband = nextpas.core.git.native.transport.TGitSideband;
  TGitSidebandArray = nextpas.core.git.native.transport.TGitSidebandArray;
  TGitSidebandDemuxed = nextpas.core.git.native.transport.TGitSidebandDemuxed;
  TGitPushUpdate = nextpas.core.git.native.transport.TGitPushUpdate;
  TGitPushUpdateArray = nextpas.core.git.native.transport.TGitPushUpdateArray;

  { Re-export extensions types }
  TGitSubmodule = nextpas.core.git.native.extensions.TGitSubmodule;
  TGitSubmoduleArray = nextpas.core.git.native.extensions.TGitSubmoduleArray;
  TGitMailmapEntry = nextpas.core.git.native.extensions.TGitMailmapEntry;
  TGitMailmap = nextpas.core.git.native.extensions.TGitMailmap;
  TGitTrailer = nextpas.core.git.native.extensions.TGitTrailer;
  TGitTrailerArray = nextpas.core.git.native.extensions.TGitTrailerArray;
  TGitBundleRef = nextpas.core.git.native.extensions.TGitBundleRef;
  TGitBundleRefArray = nextpas.core.git.native.extensions.TGitBundleRefArray;
  TGitBundlePrereq = nextpas.core.git.native.extensions.TGitBundlePrereq;
  TGitBundlePrereqArray = nextpas.core.git.native.extensions.TGitBundlePrereqArray;
  TGitBundleHeader = nextpas.core.git.native.extensions.TGitBundleHeader;
  TGitGrepHit = nextpas.core.git.native.extensions.TGitGrepHit;
  TGitGrepHitArray = nextpas.core.git.native.extensions.TGitGrepHitArray;
  TGitBisectCheck = nextpas.core.git.native.extensions.TGitBisectCheck;
  TGitBisectResult = nextpas.core.git.native.extensions.TGitBisectResult;

const
  GitOidHexLen = nextpas.core.git.native.objects.GitOidHexLen;
  GitOidRawLen = nextpas.core.git.native.objects.GitOidRawLen;
  GitMaxDeltaDepth = nextpas.core.git.native.objects.GitMaxDeltaDepth;

  gscUnmodified = nextpas.core.git.native.staging.gscUnmodified;
  gscAdded = nextpas.core.git.native.staging.gscAdded;
  gscModified = nextpas.core.git.native.staging.gscModified;
  gscDeleted = nextpas.core.git.native.staging.gscDeleted;
  gscTypeChanged = nextpas.core.git.native.staging.gscTypeChanged;
  gscUnmerged = nextpas.core.git.native.staging.gscUnmerged;
  gscUntracked = nextpas.core.git.native.staging.gscUntracked;
  gscRenamed = nextpas.core.git.native.staging.gscRenamed;
  gscCopied = nextpas.core.git.native.staging.gscCopied;

  gdsAdded = nextpas.core.git.native.history.gdsAdded;
  gdsModified = nextpas.core.git.native.history.gdsModified;
  gdsDeleted = nextpas.core.git.native.history.gdsDeleted;
  gdsTypeChanged = nextpas.core.git.native.history.gdsTypeChanged;

  gasNak = nextpas.core.git.native.transport.gasNak;
  gasAck = nextpas.core.git.native.transport.gasAck;
  gasCommon = nextpas.core.git.native.transport.gasCommon;
  gasContinue = nextpas.core.git.native.transport.gasContinue;
  gasReady = nextpas.core.git.native.transport.gasReady;

  gsbData = nextpas.core.git.native.transport.gsbData;
  gsbProgress = nextpas.core.git.native.transport.gsbProgress;
  gsbError = nextpas.core.git.native.transport.gsbError;

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
