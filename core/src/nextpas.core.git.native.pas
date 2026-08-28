unit nextpas.core.git.native;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.compress,
  nextpas.core.hash.sha1,
  nextpas.core.git.native.base,
  nextpas.core.git.native.zlib,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.pack,
  nextpas.core.git.native.refs,
  nextpas.core.git.native.objmodel,
  nextpas.core.git.native.repo,
  nextpas.core.git.native.write,
  nextpas.core.git.native.index,
  nextpas.core.git.native.status,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.ignore,
  nextpas.core.git.native.cachetree,
  nextpas.core.git.native.commitgraph,
  nextpas.core.git.native.reflog,
  nextpas.core.git.native.stash,
  nextpas.core.git.native.worktree,
  nextpas.core.git.native.config,
  nextpas.core.git.native.pktline,
  nextpas.core.git.native.remote,
  nextpas.core.git.native.advertise,
  nextpas.core.git.native.negotiate,
  nextpas.core.git.native.sideband,
  nextpas.core.git.native.indexer,
  nextpas.core.git.native.fetch,
  nextpas.core.git.native.clone,
  nextpas.core.git.native.checkout,
  nextpas.core.git.native.push,
  nextpas.core.git.native.reset,
  nextpas.core.git.native.prune,
  nextpas.core.git.native.clean,
  nextpas.core.git.native.revparse,
  nextpas.core.git.native.notes,
  nextpas.core.git.native.branch,
  nextpas.core.git.native.tag,
  nextpas.core.git.native.log,
  nextpas.core.git.native.describe,
  nextpas.core.git.native.diff,
  nextpas.core.git.native.blame,
  nextpas.core.git.native.mergebase,
  nextpas.core.git.native.show,
  nextpas.core.git.native.shortlog,
  nextpas.core.git.native.catfile,
  nextpas.core.git.native.lsfiles,
  nextpas.core.git.native.cherrypick,
  nextpas.core.git.native.revert,
  nextpas.core.git.native.archive,
  nextpas.core.git.native.submodule,
  nextpas.core.git.native.mailmap,
  nextpas.core.git.native.trailer,
  nextpas.core.git.native.attributes,
  nextpas.core.git.native.bundle,
  nextpas.core.git.native.grep,
  nextpas.core.git.native.bisect;

{ Pure-Pascal git subfamily facade: object layer (loose + pack), refs,
  object model parsing, index read/write, worktree status, revision
  walking. No external git binary or libgit2 involved. }

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
  TGitIndexEntry = nextpas.core.git.native.index.TGitIndexEntry;
  TGitIndexFile = nextpas.core.git.native.index.TGitIndexFile;
  TGitIndexEntryArray = nextpas.core.git.native.index.TGitIndexEntryArray;
  TGitStatusCode = nextpas.core.git.native.status.TGitStatusCode;
  TGitNativeStatusEntry =
    nextpas.core.git.native.status.TGitNativeStatusEntry;
  TGitNativeStatusArray =
    nextpas.core.git.native.status.TGitNativeStatusArray;
  TGitRevWalker = nextpas.core.git.native.revwalk.TGitRevWalker;
  TGitOidArray = nextpas.core.git.native.revwalk.TGitOidArray;
  TGitOidSet = nextpas.core.git.native.revwalk.TGitOidSet;
  TGitRevEntry = nextpas.core.git.native.revwalk.TGitRevEntry;
  TGitRevEntryArray = nextpas.core.git.native.revwalk.TGitRevEntryArray;
  TGitRevOptions = nextpas.core.git.native.revwalk.TGitRevOptions;
  TGitIgnoreMatcher = nextpas.core.git.native.ignore.TGitIgnoreMatcher;
  TGitCacheTree = nextpas.core.git.native.cachetree.TGitCacheTree;
  TCommitGraph = nextpas.core.git.native.commitgraph.TCommitGraph;
  TCommitGraphEntry = nextpas.core.git.native.commitgraph.TCommitGraphEntry;
  TGitReflogEntry = nextpas.core.git.native.reflog.TGitReflogEntry;
  TGitReflog = nextpas.core.git.native.reflog.TGitReflog;
  TGitStashEntry = nextpas.core.git.native.stash.TGitStashEntry;
  TGitStashArray = nextpas.core.git.native.stash.TGitStashArray;
  TGitNoteEntry = nextpas.core.git.native.notes.TGitNoteEntry;
  TGitNoteArray = nextpas.core.git.native.notes.TGitNoteArray;
  TGitBranchEntry = nextpas.core.git.native.branch.TGitBranchEntry;
  TGitBranchArray = nextpas.core.git.native.branch.TGitBranchArray;
  TGitTagEntry = nextpas.core.git.native.tag.TGitTagEntry;
  TGitTagArray = nextpas.core.git.native.tag.TGitTagArray;
  TGitLogEntry = nextpas.core.git.native.log.TGitLogEntry;
  TGitLogArray = nextpas.core.git.native.log.TGitLogArray;
  TGitDiffStatus = nextpas.core.git.native.diff.TGitDiffStatus;
  TGitDiffEntry = nextpas.core.git.native.diff.TGitDiffEntry;
  TGitDiffArray = nextpas.core.git.native.diff.TGitDiffArray;
  TGitBlameEntry = nextpas.core.git.native.blame.TGitBlameEntry;
  TGitBlameArray = nextpas.core.git.native.blame.TGitBlameArray;
  TGitShow = nextpas.core.git.native.show.TGitShow;
  TGitShortlogEntry = nextpas.core.git.native.shortlog.TGitShortlogEntry;
  TGitShortlogArray = nextpas.core.git.native.shortlog.TGitShortlogArray;
  TGitCatFile = nextpas.core.git.native.catfile.TGitCatFile;
  TGitLsFilesOptions = nextpas.core.git.native.lsfiles.TGitLsFilesOptions;
  TGitSubmodule = nextpas.core.git.native.submodule.TGitSubmodule;
  TGitSubmoduleArray = nextpas.core.git.native.submodule.TGitSubmoduleArray;
  TGitMailmapEntry = nextpas.core.git.native.mailmap.TGitMailmapEntry;
  TGitMailmap = nextpas.core.git.native.mailmap.TGitMailmap;
  TGitTrailer = nextpas.core.git.native.trailer.TGitTrailer;
  TGitTrailerArray = nextpas.core.git.native.trailer.TGitTrailerArray;
  TGitAttr = nextpas.core.git.native.attributes.TGitAttr;
  TGitAttrArray = nextpas.core.git.native.attributes.TGitAttrArray;
  TGitAttrEntry = nextpas.core.git.native.attributes.TGitAttrEntry;
  TGitAttrEntries = nextpas.core.git.native.attributes.TGitAttrEntries;
  TGitAttrKind = nextpas.core.git.native.attributes.TGitAttrKind;
  TGitBundleRef = nextpas.core.git.native.bundle.TGitBundleRef;
  TGitBundleRefArray = nextpas.core.git.native.bundle.TGitBundleRefArray;
  TGitBundlePrereq = nextpas.core.git.native.bundle.TGitBundlePrereq;
  TGitBundlePrereqArray = nextpas.core.git.native.bundle.TGitBundlePrereqArray;
  TGitBundleHeader = nextpas.core.git.native.bundle.TGitBundleHeader;
  TGitGrepHit = nextpas.core.git.native.grep.TGitGrepHit;
  TGitGrepHitArray = nextpas.core.git.native.grep.TGitGrepHitArray;
  TGitBisectCheck = nextpas.core.git.native.bisect.TGitBisectCheck;
  TGitBisectResult = nextpas.core.git.native.bisect.TGitBisectResult;
  TGitWorktree = nextpas.core.git.native.worktree.TGitWorktree;
  TGitWorktreeArray = nextpas.core.git.native.worktree.TGitWorktreeArray;
  TGitConfig = nextpas.core.git.native.config.TGitConfig;
  TGitConfigEntry = nextpas.core.git.native.config.TGitConfigEntry;
  TGitPktKind = nextpas.core.git.native.pktline.TGitPktKind;
  TGitPkt = nextpas.core.git.native.pktline.TGitPkt;
  TGitPktArray = nextpas.core.git.native.pktline.TGitPktArray;
  TGitRemote = nextpas.core.git.native.remote.TGitRemote;
  TGitRemoteArray = nextpas.core.git.native.remote.TGitRemoteArray;
  TGitAdvertisedRef = nextpas.core.git.native.advertise.TGitAdvertisedRef;
  TGitAdvertisedRefArray = nextpas.core.git.native.advertise.TGitAdvertisedRefArray;
  TGitAdvertised = nextpas.core.git.native.advertise.TGitAdvertised;
  TGitAckStatus = nextpas.core.git.native.negotiate.TGitAckStatus;
  TGitAck = nextpas.core.git.native.negotiate.TGitAck;
  TGitAckArray = nextpas.core.git.native.negotiate.TGitAckArray;
  TGitSidebandKind = nextpas.core.git.native.sideband.TGitSidebandKind;
  TGitSideband = nextpas.core.git.native.sideband.TGitSideband;
  TGitSidebandArray = nextpas.core.git.native.sideband.TGitSidebandArray;
  TGitSidebandDemuxed = nextpas.core.git.native.sideband.TGitSidebandDemuxed;
  TGitPushUpdate = nextpas.core.git.native.push.TGitPushUpdate;
  TGitPushUpdateArray = nextpas.core.git.native.push.TGitPushUpdateArray;

const
  GitOidHexLen = nextpas.core.git.native.base.GitOidHexLen;
  GitOidRawLen = nextpas.core.git.native.base.GitOidRawLen;
  GitMaxDeltaDepth = nextpas.core.git.native.pack.GitMaxDeltaDepth;

  gscUnmodified = nextpas.core.git.native.status.gscUnmodified;
  gscAdded = nextpas.core.git.native.status.gscAdded;
  gscModified = nextpas.core.git.native.status.gscModified;
  gscDeleted = nextpas.core.git.native.status.gscDeleted;
  gscTypeChanged = nextpas.core.git.native.status.gscTypeChanged;
  gscUnmerged = nextpas.core.git.native.status.gscUnmerged;
  gscUntracked = nextpas.core.git.native.status.gscUntracked;
  gscRenamed = nextpas.core.git.native.status.gscRenamed;
  gscCopied = nextpas.core.git.native.status.gscCopied;

  gdsAdded = nextpas.core.git.native.diff.gdsAdded;
  gdsModified = nextpas.core.git.native.diff.gdsModified;
  gdsDeleted = nextpas.core.git.native.diff.gdsDeleted;
  gdsTypeChanged = nextpas.core.git.native.diff.gdsTypeChanged;

  gasNak = nextpas.core.git.native.negotiate.gasNak;
  gasAck = nextpas.core.git.native.negotiate.gasAck;
  gasCommon = nextpas.core.git.native.negotiate.gasCommon;
  gasContinue = nextpas.core.git.native.negotiate.gasContinue;
  gasReady = nextpas.core.git.native.negotiate.gasReady;

  gsbData = nextpas.core.git.native.sideband.gsbData;
  gsbProgress = nextpas.core.git.native.sideband.gsbProgress;
  gsbError = nextpas.core.git.native.sideband.gsbError;

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

function GitParseIndex(const AData: TBytes): TGitIndexFile; inline;
function GitReadIndex(const AGitDir: string): TGitIndexFile; inline;
procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray); inline;
function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes; inline;
procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal); inline;

{ cache-tree: parse/serialize the TREE extension payload directly, or
  derive a full hierarchy from index entries (conflicts invalidate) }
function GitParseCacheTree(const AData: TBytes): TGitCacheTree; inline;
function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes; inline;
function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree; inline;

{ full-record variants preserving the parsed TREE cache on write }
function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes; inline;
procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile); inline;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray; overload; inline;
function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray; overload; inline;

function DefaultGitRevOptions: TGitRevOptions; inline;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

{ topological order (children always precede parents, ready set drained
  LIFO exactly like git's default --topo-order); AMaxCount < 0 means
  unlimited }
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray; overload; inline;
function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray; inline;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean; inline;
function GitCommitGraphPath(const AGitDir: string): string; inline;
function GitVerifyCommitGraph(const AGitDir: string): Boolean; inline;
procedure InvalidateCommitGraphCache(const AGitDir: string); inline;
function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes; inline;
function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string; inline;
function GitWriteCommitGraphAll(const AGitDir: string): string; inline;

function GitReflogPath(const AGitDir, ARefName: string): string; inline;
function GitReflogExists(const AGitDir, ARefName: string): Boolean; inline;
function GitParseReflogLine(const ALine: string): TGitReflogEntry; inline;
function GitParseReflog(const AData: TBytes): TGitReflog; inline;
function GitReadReflog(const AGitDir, ARefName: string): TGitReflog; inline;

function GitStashExists(const AGitDir: string): Boolean; inline;
function GitStashCount(const AGitDir: string): Integer; inline;
function GitStashList(const AGitDir: string): TGitStashArray; inline;
function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry; inline;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid; overload; inline;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid; overload; inline;
function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; overload; inline;
function GitStashApply(const AGitDir, AWorkTree: string): TGitOid; overload; inline;
procedure GitStashDrop(const AGitDir: string; AIndex: Integer); overload; inline;
procedure GitStashDrop(const AGitDir: string); overload; inline;
function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; overload; inline;
function GitStashPop(const AGitDir, AWorkTree: string): TGitOid; overload; inline;
procedure GitStashClear(const AGitDir: string); inline;

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean; overload; inline;
function GitNotesRefExists(const AGitDir: string): Boolean; overload; inline;
function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray; overload; inline;
function GitNotesList(const AGitDir: string): TGitNoteArray; overload; inline;
function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes; overload; inline;
function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes; overload; inline;
function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string; overload; inline;
function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string; overload; inline;
function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload; inline;
function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload; inline;
function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid; inline;
function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean; overload; inline;

function GitBranchList(const AGitDir: string): TGitBranchArray; inline;
function GitBranchExists(const AGitDir, ABranchName: string): Boolean; inline;
function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid; inline;
function GitBranchCurrent(const AGitDir: string): string; inline;
function GitBranchIsDetached(const AGitDir: string): Boolean; inline;
function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid; inline;
function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid; inline;
procedure GitBranchDelete(const AGitDir, ABranchName: string); inline;
function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;

function GitTagList(const AGitDir: string): TGitTagArray; inline;
function GitTagExists(const AGitDir, ATagName: string): Boolean; inline;
function GitTagGetOid(const AGitDir, ATagName: string): TGitOid; inline;
function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid; inline;
function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid; inline;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid; overload; inline;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid; overload; inline;
procedure GitTagDelete(const AGitDir, ATagName: string); inline;
function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray; overload; inline;
function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray; overload; inline;
function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray; overload; inline;
function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray; overload; inline;
function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry; inline;
function GitLogFirstLine(const AMessage: string): string; inline;

function GitDescribe(const AGitDir: string): string; overload; inline;
function GitDescribe(const AGitDir, ARef: string): string; overload; inline;
function GitDescribeTags(const AGitDir: string): string; overload; inline;
function GitDescribeTags(const AGitDir, ARef: string): string; overload; inline;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray; inline;
function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray; inline;
function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray; inline;
function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray; inline;
function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string; inline;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray; overload; inline;
function GitBlame(const AGitDir, APath: string): TGitBlameArray; overload; inline;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid; overload; inline;
function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid; overload; inline;
function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid; inline;

function GitShow(const AGitDir, ARef: string): TGitShow; overload; inline;
function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow; overload; inline;
function GitShowText(const AGitDir, ARef: string): string; overload; inline;
function GitShowText(const AGitDir: string; const AOid: TGitOid): string; overload; inline;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; overload; inline;
function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; overload; inline;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; overload; inline;
function GitCatFile(const AGitDir, ARev: string): TGitCatFile; overload; inline;
function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFileType(const AGitDir, ARev: string): string; overload; inline;
function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; overload; inline;
function GitCatFileSize(const AGitDir, ARev: string): Integer; overload; inline;
function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFilePretty(const AGitDir, ARev: string): string; overload; inline;

function DefaultGitLsFilesOptions: TGitLsFilesOptions; inline;
function GitLsFiles(const AGitDir: string): TStringArray; overload; inline;
function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray; overload; inline;
function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray; inline;
function GitLsFilesStage(const AGitDir: string): TStringArray; inline;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

function GitArchive(const AGitDir: string; const ATreeOid: TGitOid): TBytes; overload; inline;
function GitArchive(const AGitDir: string; const ACommitOid: TGitOid; APeelCommit: Boolean): TBytes; overload; inline;
function GitArchiveRef(const AGitDir, ARef: string): TBytes; inline;
function GitArchiveToFile(const AGitDir, ARef, AOutPath: string): string; inline;

function GitParseGitModules(const AText: string): TGitSubmoduleArray; overload; inline;
function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray; overload; inline;
function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray; inline;
function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray; inline;
function GitListSubmodulesAtRef(const AGitDir, ARef: string): TGitSubmoduleArray; inline;
function GitSubmoduleAtPath(const AGitDir, APath: string): TGitSubmodule; inline;

function GitParseMailmap(const AText: string): TGitMailmap; overload; inline;
function GitParseMailmap(const AData: TBytes): TGitMailmap; overload; inline;
function GitLoadMailmap(const AGitDir: string): TGitMailmap; inline;
function GitMailmapResolve(const AMailmap: TGitMailmap; const AName, AEmail: string; out AOutName, AOutEmail: string): Boolean; inline;
function GitMailmapResolveName(const AMailmap: TGitMailmap; const AName, AEmail: string): string; inline;
function GitMailmapResolveEmail(const AMailmap: TGitMailmap; const AName, AEmail: string): string; inline;

function GitParseTrailers(const AMessage: string): TGitTrailerArray; inline;
function GitFindTrailer(const ATrailers: TGitTrailerArray; const AKey: string): string; inline;
function GitHasTrailer(const ATrailers: TGitTrailerArray; const AKey: string): Boolean; inline;
function GitFormatTrailer(const AKey, AValue: string): string; inline;
function GitFormatTrailers(const ATrailers: TGitTrailerArray): string; inline;
function GitAppendTrailer(const AMessage, AKey, AValue: string): string; inline;

function GitParseAttributes(const AText: string): TGitAttrEntries; overload; inline;
function GitParseAttributes(const AData: TBytes): TGitAttrEntries; overload; inline;
function GitLoadAttributes(const AGitDir: string): TGitAttrEntries; inline;
function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray; overload; inline;
function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray; overload; inline;
function GitAttributeGet(const AGitDir, APath, AName: string): string; overload; inline;
function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string; overload; inline;

function GitCommonDir(const AGitDir: string): string; inline;
function GitIsWorktree(const AGitDir: string): Boolean; inline;
function GitWorktreeList(const AGitDir: string): TGitWorktreeArray; inline;
function GitWorktreeCount(const AGitDir: string): Integer; inline;
function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree; overload; inline;
function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree; inline;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string); overload; inline;
procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean); overload; inline;

function GitConfigPath(const AGitDir: string): string; inline;
function GitConfigExists(const AGitDir: string): Boolean; inline;
function GitParseConfig(const AData: TBytes): TGitConfig; inline;
function GitReadConfig(const AGitDir: string): TGitConfig; inline;
function GitConfigHas(const AConfig: TGitConfig; const AKey: string): Boolean; inline;
function GitConfigGet(const AConfig: TGitConfig; const AKey: string): string; inline;
function GitConfigGetAll(const AConfig: TGitConfig; const AKey: string): TStringArray; inline;
function GitConfigGetBool(const AConfig: TGitConfig; const AKey: string; out AValue: Boolean): Boolean; inline;

function GitPktEncode(const AData: TBytes): TBytes; inline;
function GitPktEncodeStr(const AText: string): TBytes; inline;
function GitPktEncodeFlush: TBytes; inline;
function GitPktEncodeDelim: TBytes; inline;
function GitPktDecode(const AFrame: TBytes; out APkt: TGitPkt): Boolean; inline;
function GitPktIsFlush(const AFrame: TBytes): Boolean; inline;
function GitPktIsDelim(const AFrame: TBytes): Boolean; inline;
function GitPktScan(const AStream: TBytes): TGitPktArray; inline;
function GitPktJoin(const APkts: TGitPktArray): TBytes; inline;

function GitRemoteList(const AGitDir: string): TGitRemoteArray; inline;
function GitRemoteFind(const AGitDir: string; const AName: string; out ARemote: TGitRemote): Boolean; inline;
function GitRemoteCount(const AGitDir: string): Integer; inline;
function GitRemoteUrl(const AGitDir: string; const AName: string): string; inline;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised; inline;
function GitParseAdvertisedRefs(const AStream: TBytes): TGitAdvertisedRefArray; inline;
function GitAdvertiseFind(const AAdv: TGitAdvertised; const AName: string; out ARef: TGitAdvertisedRef): Boolean; inline;
function GitHasCapability(const AAdv: TGitAdvertised; const ACap: string): Boolean; inline;

function GitEncodeWant(const AOid: TGitOid; const ACaps: TStringArray): TBytes; inline;
function GitEncodeWantSimple(const AOid: TGitOid): TBytes; inline;
function GitEncodeWants(const AOids: array of TGitOid; const ACaps: TStringArray): TBytes; inline;
function GitEncodeHave(const AOid: TGitOid): TBytes; inline;
function GitEncodeDone: TBytes; inline;
function GitParseAck(const AData: TBytes; out AAck: TGitAck): Boolean; inline;
function GitParseAckLine(const ALine: string; out AAck: TGitAck): Boolean; inline;
function GitParseAckStream(const AStream: TBytes): TGitAckArray; inline;

function GitSidebandEncode(AKind: TGitSidebandKind; const AData: TBytes): TBytes; inline;
function GitSidebandEncodeStr(AKind: TGitSidebandKind; const AText: string): TBytes; inline;
function GitSidebandDecode(const APktData: TBytes; out AKind: TGitSidebandKind; out APayload: TBytes): Boolean; inline;
procedure GitSidebandDemux(const AStream: TBytes; out ADemuxed: TGitSidebandDemuxed); inline;
function GitSidebandDemuxRaw(const AStream: TBytes): TGitSidebandArray; inline;
function GitSidebandJoin(const AEntries: TGitSidebandArray): TBytes; inline;

function GitBuildPackIndex(const APackData: TBytes): TBytes; inline;
function GitBuildPackIndexFile(const APackPath: string): string; inline;
function GitPackIndexPath(const APackPath: string): string; inline;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid): TBytes; overload; inline;
function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid; const AHaves: array of TGitOid): TBytes; overload; inline;
function GitFetchPackSingle(const ARemoteGitDir: string; const AWant: TGitOid): TBytes; inline;

function GitLsRemote(const ARemoteGitDir: string): TGitAdvertised; inline;
function GitCloneBare(const ARemoteGitDir, ALocalGitDir: string): TGitOid; inline;
function GitCloneBareHead(const ARemoteGitDir, ALocalGitDir: string): string; inline;
function GitClone(const ARemoteGitDir, ALocalWorkTree: string): TGitOid; inline;
function GitCloneHead(const ARemoteGitDir, ALocalWorkTree: string): string; inline;

procedure GitCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid); inline;
procedure GitCheckoutHead(const AGitDir, AWorkTree: string); inline;
function GitCheckoutCommit(const AGitDir, AWorkTree: string; const ACommitOid: TGitOid): TGitOid; inline;
function GitCheckoutRef(const AGitDir, AWorkTree, ARefName: string): TGitOid; inline;

function GitOidZero: TGitOid; inline;
function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
function GitPush(const ALocalGitDir, ARemoteGitDir, ARefName: string; const AOldOid, ANewOid: TGitOid): Boolean; overload; inline;
function GitPush(const ALocalGitDir, ARemoteGitDir: string; const AUpdates: array of TGitPushUpdate): Boolean; overload; inline;
function GitPushBranch(const ALocalGitDir, ARemoteGitDir, ABranchName: string): Boolean; inline;

function GitResetHard(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitResetHard(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

function GitRemotePrune(const ALocalGitDir, ARemoteName: string): TStringArray; inline;

function GitClean(const AGitDir, AWorkTree: string): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray; overload; inline;
function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray; overload; inline;

function GitRevParse(const AGitDir, ARev: string): TGitOid; inline;
function GitRevParseCommit(const AGitDir, ARev: string): TGitOid; inline;

function GitBundleCreate(const AGitDir, ARef, ABundlePath: string): TGitOid; overload; inline;
function GitBundleCreateFromRevs(const AGitDir: string; const ARevs: array of string; const ABundlePath: string): Integer; overload; inline;
function GitBundleCreateRange(const AGitDir, AFromRev, AToRev, ABundlePath: string): Integer; overload; inline;
function GitBundleVerify(const ABundlePath: string): Boolean; inline;
function GitBundleList(const ABundlePath: string): TGitBundleRefArray; inline;
function GitBundleParseHeader(const ABundlePath: string): TGitBundleHeader; inline;
function GitBundleParseHeaderBytes(const AData: TBytes): TGitBundleHeader; inline;
function GitBundleUnbundle(const ABundlePath, ATargetGitDir: string): Integer; inline;

function GitGrep(const AGitDir, ARev, APattern: string): TGitGrepHitArray; overload; inline;
function GitGrep(const AGitDir, ARev, APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; overload; inline;
function GitGrepTree(const AGitDir: string; const ATreeOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; overload; inline;

function GitBisectCandidates(const AGitDir, AGoodRev, ABadRev: string): TGitOidArray; inline;
function GitBisectFind(const AGitDir: string; const AGoodRev, ABadRev: string; ACheck: TGitBisectCheck): TGitBisectResult; inline;

implementation

function GitOidFromHex(const AHex: string): TGitOid;
begin
  Result := nextpas.core.git.native.base.GitOidFromHex(AHex);
end;

function GitOidToHex(const AOid: TGitOid): string;
begin
  Result := nextpas.core.git.native.base.GitOidToHex(AOid);
end;

function GitOidIsValidHex(const AHex: string): Boolean;
begin
  Result := nextpas.core.git.native.base.GitOidIsValidHex(AHex);
end;

function GitOidSame(const AA, AB: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.base.GitOidSame(AA, AB);
end;

function GitKindToString(AKind: TGitObjectKind): string;
begin
  Result := nextpas.core.git.native.base.GitKindToString(AKind);
end;

function GitKindFromString(const AName: string): TGitObjectKind;
begin
  Result := nextpas.core.git.native.base.GitKindFromString(AName);
end;

function GitKindFromMode(AMode: Cardinal): TGitObjectKind;
begin
  Result := nextpas.core.git.native.base.GitKindFromMode(AMode);
end;

function GitZlibAdler32(const AData: TBytes): UInt32;
begin
  Result := nextpas.core.git.native.zlib.GitZlibAdler32(AData);
end;

function GitZlibCompress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.git.native.zlib.GitZlibCompress(AData);
end;

function GitZlibDecompress(const AData: TBytes; AStart: SizeUInt;
  out AEndPos: SizeUInt): TBytes;
begin
  Result := nextpas.core.git.native.zlib.GitZlibDecompress(
    AData, AStart, AEndPos);
end;

function GitObjectHeader(AKind: TGitObjectKind; ASize: SizeInt): TBytes;
begin
  Result := nextpas.core.git.native.loose.GitObjectHeader(AKind, ASize);
end;

function GitHashObject(AKind: TGitObjectKind;
  const AData: TBytes): TGitOid;
begin
  Result := nextpas.core.git.native.loose.GitHashObject(AKind, AData);
end;

function GitLoosePath(const AGitDir: string; const AOid: TGitOid): string;
begin
  Result := nextpas.core.git.native.loose.GitLoosePath(AGitDir, AOid);
end;

function GitLooseExists(const AGitDir: string; const AOid: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.loose.GitLooseExists(AGitDir, AOid);
end;

function GitLooseWrite(const AGitDir: string; AKind: TGitObjectKind;
  const AData: TBytes): TGitOid;
begin
  Result := nextpas.core.git.native.loose.GitLooseWrite(AGitDir, AKind, AData);
end;

function GitLooseRead(const AGitDir: string; const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes;
begin
  Result := nextpas.core.git.native.loose.GitLooseRead(AGitDir, AOid, AKind);
end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;
begin
  Result := nextpas.core.git.native.pack.GitApplyDelta(ABase, ADelta);
end;

function IsGitDirShape(const APath: string): Boolean;
begin
  Result := nextpas.core.git.native.refs.IsGitDirShape(APath);
end;

function GitTryDiscoverGitDir(const AStartDir: string;
  out AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.refs.GitTryDiscoverGitDir(
    AStartDir, AGitDir);
end;

function GitDiscoverGitDir(const AStartDir: string): string;
begin
  Result := nextpas.core.git.native.refs.GitDiscoverGitDir(AStartDir);
end;

function GitHeadRefName(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.refs.GitHeadRefName(AGitDir);
end;

function GitResolveHead(const AGitDir: string): TGitOid;
begin
  Result := nextpas.core.git.native.refs.GitResolveHead(AGitDir);
end;

function GitResolveRef(const AGitDir: string;
  const ARefName: string): TGitOid;
begin
  Result := nextpas.core.git.native.refs.GitResolveRef(AGitDir, ARefName);
end;

function GitParseTree(const AData: TBytes): TGitTreeEntryArray;
begin
  Result := nextpas.core.git.native.objmodel.GitParseTree(AData);
end;

function GitParseSignature(const ALine: string): TGitSignature;
begin
  Result := nextpas.core.git.native.objmodel.GitParseSignature(ALine);
end;

function GitParseCommit(const AData: TBytes): TGitCommitInfo;
begin
  Result := nextpas.core.git.native.objmodel.GitParseCommit(AData);
end;

function GitParseTag(const AData: TBytes): TGitTagInfo;
begin
  Result := nextpas.core.git.native.objmodel.GitParseTag(AData);
end;

procedure GitSortTreeEntries(var AEntries: TGitTreeEntryArray);
begin
  nextpas.core.git.native.write.GitSortTreeEntries(AEntries);
end;

function GitEntryCompare(const AA, AB: TGitTreeEntry): Integer;
begin
  Result := nextpas.core.git.native.write.GitEntryCompare(AA, AB);
end;

function GitModeToString(AMode: Cardinal): string;
begin
  Result := nextpas.core.git.native.write.GitModeToString(AMode);
end;

function GitSerializeTree(const AEntries: TGitTreeEntryArray): TBytes;
begin
  Result := nextpas.core.git.native.write.GitSerializeTree(AEntries);
end;

function GitWriteBlob(const AGitDir: string;
  const AContent: TBytes): TGitOid;
begin
  Result := nextpas.core.git.native.write.GitWriteBlob(AGitDir, AContent);
end;

function GitWriteTree(const AGitDir: string;
  var AEntries: TGitTreeEntryArray): TGitOid;
begin
  Result := nextpas.core.git.native.write.GitWriteTree(AGitDir, AEntries);
end;

function GitBuildCommitBytes(const ABuilder: TGitCommitBuilder): TBytes;
begin
  Result := nextpas.core.git.native.write.GitBuildCommitBytes(ABuilder);
end;

function GitWriteCommit(const AGitDir: string;
  const ABuilder: TGitCommitBuilder): TGitOid;
begin
  Result := nextpas.core.git.native.write.GitWriteCommit(AGitDir, ABuilder);
end;

function GitBuildTagBytes(const ABuilder: TGitTagBuilder): TBytes;
begin
  Result := nextpas.core.git.native.write.GitBuildTagBytes(ABuilder);
end;

function GitWriteTag(const AGitDir: string;
  const ABuilder: TGitTagBuilder): TGitOid;
begin
  Result := nextpas.core.git.native.write.GitWriteTag(AGitDir, ABuilder);
end;

function GitParseIndex(const AData: TBytes): TGitIndexFile;
begin
  Result := nextpas.core.git.native.index.GitParseIndex(AData);
end;

function GitReadIndex(const AGitDir: string): TGitIndexFile;
begin
  Result := nextpas.core.git.native.index.GitReadIndex(AGitDir);
end;

procedure GitSortIndexEntries(var AEntries: TGitIndexEntryArray);
begin
  nextpas.core.git.native.index.GitSortIndexEntries(AEntries);
end;

function GitSerializeIndex(
  const AEntries: array of TGitIndexEntry;
  AVersion: Cardinal): TBytes;
begin
  Result := nextpas.core.git.native.index.GitSerializeIndex(
    AEntries, AVersion);
end;

procedure GitWriteIndex(const AGitDir: string;
  var AEntries: TGitIndexEntryArray; AVersion: Cardinal);
begin
  nextpas.core.git.native.index.GitWriteIndex(AGitDir, AEntries, AVersion);
end;

function GitParseCacheTree(const AData: TBytes): TGitCacheTree;
begin
  Result := nextpas.core.git.native.cachetree.GitParseCacheTree(AData);
end;

function GitSerializeCacheTree(const ATree: TGitCacheTree): TBytes;
begin
  Result := nextpas.core.git.native.cachetree.GitSerializeCacheTree(ATree);
end;

function GitBuildIndexCacheTree(
  const AEntries: array of TGitIndexEntry): TGitCacheTree;
begin
  Result := nextpas.core.git.native.index.GitBuildIndexCacheTree(AEntries);
end;

function GitSerializeIndexFile(const AFile: TGitIndexFile): TBytes;
begin
  Result := nextpas.core.git.native.index.GitSerializeIndexFile(AFile);
end;

procedure GitWriteIndexFile(const AGitDir: string;
  var AFile: TGitIndexFile);
begin
  nextpas.core.git.native.index.GitWriteIndexFile(AGitDir, AFile);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean): TGitNativeStatusArray;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer): TGitNativeStatusArray;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold);
end;

function GitCollectStatus(const AGitDir, AWorkTree: string;
  AIncludeUntracked: Boolean; AFindRenames: Boolean;
  ARenameThreshold: Integer; AFindCopies: Boolean;
  ACopyThreshold: Integer): TGitNativeStatusArray;
begin
  Result := nextpas.core.git.native.status.GitCollectStatus(
    AGitDir, AWorkTree, AIncludeUntracked, AFindRenames, ARenameThreshold,
    AFindCopies, ACopyThreshold);
end;

function DefaultGitRevOptions: TGitRevOptions;
begin
  Result := nextpas.core.git.native.revwalk.DefaultGitRevOptions;
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitCollectCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitCollectCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
begin
  Result := nextpas.core.git.native.revwalk.GitCollectCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts: TGitOidArray; AMaxCount: SizeInt): TGitOidArray;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommits(
    ARepo, AStarts, AMaxCount);
end;

function GitTopoOrderCommits(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitOidArray;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommits(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTopoOrderCommitsWithBoundary(ARepo: TNativeRepository;
  const AStarts, AHides: TGitOidArray;
  const AOptions: TGitRevOptions; AMaxCount: SizeInt): TGitRevEntryArray;
begin
  Result := nextpas.core.git.native.revwalk.GitTopoOrderCommitsWithBoundary(
    ARepo, AStarts, AHides, AOptions, AMaxCount);
end;

function GitTryLoadCommitGraph(const AGitDir: string; out AGraph: TCommitGraph): Boolean;
begin
  Result := nextpas.core.git.native.commitgraph.GitTryLoadCommitGraph(AGitDir, AGraph);
end;

function GitCommitGraphPath(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.commitgraph.GitCommitGraphPath(AGitDir);
end;

function GitVerifyCommitGraph(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.commitgraph.GitVerifyCommitGraph(AGitDir);
end;

procedure InvalidateCommitGraphCache(const AGitDir: string);
begin
  nextpas.core.git.native.commitgraph.InvalidateCommitGraphCache(AGitDir);
end;

function GitBuildCommitGraph(const AGitDir: string; const AOids: TGitOidArray): TBytes;
begin
  Result := nextpas.core.git.native.commitgraph.GitBuildCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraph(const AGitDir: string; const AOids: TGitOidArray): string;
begin
  Result := nextpas.core.git.native.commitgraph.GitWriteCommitGraph(AGitDir, AOids);
end;

function GitWriteCommitGraphAll(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.commitgraph.GitWriteCommitGraphAll(AGitDir);
end;

function GitReflogPath(const AGitDir, ARefName: string): string;
begin
  Result := nextpas.core.git.native.reflog.GitReflogPath(AGitDir, ARefName);
end;

function GitReflogExists(const AGitDir, ARefName: string): Boolean;
begin
  Result := nextpas.core.git.native.reflog.GitReflogExists(AGitDir, ARefName);
end;

function GitParseReflogLine(const ALine: string): TGitReflogEntry;
begin
  Result := nextpas.core.git.native.reflog.GitParseReflogLine(ALine);
end;

function GitParseReflog(const AData: TBytes): TGitReflog;
begin
  Result := nextpas.core.git.native.reflog.GitParseReflog(AData);
end;

function GitReadReflog(const AGitDir, ARefName: string): TGitReflog;
begin
  Result := nextpas.core.git.native.reflog.GitReadReflog(AGitDir, ARefName);
end;

function GitStashExists(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.stash.GitStashExists(AGitDir);
end;

function GitStashCount(const AGitDir: string): Integer;
begin
  Result := nextpas.core.git.native.stash.GitStashCount(AGitDir);
end;

function GitStashList(const AGitDir: string): TGitStashArray;
begin
  Result := nextpas.core.git.native.stash.GitStashList(AGitDir);
end;

function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry;
begin
  Result := nextpas.core.git.native.stash.GitStashAt(AGitDir, AIndex);
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashPush(AGitDir, AWorkTree, AMessage, AIncludeUntracked);
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashPush(AGitDir, AWorkTree, AMessage);
end;

function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashApply(AGitDir, AWorkTree, AIndex);
end;

function GitStashApply(const AGitDir, AWorkTree: string): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashApply(AGitDir, AWorkTree);
end;

procedure GitStashDrop(const AGitDir: string; AIndex: Integer);
begin
  nextpas.core.git.native.stash.GitStashDrop(AGitDir, AIndex);
end;

procedure GitStashDrop(const AGitDir: string);
begin
  nextpas.core.git.native.stash.GitStashDrop(AGitDir);
end;

function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashPop(AGitDir, AWorkTree, AIndex);
end;

function GitStashPop(const AGitDir, AWorkTree: string): TGitOid;
begin
  Result := nextpas.core.git.native.stash.GitStashPop(AGitDir, AWorkTree);
end;

procedure GitStashClear(const AGitDir: string);
begin
  nextpas.core.git.native.stash.GitStashClear(AGitDir);
end;

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesRefExists(AGitDir, ARefName);
end;

function GitNotesRefExists(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesRefExists(AGitDir);
end;

function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray;
begin
  Result := nextpas.core.git.native.notes.GitNotesList(AGitDir, ARefName);
end;

function GitNotesList(const AGitDir: string): TGitNoteArray;
begin
  Result := nextpas.core.git.native.notes.GitNotesList(AGitDir);
end;

function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.notes.GitNotesGet(AGitDir, ATarget);
end;

function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.notes.GitNotesGet(AGitDir, ARefName, ATarget);
end;

function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string;
begin
  Result := nextpas.core.git.native.notes.GitNotesGetStr(AGitDir, ATarget);
end;

function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string;
begin
  Result := nextpas.core.git.native.notes.GitNotesGetStr(AGitDir, ARefName, ATarget);
end;

function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesExists(AGitDir, ATarget);
end;

function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesExists(AGitDir, ARefName, ATarget);
end;

function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid;
begin
  Result := nextpas.core.git.native.notes.GitNotesAdd(AGitDir, ATarget, ANote);
end;

function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid;
begin
  Result := nextpas.core.git.native.notes.GitNotesAdd(AGitDir, ARefName, ATarget, ANote);
end;

function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid;
begin
  Result := nextpas.core.git.native.notes.GitNotesAddBytes(AGitDir, ARefName, ATarget, AData);
end;

function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesRemove(AGitDir, ARefName, ATarget);
end;

function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.notes.GitNotesRemove(AGitDir, ATarget);
end;

function GitBranchList(const AGitDir: string): TGitBranchArray;
begin
  Result := nextpas.core.git.native.branch.GitBranchList(AGitDir);
end;

function GitBranchExists(const AGitDir, ABranchName: string): Boolean;
begin
  Result := nextpas.core.git.native.branch.GitBranchExists(AGitDir, ABranchName);
end;

function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid;
begin
  Result := nextpas.core.git.native.branch.GitBranchGetOid(AGitDir, ABranchName);
end;

function GitBranchCurrent(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.branch.GitBranchCurrent(AGitDir);
end;

function GitBranchIsDetached(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.branch.GitBranchIsDetached(AGitDir);
end;

function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.branch.GitBranchCreate(AGitDir, ABranchName, AOid);
end;

function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid;
begin
  Result := nextpas.core.git.native.branch.GitBranchCreateFromRef(AGitDir, ABranchName, ARefName);
end;

procedure GitBranchDelete(const AGitDir, ABranchName: string);
begin
  nextpas.core.git.native.branch.GitBranchDelete(AGitDir, ABranchName);
end;

function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid;
begin
  Result := nextpas.core.git.native.branch.GitBranchRename(AGitDir, AOldName, ANewName);
end;

function GitTagList(const AGitDir: string): TGitTagArray;
begin
  Result := nextpas.core.git.native.tag.GitTagList(AGitDir);
end;

function GitTagExists(const AGitDir, ATagName: string): Boolean;
begin
  Result := nextpas.core.git.native.tag.GitTagExists(AGitDir, ATagName);
end;

function GitTagGetOid(const AGitDir, ATagName: string): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagGetOid(AGitDir, ATagName);
end;

function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagGetPeeled(AGitDir, ATagName);
end;

function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateLightweight(AGitDir, ATagName, ATargetOid);
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateAnnotated(AGitDir, ATagName, ATargetOid, AMessage);
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateAnnotated(AGitDir, ATagName, ATargetOid, AMessage, ATaggerName, ATaggerEmail);
end;

procedure GitTagDelete(const AGitDir, ATagName: string);
begin
  nextpas.core.git.native.tag.GitTagDelete(AGitDir, ATagName);
end;

function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid;
begin
  Result := nextpas.core.git.native.tag.GitTagRename(AGitDir, AOldName, ANewName);
end;

function GitLogList(const AGitDir: string; AMaxCount: Integer): TGitLogArray;
begin
  Result := nextpas.core.git.native.log.GitLogList(AGitDir, AMaxCount);
end;

function GitLogList(const AGitDir, ARef: string; AMaxCount: Integer): TGitLogArray;
begin
  Result := nextpas.core.git.native.log.GitLogList(AGitDir, ARef, AMaxCount);
end;

function GitLogOneline(const AGitDir: string; AMaxCount: Integer): TStringArray;
begin
  Result := nextpas.core.git.native.log.GitLogOneline(AGitDir, AMaxCount);
end;

function GitLogOneline(const AGitDir, ARef: string; AMaxCount: Integer): TStringArray;
begin
  Result := nextpas.core.git.native.log.GitLogOneline(AGitDir, ARef, AMaxCount);
end;

function GitLogFind(const AGitDir: string; const AOid: TGitOid): TGitLogEntry;
begin
  Result := nextpas.core.git.native.log.GitLogFind(AGitDir, AOid);
end;

function GitLogFirstLine(const AMessage: string): string;
begin
  Result := nextpas.core.git.native.log.GitLogFirstLine(AMessage);
end;

function GitDescribe(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.describe.GitDescribe(AGitDir);
end;

function GitDescribe(const AGitDir, ARef: string): string;
begin
  Result := nextpas.core.git.native.describe.GitDescribe(AGitDir, ARef);
end;

function GitDescribeTags(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.describe.GitDescribeTags(AGitDir);
end;

function GitDescribeTags(const AGitDir, ARef: string): string;
begin
  Result := nextpas.core.git.native.describe.GitDescribeTags(AGitDir, ARef);
end;

function GitDiffTrees(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TGitDiffArray;
begin
  Result := nextpas.core.git.native.diff.GitDiffTrees(AGitDir, AOldTree, ANewTree);
end;

function GitDiffCommits(const AGitDir: string; const AOldCommit, ANewCommit: TGitOid): TGitDiffArray;
begin
  Result := nextpas.core.git.native.diff.GitDiffCommits(AGitDir, AOldCommit, ANewCommit);
end;

function GitDiffRefs(const AGitDir, AOldRef, ANewRef: string): TGitDiffArray;
begin
  Result := nextpas.core.git.native.diff.GitDiffRefs(AGitDir, AOldRef, ANewRef);
end;

function GitDiffNameStatus(const AGitDir: string; const AOldTree, ANewTree: TGitOid): TStringArray;
begin
  Result := nextpas.core.git.native.diff.GitDiffNameStatus(AGitDir, AOldTree, ANewTree);
end;

function GitDiffStatSummary(const AGitDir: string; const AOldTree, ANewTree: TGitOid): string;
begin
  Result := nextpas.core.git.native.diff.GitDiffStatSummary(AGitDir, AOldTree, ANewTree);
end;

function GitBlame(const AGitDir, ARef, APath: string): TGitBlameArray;
begin
  Result := nextpas.core.git.native.blame.GitBlame(AGitDir, ARef, APath);
end;

function GitBlame(const AGitDir, APath: string): TGitBlameArray;
begin
  Result := nextpas.core.git.native.blame.GitBlame(AGitDir, APath);
end;

function GitMergeBase(const AGitDir, ARefA, ARefB: string): TGitOid;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBase(AGitDir, ARefA, ARefB);
end;

function GitMergeBase(const AGitDir: string; const AOidA, AOidB: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBase(AGitDir, AOidA, AOidB);
end;

function GitMergeBaseMany(const AGitDir: string; const AOids: array of TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.mergebase.GitMergeBaseMany(AGitDir, AOids);
end;

function GitShow(const AGitDir, ARef: string): TGitShow;
begin
  Result := nextpas.core.git.native.show.GitShow(AGitDir, ARef);
end;

function GitShow(const AGitDir: string; const AOid: TGitOid): TGitShow;
begin
  Result := nextpas.core.git.native.show.GitShow(AGitDir, AOid);
end;

function GitShowText(const AGitDir, ARef: string): string;
begin
  Result := nextpas.core.git.native.show.GitShowText(AGitDir, ARef);
end;

function GitShowText(const AGitDir: string; const AOid: TGitOid): string;
begin
  Result := nextpas.core.git.native.show.GitShowText(AGitDir, AOid);
end;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlog(AGitDir, ARef, AMaxCount);
end;

function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlog(AGitDir, AMaxCount);
end;

function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlogText(AGitDir, ARef, AMaxCount);
end;

function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlogText(AGitDir, AMaxCount);
end;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile;
begin
  Result := nextpas.core.git.native.catfile.GitCatFile(AGitDir, AOid);
end;

function GitCatFile(const AGitDir, ARev: string): TGitCatFile;
begin
  Result := nextpas.core.git.native.catfile.GitCatFile(AGitDir, ARev);
end;

function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileType(AGitDir, AOid);
end;

function GitCatFileType(const AGitDir, ARev: string): string;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileType(AGitDir, ARev);
end;

function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileSize(AGitDir, AOid);
end;

function GitCatFileSize(const AGitDir, ARev: string): Integer;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileSize(AGitDir, ARev);
end;

function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string;
begin
  Result := nextpas.core.git.native.catfile.GitCatFilePretty(AGitDir, AOid);
end;

function GitCatFilePretty(const AGitDir, ARev: string): string;
begin
  Result := nextpas.core.git.native.catfile.GitCatFilePretty(AGitDir, ARev);
end;

function DefaultGitLsFilesOptions: TGitLsFilesOptions;
begin
  Result := nextpas.core.git.native.lsfiles.DefaultGitLsFilesOptions;
end;

function GitLsFiles(const AGitDir: string): TStringArray;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFiles(AGitDir);
end;

function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFiles(AGitDir, AOptions);
end;

function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFilesDetailed(AGitDir);
end;

function GitLsFilesStage(const AGitDir: string): TStringArray;
begin
  Result := nextpas.core.git.native.lsfiles.GitLsFilesStage(AGitDir);
end;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.cherrypick.GitCherryPick(AGitDir, AWorkTree, ATargetOid);
end;

function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
begin
  Result := nextpas.core.git.native.cherrypick.GitCherryPick(AGitDir, AWorkTree, ATargetRef);
end;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.revert.GitRevert(AGitDir, AWorkTree, ATargetOid);
end;

function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
begin
  Result := nextpas.core.git.native.revert.GitRevert(AGitDir, AWorkTree, ATargetRef);
end;

function GitArchive(const AGitDir: string; const ATreeOid: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.archive.GitArchive(AGitDir, ATreeOid);
end;

function GitArchive(const AGitDir: string; const ACommitOid: TGitOid; APeelCommit: Boolean): TBytes;
begin
  Result := nextpas.core.git.native.archive.GitArchive(AGitDir, ACommitOid, APeelCommit);
end;

function GitArchiveRef(const AGitDir, ARef: string): TBytes;
begin
  Result := nextpas.core.git.native.archive.GitArchiveRef(AGitDir, ARef);
end;

function GitArchiveToFile(const AGitDir, ARef, AOutPath: string): string;
begin
  Result := nextpas.core.git.native.archive.GitArchiveToFile(AGitDir, ARef, AOutPath);
end;

function GitParseGitModules(const AText: string): TGitSubmoduleArray;
begin
  Result := nextpas.core.git.native.submodule.GitParseGitModules(AText);
end;

function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray;
begin
  Result := nextpas.core.git.native.submodule.GitParseGitModules(AData);
end;

function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodules(AGitDir);
end;

function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodulesAtTree(AGitDir, ATreeOid);
end;

function GitListSubmodulesAtRef(const AGitDir, ARef: string): TGitSubmoduleArray;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodulesAtRef(AGitDir, ARef);
end;

function GitSubmoduleAtPath(const AGitDir, APath: string): TGitSubmodule;
begin
  Result := nextpas.core.git.native.submodule.GitSubmoduleAtPath(AGitDir, APath);
end;

function GitParseMailmap(const AText: string): TGitMailmap;
begin
  Result := nextpas.core.git.native.mailmap.GitParseMailmap(AText);
end;

function GitParseMailmap(const AData: TBytes): TGitMailmap;
begin
  Result := nextpas.core.git.native.mailmap.GitParseMailmap(AData);
end;

function GitLoadMailmap(const AGitDir: string): TGitMailmap;
begin
  Result := nextpas.core.git.native.mailmap.GitLoadMailmap(AGitDir);
end;

function GitMailmapResolve(const AMailmap: TGitMailmap; const AName, AEmail: string; out AOutName, AOutEmail: string): Boolean;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolve(AMailmap, AName, AEmail, AOutName, AOutEmail);
end;

function GitMailmapResolveName(const AMailmap: TGitMailmap; const AName, AEmail: string): string;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolveName(AMailmap, AName, AEmail);
end;

function GitMailmapResolveEmail(const AMailmap: TGitMailmap; const AName, AEmail: string): string;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolveEmail(AMailmap, AName, AEmail);
end;

function GitParseTrailers(const AMessage: string): TGitTrailerArray;
begin
  Result := nextpas.core.git.native.trailer.GitParseTrailers(AMessage);
end;

function GitFindTrailer(const ATrailers: TGitTrailerArray; const AKey: string): string;
begin
  Result := nextpas.core.git.native.trailer.GitFindTrailer(ATrailers, AKey);
end;

function GitHasTrailer(const ATrailers: TGitTrailerArray; const AKey: string): Boolean;
begin
  Result := nextpas.core.git.native.trailer.GitHasTrailer(ATrailers, AKey);
end;

function GitFormatTrailer(const AKey, AValue: string): string;
begin
  Result := nextpas.core.git.native.trailer.GitFormatTrailer(AKey, AValue);
end;

function GitFormatTrailers(const ATrailers: TGitTrailerArray): string;
begin
  Result := nextpas.core.git.native.trailer.GitFormatTrailers(ATrailers);
end;

function GitAppendTrailer(const AMessage, AKey, AValue: string): string;
begin
  Result := nextpas.core.git.native.trailer.GitAppendTrailer(AMessage, AKey, AValue);
end;

function GitParseAttributes(const AText: string): TGitAttrEntries;
begin
  Result := nextpas.core.git.native.attributes.GitParseAttributes(AText);
end;

function GitParseAttributes(const AData: TBytes): TGitAttrEntries;
begin
  Result := nextpas.core.git.native.attributes.GitParseAttributes(AData);
end;

function GitLoadAttributes(const AGitDir: string): TGitAttrEntries;
begin
  Result := nextpas.core.git.native.attributes.GitLoadAttributes(AGitDir);
end;

function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray;
begin
  Result := nextpas.core.git.native.attributes.GitAttributesFor(AGitDir, APath);
end;

function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray;
begin
  Result := nextpas.core.git.native.attributes.GitAttributesFor(AEntries, APath);
end;

function GitAttributeGet(const AGitDir, APath, AName: string): string;
begin
  Result := nextpas.core.git.native.attributes.GitAttributeGet(AGitDir, APath, AName);
end;

function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string;
begin
  Result := nextpas.core.git.native.attributes.GitAttributeGet(AEntries, APath, AName);
end;

function GitCommonDir(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.worktree.GitCommonDir(AGitDir);
end;

function GitIsWorktree(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.worktree.GitIsWorktree(AGitDir);
end;

function GitWorktreeList(const AGitDir: string): TGitWorktreeArray;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeList(AGitDir);
end;

function GitWorktreeCount(const AGitDir: string): Integer;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeCount(AGitDir);
end;

function GitWorktreeAdd(const AGitDir, AWorkTreePath, ABranchName: string): TGitWorktree;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeAdd(AGitDir, AWorkTreePath, ABranchName);
end;

function GitWorktreeAddDetached(const AGitDir, AWorkTreePath: string; const AOid: TGitOid): TGitWorktree;
begin
  Result := nextpas.core.git.native.worktree.GitWorktreeAddDetached(AGitDir, AWorkTreePath, AOid);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string);
begin
  nextpas.core.git.native.worktree.GitWorktreeRemove(AGitDir, AWorkTreePath);
end;

procedure GitWorktreeRemove(const AGitDir, AWorkTreePath: string; AForce: Boolean);
begin
  nextpas.core.git.native.worktree.GitWorktreeRemove(AGitDir, AWorkTreePath, AForce);
end;

function GitConfigPath(const AGitDir: string): string;
begin
  Result := nextpas.core.git.native.config.GitConfigPath(AGitDir);
end;

function GitConfigExists(const AGitDir: string): Boolean;
begin
  Result := nextpas.core.git.native.config.GitConfigExists(AGitDir);
end;

function GitParseConfig(const AData: TBytes): TGitConfig;
begin
  Result := nextpas.core.git.native.config.GitParseConfig(AData);
end;

function GitReadConfig(const AGitDir: string): TGitConfig;
begin
  Result := nextpas.core.git.native.config.GitReadConfig(AGitDir);
end;

function GitConfigHas(const AConfig: TGitConfig; const AKey: string): Boolean;
begin
  Result := nextpas.core.git.native.config.GitConfigHas(AConfig, AKey);
end;

function GitConfigGet(const AConfig: TGitConfig; const AKey: string): string;
begin
  Result := nextpas.core.git.native.config.GitConfigGet(AConfig, AKey);
end;

function GitConfigGetAll(const AConfig: TGitConfig; const AKey: string): TStringArray;
begin
  Result := nextpas.core.git.native.config.GitConfigGetAll(AConfig, AKey);
end;

function GitConfigGetBool(const AConfig: TGitConfig; const AKey: string; out AValue: Boolean): Boolean;
begin
  Result := nextpas.core.git.native.config.GitConfigGetBool(AConfig, AKey, AValue);
end;

function GitPktEncode(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncode(AData);
end;

function GitPktEncodeStr(const AText: string): TBytes;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeStr(AText);
end;

function GitPktEncodeFlush: TBytes;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeFlush;
end;

function GitPktEncodeDelim: TBytes;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeDelim;
end;

function GitPktDecode(const AFrame: TBytes; out APkt: TGitPkt): Boolean;
begin
  Result := nextpas.core.git.native.pktline.GitPktDecode(AFrame, APkt);
end;

function GitPktIsFlush(const AFrame: TBytes): Boolean;
begin
  Result := nextpas.core.git.native.pktline.GitPktIsFlush(AFrame);
end;

function GitPktIsDelim(const AFrame: TBytes): Boolean;
begin
  Result := nextpas.core.git.native.pktline.GitPktIsDelim(AFrame);
end;

function GitPktScan(const AStream: TBytes): TGitPktArray;
begin
  Result := nextpas.core.git.native.pktline.GitPktScan(AStream);
end;

function GitPktJoin(const APkts: TGitPktArray): TBytes;
begin
  Result := nextpas.core.git.native.pktline.GitPktJoin(APkts);
end;

function GitRemoteList(const AGitDir: string): TGitRemoteArray;
begin
  Result := nextpas.core.git.native.remote.GitRemoteList(AGitDir);
end;

function GitRemoteFind(const AGitDir: string; const AName: string; out ARemote: TGitRemote): Boolean;
begin
  Result := nextpas.core.git.native.remote.GitRemoteFind(AGitDir, AName, ARemote);
end;

function GitRemoteCount(const AGitDir: string): Integer;
begin
  Result := nextpas.core.git.native.remote.GitRemoteCount(AGitDir);
end;

function GitRemoteUrl(const AGitDir: string; const AName: string): string;
begin
  Result := nextpas.core.git.native.remote.GitRemoteUrl(AGitDir, AName);
end;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised;
begin
  Result := nextpas.core.git.native.advertise.GitParseAdvertise(AStream);
end;

function GitParseAdvertisedRefs(const AStream: TBytes): TGitAdvertisedRefArray;
begin
  Result := nextpas.core.git.native.advertise.GitParseAdvertisedRefs(AStream);
end;

function GitAdvertiseFind(const AAdv: TGitAdvertised; const AName: string; out ARef: TGitAdvertisedRef): Boolean;
begin
  Result := nextpas.core.git.native.advertise.GitAdvertiseFind(AAdv, AName, ARef);
end;

function GitHasCapability(const AAdv: TGitAdvertised; const ACap: string): Boolean;
begin
  Result := nextpas.core.git.native.advertise.GitHasCapability(AAdv, ACap);
end;

function GitEncodeWant(const AOid: TGitOid; const ACaps: TStringArray): TBytes;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWant(AOid, ACaps);
end;

function GitEncodeWantSimple(const AOid: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWantSimple(AOid);
end;

function GitEncodeWants(const AOids: array of TGitOid; const ACaps: TStringArray): TBytes;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWants(AOids, ACaps);
end;

function GitEncodeHave(const AOid: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeHave(AOid);
end;

function GitEncodeDone: TBytes;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeDone;
end;

function GitParseAck(const AData: TBytes; out AAck: TGitAck): Boolean;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAck(AData, AAck);
end;

function GitParseAckLine(const ALine: string; out AAck: TGitAck): Boolean;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAckLine(ALine, AAck);
end;

function GitParseAckStream(const AStream: TBytes): TGitAckArray;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAckStream(AStream);
end;

function GitSidebandEncode(AKind: TGitSidebandKind; const AData: TBytes): TBytes;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandEncode(AKind, AData);
end;

function GitSidebandEncodeStr(AKind: TGitSidebandKind; const AText: string): TBytes;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandEncodeStr(AKind, AText);
end;

function GitSidebandDecode(const APktData: TBytes; out AKind: TGitSidebandKind; out APayload: TBytes): Boolean;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandDecode(APktData, AKind, APayload);
end;

procedure GitSidebandDemux(const AStream: TBytes; out ADemuxed: TGitSidebandDemuxed);
begin
  nextpas.core.git.native.sideband.GitSidebandDemux(AStream, ADemuxed);
end;

function GitSidebandDemuxRaw(const AStream: TBytes): TGitSidebandArray;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandDemuxRaw(AStream);
end;

function GitSidebandJoin(const AEntries: TGitSidebandArray): TBytes;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandJoin(AEntries);
end;

function GitBuildPackIndex(const APackData: TBytes): TBytes;
begin
  Result := nextpas.core.git.native.indexer.GitBuildPackIndex(APackData);
end;

function GitBuildPackIndexFile(const APackPath: string): string;
begin
  Result := nextpas.core.git.native.indexer.GitBuildPackIndexFile(APackPath);
end;

function GitPackIndexPath(const APackPath: string): string;
begin
  Result := nextpas.core.git.native.indexer.GitPackIndexPath(APackPath);
end;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPack(ARemoteGitDir, AWants);
end;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid; const AHaves: array of TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPack(ARemoteGitDir, AWants, AHaves);
end;

function GitFetchPackSingle(const ARemoteGitDir: string; const AWant: TGitOid): TBytes;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPackSingle(ARemoteGitDir, AWant);
end;

function GitLsRemote(const ARemoteGitDir: string): TGitAdvertised;
begin
  Result := nextpas.core.git.native.clone.GitLsRemote(ARemoteGitDir);
end;

function GitCloneBare(const ARemoteGitDir, ALocalGitDir: string): TGitOid;
begin
  Result := nextpas.core.git.native.clone.GitCloneBare(ARemoteGitDir, ALocalGitDir);
end;

function GitCloneBareHead(const ARemoteGitDir, ALocalGitDir: string): string;
begin
  Result := nextpas.core.git.native.clone.GitCloneBareHead(ARemoteGitDir, ALocalGitDir);
end;

function GitClone(const ARemoteGitDir, ALocalWorkTree: string): TGitOid;
begin
  Result := nextpas.core.git.native.clone.GitClone(ARemoteGitDir, ALocalWorkTree);
end;

function GitCloneHead(const ARemoteGitDir, ALocalWorkTree: string): string;
begin
  Result := nextpas.core.git.native.clone.GitCloneHead(ARemoteGitDir, ALocalWorkTree);
end;

procedure GitCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid);
begin
  nextpas.core.git.native.checkout.GitCheckoutTree(AGitDir, AWorkTree, ATreeOid);
end;

procedure GitCheckoutHead(const AGitDir, AWorkTree: string);
begin
  nextpas.core.git.native.checkout.GitCheckoutHead(AGitDir, AWorkTree);
end;

function GitCheckoutCommit(const AGitDir, AWorkTree: string; const ACommitOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.checkout.GitCheckoutCommit(AGitDir, AWorkTree, ACommitOid);
end;

function GitCheckoutRef(const AGitDir, AWorkTree, ARefName: string): TGitOid;
begin
  Result := nextpas.core.git.native.checkout.GitCheckoutRef(AGitDir, AWorkTree, ARefName);
end;

function GitOidZero: TGitOid;
begin
  Result := nextpas.core.git.native.push.GitOidZero;
end;

function GitOidIsZero(const AOid: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.push.GitOidIsZero(AOid);
end;

function GitPush(const ALocalGitDir, ARemoteGitDir, ARefName: string; const AOldOid, ANewOid: TGitOid): Boolean;
begin
  Result := nextpas.core.git.native.push.GitPush(ALocalGitDir, ARemoteGitDir, ARefName, AOldOid, ANewOid);
end;

function GitPush(const ALocalGitDir, ARemoteGitDir: string; const AUpdates: array of TGitPushUpdate): Boolean;
begin
  Result := nextpas.core.git.native.push.GitPush(ALocalGitDir, ARemoteGitDir, AUpdates);
end;

function GitPushBranch(const ALocalGitDir, ARemoteGitDir, ABranchName: string): Boolean;
begin
  Result := nextpas.core.git.native.push.GitPushBranch(ALocalGitDir, ARemoteGitDir, ABranchName);
end;

function GitResetHard(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid;
begin
  Result := nextpas.core.git.native.reset.GitResetHard(AGitDir, AWorkTree, ATargetOid);
end;

function GitResetHard(const AGitDir, AWorkTree, ATargetRef: string): TGitOid;
begin
  Result := nextpas.core.git.native.reset.GitResetHard(AGitDir, AWorkTree, ATargetRef);
end;

function GitRemotePrune(const ALocalGitDir, ARemoteName: string): TStringArray;
begin
  Result := nextpas.core.git.native.prune.GitRemotePrune(ALocalGitDir, ARemoteName);
end;

function GitClean(const AGitDir, AWorkTree: string): TStringArray;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored, ADryRun);
end;

function GitRevParse(const AGitDir, ARev: string): TGitOid;
begin
  Result := nextpas.core.git.native.revparse.GitRevParse(AGitDir, ARev);
end;

function GitRevParseCommit(const AGitDir, ARev: string): TGitOid;
begin
  Result := nextpas.core.git.native.revparse.GitRevParseCommit(AGitDir, ARev);
end;

function GitBundleCreate(const AGitDir, ARef, ABundlePath: string): TGitOid;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreate(AGitDir, ARef, ABundlePath);
end;

function GitBundleCreateFromRevs(const AGitDir: string; const ARevs: array of string; const ABundlePath: string): Integer;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreateFromRevs(AGitDir, ARevs, ABundlePath);
end;

function GitBundleCreateRange(const AGitDir, AFromRev, AToRev, ABundlePath: string): Integer;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreateRange(AGitDir, AFromRev, AToRev, ABundlePath);
end;

function GitBundleVerify(const ABundlePath: string): Boolean;
begin
  Result := nextpas.core.git.native.bundle.GitBundleVerify(ABundlePath);
end;

function GitBundleList(const ABundlePath: string): TGitBundleRefArray;
begin
  Result := nextpas.core.git.native.bundle.GitBundleList(ABundlePath);
end;

function GitBundleParseHeader(const ABundlePath: string): TGitBundleHeader;
begin
  Result := nextpas.core.git.native.bundle.GitBundleParseHeader(ABundlePath);
end;

function GitBundleParseHeaderBytes(const AData: TBytes): TGitBundleHeader;
begin
  Result := nextpas.core.git.native.bundle.GitBundleParseHeaderBytes(AData);
end;

function GitBundleUnbundle(const ABundlePath, ATargetGitDir: string): Integer;
begin
  Result := nextpas.core.git.native.bundle.GitBundleUnbundle(ABundlePath, ATargetGitDir);
end;

function GitGrep(const AGitDir, ARev, APattern: string): TGitGrepHitArray;
begin
  Result := nextpas.core.git.native.grep.GitGrep(AGitDir, ARev, APattern);
end;

function GitGrep(const AGitDir, ARev, APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;
begin
  Result := nextpas.core.git.native.grep.GitGrep(AGitDir, ARev, APattern, AIgnoreCase);
end;

function GitGrepTree(const AGitDir: string; const ATreeOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray;
begin
  Result := nextpas.core.git.native.grep.GitGrepTree(AGitDir, ATreeOid, APattern, AIgnoreCase);
end;

function GitBisectCandidates(const AGitDir, AGoodRev, ABadRev: string): TGitOidArray;
begin
  Result := nextpas.core.git.native.bisect.GitBisectCandidates(AGitDir, AGoodRev, ABadRev);
end;

function GitBisectFind(const AGitDir: string; const AGoodRev, ABadRev: string; ACheck: TGitBisectCheck): TGitBisectResult;
begin
  Result := nextpas.core.git.native.bisect.GitBisectFind(AGitDir, AGoodRev, ABadRev, ACheck);
end;

end.
