unit nextpas.core.git.libgit2.bindings;
{** @desc libgit2 全量 C ABI 绑定（自动生成）。
       来源：c2pas888 --header-unit 翻译 include/git2.h（libgit2 v1.x, linux-x86_64-lp64）。
       再生成命令与 shim 说明见 core/docs/git/bindings-pitfalls.md。
       不要手工编辑本单元：改 libgit2 头后重跑管线。
       词汇复用：本单元为静态 external 轨道，与运行时轨道(ffi/binding)
       通过 nextpas.core.git.libgit2.base 共享基础词汇与零拷贝助手，
       职责按 base(类型)/ffi(ABI)/binding(加载) 分工复用。 *}

interface
{$I nextpas.core.settings.inc}
uses
  nextpas.core.base.utils,
  nextpas.core.git.libgit2.base;

type
  // Base/FFI reuse bridge: static track (TGitOid 33B) supplements base's 20B git_oid;
  // handles remain opaque Pointer/PGit* duality bridged via base's shared aliases.
  TTimeT = Int64;
  TGitCertT = LongInt;
  TGitCredentialT = LongInt;
  TSizeT = QWord;
  TGitOidT = LongInt;
  TPtrdiffT = Int64;
  TWcharT = LongInt;
  TXBuiltinVaList = Pointer;
  TClockT = Int64;
  TInt8T = ShortInt;
  TUint8T = Byte;
  TInt16T = SmallInt;
  TUint16T = Word;
  TInt32T = LongInt;
  TUint32T = LongWord;
  TInt64T = Int64;
  TUint64T = QWord;
  TIntptrT = Int64;
  TUintptrT = QWord;
  TIntmaxT = Int64;
  TUintmaxT = QWord;
  TGitFeatureT = LongInt;
  TGitLibgit2OptT = LongInt;
  TGitBuildinfoT = LongInt;
  TSsizeT = Int64;
  TUidT = LongWord;
  TGidT = LongWord;
  TPidT = LongInt;
  TOffT = Int64;
  TInoT = QWord;
  TModeT = LongWord;
  TGitObjectT = LongInt;
  TGitReferenceT = LongInt;
  TGitBranchT = LongInt;
  TGitFilemodeT = LongInt;
  TGitSubmoduleUpdateT = LongInt;
  TGitSubmoduleIgnoreT = LongInt;
  TGitSubmoduleRecurseT = LongInt;
  TGitOdbLookupFlagsT = LongInt;
  TGitReferenceFormatT = LongInt;
  TGitRefdbT = LongInt;
  TGitFilterModeT = LongInt;
  TGitFilterFlagT = LongInt;
  TGitRepositoryOpenFlagT = LongInt;
  TGitRepositoryInitFlagT = LongInt;
  TGitRepositoryInitModeT = LongInt;
  TGitRepositoryItemT = LongInt;
  TGitRepositoryStateT = LongInt;
  TGitTreewalkMode = LongInt;
  TGitTreeUpdateT = LongInt;
  TGitDiffOptionT = LongInt;
  TGitDiffFlagT = LongInt;
  TGitDeltaT = LongInt;
  TGitDiffBinaryT = LongInt;
  TGitDiffLineT = LongInt;
  TGitDiffFindT = LongInt;
  TGitDiffFormatT = LongInt;
  TGitDiffStatsFormatT = LongInt;
  TGitApplyFlagsT = LongInt;
  TGitApplyLocationT = LongInt;
  TGitAttrValueT = LongInt;
  TGitBlobFilterFlagT = LongInt;
  TGitBlameFlagT = LongInt;
  TGitCertSshT = LongInt;
  TGitCertSshRawTypeT = LongInt;
  TGitCheckoutStrategyT = LongInt;
  TGitCheckoutNotifyT = LongInt;
  TGitIndexEntryFlagT = LongInt;
  TGitIndexEntryExtendedFlagT = LongInt;
  TGitIndexCapabilityT = LongInt;
  TGitIndexAddOptionT = LongInt;
  TGitIndexStageT = LongInt;
  TGitMergeFlagT = LongInt;
  TGitMergeFileFavorT = LongInt;
  TGitMergeFileFlagT = LongInt;
  TGitMergeAnalysisT = LongInt;
  TGitMergePreferenceT = LongInt;
  TGitDirection = LongInt;
  TGitPackbuilderStageT = LongInt;
  TGitProxyT = LongInt;
  TGitRemoteRedirectT = LongInt;
  TGitRemoteCreateFlags = LongInt;
  TGitRemoteUpdateFlags = LongInt;
  TGitRemoteCompletionT = LongInt;
  TGitFetchPruneT = LongInt;
  TGitRemoteAutotagOptionT = LongInt;
  TGitFetchDepthT = LongInt;
  TGitCloneLocalT = LongInt;
  TGitConfigLevelT = LongInt;
  TGitConfigmapT = LongInt;
  TGitDescribeStrategyT = LongInt;
  TGitErrorCode = LongInt;
  TGitErrorT = LongInt;
  TGitRebaseOperationT = LongInt;
  TGitTraceLevelT = LongInt;
  TGitRevspecT = LongInt;
  TGitStashFlags = LongInt;
  TGitStashApplyFlags = LongInt;
  TGitStashApplyProgressT = LongInt;
  TGitStatusT = LongInt;
  TGitStatusShowT = LongInt;
  TGitStatusOptT = LongInt;
  TGitSubmoduleStatusT = LongInt;
  TGitWorktreePruneT = LongInt;
  TGitDiffFormatEmailFlagsT = LongInt;
  TGitEmailCreateFlagsT = LongInt;
  TGitOdbBackendLooseFlagT = LongInt;
  TGitOdbStreamT = LongInt;
  TGitPathspecFlagT = LongInt;
  TGitResetT = LongInt;
  TGitSortT = LongInt;
  PTm = ^TTm;
  PTimespec = ^TTimespec;
  PGitWritestream = ^TGitWritestream;
  PTGitWritestream = PGitWritestream;
  PGitCert = ^TGitCert;
  PGitCertT = ^TGitCertT;
  PTGitCertT = PGitCertT;
  PGitRemoteHead = ^TGitRemoteHead;
  PGitOid = ^TGitOid;
  PTGitOid = PGitOid;
  PGitRemoteCallbacks = ^TGitRemoteCallbacks;
  PGitCredential = ^TGitCredential;
  PTGitCredential = PGitCredential;
  PPGitCredential = ^PGitCredential;
  PTGitCert = PGitCert;
  PGitIndexerProgress = ^TGitIndexerProgress;
  PTGitIndexerProgress = PGitIndexerProgress;
  PGitPushUpdate = ^TGitPushUpdate;
  PTGitPushUpdate = PGitPushUpdate;
  PPGitPushUpdate = ^PGitPushUpdate;
  PGitTransport = ^TGitTransport;
  PTGitTransport = PGitTransport;
  PPGitTransport = ^PGitTransport;
  PGitRemote = ^TGitRemote;
  PTGitRemote = PGitRemote;
  PGitBuf = ^TGitBuf;
  PTGitBuf = PGitBuf;
  PGitRefspec = ^TGitRefspec;
  PTGitRefspec = PGitRefspec;
  PGitCredentialT = ^TGitCredentialT;
  PTGitCredentialT = PGitCredentialT;
  PGitCredentialUserpassPlaintext = ^TGitCredentialUserpassPlaintext;
  PGitCredentialUsername = ^TGitCredentialUsername;
  PGitCredentialSshKey = ^TGitCredentialSshKey;
  PGitCredentialSshInteractive = ^TGitCredentialSshInteractive;
  PLIBSSH2USERAUTHKBDINTPROMPT = ^TLIBSSH2USERAUTHKBDINTPROMPT;
  PTLIBSSH2USERAUTHKBDINTPROMPT = PLIBSSH2USERAUTHKBDINTPROMPT;
  PLIBSSH2USERAUTHKBDINTRESPONSE = ^TLIBSSH2USERAUTHKBDINTRESPONSE;
  PTLIBSSH2USERAUTHKBDINTRESPONSE = PLIBSSH2USERAUTHKBDINTRESPONSE;
  PGitCredentialSshCustom = ^TGitCredentialSshCustom;
  PLIBSSH2SESSION = ^TLIBSSH2SESSION;
  PTLIBSSH2SESSION = PLIBSSH2SESSION;
  PPByte = ^PByte;
  PSizeT = ^TSizeT;
  PTSizeT = PSizeT;
  PGitOdbStream = ^TGitOdbStream;
  PGitOdbBackend = ^TGitOdbBackend;
  PTGitOdbBackend = PGitOdbBackend;
  PGitOidT = ^TGitOidT;
  PTGitOidT = PGitOidT;
  TGitObjectSizeT = TUint64T;
  PGitObjectSizeT = ^TGitObjectSizeT;
  PTGitObjectSizeT = PGitObjectSizeT;
  PTGitOdbStream = PGitOdbStream;
  PGitOdbWritepack = ^TGitOdbWritepack;
  PTGitOdbWritepack = PGitOdbWritepack;
  PGitFeatureT = ^TGitFeatureT;
  PTGitFeatureT = PGitFeatureT;
  PGitLibgit2OptT = ^TGitLibgit2OptT;
  PTGitLibgit2OptT = PGitLibgit2OptT;
  PGitBuildinfoT = ^TGitBuildinfoT;
  PTGitBuildinfoT = PGitBuildinfoT;
  TGitOffT = TInt64T;
  PGitOffT = ^TGitOffT;
  PTGitOffT = PGitOffT;
  TGitTimeT = TInt64T;
  PGitTimeT = ^TGitTimeT;
  PTGitTimeT = PGitTimeT;
  PGitOidShorten = ^TGitOidShorten;
  PTGitOidShorten = PGitOidShorten;
  PGitObjectT = ^TGitObjectT;
  PTGitObjectT = PGitObjectT;
  PGitOdb = ^TGitOdb;
  PTGitOdb = PGitOdb;
  PGitOdbObject = ^TGitOdbObject;
  PTGitOdbObject = PGitOdbObject;
  PGitMidxWriter = ^TGitMidxWriter;
  PTGitMidxWriter = PGitMidxWriter;
  PGitRefdb = ^TGitRefdb;
  PTGitRefdb = PGitRefdb;
  PGitRefdbBackend = ^TGitRefdbBackend;
  PTGitRefdbBackend = PGitRefdbBackend;
  PGitCommitGraph = ^TGitCommitGraph;
  PTGitCommitGraph = PGitCommitGraph;
  PGitCommitGraphWriter = ^TGitCommitGraphWriter;
  PTGitCommitGraphWriter = PGitCommitGraphWriter;
  PGitRepository = ^TGitRepository;
  PTGitRepository = PGitRepository;
  PGitWorktree = ^TGitWorktree;
  PTGitWorktree = PGitWorktree;
  PGitObject = ^TGitObject;
  PTGitObject = PGitObject;
  PGitRevwalk = ^TGitRevwalk;
  PTGitRevwalk = PGitRevwalk;
  PGitTag = ^TGitTag;
  PTGitTag = PGitTag;
  PGitBlob = ^TGitBlob;
  PTGitBlob = PGitBlob;
  PGitCommit = ^TGitCommit;
  PTGitCommit = PGitCommit;
  PGitTreeEntry = ^TGitTreeEntry;
  PTGitTreeEntry = PGitTreeEntry;
  PGitTree = ^TGitTree;
  PTGitTree = PGitTree;
  PGitTreebuilder = ^TGitTreebuilder;
  PTGitTreebuilder = PGitTreebuilder;
  PGitIndex = ^TGitIndex;
  PTGitIndex = PGitIndex;
  PGitIndexIterator = ^TGitIndexIterator;
  PTGitIndexIterator = PGitIndexIterator;
  PGitIndexConflictIterator = ^TGitIndexConflictIterator;
  PTGitIndexConflictIterator = PGitIndexConflictIterator;
  PGitConfig = ^TGitConfig;
  PTGitConfig = PGitConfig;
  PGitConfigBackend = ^TGitConfigBackend;
  PTGitConfigBackend = PGitConfigBackend;
  PGitReflogEntry = ^TGitReflogEntry;
  PTGitReflogEntry = PGitReflogEntry;
  PGitReflog = ^TGitReflog;
  PTGitReflog = PGitReflog;
  PGitNote = ^TGitNote;
  PTGitNote = PGitNote;
  PGitPackbuilder = ^TGitPackbuilder;
  PTGitPackbuilder = PGitPackbuilder;
  PGitTime = ^TGitTime;
  PTGitTime = PGitTime;
  PGitSignature = ^TGitSignature;
  PTGitSignature = PGitSignature;
  PGitReference = ^TGitReference;
  PTGitReference = PGitReference;
  PGitReferenceIterator = ^TGitReferenceIterator;
  PTGitReferenceIterator = PGitReferenceIterator;
  PGitTransaction = ^TGitTransaction;
  PTGitTransaction = PGitTransaction;
  PGitAnnotatedCommit = ^TGitAnnotatedCommit;
  PTGitAnnotatedCommit = PGitAnnotatedCommit;
  PGitStatusList = ^TGitStatusList;
  PTGitStatusList = PGitStatusList;
  PGitRebase = ^TGitRebase;
  PTGitRebase = PGitRebase;
  PGitReferenceT = ^TGitReferenceT;
  PTGitReferenceT = PGitReferenceT;
  PGitBranchT = ^TGitBranchT;
  PTGitBranchT = PGitBranchT;
  PGitFilemodeT = ^TGitFilemodeT;
  PTGitFilemodeT = PGitFilemodeT;
  PGitPush = ^TGitPush;
  PTGitPush = PGitPush;
  PTGitRemoteHead = PGitRemoteHead;
  PTGitRemoteCallbacks = PGitRemoteCallbacks;
  PGitSubmodule = ^TGitSubmodule;
  PTGitSubmodule = PGitSubmodule;
  PGitSubmoduleUpdateT = ^TGitSubmoduleUpdateT;
  PTGitSubmoduleUpdateT = PGitSubmoduleUpdateT;
  PGitSubmoduleIgnoreT = ^TGitSubmoduleIgnoreT;
  PTGitSubmoduleIgnoreT = PGitSubmoduleIgnoreT;
  PGitSubmoduleRecurseT = ^TGitSubmoduleRecurseT;
  PTGitSubmoduleRecurseT = PGitSubmoduleRecurseT;
  PGitMailmap = ^TGitMailmap;
  PTGitMailmap = PGitMailmap;
  PGitOidarray = ^TGitOidarray;
  PTGitOidarray = PGitOidarray;
  PGitIndexer = ^TGitIndexer;
  PTGitIndexer = PGitIndexer;
  PGitIndexerOptions = ^TGitIndexerOptions;
  PTGitIndexerOptions = PGitIndexerOptions;
  PGitOdbLookupFlagsT = ^TGitOdbLookupFlagsT;
  PTGitOdbLookupFlagsT = PGitOdbLookupFlagsT;
  PGitOdbOptions = ^TGitOdbOptions;
  PTGitOdbOptions = PGitOdbOptions;
  PGitOdbExpandId = ^TGitOdbExpandId;
  PTGitOdbExpandId = PGitOdbExpandId;
  PGitStrarray = ^TGitStrarray;
  PPAnsiChar = ^PAnsiChar;
  PTGitStrarray = PGitStrarray;
  PGitReferenceFormatT = ^TGitReferenceFormatT;
  PTGitReferenceFormatT = PGitReferenceFormatT;
  PGitRefdbT = ^TGitRefdbT;
  PTGitRefdbT = PGitRefdbT;
  PGitFilterModeT = ^TGitFilterModeT;
  PTGitFilterModeT = PGitFilterModeT;
  PGitFilterFlagT = ^TGitFilterFlagT;
  PTGitFilterFlagT = PGitFilterFlagT;
  PGitFilterOptions = ^TGitFilterOptions;
  PTGitFilterOptions = PGitFilterOptions;
  PGitFilter = ^TGitFilter;
  PTGitFilter = PGitFilter;
  PGitFilterList = ^TGitFilterList;
  PTGitFilterList = PGitFilterList;
  PGitObjectIdOptions = ^TGitObjectIdOptions;
  PTGitObjectIdOptions = PGitObjectIdOptions;
  PGitCommitHeader = ^TGitCommitHeader;
  PTGitCommitHeader = PGitCommitHeader;
  PGitCommitbuilder = ^TGitCommitbuilder;
  PTGitCommitbuilder = PGitCommitbuilder;
  PGitCommitCreateOptions = ^TGitCommitCreateOptions;
  PTGitCommitCreateOptions = PGitCommitCreateOptions;
  PGitCommitCreateExtOptions = ^TGitCommitCreateExtOptions;
  PTGitCommitCreateExtOptions = PGitCommitCreateExtOptions;
  PGitCommitarray = ^TGitCommitarray;
  PPGitCommit = ^PGitCommit;
  PTGitCommitarray = PGitCommitarray;
  PGitRepositoryOpenFlagT = ^TGitRepositoryOpenFlagT;
  PTGitRepositoryOpenFlagT = PGitRepositoryOpenFlagT;
  PGitRepositoryInitFlagT = ^TGitRepositoryInitFlagT;
  PTGitRepositoryInitFlagT = PGitRepositoryInitFlagT;
  PGitRepositoryInitModeT = ^TGitRepositoryInitModeT;
  PTGitRepositoryInitModeT = PGitRepositoryInitModeT;
  PGitRepositoryInitOptions = ^TGitRepositoryInitOptions;
  PTGitRepositoryInitOptions = PGitRepositoryInitOptions;
  PGitRepositoryItemT = ^TGitRepositoryItemT;
  PTGitRepositoryItemT = PGitRepositoryItemT;
  PGitRepositoryStateT = ^TGitRepositoryStateT;
  PTGitRepositoryStateT = PGitRepositoryStateT;
  PGitTreewalkMode = ^TGitTreewalkMode;
  PTGitTreewalkMode = PGitTreewalkMode;
  PGitTreeUpdateT = ^TGitTreeUpdateT;
  PTGitTreeUpdateT = PGitTreeUpdateT;
  PGitTreeUpdate = ^TGitTreeUpdate;
  PTGitTreeUpdate = PGitTreeUpdate;
  PGitDiffOptionT = ^TGitDiffOptionT;
  PTGitDiffOptionT = PGitDiffOptionT;
  PGitDiff = ^TGitDiff;
  PTGitDiff = PGitDiff;
  PGitDiffFlagT = ^TGitDiffFlagT;
  PTGitDiffFlagT = PGitDiffFlagT;
  PGitDeltaT = ^TGitDeltaT;
  PTGitDeltaT = PGitDeltaT;
  PGitDiffFile = ^TGitDiffFile;
  PTGitDiffFile = PGitDiffFile;
  PGitDiffDelta = ^TGitDiffDelta;
  PTGitDiffDelta = PGitDiffDelta;
  PGitDiffOptions = ^TGitDiffOptions;
  PTGitDiffOptions = PGitDiffOptions;
  PGitDiffBinaryT = ^TGitDiffBinaryT;
  PTGitDiffBinaryT = PGitDiffBinaryT;
  PGitDiffBinaryFile = ^TGitDiffBinaryFile;
  PTGitDiffBinaryFile = PGitDiffBinaryFile;
  PGitDiffBinary = ^TGitDiffBinary;
  PTGitDiffBinary = PGitDiffBinary;
  PGitDiffHunk = ^TGitDiffHunk;
  PTGitDiffHunk = PGitDiffHunk;
  PGitDiffLineT = ^TGitDiffLineT;
  PTGitDiffLineT = PGitDiffLineT;
  PGitDiffLine = ^TGitDiffLine;
  PTGitDiffLine = PGitDiffLine;
  PGitDiffFindT = ^TGitDiffFindT;
  PTGitDiffFindT = PGitDiffFindT;
  PGitDiffSimilarityMetric = ^TGitDiffSimilarityMetric;
  PTGitDiffSimilarityMetric = PGitDiffSimilarityMetric;
  PGitDiffFindOptions = ^TGitDiffFindOptions;
  PTGitDiffFindOptions = PGitDiffFindOptions;
  PGitDiffFormatT = ^TGitDiffFormatT;
  PTGitDiffFormatT = PGitDiffFormatT;
  PGitDiffParseOptions = ^TGitDiffParseOptions;
  PTGitDiffParseOptions = PGitDiffParseOptions;
  PGitDiffStats = ^TGitDiffStats;
  PTGitDiffStats = PGitDiffStats;
  PGitDiffStatsFormatT = ^TGitDiffStatsFormatT;
  PTGitDiffStatsFormatT = PGitDiffStatsFormatT;
  PGitDiffPatchidOptions = ^TGitDiffPatchidOptions;
  PTGitDiffPatchidOptions = PGitDiffPatchidOptions;
  PGitApplyFlagsT = ^TGitApplyFlagsT;
  PTGitApplyFlagsT = PGitApplyFlagsT;
  PGitApplyOptions = ^TGitApplyOptions;
  PTGitApplyOptions = PGitApplyOptions;
  PGitApplyLocationT = ^TGitApplyLocationT;
  PTGitApplyLocationT = PGitApplyLocationT;
  PGitAttrValueT = ^TGitAttrValueT;
  PTGitAttrValueT = PGitAttrValueT;
  PGitAttrOptions = ^TGitAttrOptions;
  PTGitAttrOptions = PGitAttrOptions;
  PGitBlobFilterFlagT = ^TGitBlobFilterFlagT;
  PTGitBlobFilterFlagT = PGitBlobFilterFlagT;
  PGitBlobFilterOptions = ^TGitBlobFilterOptions;
  PTGitBlobFilterOptions = PGitBlobFilterOptions;
  PGitBlameFlagT = ^TGitBlameFlagT;
  PTGitBlameFlagT = PGitBlameFlagT;
  PGitBlameOptions = ^TGitBlameOptions;
  PTGitBlameOptions = PGitBlameOptions;
  PGitBlameHunk = ^TGitBlameHunk;
  PTGitBlameHunk = PGitBlameHunk;
  PGitBlameLine = ^TGitBlameLine;
  PTGitBlameLine = PGitBlameLine;
  PGitBlame = ^TGitBlame;
  PTGitBlame = PGitBlame;
  PGitBranchIterator = ^TGitBranchIterator;
  PTGitBranchIterator = PGitBranchIterator;
  PGitCertSshT = ^TGitCertSshT;
  PTGitCertSshT = PGitCertSshT;
  PGitCertSshRawTypeT = ^TGitCertSshRawTypeT;
  PTGitCertSshRawTypeT = PGitCertSshRawTypeT;
  PGitCertHostkey = ^TGitCertHostkey;
  PTGitCertHostkey = PGitCertHostkey;
  PGitCertX509 = ^TGitCertX509;
  PTGitCertX509 = PGitCertX509;
  PGitCheckoutStrategyT = ^TGitCheckoutStrategyT;
  PTGitCheckoutStrategyT = PGitCheckoutStrategyT;
  PGitCheckoutNotifyT = ^TGitCheckoutNotifyT;
  PTGitCheckoutNotifyT = PGitCheckoutNotifyT;
  PGitCheckoutPerfdata = ^TGitCheckoutPerfdata;
  PTGitCheckoutPerfdata = PGitCheckoutPerfdata;
  PGitCheckoutOptions = ^TGitCheckoutOptions;
  PTGitCheckoutOptions = PGitCheckoutOptions;
  PGitIndexTime = ^TGitIndexTime;
  PTGitIndexTime = PGitIndexTime;
  PGitIndexEntry = ^TGitIndexEntry;
  PTGitIndexEntry = PGitIndexEntry;
  PGitIndexEntryFlagT = ^TGitIndexEntryFlagT;
  PTGitIndexEntryFlagT = PGitIndexEntryFlagT;
  PGitIndexEntryExtendedFlagT = ^TGitIndexEntryExtendedFlagT;
  PTGitIndexEntryExtendedFlagT = PGitIndexEntryExtendedFlagT;
  PGitIndexCapabilityT = ^TGitIndexCapabilityT;
  PTGitIndexCapabilityT = PGitIndexCapabilityT;
  PGitIndexAddOptionT = ^TGitIndexAddOptionT;
  PTGitIndexAddOptionT = PGitIndexAddOptionT;
  PGitIndexStageT = ^TGitIndexStageT;
  PTGitIndexStageT = PGitIndexStageT;
  PGitIndexOptions = ^TGitIndexOptions;
  PTGitIndexOptions = PGitIndexOptions;
  PGitMergeFileInput = ^TGitMergeFileInput;
  PTGitMergeFileInput = PGitMergeFileInput;
  PGitMergeFlagT = ^TGitMergeFlagT;
  PTGitMergeFlagT = PGitMergeFlagT;
  PGitMergeFileFavorT = ^TGitMergeFileFavorT;
  PTGitMergeFileFavorT = PGitMergeFileFavorT;
  PGitMergeFileFlagT = ^TGitMergeFileFlagT;
  PTGitMergeFileFlagT = PGitMergeFileFlagT;
  PGitMergeFileOptions = ^TGitMergeFileOptions;
  PTGitMergeFileOptions = PGitMergeFileOptions;
  PGitMergeFileResult = ^TGitMergeFileResult;
  PTGitMergeFileResult = PGitMergeFileResult;
  PGitMergeOptions = ^TGitMergeOptions;
  PTGitMergeOptions = PGitMergeOptions;
  PGitMergeAnalysisT = ^TGitMergeAnalysisT;
  PTGitMergeAnalysisT = PGitMergeAnalysisT;
  PGitMergePreferenceT = ^TGitMergePreferenceT;
  PTGitMergePreferenceT = PGitMergePreferenceT;
  PGitCherrypickOptions = ^TGitCherrypickOptions;
  PTGitCherrypickOptions = PGitCherrypickOptions;
  PGitDirection = ^TGitDirection;
  PTGitDirection = PGitDirection;
  PTGitCredentialUserpassPlaintext = PGitCredentialUserpassPlaintext;
  PTGitCredentialUsername = PGitCredentialUsername;
  PGitCredentialDefault = ^TGitCredentialDefault;
  PTGitCredentialDefault = PGitCredentialDefault;
  PTGitCredentialSshKey = PGitCredentialSshKey;
  PTGitCredentialSshInteractive = PGitCredentialSshInteractive;
  PTGitCredentialSshCustom = PGitCredentialSshCustom;
  PGitPackbuilderStageT = ^TGitPackbuilderStageT;
  PTGitPackbuilderStageT = PGitPackbuilderStageT;
  PGitProxyT = ^TGitProxyT;
  PTGitProxyT = PGitProxyT;
  PGitProxyOptions = ^TGitProxyOptions;
  PTGitProxyOptions = PGitProxyOptions;
  PGitRemoteRedirectT = ^TGitRemoteRedirectT;
  PTGitRemoteRedirectT = PGitRemoteRedirectT;
  PGitRemoteCreateFlags = ^TGitRemoteCreateFlags;
  PTGitRemoteCreateFlags = PGitRemoteCreateFlags;
  PGitRemoteUpdateFlags = ^TGitRemoteUpdateFlags;
  PTGitRemoteUpdateFlags = PGitRemoteUpdateFlags;
  PGitRemoteCreateOptions = ^TGitRemoteCreateOptions;
  PTGitRemoteCreateOptions = PGitRemoteCreateOptions;
  PGitRemoteCompletionT = ^TGitRemoteCompletionT;
  PTGitRemoteCompletionT = PGitRemoteCompletionT;
  PGitFetchPruneT = ^TGitFetchPruneT;
  PTGitFetchPruneT = PGitFetchPruneT;
  PGitRemoteAutotagOptionT = ^TGitRemoteAutotagOptionT;
  PTGitRemoteAutotagOptionT = PGitRemoteAutotagOptionT;
  PGitFetchDepthT = ^TGitFetchDepthT;
  PTGitFetchDepthT = PGitFetchDepthT;
  PGitFetchOptions = ^TGitFetchOptions;
  PTGitFetchOptions = PGitFetchOptions;
  PGitPushOptions = ^TGitPushOptions;
  PTGitPushOptions = PGitPushOptions;
  PGitRemoteConnectOptions = ^TGitRemoteConnectOptions;
  PTGitRemoteConnectOptions = PGitRemoteConnectOptions;
  PGitCloneLocalT = ^TGitCloneLocalT;
  PTGitCloneLocalT = PGitCloneLocalT;
  PPGitRemote = ^PGitRemote;
  PPGitRepository = ^PGitRepository;
  PGitCloneOptions = ^TGitCloneOptions;
  PTGitCloneOptions = PGitCloneOptions;
  PGitConfigLevelT = ^TGitConfigLevelT;
  PTGitConfigLevelT = PGitConfigLevelT;
  PGitConfigEntry = ^TGitConfigEntry;
  PTGitConfigEntry = PGitConfigEntry;
  PGitConfigIterator = ^TGitConfigIterator;
  PTGitConfigIterator = PGitConfigIterator;
  PGitConfigmapT = ^TGitConfigmapT;
  PTGitConfigmapT = PGitConfigmapT;
  PGitConfigmap = ^TGitConfigmap;
  PTGitConfigmap = PGitConfigmap;
  PGitDescribeStrategyT = ^TGitDescribeStrategyT;
  PTGitDescribeStrategyT = PGitDescribeStrategyT;
  PGitDescribeOptions = ^TGitDescribeOptions;
  PTGitDescribeOptions = PGitDescribeOptions;
  PGitDescribeFormatOptions = ^TGitDescribeFormatOptions;
  PTGitDescribeFormatOptions = PGitDescribeFormatOptions;
  PGitDescribeResult = ^TGitDescribeResult;
  PTGitDescribeResult = PGitDescribeResult;
  PGitErrorCode = ^TGitErrorCode;
  PTGitErrorCode = PGitErrorCode;
  PGitErrorT = ^TGitErrorT;
  PTGitErrorT = PGitErrorT;
  PGitError = ^TGitError;
  PTGitError = PGitError;
  PGitRebaseOptions = ^TGitRebaseOptions;
  PTGitRebaseOptions = PGitRebaseOptions;
  PGitRebaseOperationT = ^TGitRebaseOperationT;
  PTGitRebaseOperationT = PGitRebaseOperationT;
  PGitRebaseOperation = ^TGitRebaseOperation;
  PTGitRebaseOperation = PGitRebaseOperation;
  PGitTraceLevelT = ^TGitTraceLevelT;
  PTGitTraceLevelT = PGitTraceLevelT;
  PGitRevertOptions = ^TGitRevertOptions;
  PTGitRevertOptions = PGitRevertOptions;
  PGitRevspecT = ^TGitRevspecT;
  PTGitRevspecT = PGitRevspecT;
  PGitRevspec = ^TGitRevspec;
  PTGitRevspec = PGitRevspec;
  PGitStashFlags = ^TGitStashFlags;
  PTGitStashFlags = PGitStashFlags;
  PGitStashSaveOptions = ^TGitStashSaveOptions;
  PTGitStashSaveOptions = PGitStashSaveOptions;
  PGitStashApplyFlags = ^TGitStashApplyFlags;
  PTGitStashApplyFlags = PGitStashApplyFlags;
  PGitStashApplyProgressT = ^TGitStashApplyProgressT;
  PTGitStashApplyProgressT = PGitStashApplyProgressT;
  PGitStashApplyOptions = ^TGitStashApplyOptions;
  PTGitStashApplyOptions = PGitStashApplyOptions;
  PGitStatusT = ^TGitStatusT;
  PTGitStatusT = PGitStatusT;
  PGitStatusShowT = ^TGitStatusShowT;
  PTGitStatusShowT = PGitStatusShowT;
  PGitStatusOptT = ^TGitStatusOptT;
  PTGitStatusOptT = PGitStatusOptT;
  PGitStatusOptions = ^TGitStatusOptions;
  PTGitStatusOptions = PGitStatusOptions;
  PGitStatusEntry = ^TGitStatusEntry;
  PTGitStatusEntry = PGitStatusEntry;
  PGitSubmoduleStatusT = ^TGitSubmoduleStatusT;
  PTGitSubmoduleStatusT = PGitSubmoduleStatusT;
  PGitSubmoduleUpdateOptions = ^TGitSubmoduleUpdateOptions;
  PTGitSubmoduleUpdateOptions = PGitSubmoduleUpdateOptions;
  PGitWorktreeAddOptions = ^TGitWorktreeAddOptions;
  PTGitWorktreeAddOptions = PGitWorktreeAddOptions;
  PGitWorktreePruneT = ^TGitWorktreePruneT;
  PTGitWorktreePruneT = PGitWorktreePruneT;
  PGitWorktreePruneOptions = ^TGitWorktreePruneOptions;
  PTGitWorktreePruneOptions = PGitWorktreePruneOptions;
  PGitCredentialUserpassPayload = ^TGitCredentialUserpassPayload;
  PTGitCredentialUserpassPayload = PGitCredentialUserpassPayload;
  TGitAttrT = TGitAttrValueT;
  PGitAttrT = ^TGitAttrT;
  PTGitAttrT = PGitAttrT;
  PGitCvarMap = ^TGitCvarMap;
  PTGitCvarMap = PGitCvarMap;
  PGitDiffFormatEmailFlagsT = ^TGitDiffFormatEmailFlagsT;
  PTGitDiffFormatEmailFlagsT = PGitDiffFormatEmailFlagsT;
  PGitDiffFormatEmailOptions = ^TGitDiffFormatEmailOptions;
  PTGitDiffFormatEmailOptions = PGitDiffFormatEmailOptions;
  TGitRevparseModeT = TGitRevspecT;
  PGitRevparseModeT = ^TGitRevparseModeT;
  PTGitRevparseModeT = PGitRevparseModeT;
  PGitCred = ^TGitCred;
  PTGitCred = PGitCred;
  PGitCredUserpassPlaintext = ^TGitCredUserpassPlaintext;
  PTGitCredUserpassPlaintext = PGitCredUserpassPlaintext;
  PGitCredUsername = ^TGitCredUsername;
  PTGitCredUsername = PGitCredUsername;
  PGitCredDefault = ^TGitCredDefault;
  PTGitCredDefault = PGitCredDefault;
  PGitCredSshKey = ^TGitCredSshKey;
  PTGitCredSshKey = PGitCredSshKey;
  PGitCredSshInteractive = ^TGitCredSshInteractive;
  PTGitCredSshInteractive = PGitCredSshInteractive;
  PGitCredSshCustom = ^TGitCredSshCustom;
  PTGitCredSshCustom = PGitCredSshCustom;
  PGitCredUserpassPayload = ^TGitCredUserpassPayload;
  PTGitCredUserpassPayload = PGitCredUserpassPayload;
  PGitTransferProgress = ^TGitTransferProgress;
  PTGitTransferProgress = PGitTransferProgress;
  PGitEmailCreateFlagsT = ^TGitEmailCreateFlagsT;
  PTGitEmailCreateFlagsT = PGitEmailCreateFlagsT;
  PGitEmailCreateOptions = ^TGitEmailCreateOptions;
  PTGitEmailCreateOptions = PGitEmailCreateOptions;
  PGitMessageTrailer = ^TGitMessageTrailer;
  PTGitMessageTrailer = PGitMessageTrailer;
  PGitMessageTrailerArray = ^TGitMessageTrailerArray;
  PTGitMessageTrailerArray = PGitMessageTrailerArray;
  PGitIterator = ^TGitIterator;
  PGitNoteIterator = ^TGitNoteIterator;
  PTGitNoteIterator = PGitNoteIterator;
  PGitOdbBackendPackOptions = ^TGitOdbBackendPackOptions;
  PTGitOdbBackendPackOptions = PGitOdbBackendPackOptions;
  PGitOdbBackendLooseFlagT = ^TGitOdbBackendLooseFlagT;
  PTGitOdbBackendLooseFlagT = PGitOdbBackendLooseFlagT;
  PGitOdbBackendLooseOptions = ^TGitOdbBackendLooseOptions;
  PTGitOdbBackendLooseOptions = PGitOdbBackendLooseOptions;
  PGitOdbStreamT = ^TGitOdbStreamT;
  PTGitOdbStreamT = PGitOdbStreamT;
  PGitPatch = ^TGitPatch;
  PTGitPatch = PGitPatch;
  PGitPathspec = ^TGitPathspec;
  PTGitPathspec = PGitPathspec;
  PGitPathspecMatchList = ^TGitPathspecMatchList;
  PTGitPathspecMatchList = PGitPathspecMatchList;
  PGitPathspecFlagT = ^TGitPathspecFlagT;
  PTGitPathspecFlagT = PGitPathspecFlagT;
  PGitResetT = ^TGitResetT;
  PTGitResetT = PGitResetT;
  PGitSortT = ^TGitSortT;
  PTGitSortT = PGitSortT;
  PTimeT = ^TTimeT;
  PTTimeT = PTimeT;
  PWcharT = ^TWcharT;
  PTWcharT = PWcharT;
  PPGitIndexer = ^PGitIndexer;
  PPGitOdb = ^PGitOdb;
  PPGitOdbObject = ^PGitOdbObject;
  PPGitOdbStream = ^PGitOdbStream;
  PPGitOdbWritepack = ^PGitOdbWritepack;
  PPGitOdbBackend = ^PGitOdbBackend;
  PPGitReference = ^PGitReference;
  PPGitReferenceIterator = ^PGitReferenceIterator;
  PPGitObject = ^PGitObject;
  PPGitRefdb = ^PGitRefdb;
  PPGitFilterList = ^PGitFilterList;
  PPGitSignature = ^PGitSignature;
  PPGitTree = ^PGitTree;
  PPGitConfig = ^PGitConfig;
  PPGitIndex = ^PGitIndex;
  PPGitAnnotatedCommit = ^PGitAnnotatedCommit;
  PPGitTreeEntry = ^PGitTreeEntry;
  PPGitTreebuilder = ^PGitTreebuilder;
  PPGitDiff = ^PGitDiff;
  PPGitDiffStats = ^PGitDiffStats;
  PPGitBlob = ^PGitBlob;
  PPGitWritestream = ^PGitWritestream;
  PPGitBlame = ^PGitBlame;
  PPGitBranchIterator = ^PGitBranchIterator;
  PPGitIndexIterator = ^PGitIndexIterator;
  PPGitIndexEntry = ^PGitIndexEntry;
  PPGitIndexConflictIterator = ^PGitIndexConflictIterator;
  PPGitRefspec = ^PGitRefspec;
  PPGitPackbuilder = ^PGitPackbuilder;
  PPGitRemoteHead = ^PGitRemoteHead;
  PPPGitRemoteHead = ^PPGitRemoteHead;
  PPGitConfigEntry = ^PGitConfigEntry;
  PInt32T = ^TInt32T;
  PTInt32T = PInt32T;
  PInt64T = ^TInt64T;
  PTInt64T = PInt64T;
  PPGitConfigIterator = ^PGitConfigIterator;
  PPGitTransaction = ^PGitTransaction;
  PPGitDescribeResult = ^PGitDescribeResult;
  PPGitRebase = ^PGitRebase;
  PPGitRebaseOperation = ^PGitRebaseOperation;
  PPGitStatusList = ^PGitStatusList;
  PPGitSubmodule = ^PGitSubmodule;
  PPGitWorktree = ^PGitWorktree;
  PPGitMailmap = ^PGitMailmap;
  PPGitNoteIterator = ^PGitNoteIterator;
  PPGitNote = ^PGitNote;
  PPGitPatch = ^PGitPatch;
  PPGitDiffHunk = ^PGitDiffHunk;
  PPGitDiffLine = ^PGitDiffLine;
  PPGitPathspec = ^PGitPathspec;
  PPGitPathspecMatchList = ^PGitPathspecMatchList;
  PPGitReflog = ^PGitReflog;
  PPGitRevwalk = ^PGitRevwalk;
  PPGitTag = ^PGitTag;
  TRawProc391F10B1 = function(p0: PGitWritestream; p1: PAnsiChar; p2: TSizeT): LongInt; cdecl;
  TRawProcBF95F18E = function(p0: PGitWritestream): LongInt; cdecl;
  TRawProc9FD4906D = procedure(p0: PGitWritestream); cdecl;
  TGitTransportMessageCb = function(p0: PAnsiChar; p1: LongInt; p2: Pointer): LongInt; cdecl;
  TRawProcE5C6787F = function(p0: TGitRemoteCompletionT; p1: Pointer): LongInt; cdecl;
  TGitCredentialAcquireCb = function(p0: PPGitCredential; p1: PAnsiChar; p2: PAnsiChar; p3: LongWord; p4: Pointer): LongInt; cdecl;
  TGitTransportCertificateCheckCb = function(p0: PGitCert; p1: LongInt; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitIndexerProgressCb = function(p0: PGitIndexerProgress; p1: Pointer): LongInt; cdecl;
  TRawProc11B085FD = function(p0: PAnsiChar; p1: PGitOid; p2: PGitOid; p3: Pointer): LongInt; cdecl;
  TGitPackbuilderProgress = function(p0: LongInt; p1: TUint32T; p2: TUint32T; p3: Pointer): LongInt; cdecl;
  TGitPushTransferProgressCb = function(p0: LongWord; p1: LongWord; p2: TSizeT; p3: Pointer): LongInt; cdecl;
  TGitPushUpdateReferenceCb = function(p0: PAnsiChar; p1: PAnsiChar; p2: Pointer): LongInt; cdecl;
  TGitPushNegotiation = function(p0: PPGitPushUpdate; p1: TSizeT; p2: Pointer): LongInt; cdecl;
  TGitTransportCb = function(p0: PPGitTransport; p1: PGitRemote; p2: Pointer): LongInt; cdecl;
  TGitRemoteReadyCb = function(p0: PGitRemote; p1: LongInt; p2: Pointer): LongInt; cdecl;
  TGitUrlResolveCb = function(p0: PGitBuf; p1: PAnsiChar; p2: LongInt; p3: Pointer): LongInt; cdecl;
  TRawProc149943EC = function(p0: PAnsiChar; p1: PGitOid; p2: PGitOid; p3: PGitRefspec; p4: Pointer): LongInt; cdecl;
  TRawProcCEF81083 = procedure(p0: PGitCredential); cdecl;
  TGitCredentialSshInteractiveCb = procedure(p0: PAnsiChar; p1: LongInt; p2: PAnsiChar; p3: LongInt; p4: LongInt; p5: PLIBSSH2USERAUTHKBDINTPROMPT; p6: PLIBSSH2USERAUTHKBDINTRESPONSE; p7: PPointer); cdecl;
  TGitCredentialSignCb = function(p0: PLIBSSH2SESSION; p1: PPByte; p2: PSizeT; p3: PByte; p4: TSizeT; p5: PPointer): LongInt; cdecl;
  TRawProcF1FE5BBF = function(p0: PGitOdbStream; p1: PAnsiChar; p2: TSizeT): LongInt; cdecl;
  TRawProcBEB7D8A8 = function(p0: PGitOdbStream; p1: PAnsiChar; p2: TSizeT): LongInt; cdecl;
  TRawProc1B9F78D1 = function(p0: PGitOdbStream; p1: PGitOid): LongInt; cdecl;
  TRawProc01230D5A = procedure(p0: PGitOdbStream); cdecl;
  TRawProcADCD0512 = function(p0: PGitOdbWritepack; p1: Pointer; p2: TSizeT; p3: PGitIndexerProgress): LongInt; cdecl;
  TRawProcE90F8675 = function(p0: PGitOdbWritepack; p1: PGitIndexerProgress): LongInt; cdecl;
  TRawProc26238D00 = procedure(p0: PGitOdbWritepack); cdecl;
  TGitOdbForeachCb = function(p0: PGitOid; p1: Pointer): LongInt; cdecl;
  TGitReferenceForeachCb = function(p0: PGitReference; p1: Pointer): LongInt; cdecl;
  TGitReferenceForeachNameCb = function(p0: PAnsiChar; p1: Pointer): LongInt; cdecl;
  TGitCommitSignatureCb = function(p0: PGitCommitbuilder; p1: PGitRepository; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitCommitCreateCb = function(p0: PGitOid; p1: PGitSignature; p2: PGitSignature; p3: PAnsiChar; p4: PAnsiChar; p5: PGitTree; p6: TSizeT; p7: Pointer; p8: Pointer): LongInt; cdecl;
  TGitRepositoryFetchheadForeachCb = function(p0: PAnsiChar; p1: PAnsiChar; p2: PGitOid; p3: LongWord; p4: Pointer): LongInt; cdecl;
  TGitRepositoryMergeheadForeachCb = function(p0: PGitOid; p1: Pointer): LongInt; cdecl;
  TGitTreebuilderFilterCb = function(p0: PGitTreeEntry; p1: Pointer): LongInt; cdecl;
  TGitTreewalkCb = function(p0: PAnsiChar; p1: PGitTreeEntry; p2: Pointer): LongInt; cdecl;
  TGitDiffNotifyCb = function(p0: PGitDiff; p1: PGitDiffDelta; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitDiffProgressCb = function(p0: PGitDiff; p1: PAnsiChar; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitDiffFileCb = function(p0: PGitDiffDelta; p1: Single; p2: Pointer): LongInt; cdecl;
  TGitDiffBinaryCb = function(p0: PGitDiffDelta; p1: PGitDiffBinary; p2: Pointer): LongInt; cdecl;
  TGitDiffHunkCb = function(p0: PGitDiffDelta; p1: PGitDiffHunk; p2: Pointer): LongInt; cdecl;
  TGitDiffLineCb = function(p0: PGitDiffDelta; p1: PGitDiffHunk; p2: PGitDiffLine; p3: Pointer): LongInt; cdecl;
  TRawProc352C530F = function(p0: PPointer; p1: PGitDiffFile; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TRawProcF21EF923 = function(p0: PPointer; p1: PGitDiffFile; p2: PAnsiChar; p3: TSizeT; p4: Pointer): LongInt; cdecl;
  TRawProcE91755D3 = procedure(p0: Pointer; p1: Pointer); cdecl;
  TRawProc3D5997E5 = function(p0: PLongInt; p1: Pointer; p2: Pointer; p3: Pointer): LongInt; cdecl;
  TGitApplyDeltaCb = function(p0: PGitDiffDelta; p1: Pointer): LongInt; cdecl;
  TGitApplyHunkCb = function(p0: PGitDiffHunk; p1: Pointer): LongInt; cdecl;
  TGitAttrForeachCb = function(p0: PAnsiChar; p1: PAnsiChar; p2: Pointer): LongInt; cdecl;
  TGitCheckoutNotifyCb = function(p0: TGitCheckoutNotifyT; p1: PAnsiChar; p2: PGitDiffFile; p3: PGitDiffFile; p4: PGitDiffFile; p5: Pointer): LongInt; cdecl;
  TGitCheckoutProgressCb = procedure(p0: PAnsiChar; p1: TSizeT; p2: TSizeT; p3: Pointer); cdecl;
  TGitCheckoutPerfdataCb = procedure(p0: PGitCheckoutPerfdata; p1: Pointer); cdecl;
  TGitIndexMatchedPathCb = function(p0: PAnsiChar; p1: PAnsiChar; p2: Pointer): LongInt; cdecl;
  TGitPackbuilderForeachCb = function(p0: Pointer; p1: TSizeT; p2: Pointer): LongInt; cdecl;
  TGitRemoteCreateCb = function(p0: PPGitRemote; p1: PGitRepository; p2: PAnsiChar; p3: PAnsiChar; p4: Pointer): LongInt; cdecl;
  TGitRepositoryCreateCb = function(p0: PPGitRepository; p1: PAnsiChar; p2: LongInt; p3: Pointer): LongInt; cdecl;
  TGitConfigForeachCb = function(p0: PGitConfigEntry; p1: Pointer): LongInt; cdecl;
  TRawProc2860D6C9 = function(p0: PGitBuf; p1: PGitBuf; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitTraceCb = procedure(p0: TGitTraceLevelT; p1: PAnsiChar); cdecl;
  TGitStashApplyProgressCb = function(p0: TGitStashApplyProgressT; p1: Pointer): LongInt; cdecl;
  TGitStashCb = function(p0: TSizeT; p1: PAnsiChar; p2: PGitOid; p3: Pointer): LongInt; cdecl;
  TGitStatusCb = function(p0: PAnsiChar; p1: LongWord; p2: Pointer): LongInt; cdecl;
  TGitSubmoduleCb = function(p0: PGitSubmodule; p1: PAnsiChar; p2: Pointer): LongInt; cdecl;
  TGitCommitSigningCb = function(p0: PGitBuf; p1: PGitBuf; p2: PAnsiChar; p3: Pointer): LongInt; cdecl;
  TGitCredAcquireCb = function(p0: PPGitCredential; p1: PAnsiChar; p2: PAnsiChar; p3: LongWord; p4: Pointer): LongInt; cdecl;
  TGitCredSignCallback = function(p0: PLIBSSH2SESSION; p1: PPByte; p2: PSizeT; p3: PByte; p4: TSizeT; p5: PPointer): LongInt; cdecl;
  TGitCredSignCb = function(p0: PLIBSSH2SESSION; p1: PPByte; p2: PSizeT; p3: PByte; p4: TSizeT; p5: PPointer): LongInt; cdecl;
  TGitCredSshInteractiveCallback = procedure(p0: PAnsiChar; p1: LongInt; p2: PAnsiChar; p3: LongInt; p4: LongInt; p5: PLIBSSH2USERAUTHKBDINTPROMPT; p6: PLIBSSH2USERAUTHKBDINTRESPONSE; p7: PPointer); cdecl;
  TGitCredSshInteractiveCb = procedure(p0: PAnsiChar; p1: LongInt; p2: PAnsiChar; p3: LongInt; p4: LongInt; p5: PLIBSSH2USERAUTHKBDINTPROMPT; p6: PLIBSSH2USERAUTHKBDINTRESPONSE; p7: PPointer); cdecl;
  TGitTraceCallback = procedure(p0: TGitTraceLevelT; p1: PAnsiChar); cdecl;
  TGitTransferProgressCb = function(p0: PGitIndexerProgress; p1: Pointer): LongInt; cdecl;
  TGitPushTransferProgress = function(p0: LongWord; p1: LongWord; p2: TSizeT; p3: Pointer): LongInt; cdecl;
  TGitHeadlistCb = function(p0: PGitRemoteHead; p1: Pointer): LongInt; cdecl;
  TGitNoteForeachCb = function(p0: PGitOid; p1: PGitOid; p2: Pointer): LongInt; cdecl;
  TGitRevwalkHideCb = function(p0: PGitOid; p1: Pointer): LongInt; cdecl;
  TGitTagForeachCb = function(p0: PAnsiChar; p1: PGitOid; p2: Pointer): LongInt; cdecl;
  TRawProc9779B54A = function(p0: Pointer; p1: Pointer): LongInt; cdecl;
  TRawProcE21ED0E9 = procedure; cdecl;
  TTm = record
    tm_sec: LongInt;
    tm_min: LongInt;
    tm_hour: LongInt;
    tm_mday: LongInt;
    tm_mon: LongInt;
    tm_year: LongInt;
    tm_wday: LongInt;
    tm_yday: LongInt;
    tm_isdst: LongInt;
  end;
  TTimespec = record
    tv_sec: TTimeT;
    tv_nsec: Int64;
  end;
  TGitWritestream = record
    write: TRawProc391F10B1;
    close: TRawProcBF95F18E;
    free: TRawProc9FD4906D;
  end;
  TGitCert = record
    cert_type: TGitCertT;
  end;
  TGitOid = record
    &type: Byte;
    id: array[0..31] of Byte;
  end;
  TGitRemoteHead = record
    local: LongInt;
    oid: TGitOid;
    loid: TGitOid;
    name: PAnsiChar;
    symref_target: PAnsiChar;
  end;
  TGitRemoteCallbacks = record
    version: LongWord;
    sideband_progress: TGitTransportMessageCb;
    completion: TRawProcE5C6787F;
    credentials: TGitCredentialAcquireCb;
    certificate_check: TGitTransportCertificateCheckCb;
    transfer_progress: TGitIndexerProgressCb;
    update_tips: TRawProc11B085FD;
    pack_progress: TGitPackbuilderProgress;
    push_transfer_progress: TGitPushTransferProgressCb;
    push_update_reference: TGitPushUpdateReferenceCb;
    push_negotiation: TGitPushNegotiation;
    transport: TGitTransportCb;
    remote_ready: TGitRemoteReadyCb;
    payload: Pointer;
    resolve_url: TGitUrlResolveCb;
    update_refs: TRawProc149943EC;
  end;
  TGitCredential = record
    credtype: TGitCredentialT;
    free: TRawProcCEF81083;
  end;
  TGitCredentialUserpassPlaintext = record
    parent: TGitCredential;
    username: PAnsiChar;
    password: PAnsiChar;
  end;
  TGitCredentialUsername = record
    parent: TGitCredential;
    username: array[0..0] of AnsiChar;
  end;
  TGitCredentialSshKey = record
    parent: TGitCredential;
    username: PAnsiChar;
    publickey: PAnsiChar;
    privatekey: PAnsiChar;
    passphrase: PAnsiChar;
  end;
  TGitCredentialSshInteractive = record
    parent: TGitCredential;
    username: PAnsiChar;
    prompt_callback: TGitCredentialSshInteractiveCb;
    payload: Pointer;
  end;
  TGitCredentialSshCustom = record
    parent: TGitCredential;
    username: PAnsiChar;
    publickey: PAnsiChar;
    publickey_len: TSizeT;
    sign_callback: TGitCredentialSignCb;
    payload: Pointer;
  end;
  TGitOdbBackend = record
  end;
  TGitOdbStream = record
    backend: PGitOdbBackend;
    mode: LongWord;
    hash_ctx: Pointer;
    oid_type: TGitOidT;
    declared_size: TGitObjectSizeT;
    received_bytes: TGitObjectSizeT;
    read: TRawProcF1FE5BBF;
    write: TRawProcBEB7D8A8;
    finalize_write: TRawProc1B9F78D1;
    free: TRawProc01230D5A;
  end;
  TGitOdbWritepack = record
    backend: PGitOdbBackend;
    append: TRawProcADCD0512;
    commit: TRawProcE90F8675;
    free: TRawProc26238D00;
  end;
  TGitBuf = record
    ptr: PAnsiChar;
    reserved: TSizeT;
    size: TSizeT;
  end;
  TGitOidShorten = record
  end;
  TGitOdb = record
  end;
  TGitOdbObject = record
  end;
  TGitMidxWriter = record
  end;
  TGitRefdb = record
  end;
  TGitRefdbBackend = record
  end;
  TGitCommitGraph = record
  end;
  TGitCommitGraphWriter = record
  end;
  TGitRepository = record
  end;
  TGitWorktree = record
  end;
  TGitObject = record
  end;
  TGitRevwalk = record
  end;
  TGitTag = record
  end;
  TGitBlob = record
  end;
  TGitCommit = record
  end;
  TGitTreeEntry = record
  end;
  TGitTree = record
  end;
  TGitTreebuilder = record
  end;
  TGitIndex = record
  end;
  TGitIndexIterator = record
  end;
  TGitIndexConflictIterator = record
  end;
  TGitConfig = record
  end;
  TGitConfigBackend = record
  end;
  TGitReflogEntry = record
  end;
  TGitReflog = record
  end;
  TGitNote = record
  end;
  TGitPackbuilder = record
  end;
  TGitTime = record
    time: TGitTimeT;
    offset: LongInt;
    sign: AnsiChar;
  end;
  TGitSignature = record
    name: PAnsiChar;
    email: PAnsiChar;
    when: TGitTime;
  end;
  TGitReference = record
  end;
  TGitReferenceIterator = record
  end;
  TGitTransaction = record
  end;
  TGitAnnotatedCommit = record
  end;
  TGitStatusList = record
  end;
  TGitRebase = record
  end;
  TGitRefspec = record
  end;
  TGitRemote = record
  end;
  TGitTransport = record
  end;
  TGitPush = record
  end;
  TGitSubmodule = record
  end;
  TGitMailmap = record
  end;
  TGitOidarray = record
    ids: PGitOid;
    count: TSizeT;
  end;
  TGitIndexer = record
  end;
  TGitIndexerProgress = record
    total_objects: LongWord;
    indexed_objects: LongWord;
    received_objects: LongWord;
    local_objects: LongWord;
    total_deltas: LongWord;
    indexed_deltas: LongWord;
    received_bytes: TSizeT;
  end;
  TGitIndexerOptions = record
    version: LongWord;
    mode: LongWord;
    oid_type: TGitOidT;
    odb: PGitOdb;
    progress_cb: TGitIndexerProgressCb;
    progress_cb_payload: Pointer;
    verify: Byte;
  end;
  TGitOdbOptions = record
    version: LongWord;
    oid_type: TGitOidT;
  end;
  TGitOdbExpandId = record
    id: TGitOid;
    length: Word;
    &type: TGitObjectT;
  end;
  TGitStrarray = record
    strings: PPAnsiChar;
    count: TSizeT;
  end;
  TGitFilterOptions = record
    version: LongWord;
    flags: TUint32T;
    commit_id: PGitOid;
    attr_commit_id: TGitOid;
  end;
  TGitFilter = record
  end;
  TGitFilterList = record
  end;
  TGitObjectIdOptions = record
    version: LongWord;
    object_type: TGitObjectT;
    oid_type: TGitOidT;
    filters: PGitFilterList;
  end;
  TGitCommitHeader = record
    field: PAnsiChar;
    value: PAnsiChar;
  end;
  TGitCommitbuilder = record
  end;
  TGitCommitCreateOptionsBits = bitpacked record
    allow_empty_commit: 0..1;
  end;
  TGitCommitCreateOptions = record
    version: LongWord;
    Bits: TGitCommitCreateOptionsBits;
    __c2p_pad0: array[0..2] of Byte;
    author: PGitSignature;
    committer: PGitSignature;
    message_encoding: PAnsiChar;
    extra_headers: PGitCommitHeader;
    extra_headers_len: TSizeT;
    sign: TGitCommitSignatureCb;
    payload: Pointer;
  end;
  TGitCommitCreateExtOptions = record
    version: LongWord;
    update_ref: PAnsiChar;
    message_encoding: PAnsiChar;
    extra_headers: PGitCommitHeader;
    extra_headers_len: TSizeT;
    sign: TGitCommitSignatureCb;
    payload: Pointer;
  end;
  TGitCommitarray = record
    commits: PPGitCommit;
    count: TSizeT;
  end;
  TGitRepositoryInitOptions = record
    version: LongWord;
    flags: TUint32T;
    mode: TUint32T;
    workdir_path: PAnsiChar;
    description: PAnsiChar;
    template_path: PAnsiChar;
    initial_head: PAnsiChar;
    origin_url: PAnsiChar;
    oid_type: TGitOidT;
    refdb_type: TGitRefdbT;
  end;
  TGitTreeUpdate = record
    action: TGitTreeUpdateT;
    id: TGitOid;
    filemode: TGitFilemodeT;
    path: PAnsiChar;
  end;
  TGitDiff = record
  end;
  TGitDiffFile = record
    id: TGitOid;
    path: PAnsiChar;
    size: TGitObjectSizeT;
    flags: TUint32T;
    mode: TUint16T;
    id_abbrev: TUint16T;
  end;
  TGitDiffDelta = record
    status: TGitDeltaT;
    flags: TUint32T;
    similarity: TUint16T;
    nfiles: TUint16T;
    old_file: TGitDiffFile;
    new_file: TGitDiffFile;
  end;
  TGitDiffOptions = record
    version: LongWord;
    flags: TUint32T;
    ignore_submodules: TGitSubmoduleIgnoreT;
    pathspec: TGitStrarray;
    notify_cb: TGitDiffNotifyCb;
    progress_cb: TGitDiffProgressCb;
    payload: Pointer;
    context_lines: TUint32T;
    interhunk_lines: TUint32T;
    oid_type: TGitOidT;
    id_abbrev: TUint16T;
    max_size: TGitOffT;
    old_prefix: PAnsiChar;
    new_prefix: PAnsiChar;
  end;
  TGitDiffBinaryFile = record
    &type: TGitDiffBinaryT;
    data: PAnsiChar;
    datalen: TSizeT;
    inflatedlen: TSizeT;
  end;
  TGitDiffBinary = record
    contains_data: LongWord;
    old_file: TGitDiffBinaryFile;
    new_file: TGitDiffBinaryFile;
  end;
  TGitDiffHunk = record
    old_start: LongInt;
    old_lines: LongInt;
    new_start: LongInt;
    new_lines: LongInt;
    header_len: TSizeT;
    header: array[0..127] of AnsiChar;
  end;
  TGitDiffLine = record
    origin: AnsiChar;
    old_lineno: LongInt;
    new_lineno: LongInt;
    num_lines: LongInt;
    content_len: TSizeT;
    content_offset: TGitOffT;
    content: PAnsiChar;
  end;
  TGitDiffSimilarityMetric = record
    file_signature: TRawProc352C530F;
    buffer_signature: TRawProcF21EF923;
    free_signature: TRawProcE91755D3;
    similarity: TRawProc3D5997E5;
    payload: Pointer;
  end;
  TGitDiffFindOptions = record
    version: LongWord;
    flags: TUint32T;
    rename_threshold: TUint16T;
    rename_from_rewrite_threshold: TUint16T;
    copy_threshold: TUint16T;
    break_rewrite_threshold: TUint16T;
    rename_limit: TSizeT;
    metric: PGitDiffSimilarityMetric;
  end;
  TGitDiffParseOptions = record
    version: LongWord;
    oid_type: TGitOidT;
  end;
  TGitDiffStats = record
  end;
  TGitDiffPatchidOptions = record
    version: LongWord;
  end;
  TGitApplyOptions = record
    version: LongWord;
    delta_cb: TGitApplyDeltaCb;
    hunk_cb: TGitApplyHunkCb;
    payload: Pointer;
    flags: LongWord;
  end;
  TGitAttrOptions = record
    version: LongWord;
    flags: LongWord;
    commit_id: PGitOid;
    attr_commit_id: TGitOid;
  end;
  TGitBlobFilterOptions = record
    version: LongInt;
    flags: TUint32T;
    commit_id: PGitOid;
    attr_commit_id: TGitOid;
  end;
  TGitBlameOptions = record
    version: LongWord;
    flags: LongWord;
    min_match_characters: TUint16T;
    newest_commit: TGitOid;
    oldest_commit: TGitOid;
    min_line: TSizeT;
    max_line: TSizeT;
  end;
  TGitBlameHunk = record
    lines_in_hunk: TSizeT;
    final_commit_id: TGitOid;
    final_start_line_number: TSizeT;
    final_signature: PGitSignature;
    final_committer: PGitSignature;
    orig_commit_id: TGitOid;
    orig_path: PAnsiChar;
    orig_start_line_number: TSizeT;
    orig_signature: PGitSignature;
    orig_committer: PGitSignature;
    summary: PAnsiChar;
    boundary: AnsiChar;
  end;
  TGitBlameLine = record
    ptr: PAnsiChar;
    len: TSizeT;
  end;
  TGitBlame = record
  end;
  TGitBranchIterator = record
  end;
  TGitCertHostkey = record
    parent: TGitCert;
    &type: TGitCertSshT;
    hash_md5: array[0..15] of Byte;
    hash_sha1: array[0..19] of Byte;
    hash_sha256: array[0..31] of Byte;
    raw_type: TGitCertSshRawTypeT;
    hostkey: PAnsiChar;
    hostkey_len: TSizeT;
  end;
  TGitCertX509 = record
    parent: TGitCert;
    data: Pointer;
    len: TSizeT;
  end;
  TGitCheckoutPerfdata = record
    mkdir_calls: TSizeT;
    stat_calls: TSizeT;
    chmod_calls: TSizeT;
  end;
  TGitCheckoutOptions = record
    version: LongWord;
    checkout_strategy: LongWord;
    disable_filters: LongInt;
    dir_mode: LongWord;
    file_mode: LongWord;
    file_open_flags: LongInt;
    notify_flags: LongWord;
    notify_cb: TGitCheckoutNotifyCb;
    notify_payload: Pointer;
    progress_cb: TGitCheckoutProgressCb;
    progress_payload: Pointer;
    paths: TGitStrarray;
    baseline: PGitTree;
    baseline_index: PGitIndex;
    target_directory: PAnsiChar;
    ancestor_label: PAnsiChar;
    our_label: PAnsiChar;
    their_label: PAnsiChar;
    perfdata_cb: TGitCheckoutPerfdataCb;
    perfdata_payload: Pointer;
  end;
  TGitIndexTime = record
    seconds: TInt32T;
    nanoseconds: TUint32T;
  end;
  TGitIndexEntry = record
    ctime: TGitIndexTime;
    mtime: TGitIndexTime;
    dev: TUint32T;
    ino: TUint32T;
    mode: TUint32T;
    uid: TUint32T;
    gid: TUint32T;
    file_size: TUint32T;
    id: TGitOid;
    flags: TUint16T;
    flags_extended: TUint16T;
    path: PAnsiChar;
  end;
  TGitIndexOptions = record
    version: LongWord;
    oid_type: TGitOidT;
  end;
  TGitMergeFileInput = record
    version: LongWord;
    ptr: PAnsiChar;
    size: TSizeT;
    path: PAnsiChar;
    mode: LongWord;
  end;
  TGitMergeFileOptions = record
    version: LongWord;
    ancestor_label: PAnsiChar;
    our_label: PAnsiChar;
    their_label: PAnsiChar;
    favor: TGitMergeFileFavorT;
    flags: TUint32T;
    marker_size: Word;
  end;
  TGitMergeFileResult = record
    automergeable: LongWord;
    path: PAnsiChar;
    mode: LongWord;
    ptr: PAnsiChar;
    len: TSizeT;
  end;
  TGitMergeOptions = record
    version: LongWord;
    flags: TUint32T;
    rename_threshold: LongWord;
    target_limit: LongWord;
    metric: PGitDiffSimilarityMetric;
    recursion_limit: LongWord;
    default_driver: PAnsiChar;
    file_favor: TGitMergeFileFavorT;
    file_flags: TUint32T;
  end;
  TGitCherrypickOptions = record
    version: LongWord;
    mainline: LongWord;
    merge_opts: TGitMergeOptions;
    checkout_opts: TGitCheckoutOptions;
  end;
  TLIBSSH2SESSION = record
  end;
  TLIBSSH2USERAUTHKBDINTPROMPT = record
  end;
  TLIBSSH2USERAUTHKBDINTRESPONSE = record
  end;
  TGitProxyOptions = record
    version: LongWord;
    &type: TGitProxyT;
    url: PAnsiChar;
    credentials: TGitCredentialAcquireCb;
    certificate_check: TGitTransportCertificateCheckCb;
    payload: Pointer;
  end;
  TGitRemoteCreateOptions = record
    version: LongWord;
    repository: PGitRepository;
    name: PAnsiChar;
    fetchspec: PAnsiChar;
    flags: LongWord;
  end;
  TGitPushUpdate = record
    src_refname: PAnsiChar;
    dst_refname: PAnsiChar;
    src: TGitOid;
    dst: TGitOid;
  end;
  TGitFetchOptions = record
    version: LongInt;
    callbacks: TGitRemoteCallbacks;
    prune: TGitFetchPruneT;
    update_fetchhead: LongWord;
    download_tags: TGitRemoteAutotagOptionT;
    proxy_opts: TGitProxyOptions;
    depth: LongInt;
    follow_redirects: TGitRemoteRedirectT;
    custom_headers: TGitStrarray;
  end;
  TGitPushOptions = record
    version: LongWord;
    pb_parallelism: LongWord;
    callbacks: TGitRemoteCallbacks;
    proxy_opts: TGitProxyOptions;
    follow_redirects: TGitRemoteRedirectT;
    custom_headers: TGitStrarray;
    remote_push_options: TGitStrarray;
  end;
  TGitRemoteConnectOptions = record
    version: LongWord;
    callbacks: TGitRemoteCallbacks;
    proxy_opts: TGitProxyOptions;
    follow_redirects: TGitRemoteRedirectT;
    custom_headers: TGitStrarray;
  end;
  TGitCloneOptions = record
    version: LongWord;
    checkout_opts: TGitCheckoutOptions;
    fetch_opts: TGitFetchOptions;
    bare: LongInt;
    local: TGitCloneLocalT;
    checkout_branch: PAnsiChar;
    repository_cb: TGitRepositoryCreateCb;
    repository_cb_payload: Pointer;
    remote_cb: TGitRemoteCreateCb;
    remote_cb_payload: Pointer;
  end;
  TGitConfigEntry = record
    name: PAnsiChar;
    value: PAnsiChar;
    backend_type: PAnsiChar;
    origin_path: PAnsiChar;
    include_depth: LongWord;
    level: TGitConfigLevelT;
  end;
  TGitConfigIterator = record
  end;
  TGitConfigmap = record
    &type: TGitConfigmapT;
    str_match: PAnsiChar;
    map_value: LongInt;
  end;
  TGitDescribeOptions = record
    version: LongWord;
    max_candidates_tags: LongWord;
    describe_strategy: LongWord;
    pattern: PAnsiChar;
    only_follow_first_parent: LongInt;
    show_commit_oid_as_fallback: LongInt;
  end;
  TGitDescribeFormatOptions = record
    version: LongWord;
    abbreviated_size: LongWord;
    always_use_long_format: LongInt;
    dirty_suffix: PAnsiChar;
  end;
  TGitDescribeResult = record
  end;
  TGitError = record
    message: PAnsiChar;
    klass: LongInt;
  end;
  TGitRebaseOptions = record
    version: LongWord;
    quiet: LongInt;
    inmemory: LongInt;
    rewrite_notes_ref: PAnsiChar;
    merge_options: TGitMergeOptions;
    checkout_options: TGitCheckoutOptions;
    commit_create_cb: TGitCommitCreateCb;
    signing_cb: TRawProc2860D6C9;
    payload: Pointer;
  end;
  TGitRebaseOperation = record
    &type: TGitRebaseOperationT;
    id: TGitOid;
    exec: PAnsiChar;
  end;
  TGitRevertOptions = record
    version: LongWord;
    mainline: LongWord;
    merge_opts: TGitMergeOptions;
    checkout_opts: TGitCheckoutOptions;
  end;
  TGitRevspec = record
    from: PGitObject;
    &to: PGitObject;
    flags: LongWord;
  end;
  TGitStashSaveOptions = record
    version: LongWord;
    flags: TUint32T;
    stasher: PGitSignature;
    message: PAnsiChar;
    paths: TGitStrarray;
  end;
  TGitStashApplyOptions = record
    version: LongWord;
    flags: TUint32T;
    checkout_options: TGitCheckoutOptions;
    progress_cb: TGitStashApplyProgressCb;
    progress_payload: Pointer;
  end;
  TGitStatusOptions = record
    version: LongWord;
    show: TGitStatusShowT;
    flags: LongWord;
    pathspec: TGitStrarray;
    baseline: PGitTree;
    rename_threshold: TUint16T;
  end;
  TGitStatusEntry = record
    status: TGitStatusT;
    head_to_index: PGitDiffDelta;
    index_to_workdir: PGitDiffDelta;
  end;
  TGitSubmoduleUpdateOptions = record
    version: LongWord;
    checkout_opts: TGitCheckoutOptions;
    fetch_opts: TGitFetchOptions;
    allow_fetch: LongInt;
  end;
  TGitWorktreeAddOptions = record
    version: LongWord;
    lock: LongInt;
    checkout_existing: LongInt;
    ref: PGitReference;
    checkout_options: TGitCheckoutOptions;
  end;
  TGitWorktreePruneOptions = record
    version: LongWord;
    flags: TUint32T;
  end;
  TGitCredentialUserpassPayload = record
    username: PAnsiChar;
    password: PAnsiChar;
  end;
  TGitDiffFormatEmailOptions = record
    version: LongWord;
    flags: TUint32T;
    patch_no: TSizeT;
    total_patches: TSizeT;
    id: PGitOid;
    summary: PAnsiChar;
    body: PAnsiChar;
    author: PGitSignature;
  end;
  TGitEmailCreateOptions = record
    version: LongWord;
    flags: TUint32T;
    diff_opts: TGitDiffOptions;
    diff_find_opts: TGitDiffFindOptions;
    subject_prefix: PAnsiChar;
    start_number: TSizeT;
    reroll_number: TSizeT;
  end;
  TGitMessageTrailer = record
    key: PAnsiChar;
    value: PAnsiChar;
  end;
  TGitMessageTrailerArray = record
    trailers: PGitMessageTrailer;
    count: TSizeT;
    _trailer_block: PAnsiChar;
  end;
  TGitIterator = record
  end;
  TGitOdbBackendPackOptions = record
    version: LongWord;
    oid_type: TGitOidT;
  end;
  TGitOdbBackendLooseOptions = record
    version: LongWord;
    flags: TUint32T;
    compression_level: LongInt;
    dir_mode: LongWord;
    file_mode: LongWord;
    oid_type: TGitOidT;
  end;
  TGitPatch = record
  end;
  TGitPathspec = record
  end;
  TGitPathspecMatchList = record
  end;
  TGitCredentialDefault = TGitCredential;
  TGitCvarMap = TGitConfigmap;
  TGitCred = TGitCredential;
  TGitCredUserpassPlaintext = TGitCredentialUserpassPlaintext;
  TGitCredUsername = TGitCredentialUsername;
  TGitCredSshKey = TGitCredentialSshKey;
  TGitCredSshInteractive = TGitCredentialSshInteractive;
  TGitCredSshCustom = TGitCredentialSshCustom;
  TGitCredUserpassPayload = TGitCredentialUserpassPayload;
  TGitTransferProgress = TGitIndexerProgress;
  TGitNoteIterator = TGitIterator;
  TGitCredDefault = TGitCredentialDefault;

const
  GIT_CERT_NONE = 0;
  GIT_CERT_X509 = 1;
  GIT_CERT_HOSTKEY_LIBSSH2 = 2;
  GIT_CERT_STRARRAY = 3;
  GIT_CREDENTIAL_USERPASS_PLAINTEXT = 1;
  GIT_CREDENTIAL_SSH_KEY = 2;
  GIT_CREDENTIAL_SSH_CUSTOM = 4;
  GIT_CREDENTIAL_DEFAULT = 8;
  GIT_CREDENTIAL_SSH_INTERACTIVE = 16;
  GIT_CREDENTIAL_USERNAME = 32;
  GIT_CREDENTIAL_SSH_MEMORY = 64;
  GIT_OID_SHA1 = 1;
  GIT_OID_SHA256 = 2;
  GIT_FEATURE_THREADS = 1;
  GIT_FEATURE_HTTPS = 2;
  GIT_FEATURE_SSH = 4;
  GIT_FEATURE_NSEC = 8;
  GIT_FEATURE_HTTP_PARSER = 16;
  GIT_FEATURE_REGEX = 32;
  GIT_FEATURE_I18N = 64;
  GIT_FEATURE_AUTH_NTLM = 128;
  GIT_FEATURE_AUTH_NEGOTIATE = 256;
  GIT_FEATURE_COMPRESSION = 512;
  GIT_FEATURE_SHA1 = 1024;
  GIT_FEATURE_SHA256 = 2048;
  GIT_FEATURE_HTTP = 4096;
  GIT_OPT_GET_MWINDOW_SIZE = 0;
  GIT_OPT_SET_MWINDOW_SIZE = 1;
  GIT_OPT_GET_MWINDOW_MAPPED_LIMIT = 2;
  GIT_OPT_SET_MWINDOW_MAPPED_LIMIT = 3;
  GIT_OPT_GET_SEARCH_PATH = 4;
  GIT_OPT_SET_SEARCH_PATH = 5;
  GIT_OPT_SET_CACHE_OBJECT_LIMIT = 6;
  GIT_OPT_SET_CACHE_MAX_SIZE = 7;
  GIT_OPT_ENABLE_CACHING = 8;
  GIT_OPT_GET_CACHED_MEMORY = 9;
  GIT_OPT_GET_TEMPLATE_PATH = 10;
  GIT_OPT_SET_TEMPLATE_PATH = 11;
  GIT_OPT_SET_SSL_CERT_LOCATIONS = 12;
  GIT_OPT_SET_USER_AGENT = 13;
  GIT_OPT_ENABLE_STRICT_OBJECT_CREATION = 14;
  GIT_OPT_ENABLE_STRICT_SYMBOLIC_REF_CREATION = 15;
  GIT_OPT_SET_SSL_CIPHERS = 16;
  GIT_OPT_GET_USER_AGENT = 17;
  GIT_OPT_ENABLE_OFS_DELTA = 18;
  GIT_OPT_ENABLE_FSYNC_GITDIR = 19;
  GIT_OPT_GET_WINDOWS_SHAREMODE = 20;
  GIT_OPT_SET_WINDOWS_SHAREMODE = 21;
  GIT_OPT_ENABLE_STRICT_HASH_VERIFICATION = 22;
  GIT_OPT_SET_ALLOCATOR = 23;
  GIT_OPT_ENABLE_UNSAVED_INDEX_SAFETY = 24;
  GIT_OPT_GET_PACK_MAX_OBJECTS = 25;
  GIT_OPT_SET_PACK_MAX_OBJECTS = 26;
  GIT_OPT_DISABLE_PACK_KEEP_FILE_CHECKS = 27;
  GIT_OPT_ENABLE_HTTP_EXPECT_CONTINUE = 28;
  GIT_OPT_GET_MWINDOW_FILE_LIMIT = 29;
  GIT_OPT_SET_MWINDOW_FILE_LIMIT = 30;
  GIT_OPT_SET_ODB_PACKED_PRIORITY = 31;
  GIT_OPT_SET_ODB_LOOSE_PRIORITY = 32;
  GIT_OPT_GET_EXTENSIONS = 33;
  GIT_OPT_SET_EXTENSIONS = 34;
  GIT_OPT_GET_OWNER_VALIDATION = 35;
  GIT_OPT_SET_OWNER_VALIDATION = 36;
  GIT_OPT_GET_HOMEDIR = 37;
  GIT_OPT_SET_HOMEDIR = 38;
  GIT_OPT_SET_SERVER_CONNECT_TIMEOUT = 39;
  GIT_OPT_GET_SERVER_CONNECT_TIMEOUT = 40;
  GIT_OPT_SET_SERVER_TIMEOUT = 41;
  GIT_OPT_GET_SERVER_TIMEOUT = 42;
  GIT_OPT_SET_USER_AGENT_PRODUCT = 43;
  GIT_OPT_GET_USER_AGENT_PRODUCT = 44;
  GIT_OPT_ADD_SSL_X509_CERT = 45;
  GIT_OPT_GET_PACK_MAX_OBJECT_SIZE = 46;
  GIT_OPT_SET_PACK_MAX_OBJECT_SIZE = 47;
  GIT_BUILDINFO_CPU = 1;
  GIT_BUILDINFO_COMMIT = 2;
  GIT_OBJECT_ANY = -2;
  GIT_OBJECT_INVALID = -1;
  GIT_OBJECT_COMMIT = 1;
  GIT_OBJECT_TREE = 2;
  GIT_OBJECT_BLOB = 3;
  GIT_OBJECT_TAG = 4;
  GIT_REFERENCE_INVALID = 0;
  GIT_REFERENCE_DIRECT = 1;
  GIT_REFERENCE_SYMBOLIC = 2;
  GIT_REFERENCE_ALL = 3;
  GIT_BRANCH_LOCAL = 1;
  GIT_BRANCH_REMOTE = 2;
  GIT_BRANCH_ALL = 3;
  GIT_FILEMODE_UNREADABLE = 0;
  GIT_FILEMODE_TREE = 16384;
  GIT_FILEMODE_BLOB = 33188;
  GIT_FILEMODE_BLOB_EXECUTABLE = 33261;
  GIT_FILEMODE_LINK = 40960;
  GIT_FILEMODE_COMMIT = 57344;
  GIT_SUBMODULE_UPDATE_CHECKOUT = 1;
  GIT_SUBMODULE_UPDATE_REBASE = 2;
  GIT_SUBMODULE_UPDATE_MERGE = 3;
  GIT_SUBMODULE_UPDATE_NONE = 4;
  GIT_SUBMODULE_UPDATE_DEFAULT = 0;
  GIT_SUBMODULE_IGNORE_UNSPECIFIED = -1;
  GIT_SUBMODULE_IGNORE_NONE = 1;
  GIT_SUBMODULE_IGNORE_UNTRACKED = 2;
  GIT_SUBMODULE_IGNORE_DIRTY = 3;
  GIT_SUBMODULE_IGNORE_ALL = 4;
  GIT_SUBMODULE_RECURSE_NO = 0;
  GIT_SUBMODULE_RECURSE_YES = 1;
  GIT_SUBMODULE_RECURSE_ONDEMAND = 2;
  GIT_ODB_LOOKUP_NO_REFRESH = 1;
  GIT_REFERENCE_FORMAT_NORMAL = 0;
  GIT_REFERENCE_FORMAT_ALLOW_ONELEVEL = 1;
  GIT_REFERENCE_FORMAT_REFSPEC_PATTERN = 2;
  GIT_REFERENCE_FORMAT_REFSPEC_SHORTHAND = 4;
  GIT_REFDB_FILES = 1;
  GIT_REFDB_REFTABLE = 2;
  GIT_FILTER_TO_WORKTREE = 0;
  GIT_FILTER_SMUDGE = 0;
  GIT_FILTER_TO_ODB = 1;
  GIT_FILTER_CLEAN = 1;
  GIT_FILTER_DEFAULT = 0;
  GIT_FILTER_ALLOW_UNSAFE = 1;
  GIT_FILTER_NO_SYSTEM_ATTRIBUTES = 2;
  GIT_FILTER_ATTRIBUTES_FROM_HEAD = 4;
  GIT_FILTER_ATTRIBUTES_FROM_COMMIT = 8;
  GIT_REPOSITORY_OPEN_NO_SEARCH = 1;
  GIT_REPOSITORY_OPEN_CROSS_FS = 2;
  GIT_REPOSITORY_OPEN_BARE_CONST = 4;
  GIT_REPOSITORY_OPEN_NO_DOTGIT = 8;
  GIT_REPOSITORY_OPEN_FROM_ENV = 16;
  GIT_REPOSITORY_INIT_BARE = 1;
  GIT_REPOSITORY_INIT_NO_REINIT = 2;
  GIT_REPOSITORY_INIT_MKDIR = 8;
  GIT_REPOSITORY_INIT_MKPATH = 16;
  GIT_REPOSITORY_INIT_EXTERNAL_TEMPLATE = 32;
  GIT_REPOSITORY_INIT_RELATIVE_GITLINK = 64;
  GIT_REPOSITORY_INIT_SHARED_UMASK = 0;
  GIT_REPOSITORY_INIT_SHARED_GROUP = 1533;
  GIT_REPOSITORY_INIT_SHARED_ALL = 1535;
  GIT_REPOSITORY_ITEM_GITDIR = 0;
  GIT_REPOSITORY_ITEM_WORKDIR = 1;
  GIT_REPOSITORY_ITEM_COMMONDIR = 2;
  GIT_REPOSITORY_ITEM_INDEX = 3;
  GIT_REPOSITORY_ITEM_OBJECTS = 4;
  GIT_REPOSITORY_ITEM_REFS = 5;
  GIT_REPOSITORY_ITEM_PACKED_REFS = 6;
  GIT_REPOSITORY_ITEM_REMOTES = 7;
  GIT_REPOSITORY_ITEM_CONFIG = 8;
  GIT_REPOSITORY_ITEM_INFO = 9;
  GIT_REPOSITORY_ITEM_HOOKS = 10;
  GIT_REPOSITORY_ITEM_LOGS = 11;
  GIT_REPOSITORY_ITEM_MODULES = 12;
  GIT_REPOSITORY_ITEM_WORKTREES = 13;
  GIT_REPOSITORY_ITEM_WORKTREE_CONFIG = 14;
  GIT_REPOSITORY_ITEM__LAST = 15;
  GIT_REPOSITORY_STATE_NONE = 0;
  GIT_REPOSITORY_STATE_MERGE = 1;
  GIT_REPOSITORY_STATE_REVERT = 2;
  GIT_REPOSITORY_STATE_REVERT_SEQUENCE = 3;
  GIT_REPOSITORY_STATE_CHERRYPICK = 4;
  GIT_REPOSITORY_STATE_CHERRYPICK_SEQUENCE = 5;
  GIT_REPOSITORY_STATE_BISECT = 6;
  GIT_REPOSITORY_STATE_REBASE = 7;
  GIT_REPOSITORY_STATE_REBASE_INTERACTIVE = 8;
  GIT_REPOSITORY_STATE_REBASE_MERGE = 9;
  GIT_REPOSITORY_STATE_APPLY_MAILBOX = 10;
  GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE = 11;
  GIT_TREEWALK_PRE = 0;
  GIT_TREEWALK_POST = 1;
  GIT_TREE_UPDATE_UPSERT = 0;
  GIT_TREE_UPDATE_REMOVE = 1;
  GIT_DIFF_NORMAL = 0;
  GIT_DIFF_REVERSE = 1;
  GIT_DIFF_INCLUDE_IGNORED = 2;
  GIT_DIFF_RECURSE_IGNORED_DIRS = 4;
  GIT_DIFF_INCLUDE_UNTRACKED = 8;
  GIT_DIFF_RECURSE_UNTRACKED_DIRS = 16;
  GIT_DIFF_INCLUDE_UNMODIFIED = 32;
  GIT_DIFF_INCLUDE_TYPECHANGE = 64;
  GIT_DIFF_INCLUDE_TYPECHANGE_TREES = 128;
  GIT_DIFF_IGNORE_FILEMODE = 256;
  GIT_DIFF_IGNORE_SUBMODULES = 512;
  GIT_DIFF_IGNORE_CASE = 1024;
  GIT_DIFF_INCLUDE_CASECHANGE = 2048;
  GIT_DIFF_DISABLE_PATHSPEC_MATCH = 4096;
  GIT_DIFF_SKIP_BINARY_CHECK = 8192;
  GIT_DIFF_ENABLE_FAST_UNTRACKED_DIRS = 16384;
  GIT_DIFF_UPDATE_INDEX = 32768;
  GIT_DIFF_INCLUDE_UNREADABLE = 65536;
  GIT_DIFF_INCLUDE_UNREADABLE_AS_UNTRACKED = 131072;
  GIT_DIFF_INDENT_HEURISTIC = 262144;
  GIT_DIFF_IGNORE_BLANK_LINES = 524288;
  GIT_DIFF_FORCE_TEXT = 1048576;
  GIT_DIFF_FORCE_BINARY = 2097152;
  GIT_DIFF_IGNORE_WHITESPACE = 4194304;
  GIT_DIFF_IGNORE_WHITESPACE_CHANGE = 8388608;
  GIT_DIFF_IGNORE_WHITESPACE_EOL = 16777216;
  GIT_DIFF_SHOW_UNTRACKED_CONTENT = 33554432;
  GIT_DIFF_SHOW_UNMODIFIED = 67108864;
  GIT_DIFF_PATIENCE = 268435456;
  GIT_DIFF_MINIMAL = 536870912;
  GIT_DIFF_SHOW_BINARY = 1073741824;
  GIT_DIFF_FLAG_BINARY = 1;
  GIT_DIFF_FLAG_NOT_BINARY = 2;
  GIT_DIFF_FLAG_VALID_ID = 4;
  GIT_DIFF_FLAG_EXISTS = 8;
  GIT_DIFF_FLAG_VALID_SIZE = 16;
  GIT_DELTA_UNMODIFIED = 0;
  GIT_DELTA_ADDED = 1;
  GIT_DELTA_DELETED = 2;
  GIT_DELTA_MODIFIED = 3;
  GIT_DELTA_RENAMED = 4;
  GIT_DELTA_COPIED = 5;
  GIT_DELTA_IGNORED = 6;
  GIT_DELTA_UNTRACKED = 7;
  GIT_DELTA_TYPECHANGE = 8;
  GIT_DELTA_UNREADABLE = 9;
  GIT_DELTA_CONFLICTED = 10;
  GIT_DIFF_BINARY_NONE = 0;
  GIT_DIFF_BINARY_LITERAL = 1;
  GIT_DIFF_BINARY_DELTA = 2;
  GIT_DIFF_LINE_CONTEXT = 32;
  GIT_DIFF_LINE_ADDITION = 43;
  GIT_DIFF_LINE_DELETION = 45;
  GIT_DIFF_LINE_CONTEXT_EOFNL = 61;
  GIT_DIFF_LINE_ADD_EOFNL = 62;
  GIT_DIFF_LINE_DEL_EOFNL = 60;
  GIT_DIFF_LINE_FILE_HDR = 70;
  GIT_DIFF_LINE_HUNK_HDR = 72;
  GIT_DIFF_LINE_BINARY = 66;
  GIT_DIFF_FIND_BY_CONFIG = 0;
  GIT_DIFF_FIND_RENAMES = 1;
  GIT_DIFF_FIND_RENAMES_FROM_REWRITES = 2;
  GIT_DIFF_FIND_COPIES = 4;
  GIT_DIFF_FIND_COPIES_FROM_UNMODIFIED = 8;
  GIT_DIFF_FIND_REWRITES = 16;
  GIT_DIFF_BREAK_REWRITES = 32;
  GIT_DIFF_FIND_AND_BREAK_REWRITES = 48;
  GIT_DIFF_FIND_FOR_UNTRACKED = 64;
  GIT_DIFF_FIND_ALL = 255;
  GIT_DIFF_FIND_IGNORE_LEADING_WHITESPACE = 0;
  GIT_DIFF_FIND_IGNORE_WHITESPACE = 4096;
  GIT_DIFF_FIND_DONT_IGNORE_WHITESPACE = 8192;
  GIT_DIFF_FIND_EXACT_MATCH_ONLY = 16384;
  GIT_DIFF_BREAK_REWRITES_FOR_RENAMES_ONLY = 32768;
  GIT_DIFF_FIND_REMOVE_UNMODIFIED = 65536;
  GIT_DIFF_FORMAT_PATCH = 1;
  GIT_DIFF_FORMAT_PATCH_HEADER = 2;
  GIT_DIFF_FORMAT_RAW = 3;
  GIT_DIFF_FORMAT_NAME_ONLY = 4;
  GIT_DIFF_FORMAT_NAME_STATUS = 5;
  GIT_DIFF_FORMAT_PATCH_ID = 6;
  GIT_DIFF_STATS_NONE = 0;
  GIT_DIFF_STATS_FULL = 1;
  GIT_DIFF_STATS_SHORT = 2;
  GIT_DIFF_STATS_NUMBER = 4;
  GIT_DIFF_STATS_INCLUDE_SUMMARY = 8;
  GIT_APPLY_CHECK = 1;
  GIT_APPLY_LOCATION_WORKDIR = 0;
  GIT_APPLY_LOCATION_INDEX = 1;
  GIT_APPLY_LOCATION_BOTH = 2;
  GIT_ATTR_VALUE_UNSPECIFIED = 0;
  GIT_ATTR_VALUE_TRUE = 1;
  GIT_ATTR_VALUE_FALSE = 2;
  GIT_ATTR_VALUE_STRING = 3;
  GIT_BLOB_FILTER_CHECK_FOR_BINARY = 1;
  GIT_BLOB_FILTER_NO_SYSTEM_ATTRIBUTES = 2;
  GIT_BLOB_FILTER_ATTRIBUTES_FROM_HEAD = 4;
  GIT_BLOB_FILTER_ATTRIBUTES_FROM_COMMIT = 8;
  GIT_BLAME_NORMAL = 0;
  GIT_BLAME_TRACK_COPIES_SAME_FILE = 1;
  GIT_BLAME_TRACK_COPIES_SAME_COMMIT_MOVES = 2;
  GIT_BLAME_TRACK_COPIES_SAME_COMMIT_COPIES = 4;
  GIT_BLAME_TRACK_COPIES_ANY_COMMIT_COPIES = 8;
  GIT_BLAME_FIRST_PARENT = 16;
  GIT_BLAME_USE_MAILMAP = 32;
  GIT_BLAME_IGNORE_WHITESPACE = 64;
  GIT_CERT_SSH_MD5 = 1;
  GIT_CERT_SSH_SHA1 = 2;
  GIT_CERT_SSH_SHA256 = 4;
  GIT_CERT_SSH_RAW = 8;
  GIT_CERT_SSH_RAW_TYPE_UNKNOWN = 0;
  GIT_CERT_SSH_RAW_TYPE_RSA = 1;
  GIT_CERT_SSH_RAW_TYPE_DSS = 2;
  GIT_CERT_SSH_RAW_TYPE_KEY_ECDSA_256 = 3;
  GIT_CERT_SSH_RAW_TYPE_KEY_ECDSA_384 = 4;
  GIT_CERT_SSH_RAW_TYPE_KEY_ECDSA_521 = 5;
  GIT_CERT_SSH_RAW_TYPE_KEY_ED25519 = 6;
  GIT_CHECKOUT_SAFE = 0;
  GIT_CHECKOUT_FORCE = 2;
  GIT_CHECKOUT_RECREATE_MISSING = 4;
  GIT_CHECKOUT_ALLOW_CONFLICTS = 16;
  GIT_CHECKOUT_REMOVE_UNTRACKED = 32;
  GIT_CHECKOUT_REMOVE_IGNORED = 64;
  GIT_CHECKOUT_UPDATE_ONLY = 128;
  GIT_CHECKOUT_DONT_UPDATE_INDEX = 256;
  GIT_CHECKOUT_NO_REFRESH = 512;
  GIT_CHECKOUT_SKIP_UNMERGED = 1024;
  GIT_CHECKOUT_USE_OURS = 2048;
  GIT_CHECKOUT_USE_THEIRS = 4096;
  GIT_CHECKOUT_DISABLE_PATHSPEC_MATCH = 8192;
  GIT_CHECKOUT_SKIP_LOCKED_DIRECTORIES = 262144;
  GIT_CHECKOUT_DONT_OVERWRITE_IGNORED = 524288;
  GIT_CHECKOUT_CONFLICT_STYLE_MERGE = 1048576;
  GIT_CHECKOUT_CONFLICT_STYLE_DIFF3 = 2097152;
  GIT_CHECKOUT_DONT_REMOVE_EXISTING = 4194304;
  GIT_CHECKOUT_DONT_WRITE_INDEX = 8388608;
  GIT_CHECKOUT_DRY_RUN = 16777216;
  GIT_CHECKOUT_CONFLICT_STYLE_ZDIFF3 = 33554432;
  GIT_CHECKOUT_NONE = 1073741824;
  GIT_CHECKOUT_UPDATE_SUBMODULES = 65536;
  GIT_CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED = 131072;
  GIT_CHECKOUT_NOTIFY_NONE = 0;
  GIT_CHECKOUT_NOTIFY_CONFLICT = 1;
  GIT_CHECKOUT_NOTIFY_DIRTY = 2;
  GIT_CHECKOUT_NOTIFY_UPDATED = 4;
  GIT_CHECKOUT_NOTIFY_UNTRACKED = 8;
  GIT_CHECKOUT_NOTIFY_IGNORED = 16;
  GIT_CHECKOUT_NOTIFY_ALL = 65535;
  GIT_INDEX_ENTRY_EXTENDED = 16384;
  GIT_INDEX_ENTRY_VALID = 32768;
  GIT_INDEX_ENTRY_INTENT_TO_ADD = 8192;
  GIT_INDEX_ENTRY_SKIP_WORKTREE = 16384;
  GIT_INDEX_ENTRY_EXTENDED_FLAGS = 24576;
  GIT_INDEX_ENTRY_UPTODATE = 4;
  GIT_INDEX_CAPABILITY_IGNORE_CASE = 1;
  GIT_INDEX_CAPABILITY_NO_FILEMODE = 2;
  GIT_INDEX_CAPABILITY_NO_SYMLINKS = 4;
  GIT_INDEX_CAPABILITY_FROM_OWNER = -1;
  GIT_INDEX_ADD_DEFAULT = 0;
  GIT_INDEX_ADD_FORCE = 1;
  GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH = 2;
  GIT_INDEX_ADD_CHECK_PATHSPEC = 4;
  GIT_INDEX_STAGE_ANY = -1;
  GIT_INDEX_STAGE_NORMAL = 0;
  GIT_INDEX_STAGE_ANCESTOR = 1;
  GIT_INDEX_STAGE_OURS = 2;
  GIT_INDEX_STAGE_THEIRS = 3;
  GIT_MERGE_FIND_RENAMES = 1;
  GIT_MERGE_FAIL_ON_CONFLICT = 2;
  GIT_MERGE_SKIP_REUC = 4;
  GIT_MERGE_NO_RECURSIVE = 8;
  GIT_MERGE_VIRTUAL_BASE = 16;
  GIT_MERGE_FILE_FAVOR_NORMAL = 0;
  GIT_MERGE_FILE_FAVOR_OURS = 1;
  GIT_MERGE_FILE_FAVOR_THEIRS = 2;
  GIT_MERGE_FILE_FAVOR_UNION = 3;
  GIT_MERGE_FILE_DEFAULT = 0;
  GIT_MERGE_FILE_STYLE_MERGE = 1;
  GIT_MERGE_FILE_STYLE_DIFF3 = 2;
  GIT_MERGE_FILE_SIMPLIFY_ALNUM = 4;
  GIT_MERGE_FILE_IGNORE_WHITESPACE = 8;
  GIT_MERGE_FILE_IGNORE_WHITESPACE_CHANGE = 16;
  GIT_MERGE_FILE_IGNORE_WHITESPACE_EOL = 32;
  GIT_MERGE_FILE_DIFF_PATIENCE = 64;
  GIT_MERGE_FILE_DIFF_MINIMAL = 128;
  GIT_MERGE_FILE_STYLE_ZDIFF3 = 256;
  GIT_MERGE_FILE_ACCEPT_CONFLICTS = 512;
  GIT_MERGE_ANALYSIS_NONE = 0;
  GIT_MERGE_ANALYSIS_NORMAL = 1;
  GIT_MERGE_ANALYSIS_UP_TO_DATE = 2;
  GIT_MERGE_ANALYSIS_FASTFORWARD = 4;
  GIT_MERGE_ANALYSIS_UNBORN = 8;
  GIT_MERGE_PREFERENCE_NONE = 0;
  GIT_MERGE_PREFERENCE_NO_FASTFORWARD = 1;
  GIT_MERGE_PREFERENCE_FASTFORWARD_ONLY = 2;
  GIT_DIRECTION_FETCH = 0;
  GIT_DIRECTION_PUSH = 1;
  GIT_PACKBUILDER_ADDING_OBJECTS = 0;
  GIT_PACKBUILDER_DELTAFICATION = 1;
  GIT_PROXY_NONE = 0;
  GIT_PROXY_AUTO = 1;
  GIT_PROXY_SPECIFIED = 2;
  GIT_REMOTE_REDIRECT_NONE = 1;
  GIT_REMOTE_REDIRECT_INITIAL = 2;
  GIT_REMOTE_REDIRECT_ALL = 4;
  GIT_REMOTE_CREATE_SKIP_INSTEADOF = 1;
  GIT_REMOTE_CREATE_SKIP_DEFAULT_FETCHSPEC = 2;
  GIT_REMOTE_UPDATE_FETCHHEAD = 1;
  GIT_REMOTE_UPDATE_REPORT_UNCHANGED = 2;
  GIT_REMOTE_COMPLETION_DOWNLOAD = 0;
  GIT_REMOTE_COMPLETION_INDEXING = 1;
  GIT_REMOTE_COMPLETION_ERROR = 2;
  GIT_FETCH_PRUNE_UNSPECIFIED = 0;
  GIT_FETCH_PRUNE = 1;
  GIT_FETCH_NO_PRUNE = 2;
  GIT_REMOTE_DOWNLOAD_TAGS_UNSPECIFIED = 0;
  GIT_REMOTE_DOWNLOAD_TAGS_AUTO = 1;
  GIT_REMOTE_DOWNLOAD_TAGS_NONE = 2;
  GIT_REMOTE_DOWNLOAD_TAGS_ALL = 3;
  GIT_FETCH_DEPTH_FULL = 0;
  GIT_FETCH_DEPTH_UNSHALLOW = 2147483647;
  GIT_CLONE_LOCAL_AUTO = 0;
  GIT_CLONE_LOCAL = 1;
  GIT_CLONE_NO_LOCAL = 2;
  GIT_CLONE_LOCAL_NO_LINKS = 3;
  GIT_CONFIG_LEVEL_SYSTEM = 2;
  GIT_CONFIG_LEVEL_XDG = 3;
  GIT_CONFIG_LEVEL_GLOBAL = 4;
  GIT_CONFIG_LEVEL_LOCAL = 5;
  GIT_CONFIG_LEVEL_WORKTREE = 6;
  GIT_CONFIG_LEVEL_APP = 7;
  GIT_CONFIG_HIGHEST_LEVEL = -1;
  GIT_CONFIGMAP_FALSE = 0;
  GIT_CONFIGMAP_TRUE = 1;
  GIT_CONFIGMAP_INT32 = 2;
  GIT_CONFIGMAP_STRING = 3;
  GIT_DESCRIBE_DEFAULT = 0;
  GIT_DESCRIBE_TAGS = 1;
  GIT_DESCRIBE_ALL = 2;
  GIT_OK = 0;
  GIT_ERROR = -1;
  GIT_ENOTFOUND = -3;
  GIT_EEXISTS = -4;
  GIT_EAMBIGUOUS = -5;
  GIT_EBUFS = -6;
  GIT_EUSER = -7;
  GIT_EBAREREPO = -8;
  GIT_EUNBORNBRANCH = -9;
  GIT_EUNMERGED = -10;
  GIT_ENONFASTFORWARD = -11;
  GIT_EINVALIDSPEC = -12;
  GIT_ECONFLICT = -13;
  GIT_ELOCKED = -14;
  GIT_EMODIFIED = -15;
  GIT_EAUTH = -16;
  GIT_ECERTIFICATE = -17;
  GIT_EAPPLIED = -18;
  GIT_EPEEL = -19;
  GIT_EEOF = -20;
  GIT_EINVALID = -21;
  GIT_EUNCOMMITTED = -22;
  GIT_EDIRECTORY = -23;
  GIT_EMERGECONFLICT = -24;
  GIT_PASSTHROUGH = -30;
  GIT_ITEROVER = -31;
  GIT_RETRY = -32;
  GIT_EMISMATCH = -33;
  GIT_EINDEXDIRTY = -34;
  GIT_EAPPLYFAIL = -35;
  GIT_EOWNER = -36;
  GIT_TIMEOUT = -37;
  GIT_EUNCHANGED = -38;
  GIT_ENOTSUPPORTED = -39;
  GIT_EREADONLY = -40;
  GIT_ERROR_NONE = 0;
  GIT_ERROR_NOMEMORY = 1;
  GIT_ERROR_OS = 2;
  GIT_ERROR_INVALID = 3;
  GIT_ERROR_REFERENCE = 4;
  GIT_ERROR_ZLIB = 5;
  GIT_ERROR_REPOSITORY = 6;
  GIT_ERROR_CONFIG = 7;
  GIT_ERROR_REGEX = 8;
  GIT_ERROR_ODB = 9;
  GIT_ERROR_INDEX = 10;
  GIT_ERROR_OBJECT = 11;
  GIT_ERROR_NET = 12;
  GIT_ERROR_TAG = 13;
  GIT_ERROR_TREE = 14;
  GIT_ERROR_INDEXER = 15;
  GIT_ERROR_SSL = 16;
  GIT_ERROR_SUBMODULE = 17;
  GIT_ERROR_THREAD = 18;
  GIT_ERROR_STASH = 19;
  GIT_ERROR_CHECKOUT = 20;
  GIT_ERROR_FETCHHEAD = 21;
  GIT_ERROR_MERGE = 22;
  GIT_ERROR_SSH = 23;
  GIT_ERROR_FILTER = 24;
  GIT_ERROR_REVERT = 25;
  GIT_ERROR_CALLBACK = 26;
  GIT_ERROR_CHERRYPICK = 27;
  GIT_ERROR_DESCRIBE = 28;
  GIT_ERROR_REBASE = 29;
  GIT_ERROR_FILESYSTEM = 30;
  GIT_ERROR_PATCH = 31;
  GIT_ERROR_WORKTREE = 32;
  GIT_ERROR_SHA = 33;
  GIT_ERROR_HTTP = 34;
  GIT_ERROR_INTERNAL = 35;
  GIT_ERROR_GRAFTS = 36;
  GIT_REBASE_OPERATION_PICK = 0;
  GIT_REBASE_OPERATION_REWORD = 1;
  GIT_REBASE_OPERATION_EDIT = 2;
  GIT_REBASE_OPERATION_SQUASH = 3;
  GIT_REBASE_OPERATION_FIXUP = 4;
  GIT_REBASE_OPERATION_EXEC = 5;
  GIT_TRACE_NONE = 0;
  GIT_TRACE_FATAL = 1;
  GIT_TRACE_ERROR = 2;
  GIT_TRACE_WARN = 3;
  GIT_TRACE_INFO = 4;
  GIT_TRACE_DEBUG = 5;
  GIT_TRACE_TRACE = 6;
  GIT_REVSPEC_SINGLE = 1;
  GIT_REVSPEC_RANGE = 2;
  GIT_REVSPEC_MERGE_BASE = 4;
  GIT_STASH_DEFAULT = 0;
  GIT_STASH_KEEP_INDEX = 1;
  GIT_STASH_INCLUDE_UNTRACKED = 2;
  GIT_STASH_INCLUDE_IGNORED = 4;
  GIT_STASH_KEEP_ALL = 8;
  GIT_STASH_APPLY_DEFAULT = 0;
  GIT_STASH_APPLY_REINSTATE_INDEX = 1;
  GIT_STASH_APPLY_PROGRESS_NONE = 0;
  GIT_STASH_APPLY_PROGRESS_LOADING_STASH = 1;
  GIT_STASH_APPLY_PROGRESS_ANALYZE_INDEX = 2;
  GIT_STASH_APPLY_PROGRESS_ANALYZE_MODIFIED = 3;
  GIT_STASH_APPLY_PROGRESS_ANALYZE_UNTRACKED = 4;
  GIT_STASH_APPLY_PROGRESS_CHECKOUT_UNTRACKED = 5;
  GIT_STASH_APPLY_PROGRESS_CHECKOUT_MODIFIED = 6;
  GIT_STASH_APPLY_PROGRESS_DONE = 7;
  GIT_STATUS_CURRENT = 0;
  GIT_STATUS_INDEX_NEW = 1;
  GIT_STATUS_INDEX_MODIFIED = 2;
  GIT_STATUS_INDEX_DELETED = 4;
  GIT_STATUS_INDEX_RENAMED = 8;
  GIT_STATUS_INDEX_TYPECHANGE = 16;
  GIT_STATUS_WT_NEW = 128;
  GIT_STATUS_WT_MODIFIED = 256;
  GIT_STATUS_WT_DELETED = 512;
  GIT_STATUS_WT_TYPECHANGE = 1024;
  GIT_STATUS_WT_RENAMED = 2048;
  GIT_STATUS_WT_UNREADABLE = 4096;
  GIT_STATUS_IGNORED = 16384;
  GIT_STATUS_CONFLICTED = 32768;
  GIT_STATUS_SHOW_INDEX_AND_WORKDIR = 0;
  GIT_STATUS_SHOW_INDEX_ONLY = 1;
  GIT_STATUS_SHOW_WORKDIR_ONLY = 2;
  GIT_STATUS_OPT_INCLUDE_UNTRACKED = 1;
  GIT_STATUS_OPT_INCLUDE_IGNORED = 2;
  GIT_STATUS_OPT_INCLUDE_UNMODIFIED = 4;
  GIT_STATUS_OPT_EXCLUDE_SUBMODULES = 8;
  GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS = 16;
  GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH = 32;
  GIT_STATUS_OPT_RECURSE_IGNORED_DIRS = 64;
  GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX = 128;
  GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR = 256;
  GIT_STATUS_OPT_SORT_CASE_SENSITIVELY = 512;
  GIT_STATUS_OPT_SORT_CASE_INSENSITIVELY = 1024;
  GIT_STATUS_OPT_RENAMES_FROM_REWRITES = 2048;
  GIT_STATUS_OPT_NO_REFRESH = 4096;
  GIT_STATUS_OPT_UPDATE_INDEX = 8192;
  GIT_STATUS_OPT_INCLUDE_UNREADABLE = 16384;
  GIT_STATUS_OPT_INCLUDE_UNREADABLE_AS_UNTRACKED = 32768;
  GIT_SUBMODULE_STATUS_IN_HEAD = 1;
  GIT_SUBMODULE_STATUS_IN_INDEX = 2;
  GIT_SUBMODULE_STATUS_IN_CONFIG = 4;
  GIT_SUBMODULE_STATUS_IN_WD = 8;
  GIT_SUBMODULE_STATUS_INDEX_ADDED = 16;
  GIT_SUBMODULE_STATUS_INDEX_DELETED = 32;
  GIT_SUBMODULE_STATUS_INDEX_MODIFIED = 64;
  GIT_SUBMODULE_STATUS_WD_UNINITIALIZED = 128;
  GIT_SUBMODULE_STATUS_WD_ADDED = 256;
  GIT_SUBMODULE_STATUS_WD_DELETED = 512;
  GIT_SUBMODULE_STATUS_WD_MODIFIED = 1024;
  GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED = 2048;
  GIT_SUBMODULE_STATUS_WD_WD_MODIFIED = 4096;
  GIT_SUBMODULE_STATUS_WD_UNTRACKED = 8192;
  GIT_WORKTREE_PRUNE_VALID = 1;
  GIT_WORKTREE_PRUNE_LOCKED = 2;
  GIT_WORKTREE_PRUNE_WORKING_TREE = 4;
  GIT_DIFF_FORMAT_EMAIL_NONE = 0;
  GIT_DIFF_FORMAT_EMAIL_EXCLUDE_SUBJECT_PATCH_MARKER = 1;
  GIT_EMAIL_CREATE_DEFAULT = 0;
  GIT_EMAIL_CREATE_OMIT_NUMBERS = 1;
  GIT_EMAIL_CREATE_ALWAYS_NUMBER = 2;
  GIT_EMAIL_CREATE_NO_RENAMES = 4;
  GIT_ODB_BACKEND_LOOSE_FSYNC = 1;
  GIT_STREAM_RDONLY = 2;
  GIT_STREAM_WRONLY = 4;
  GIT_STREAM_RW = 6;
  GIT_PATHSPEC_DEFAULT = 0;
  GIT_PATHSPEC_IGNORE_CASE = 1;
  GIT_PATHSPEC_USE_CASE = 2;
  GIT_PATHSPEC_NO_GLOB = 4;
  GIT_PATHSPEC_NO_MATCH_ERROR = 8;
  GIT_PATHSPEC_FIND_FAILURES = 16;
  GIT_PATHSPEC_FAILURES_ONLY = 32;
  GIT_RESET_SOFT = 1;
  GIT_RESET_MIXED = 2;
  GIT_RESET_HARD = 3;
  GIT_SORT_NONE = 0;
  GIT_SORT_TOPOLOGICAL = 1;
  GIT_SORT_TIME = 2;
  GIT_SORT_REVERSE = 4;
  GIT_PATH_LIST_SEPARATOR = 58;
  GIT_PATH_MAX = 4096;
  GIT_OID_SHA1_SIZE = 20;
  GIT_OID_SHA256_SIZE = 32;
  GIT_OID_MINPREFIXLEN = 4;
  GIT_INDEXER_OPTIONS_VERSION = 1;
  GIT_ODB_OPTIONS_VERSION = 1;
  GIT_FILTER_OPTIONS_VERSION = 1;
  GIT_OBJECT_ID_OPTIONS_VERSION = 1;
  GIT_COMMIT_CREATE_OPTIONS_VERSION = 1;
  GIT_COMMIT_CREATE_EXT_OPTIONS_VERSION = 1;
  GIT_REPOSITORY_INIT_OPTIONS_VERSION = 1;
  GIT_DIFF_OPTIONS_VERSION = 1;
  GIT_DIFF_HUNK_HEADER_SIZE = 128;
  GIT_DIFF_FIND_OPTIONS_VERSION = 1;
  GIT_DIFF_PARSE_OPTIONS_VERSION = 1;
  GIT_DIFF_PATCHID_OPTIONS_VERSION = 1;
  GIT_APPLY_OPTIONS_VERSION = 1;
  GIT_ATTR_CHECK_FILE_THEN_INDEX = 0;
  GIT_ATTR_CHECK_INDEX_THEN_FILE = 1;
  GIT_ATTR_CHECK_INDEX_ONLY = 2;
  GIT_ATTR_CHECK_NO_SYSTEM = 4;
  GIT_ATTR_CHECK_INCLUDE_HEAD = 8;
  GIT_ATTR_CHECK_INCLUDE_COMMIT = 16;
  GIT_ATTR_OPTIONS_VERSION = 1;
  GIT_BLOB_FILTER_OPTIONS_VERSION = 1;
  GIT_BLAME_OPTIONS_VERSION = 1;
  GIT_CHECKOUT_OPTIONS_VERSION = 1;
  GIT_INDEX_ENTRY_NAMEMASK = 4095;
  GIT_INDEX_ENTRY_STAGEMASK = 12288;
  GIT_INDEX_ENTRY_STAGESHIFT = 12;
  GIT_INDEX_OPTIONS_VERSION = 1;
  GIT_MERGE_FILE_INPUT_VERSION = 1;
  GIT_MERGE_CONFLICT_MARKER_SIZE = 7;
  GIT_MERGE_FILE_OPTIONS_VERSION = 1;
  GIT_MERGE_OPTIONS_VERSION = 1;
  GIT_CHERRYPICK_OPTIONS_VERSION = 1;
  GIT_PROXY_OPTIONS_VERSION = 1;
  GIT_REMOTE_CREATE_OPTIONS_VERSION = 1;
  GIT_REMOTE_CALLBACKS_VERSION = 1;
  GIT_FETCH_OPTIONS_VERSION = 1;
  GIT_PUSH_OPTIONS_VERSION = 1;
  GIT_REMOTE_CONNECT_OPTIONS_VERSION = 1;
  GIT_CLONE_OPTIONS_VERSION = 1;
  GIT_DESCRIBE_DEFAULT_MAX_CANDIDATES_TAGS = 10;
  GIT_DESCRIBE_DEFAULT_ABBREVIATED_SIZE = 7;
  GIT_DESCRIBE_OPTIONS_VERSION = 1;
  GIT_DESCRIBE_FORMAT_OPTIONS_VERSION = 1;
  GIT_REBASE_OPTIONS_VERSION = 1;
  GIT_REVERT_OPTIONS_VERSION = 1;
  GIT_STASH_SAVE_OPTIONS_VERSION = 1;
  GIT_STASH_APPLY_OPTIONS_VERSION = 1;
  GIT_STATUS_OPTIONS_VERSION = 1;
  GIT_SUBMODULE_STATUS__IN_FLAGS = 15;
  GIT_SUBMODULE_STATUS__INDEX_FLAGS = 112;
  GIT_SUBMODULE_STATUS__WD_FLAGS = 16256;
  GIT_SUBMODULE_UPDATE_OPTIONS_VERSION = 1;
  GIT_WORKTREE_ADD_OPTIONS_VERSION = 1;
  GIT_WORKTREE_PRUNE_OPTIONS_VERSION = 1;
  GIT_CONFIG_LEVEL_PROGRAMDATA = 1;
  GIT_DIFF_FORMAT_EMAIL_OPTIONS_VERSION = 1;
  GIT_IDXENTRY_EXTENDED2 = 32768;
  GIT_IDXENTRY_UPDATE = 1;
  GIT_IDXENTRY_REMOVE = 2;
  GIT_IDXENTRY_UPTODATE = 4;
  GIT_IDXENTRY_ADDED = 8;
  GIT_IDXENTRY_HASHED = 16;
  GIT_IDXENTRY_UNHASHED = 32;
  GIT_IDXENTRY_WT_REMOVE = 64;
  GIT_IDXENTRY_CONFLICTED = 128;
  GIT_IDXENTRY_UNPACKED = 256;
  GIT_IDXENTRY_NEW_SKIP_WORKTREE = 512;
  GIT_OBJ__EXT1 = 0;
  GIT_OBJ__EXT2 = 5;
  GIT_REPOSITORY_INIT_NO_DOTGIT_DIR = 0;
  GIT_EMAIL_CREATE_OPTIONS_VERSION = 1;
  GIT_ODB_BACKEND_PACK_OPTIONS_VERSION = 1;
  GIT_ODB_BACKEND_LOOSE_OPTIONS_VERSION = 1;
  LIBGIT2_VERSION_MAJOR = 1;
  LIBGIT2_VERSION_MINOR = 9;
  LIBGIT2_VERSION_REVISION = 0;
  LIBGIT2_VERSION_PATCH = 0;

function memcpy(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memcpy';

function memmove(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memmove';

function memset(s: Pointer; c: LongInt; n: TSizeT): Pointer; cdecl; external 'c' name 'memset';

function memcmp(s1: Pointer; s2: Pointer; n: TSizeT): LongInt; cdecl; external 'c' name 'memcmp';

function strlen(s: PAnsiChar): TSizeT; cdecl; external 'c' name 'strlen';

function strcmp(s1: PAnsiChar; s2: PAnsiChar): LongInt; cdecl; external 'c' name 'strcmp';

function time(t: PTimeT): TTimeT; cdecl; external 'c' name 'time';

function difftime(&end: TTimeT; beginning: TTimeT): Double; cdecl; external 'c' name 'difftime';

function mktime(tp: PTm): TTimeT; cdecl; external 'c' name 'mktime';

function localtime(timer: PTimeT): PTm; cdecl; external 'c' name 'localtime';

function gmtime(timer: PTimeT): PTm; cdecl; external 'c' name 'gmtime';

function asctime(tp: PTm): PAnsiChar; cdecl; external 'c' name 'asctime';

function ctime(timer: PTimeT): PAnsiChar; cdecl; external 'c' name 'ctime';

function strftime(s: PAnsiChar; maxsize: TSizeT; format: PAnsiChar; tp: PTm): TSizeT; cdecl; external 'c' name 'strftime';

function clock(): TClockT; cdecl; external 'c' name 'clock';

function nanosleep(req: PTimespec; rem: PTimespec): LongInt; cdecl; external 'c' name 'nanosleep';

function clock_gettime(clk_id: LongInt; tp: PTimespec): LongInt; cdecl; external 'c' name 'clock_gettime';

function clock_getres(clk_id: LongInt; res: PTimespec): LongInt; cdecl; external 'c' name 'clock_getres';

function clock_settime(clk_id: LongInt; tp: PTimespec): LongInt; cdecl; external 'c' name 'clock_settime';

function utimensat(dirfd: LongInt; pathname: PAnsiChar; times: PTimespec; flags: LongInt): LongInt; cdecl; external 'c' name 'utimensat';

function futimens(fd: LongInt; times: PTimespec): LongInt; cdecl; external 'c' name 'futimens';

function malloc(size: TSizeT): Pointer; cdecl; external 'c' name 'malloc';

function calloc(nmemb: TSizeT; size: TSizeT): Pointer; cdecl; external 'c' name 'calloc';

function realloc(ptr: Pointer; size: TSizeT): Pointer; cdecl; external 'c' name 'realloc';

procedure free(ptr: Pointer); cdecl; external 'c' name 'free';

procedure abort(); cdecl;

procedure exit_(status: LongInt); cdecl;

function atoi(nptr: PAnsiChar): LongInt; cdecl;

function atol(nptr: PAnsiChar): Int64; cdecl;

function atoll(nptr: PAnsiChar): Int64; cdecl;

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;

function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;

function atof(nptr: PAnsiChar): Double; cdecl;

function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;

function abs(j: LongInt): LongInt; cdecl; external 'c' name 'abs';

function labs(j: Int64): Int64; cdecl; external 'c' name 'labs';

function rand(): LongInt; cdecl;

procedure srand(seed: LongWord); cdecl;

procedure qsort(base: Pointer; nmemb: TSizeT; size: TSizeT; compar: TRawProc9779B54A); cdecl; external 'c' name 'qsort';

function getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';

function _wgetenv(name: PWcharT): PWcharT; cdecl; external 'c' name '_wgetenv';

function wcslen(s: PWcharT): TSizeT; cdecl; external 'c' name 'wcslen';

function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external 'c' name 'setenv';

function unsetenv(name: PAnsiChar): LongInt; cdecl; external 'c' name 'unsetenv';

function putenv(&string: PAnsiChar): LongInt; cdecl; external 'c' name 'putenv';

function system_(command: PAnsiChar): LongInt; cdecl; external 'c' name 'system';

function atexit(&function: TRawProcE21ED0E9): LongInt; cdecl; external 'c' name 'atexit';

function realpath(path: PAnsiChar; resolved_path: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'realpath';

function imaxabs(j: TIntmaxT): TIntmaxT; cdecl; external 'c' name 'imaxabs';

function strtoimax(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): TIntmaxT; cdecl; external 'c' name 'strtoimax';

function strtoumax(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): TUintmaxT; cdecl; external 'c' name 'strtoumax';

function git_libgit2_version(major: PLongInt; minor: PLongInt; rev: PLongInt): LongInt; cdecl; external 'c' name 'git_libgit2_version';

function git_libgit2_prerelease(): PAnsiChar; cdecl; external 'c' name 'git_libgit2_prerelease';

function git_libgit2_features(): LongInt; cdecl; external 'c' name 'git_libgit2_features';

function git_libgit2_feature_backend(feature: TGitFeatureT): PAnsiChar; cdecl; external 'c' name 'git_libgit2_feature_backend';

function git_libgit2_opts(option: LongInt): LongInt; cdecl; varargs; external 'c' name 'git_libgit2_opts';

function git_libgit2_buildinfo(info: TGitBuildinfoT): PAnsiChar; cdecl; external 'c' name 'git_libgit2_buildinfo';

procedure git_buf_dispose(buffer: PGitBuf); cdecl; external 'c' name 'git_buf_dispose';

function git_oid_from_string(&out: PGitOid; str: PAnsiChar; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_string';

function git_oid_from_prefix(&out: PGitOid; str: PAnsiChar; len: TSizeT; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_prefix';

function git_oid_from_raw(&out: PGitOid; raw: PByte; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_raw';

function git_oid_fromstr(&out: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_fromstr';

function git_oid_fromstrp(&out: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_fromstrp';

function git_oid_fromstrn(&out: PGitOid; str: PAnsiChar; length: TSizeT): LongInt; cdecl; external 'c' name 'git_oid_fromstrn';

function git_oid_fromraw(&out: PGitOid; raw: PByte): LongInt; cdecl; external 'c' name 'git_oid_fromraw';

function git_oid_fmt(&out: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_fmt';

function git_oid_nfmt(&out: PAnsiChar; n: TSizeT; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_nfmt';

function git_oid_pathfmt(&out: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_pathfmt';

function git_oid_tostr_s(oid: PGitOid): PAnsiChar; cdecl; external 'c' name 'git_oid_tostr_s';

function git_oid_tostr(&out: PAnsiChar; n: TSizeT; id: PGitOid): PAnsiChar; cdecl; external 'c' name 'git_oid_tostr';

function git_oid_cpy(&out: PGitOid; src: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_cpy';

function git_oid_cmp(a: PGitOid; b: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_cmp';

function git_oid_equal(a: PGitOid; b: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_equal';

function git_oid_ncmp(a: PGitOid; b: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_oid_ncmp';

function git_oid_streq(id: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_streq';

function git_oid_strcmp(id: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_strcmp';

function git_oid_is_zero(id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_is_zero';

function git_oid_shorten_new(min_length: TSizeT): PGitOidShorten; cdecl; external 'c' name 'git_oid_shorten_new';

function git_oid_shorten_add(os: PGitOidShorten; text_id: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_shorten_add';

procedure git_oid_shorten_free(os: PGitOidShorten); cdecl; external 'c' name 'git_oid_shorten_free';

procedure git_oidarray_dispose(&array: PGitOidarray); cdecl; external 'c' name 'git_oidarray_dispose';

function git_indexer_options_init(opts: PGitIndexerOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_indexer_options_init';

function git_indexer_new(&out: PPGitIndexer; path: PAnsiChar; opts: PGitIndexerOptions): LongInt; cdecl; external 'c' name 'git_indexer_new';

function git_indexer_append(idx: PGitIndexer; data: Pointer; size: TSizeT; stats: PGitIndexerProgress): LongInt; cdecl; external 'c' name 'git_indexer_append';

function git_indexer_commit(idx: PGitIndexer; stats: PGitIndexerProgress): LongInt; cdecl; external 'c' name 'git_indexer_commit';

function git_indexer_hash(idx: PGitIndexer): PGitOid; cdecl; external 'c' name 'git_indexer_hash';

function git_indexer_name(idx: PGitIndexer): PAnsiChar; cdecl; external 'c' name 'git_indexer_name';

procedure git_indexer_free(idx: PGitIndexer); cdecl; external 'c' name 'git_indexer_free';

function git_odb_options_init(opts: PGitOdbOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_odb_options_init';

function git_odb_new(odb: PPGitOdb): LongInt; cdecl; external 'c' name 'git_odb_new';

function git_odb_new_ext(odb: PPGitOdb; opts: PGitOdbOptions): LongInt; cdecl; external 'c' name 'git_odb_new_ext';

function git_odb_open(odb_out: PPGitOdb; objects_dir: PAnsiChar): LongInt; cdecl; external 'c' name 'git_odb_open';

function git_odb_open_ext(odb_out: PPGitOdb; objects_dir: PAnsiChar; opts: PGitOdbOptions): LongInt; cdecl; external 'c' name 'git_odb_open_ext';

function git_odb_add_disk_alternate(odb: PGitOdb; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_odb_add_disk_alternate';

procedure git_odb_free(db: PGitOdb); cdecl; external 'c' name 'git_odb_free';

function git_odb_read(obj: PPGitOdbObject; db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_read';

function git_odb_read_prefix(obj: PPGitOdbObject; db: PGitOdb; short_id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_read_prefix';

function git_odb_read_header(len_out: PSizeT; type_out: PGitObjectT; db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_read_header';

function git_odb_exists(db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_exists';

function git_odb_exists_ext(db: PGitOdb; id: PGitOid; flags: LongWord): LongInt; cdecl; external 'c' name 'git_odb_exists_ext';

function git_odb_exists_prefix(&out: PGitOid; db: PGitOdb; short_id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_exists_prefix';

function git_odb_expand_ids(db: PGitOdb; ids: PGitOdbExpandId; count: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_expand_ids';

function git_odb_refresh(db: PGitOdb): LongInt; cdecl; external 'c' name 'git_odb_refresh';

function git_odb_foreach(db: PGitOdb; cb: TGitOdbForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_odb_foreach';

function git_odb_write(&out: PGitOid; odb: PGitOdb; data: Pointer; len: TSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_write';

function git_odb_open_wstream(&out: PPGitOdbStream; db: PGitOdb; size: TGitObjectSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_open_wstream';

function git_odb_stream_write(stream: PGitOdbStream; buffer: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_stream_write';

function git_odb_stream_finalize_write(&out: PGitOid; stream: PGitOdbStream): LongInt; cdecl; external 'c' name 'git_odb_stream_finalize_write';

function git_odb_stream_read(stream: PGitOdbStream; buffer: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_stream_read';

procedure git_odb_stream_free(stream: PGitOdbStream); cdecl; external 'c' name 'git_odb_stream_free';

function git_odb_open_rstream(&out: PPGitOdbStream; len: PSizeT; &type: PGitObjectT; db: PGitOdb; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_open_rstream';

function git_odb_write_pack(&out: PPGitOdbWritepack; db: PGitOdb; progress_cb: TGitIndexerProgressCb; progress_payload: Pointer): LongInt; cdecl; external 'c' name 'git_odb_write_pack';

function git_odb_write_multi_pack_index(db: PGitOdb): LongInt; cdecl; external 'c' name 'git_odb_write_multi_pack_index';

function git_odb_object_dup(dest: PPGitOdbObject; source: PGitOdbObject): LongInt; cdecl; external 'c' name 'git_odb_object_dup';

procedure git_odb_object_free(&object: PGitOdbObject); cdecl; external 'c' name 'git_odb_object_free';

function git_odb_object_id(&object: PGitOdbObject): PGitOid; cdecl; external 'c' name 'git_odb_object_id';

function git_odb_object_data(&object: PGitOdbObject): Pointer; cdecl; external 'c' name 'git_odb_object_data';

function git_odb_object_size(&object: PGitOdbObject): TSizeT; cdecl; external 'c' name 'git_odb_object_size';

function git_odb_object_type(&object: PGitOdbObject): TGitObjectT; cdecl; external 'c' name 'git_odb_object_type';

function git_odb_add_backend(odb: PGitOdb; backend: PGitOdbBackend; priority: LongInt): LongInt; cdecl; external 'c' name 'git_odb_add_backend';

function git_odb_add_alternate(odb: PGitOdb; backend: PGitOdbBackend; priority: LongInt): LongInt; cdecl; external 'c' name 'git_odb_add_alternate';

function git_odb_num_backends(odb: PGitOdb): TSizeT; cdecl; external 'c' name 'git_odb_num_backends';

function git_odb_get_backend(&out: PPGitOdbBackend; odb: PGitOdb; pos: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_get_backend';

function git_odb_set_commit_graph(odb: PGitOdb; cgraph: PGitCommitGraph): LongInt; cdecl; external 'c' name 'git_odb_set_commit_graph';

procedure git_strarray_dispose(&array: PGitStrarray); cdecl; external 'c' name 'git_strarray_dispose';

function git_reference_lookup(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_lookup';

function git_reference_name_to_id(&out: PGitOid; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_name_to_id';

function git_reference_dwim(&out: PPGitReference; repo: PGitRepository; shorthand: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_dwim';

function git_reference_symbolic_create_matching(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar; target: PAnsiChar; force: LongInt; current_value: PAnsiChar; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_create_matching';

function git_reference_symbolic_create(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar; target: PAnsiChar; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_create';

function git_reference_create(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar; id: PGitOid; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_create';

function git_reference_create_matching(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar; id: PGitOid; force: LongInt; current_id: PGitOid; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_create_matching';

function git_reference_target(ref: PGitReference): PGitOid; cdecl; external 'c' name 'git_reference_target';

function git_reference_target_peel(ref: PGitReference): PGitOid; cdecl; external 'c' name 'git_reference_target_peel';

function git_reference_symbolic_target(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_symbolic_target';

function git_reference_type(ref: PGitReference): TGitReferenceT; cdecl; external 'c' name 'git_reference_type';

function git_reference_name(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_name';

function git_reference_resolve(&out: PPGitReference; ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_resolve';

function git_reference_owner(ref: PGitReference): PGitRepository; cdecl; external 'c' name 'git_reference_owner';

function git_reference_symbolic_set_target(&out: PPGitReference; ref: PGitReference; target: PAnsiChar; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_set_target';

function git_reference_set_target(&out: PPGitReference; ref: PGitReference; id: PGitOid; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_set_target';

function git_reference_rename(new_ref: PPGitReference; ref: PGitReference; new_name: PAnsiChar; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_rename';

function git_reference_delete(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_delete';

function git_reference_remove(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_remove';

function git_reference_list(&array: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_reference_list';

function git_reference_foreach(repo: PGitRepository; callback: TGitReferenceForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach';

function git_reference_foreach_name(repo: PGitRepository; callback: TGitReferenceForeachNameCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach_name';

function git_reference_dup(dest: PPGitReference; source: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_dup';

procedure git_reference_free(ref: PGitReference); cdecl; external 'c' name 'git_reference_free';

function git_reference_cmp(ref1: PGitReference; ref2: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_cmp';

function git_reference_iterator_new(&out: PPGitReferenceIterator; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_reference_iterator_new';

function git_reference_iterator_glob_new(&out: PPGitReferenceIterator; repo: PGitRepository; glob: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_iterator_glob_new';

function git_reference_next(&out: PPGitReference; iter: PGitReferenceIterator): LongInt; cdecl; external 'c' name 'git_reference_next';

function git_reference_next_name(&out: PPAnsiChar; iter: PGitReferenceIterator): LongInt; cdecl; external 'c' name 'git_reference_next_name';

procedure git_reference_iterator_free(iter: PGitReferenceIterator); cdecl; external 'c' name 'git_reference_iterator_free';

function git_reference_foreach_glob(repo: PGitRepository; glob: PAnsiChar; callback: TGitReferenceForeachNameCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach_glob';

function git_reference_has_log(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_has_log';

function git_reference_ensure_log(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_ensure_log';

function git_reference_is_branch(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_branch';

function git_reference_is_remote(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_remote';

function git_reference_is_tag(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_tag';

function git_reference_is_note(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_note';

function git_reference_normalize_name(buffer_out: PAnsiChar; buffer_size: TSizeT; name: PAnsiChar; flags: LongWord): LongInt; cdecl; external 'c' name 'git_reference_normalize_name';

function git_reference_peel(&out: PPGitObject; ref: PGitReference; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_reference_peel';

function git_reference_name_is_valid(valid: PLongInt; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_name_is_valid';

function git_reference_shorthand(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_shorthand';

function git_refdb_new(&out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_refdb_new';

function git_refdb_open(&out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_refdb_open';

function git_refdb_compress(refdb: PGitRefdb): LongInt; cdecl; external 'c' name 'git_refdb_compress';

procedure git_refdb_free(refdb: PGitRefdb); cdecl; external 'c' name 'git_refdb_free';

function git_filter_options_init(opts: PGitFilterOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_filter_options_init';

function git_filter_list_load(filters: PPGitFilterList; repo: PGitRepository; blob: PGitBlob; path: PAnsiChar; mode: TGitFilterModeT; flags: TUint32T): LongInt; cdecl; external 'c' name 'git_filter_list_load';

function git_filter_list_load_ext(filters: PPGitFilterList; repo: PGitRepository; blob: PGitBlob; path: PAnsiChar; mode: TGitFilterModeT; opts: PGitFilterOptions): LongInt; cdecl; external 'c' name 'git_filter_list_load_ext';

function git_filter_list_contains(filters: PGitFilterList; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_filter_list_contains';

function git_filter_list_apply_to_buffer(&out: PGitBuf; filters: PGitFilterList; &in: PAnsiChar; in_len: TSizeT): LongInt; cdecl; external 'c' name 'git_filter_list_apply_to_buffer';

function git_filter_list_apply_to_file(&out: PGitBuf; filters: PGitFilterList; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_filter_list_apply_to_file';

function git_filter_list_apply_to_blob(&out: PGitBuf; filters: PGitFilterList; blob: PGitBlob): LongInt; cdecl; external 'c' name 'git_filter_list_apply_to_blob';

function git_filter_list_stream_buffer(filters: PGitFilterList; buffer: PAnsiChar; len: TSizeT; target: PGitWritestream): LongInt; cdecl; external 'c' name 'git_filter_list_stream_buffer';

function git_filter_list_stream_file(filters: PGitFilterList; repo: PGitRepository; path: PAnsiChar; target: PGitWritestream): LongInt; cdecl; external 'c' name 'git_filter_list_stream_file';

function git_filter_list_stream_blob(filters: PGitFilterList; blob: PGitBlob; target: PGitWritestream): LongInt; cdecl; external 'c' name 'git_filter_list_stream_blob';

procedure git_filter_list_free(filters: PGitFilterList); cdecl; external 'c' name 'git_filter_list_free';

function git_object_lookup(&object: PPGitObject; repo: PGitRepository; id: PGitOid; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup';

function git_object_lookup_prefix(object_out: PPGitObject; repo: PGitRepository; id: PGitOid; len: TSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup_prefix';

function git_object_lookup_bypath(&out: PPGitObject; treeish: PGitObject; path: PAnsiChar; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup_bypath';

function git_object_id(obj: PGitObject): PGitOid; cdecl; external 'c' name 'git_object_id';

function git_object_short_id(&out: PGitBuf; obj: PGitObject): LongInt; cdecl; external 'c' name 'git_object_short_id';

function git_object_type(obj: PGitObject): TGitObjectT; cdecl; external 'c' name 'git_object_type';

function git_object_owner(obj: PGitObject): PGitRepository; cdecl; external 'c' name 'git_object_owner';

procedure git_object_free(&object: PGitObject); cdecl; external 'c' name 'git_object_free';

function git_object_type2string(&type: TGitObjectT): PAnsiChar; cdecl; external 'c' name 'git_object_type2string';

function git_object_string2type(str: PAnsiChar): TGitObjectT; cdecl; external 'c' name 'git_object_string2type';

function git_object_type_is_valid(&type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_type_is_valid';

function git_object_peel(peeled: PPGitObject; &object: PGitObject; target_type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_peel';

function git_object_dup(dest: PPGitObject; source: PGitObject): LongInt; cdecl; external 'c' name 'git_object_dup';

function git_object_id_options_init(opts: PGitObjectIdOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_object_id_options_init';

function git_object_id_from_buffer(oid_out: PGitOid; buf: Pointer; len: TSizeT; opts: PGitObjectIdOptions): LongInt; cdecl; external 'c' name 'git_object_id_from_buffer';

function git_object_id_from_file(oid_out: PGitOid; path: PAnsiChar; opts: PGitObjectIdOptions): LongInt; cdecl; external 'c' name 'git_object_id_from_file';

function git_object_rawcontent_is_valid(valid: PLongInt; buf: PAnsiChar; len: TSizeT; object_type: TGitObjectT; oid_type: TGitOidT): LongInt; cdecl; external 'c' name 'git_object_rawcontent_is_valid';

function git_commit_lookup(commit: PPGitCommit; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_commit_lookup';

function git_commit_lookup_prefix(commit: PPGitCommit; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_commit_lookup_prefix';

procedure git_commit_free(commit: PGitCommit); cdecl; external 'c' name 'git_commit_free';

function git_commit_id(commit: PGitCommit): PGitOid; cdecl; external 'c' name 'git_commit_id';

function git_commit_owner(commit: PGitCommit): PGitRepository; cdecl; external 'c' name 'git_commit_owner';

function git_commit_message_encoding(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message_encoding';

function git_commit_message(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message';

function git_commit_message_raw(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message_raw';

function git_commit_summary(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_summary';

function git_commit_body(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_body';

function git_commit_time(commit: PGitCommit): TGitTimeT; cdecl; external 'c' name 'git_commit_time';

function git_commit_time_offset(commit: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_time_offset';

function git_commit_committer(commit: PGitCommit): PGitSignature; cdecl; external 'c' name 'git_commit_committer';

function git_commit_author(commit: PGitCommit): PGitSignature; cdecl; external 'c' name 'git_commit_author';

function git_commit_committer_with_mailmap(&out: PPGitSignature; commit: PGitCommit; mailmap: PGitMailmap): LongInt; cdecl; external 'c' name 'git_commit_committer_with_mailmap';

function git_commit_author_with_mailmap(&out: PPGitSignature; commit: PGitCommit; mailmap: PGitMailmap): LongInt; cdecl; external 'c' name 'git_commit_author_with_mailmap';

function git_commit_raw_header(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_raw_header';

function git_commit_tree(tree_out: PPGitTree; commit: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_tree';

function git_commit_tree_id(commit: PGitCommit): PGitOid; cdecl; external 'c' name 'git_commit_tree_id';

function git_commit_parentcount(commit: PGitCommit): LongWord; cdecl; external 'c' name 'git_commit_parentcount';

function git_commit_parent(&out: PPGitCommit; commit: PGitCommit; n: LongWord): LongInt; cdecl; external 'c' name 'git_commit_parent';

function git_commit_parent_id(commit: PGitCommit; n: LongWord): PGitOid; cdecl; external 'c' name 'git_commit_parent_id';

function git_commit_nth_gen_ancestor(ancestor: PPGitCommit; commit: PGitCommit; n: LongWord): LongInt; cdecl; external 'c' name 'git_commit_nth_gen_ancestor';

function git_commit_header_field(&out: PGitBuf; commit: PGitCommit; field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_header_field';

function git_commit_extract_signature(signature: PGitBuf; signed_data: PGitBuf; repo: PGitRepository; commit_id: PGitOid; field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_extract_signature';

function git_commitbuilder_add_header(builder: PGitCommitbuilder; field: PAnsiChar; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commitbuilder_add_header';

function git_commit_create_options_init(opts: PGitCommitCreateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_commit_create_options_init';

function git_commit_create_from_stage(id: PGitOid; repo: PGitRepository; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_create_from_stage';

function git_commit_create_ext_options_init(opts: PGitCommitCreateExtOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_commit_create_ext_options_init';

function git_commit_create_ext(id_out: PGitOid; repo: PGitRepository; author: PGitSignature; committer: PGitSignature; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit; opts: PGitCommitCreateExtOptions): LongInt; cdecl; external 'c' name 'git_commit_create_ext';

function git_commit_create(id: PGitOid; repo: PGitRepository; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit): LongInt; cdecl; external 'c' name 'git_commit_create';

function git_commit_create_v(id: PGitOid; repo: PGitRepository; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT): LongInt; cdecl; varargs; external 'c' name 'git_commit_create_v';

function git_commit_create_from_tree(id: PGitOid; repo: PGitRepository; tree: PGitTree; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_create_from_tree';

function git_commit_amend_from_stage(id: PGitOid; repo: PGitRepository; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_amend_from_stage';

function git_commit_amend_from_tree(id: PGitOid; repo: PGitRepository; tree: PGitTree; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_amend_from_tree';

function git_commit_amend(id: PGitOid; commit_to_amend: PGitCommit; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree): LongInt; cdecl; external 'c' name 'git_commit_amend';

function git_commit_create_buffer(&out: PGitBuf; repo: PGitRepository; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit): LongInt; cdecl; external 'c' name 'git_commit_create_buffer';

function git_commit_create_with_signature(&out: PGitOid; repo: PGitRepository; commit_content: PAnsiChar; signature: PAnsiChar; signature_field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_create_with_signature';

function git_commit_dup(&out: PPGitCommit; source: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_dup';

procedure git_commitarray_dispose(&array: PGitCommitarray); cdecl; external 'c' name 'git_commitarray_dispose';

function git_repository_open(&out: PPGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open';

function git_repository_open_from_worktree(&out: PPGitRepository; wt: PGitWorktree): LongInt; cdecl; external 'c' name 'git_repository_open_from_worktree';

function git_repository_wrap_odb(&out: PPGitRepository; odb: PGitOdb): LongInt; cdecl; external 'c' name 'git_repository_wrap_odb';

function git_repository_discover(&out: PGitBuf; start_path: PAnsiChar; across_fs: LongInt; ceiling_dirs: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_discover';

function git_repository_open_ext(&out: PPGitRepository; path: PAnsiChar; flags: LongWord; ceiling_dirs: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open_ext';

function git_repository_open_bare(&out: PPGitRepository; bare_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open_bare';

procedure git_repository_free(repo: PGitRepository); cdecl; external 'c' name 'git_repository_free';

function git_repository_init(&out: PPGitRepository; path: PAnsiChar; is_bare: LongWord): LongInt; cdecl; external 'c' name 'git_repository_init';

function git_repository_init_options_init(opts: PGitRepositoryInitOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_repository_init_options_init';

function git_repository_init_ext(&out: PPGitRepository; repo_path: PAnsiChar; opts: PGitRepositoryInitOptions): LongInt; cdecl; external 'c' name 'git_repository_init_ext';

function git_repository_head(&out: PPGitReference; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head';

function git_repository_head_for_worktree(&out: PPGitReference; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_head_for_worktree';

function git_repository_head_detached(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head_detached';

function git_repository_head_detached_for_worktree(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_head_detached_for_worktree';

function git_repository_head_unborn(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head_unborn';

function git_repository_is_empty(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_empty';

function git_repository_item_path(&out: PGitBuf; repo: PGitRepository; item: TGitRepositoryItemT): LongInt; cdecl; external 'c' name 'git_repository_item_path';

function git_repository_path(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_path';

function git_repository_workdir(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_workdir';

function git_repository_commondir(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_commondir';

function git_repository_set_workdir(repo: PGitRepository; workdir: PAnsiChar; update_gitlink: LongInt): LongInt; cdecl; external 'c' name 'git_repository_set_workdir';

function git_repository_is_bare(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_bare';

function git_repository_is_worktree(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_worktree';

function git_repository_config(&out: PPGitConfig; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_config';

function git_repository_config_snapshot(&out: PPGitConfig; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_config_snapshot';

function git_repository_odb(&out: PPGitOdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_odb';

function git_repository_refdb(&out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_refdb';

function git_repository_index(&out: PPGitIndex; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_index';

function git_repository_message(&out: PGitBuf; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_message';

function git_repository_message_remove(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_message_remove';

function git_repository_state_cleanup(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_state_cleanup';

function git_repository_fetchhead_foreach(repo: PGitRepository; callback: TGitRepositoryFetchheadForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_repository_fetchhead_foreach';

function git_repository_mergehead_foreach(repo: PGitRepository; callback: TGitRepositoryMergeheadForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_repository_mergehead_foreach';

function git_repository_hashfile(&out: PGitOid; repo: PGitRepository; path: PAnsiChar; &type: TGitObjectT; as_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_hashfile';

function git_repository_set_head(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_head';

function git_repository_set_head_detached(repo: PGitRepository; committish: PGitOid): LongInt; cdecl; external 'c' name 'git_repository_set_head_detached';

function git_repository_set_head_detached_from_annotated(repo: PGitRepository; committish: PGitAnnotatedCommit): LongInt; cdecl; external 'c' name 'git_repository_set_head_detached_from_annotated';

function git_repository_detach_head(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_detach_head';

function git_repository_state(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_state';

function git_repository_set_namespace(repo: PGitRepository; nmspace: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_namespace';

function git_repository_get_namespace(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_get_namespace';

function git_repository_is_shallow(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_shallow';

function git_repository_ident(name: PPAnsiChar; email: PPAnsiChar; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_ident';

function git_repository_set_ident(repo: PGitRepository; name: PAnsiChar; email: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_ident';

function git_repository_oid_type(repo: PGitRepository): TGitOidT; cdecl; external 'c' name 'git_repository_oid_type';

function git_repository_commit_parents(commits: PGitCommitarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_commit_parents';

function git_annotated_commit_from_ref(&out: PPGitAnnotatedCommit; repo: PGitRepository; ref: PGitReference): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_ref';

function git_annotated_commit_from_fetchhead(&out: PPGitAnnotatedCommit; repo: PGitRepository; branch_name: PAnsiChar; remote_url: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_fetchhead';

function git_annotated_commit_lookup(&out: PPGitAnnotatedCommit; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_annotated_commit_lookup';

function git_annotated_commit_from_revspec(&out: PPGitAnnotatedCommit; repo: PGitRepository; revspec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_revspec';

function git_annotated_commit_id(commit: PGitAnnotatedCommit): PGitOid; cdecl; external 'c' name 'git_annotated_commit_id';

function git_annotated_commit_ref(commit: PGitAnnotatedCommit): PAnsiChar; cdecl; external 'c' name 'git_annotated_commit_ref';

procedure git_annotated_commit_free(commit: PGitAnnotatedCommit); cdecl; external 'c' name 'git_annotated_commit_free';

function git_tree_lookup(&out: PPGitTree; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_tree_lookup';

function git_tree_lookup_prefix(&out: PPGitTree; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_tree_lookup_prefix';

procedure git_tree_free(tree: PGitTree); cdecl; external 'c' name 'git_tree_free';

function git_tree_id(tree: PGitTree): PGitOid; cdecl; external 'c' name 'git_tree_id';

function git_tree_owner(tree: PGitTree): PGitRepository; cdecl; external 'c' name 'git_tree_owner';

function git_tree_entrycount(tree: PGitTree): TSizeT; cdecl; external 'c' name 'git_tree_entrycount';

function git_tree_entry_byname(tree: PGitTree; filename: PAnsiChar): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byname';

function git_tree_entry_byindex(tree: PGitTree; idx: TSizeT): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byindex';

function git_tree_entry_byid(tree: PGitTree; id: PGitOid): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byid';

function git_tree_entry_bypath(&out: PPGitTreeEntry; root: PGitTree; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_tree_entry_bypath';

function git_tree_entry_dup(dest: PPGitTreeEntry; source: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_dup';

procedure git_tree_entry_free(entry: PGitTreeEntry); cdecl; external 'c' name 'git_tree_entry_free';

function git_tree_entry_name(entry: PGitTreeEntry): PAnsiChar; cdecl; external 'c' name 'git_tree_entry_name';

function git_tree_entry_id(entry: PGitTreeEntry): PGitOid; cdecl; external 'c' name 'git_tree_entry_id';

function git_tree_entry_type(entry: PGitTreeEntry): TGitObjectT; cdecl; external 'c' name 'git_tree_entry_type';

function git_tree_entry_filemode(entry: PGitTreeEntry): TGitFilemodeT; cdecl; external 'c' name 'git_tree_entry_filemode';

function git_tree_entry_filemode_raw(entry: PGitTreeEntry): TGitFilemodeT; cdecl; external 'c' name 'git_tree_entry_filemode_raw';

function git_tree_entry_cmp(e1: PGitTreeEntry; e2: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_cmp';

function git_tree_entry_to_object(object_out: PPGitObject; repo: PGitRepository; entry: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_to_object';

function git_treebuilder_new(&out: PPGitTreebuilder; repo: PGitRepository; source: PGitTree): LongInt; cdecl; external 'c' name 'git_treebuilder_new';

function git_treebuilder_clear(bld: PGitTreebuilder): LongInt; cdecl; external 'c' name 'git_treebuilder_clear';

function git_treebuilder_entrycount(bld: PGitTreebuilder): TSizeT; cdecl; external 'c' name 'git_treebuilder_entrycount';

procedure git_treebuilder_free(bld: PGitTreebuilder); cdecl; external 'c' name 'git_treebuilder_free';

function git_treebuilder_get(bld: PGitTreebuilder; filename: PAnsiChar): PGitTreeEntry; cdecl; external 'c' name 'git_treebuilder_get';

function git_treebuilder_insert(&out: PPGitTreeEntry; bld: PGitTreebuilder; filename: PAnsiChar; id: PGitOid; filemode: TGitFilemodeT): LongInt; cdecl; external 'c' name 'git_treebuilder_insert';

function git_treebuilder_remove(bld: PGitTreebuilder; filename: PAnsiChar): LongInt; cdecl; external 'c' name 'git_treebuilder_remove';

function git_treebuilder_filter(bld: PGitTreebuilder; filter: TGitTreebuilderFilterCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_treebuilder_filter';

function git_treebuilder_write(id: PGitOid; bld: PGitTreebuilder): LongInt; cdecl; external 'c' name 'git_treebuilder_write';

function git_tree_walk(tree: PGitTree; mode: TGitTreewalkMode; callback: TGitTreewalkCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_tree_walk';

function git_tree_dup(&out: PPGitTree; source: PGitTree): LongInt; cdecl; external 'c' name 'git_tree_dup';

function git_tree_create_updated(&out: PGitOid; repo: PGitRepository; baseline: PGitTree; nupdates: TSizeT; updates: PGitTreeUpdate): LongInt; cdecl; external 'c' name 'git_tree_create_updated';

function git_diff_options_init(opts: PGitDiffOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_options_init';

function git_diff_find_options_init(opts: PGitDiffFindOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_find_options_init';

procedure git_diff_free(diff: PGitDiff); cdecl; external 'c' name 'git_diff_free';

function git_diff_tree_to_tree(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; new_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_tree';

function git_diff_tree_to_index(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_index';

function git_diff_index_to_workdir(diff: PPGitDiff; repo: PGitRepository; index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_index_to_workdir';

function git_diff_tree_to_workdir(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_workdir';

function git_diff_tree_to_workdir_with_index(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_workdir_with_index';

function git_diff_index_to_index(diff: PPGitDiff; repo: PGitRepository; old_index: PGitIndex; new_index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_index_to_index';

function git_diff_merge(onto: PGitDiff; from: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_merge';

function git_diff_find_similar(diff: PGitDiff; options: PGitDiffFindOptions): LongInt; cdecl; external 'c' name 'git_diff_find_similar';

function git_diff_num_deltas(diff: PGitDiff): TSizeT; cdecl; external 'c' name 'git_diff_num_deltas';

function git_diff_num_deltas_of_type(diff: PGitDiff; &type: TGitDeltaT): TSizeT; cdecl; external 'c' name 'git_diff_num_deltas_of_type';

function git_diff_get_delta(diff: PGitDiff; idx: TSizeT): PGitDiffDelta; cdecl; external 'c' name 'git_diff_get_delta';

function git_diff_is_sorted_icase(diff: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_is_sorted_icase';

function git_diff_foreach(diff: PGitDiff; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_foreach';

function git_diff_status_char(status: TGitDeltaT): AnsiChar; cdecl; external 'c' name 'git_diff_status_char';

function git_diff_print(diff: PGitDiff; format: TGitDiffFormatT; print_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_print';

function git_diff_to_buf(&out: PGitBuf; diff: PGitDiff; format: TGitDiffFormatT): LongInt; cdecl; external 'c' name 'git_diff_to_buf';

function git_diff_blobs(old_blob: PGitBlob; old_as_path: PAnsiChar; new_blob: PGitBlob; new_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_blobs';

function git_diff_blob_to_buffer(old_blob: PGitBlob; old_as_path: PAnsiChar; buffer: PAnsiChar; buffer_len: TSizeT; buffer_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_blob_to_buffer';

function git_diff_buffers(old_buffer: Pointer; old_len: TSizeT; old_as_path: PAnsiChar; new_buffer: Pointer; new_len: TSizeT; new_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_buffers';

function git_diff_from_buffer(&out: PPGitDiff; content: PAnsiChar; content_len: TSizeT): LongInt; cdecl; external 'c' name 'git_diff_from_buffer';

function git_diff_from_buffer_ext(&out: PPGitDiff; content: PAnsiChar; content_len: TSizeT; opts: PGitDiffParseOptions): LongInt; cdecl; external 'c' name 'git_diff_from_buffer_ext';

function git_diff_get_stats(&out: PPGitDiffStats; diff: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_get_stats';

function git_diff_stats_files_changed(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_files_changed';

function git_diff_stats_insertions(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_insertions';

function git_diff_stats_deletions(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_deletions';

function git_diff_stats_to_buf(&out: PGitBuf; stats: PGitDiffStats; format: TGitDiffStatsFormatT; width: TSizeT): LongInt; cdecl; external 'c' name 'git_diff_stats_to_buf';

procedure git_diff_stats_free(stats: PGitDiffStats); cdecl; external 'c' name 'git_diff_stats_free';

function git_diff_patchid_options_init(opts: PGitDiffPatchidOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_patchid_options_init';

function git_diff_patchid(&out: PGitOid; diff: PGitDiff; opts: PGitDiffPatchidOptions): LongInt; cdecl; external 'c' name 'git_diff_patchid';

function git_apply_options_init(opts: PGitApplyOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_apply_options_init';

function git_apply_to_tree(&out: PPGitIndex; repo: PGitRepository; preimage: PGitTree; diff: PGitDiff; options: PGitApplyOptions): LongInt; cdecl; external 'c' name 'git_apply_to_tree';

function git_apply(repo: PGitRepository; diff: PGitDiff; location: TGitApplyLocationT; options: PGitApplyOptions): LongInt; cdecl; external 'c' name 'git_apply';

function git_attr_value(attr: PAnsiChar): TGitAttrValueT; cdecl; external 'c' name 'git_attr_value';

function git_attr_options_init(opts: PGitAttrOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_attr_options_init';

function git_attr_get(value_out: PPAnsiChar; repo: PGitRepository; flags: TUint32T; path: PAnsiChar; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get';

function git_attr_get_ext(value_out: PPAnsiChar; repo: PGitRepository; opts: PGitAttrOptions; path: PAnsiChar; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get_ext';

function git_attr_get_many(values_out: PPAnsiChar; repo: PGitRepository; flags: TUint32T; path: PAnsiChar; num_attr: TSizeT; names: PPAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get_many';

function git_attr_get_many_ext(values_out: PPAnsiChar; repo: PGitRepository; opts: PGitAttrOptions; path: PAnsiChar; num_attr: TSizeT; names: PPAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get_many_ext';

function git_attr_foreach(repo: PGitRepository; flags: TUint32T; path: PAnsiChar; callback: TGitAttrForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_attr_foreach';

function git_attr_foreach_ext(repo: PGitRepository; opts: PGitAttrOptions; path: PAnsiChar; callback: TGitAttrForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_attr_foreach_ext';

function git_attr_cache_flush(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_attr_cache_flush';

function git_attr_add_macro(repo: PGitRepository; name: PAnsiChar; values: PAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_add_macro';

function git_blob_lookup(blob: PPGitBlob; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_blob_lookup';

function git_blob_lookup_prefix(blob: PPGitBlob; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_blob_lookup_prefix';

procedure git_blob_free(blob: PGitBlob); cdecl; external 'c' name 'git_blob_free';

function git_blob_id(blob: PGitBlob): PGitOid; cdecl; external 'c' name 'git_blob_id';

function git_blob_owner(blob: PGitBlob): PGitRepository; cdecl; external 'c' name 'git_blob_owner';

function git_blob_rawcontent(blob: PGitBlob): Pointer; cdecl; external 'c' name 'git_blob_rawcontent';

function git_blob_rawsize(blob: PGitBlob): TGitObjectSizeT; cdecl; external 'c' name 'git_blob_rawsize';

function git_blob_filter_options_init(opts: PGitBlobFilterOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_blob_filter_options_init';

function git_blob_filter(&out: PGitBuf; blob: PGitBlob; as_path: PAnsiChar; opts: PGitBlobFilterOptions): LongInt; cdecl; external 'c' name 'git_blob_filter';

function git_blob_create_from_workdir(id: PGitOid; repo: PGitRepository; relative_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_from_workdir';

function git_blob_create_from_disk(id: PGitOid; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_from_disk';

function git_blob_create_from_stream(&out: PPGitWritestream; repo: PGitRepository; hintpath: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_from_stream';

function git_blob_create_from_stream_commit(&out: PGitOid; stream: PGitWritestream): LongInt; cdecl; external 'c' name 'git_blob_create_from_stream_commit';

function git_blob_create_from_buffer(id: PGitOid; repo: PGitRepository; buffer: Pointer; len: TSizeT): LongInt; cdecl; external 'c' name 'git_blob_create_from_buffer';

function git_blob_is_binary(blob: PGitBlob): LongInt; cdecl; external 'c' name 'git_blob_is_binary';

function git_blob_data_is_binary(data: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_blob_data_is_binary';

function git_blob_dup(&out: PPGitBlob; source: PGitBlob): LongInt; cdecl; external 'c' name 'git_blob_dup';

function git_blame_options_init(opts: PGitBlameOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_blame_options_init';

function git_blame_linecount(blame: PGitBlame): TSizeT; cdecl; external 'c' name 'git_blame_linecount';

function git_blame_hunkcount(blame: PGitBlame): TSizeT; cdecl; external 'c' name 'git_blame_hunkcount';

function git_blame_hunk_byindex(blame: PGitBlame; index: TSizeT): PGitBlameHunk; cdecl; external 'c' name 'git_blame_hunk_byindex';

function git_blame_hunk_byline(blame: PGitBlame; lineno: TSizeT): PGitBlameHunk; cdecl; external 'c' name 'git_blame_hunk_byline';

function git_blame_line_byindex(blame: PGitBlame; idx: TSizeT): PGitBlameLine; cdecl; external 'c' name 'git_blame_line_byindex';

function git_blame_get_hunk_count(blame: PGitBlame): TUint32T; cdecl; external 'c' name 'git_blame_get_hunk_count';

function git_blame_get_hunk_byindex(blame: PGitBlame; index: TUint32T): PGitBlameHunk; cdecl; external 'c' name 'git_blame_get_hunk_byindex';

function git_blame_get_hunk_byline(blame: PGitBlame; lineno: TSizeT): PGitBlameHunk; cdecl; external 'c' name 'git_blame_get_hunk_byline';

function git_blame_file(&out: PPGitBlame; repo: PGitRepository; path: PAnsiChar; options: PGitBlameOptions): LongInt; cdecl; external 'c' name 'git_blame_file';

function git_blame_file_from_buffer(&out: PPGitBlame; repo: PGitRepository; path: PAnsiChar; contents: PAnsiChar; contents_len: TSizeT; options: PGitBlameOptions): LongInt; cdecl; external 'c' name 'git_blame_file_from_buffer';

function git_blame_buffer(&out: PPGitBlame; base: PGitBlame; buffer: PAnsiChar; buffer_len: TSizeT): LongInt; cdecl; external 'c' name 'git_blame_buffer';

procedure git_blame_free(blame: PGitBlame); cdecl; external 'c' name 'git_blame_free';

function git_branch_create(&out: PPGitReference; repo: PGitRepository; branch_name: PAnsiChar; target: PGitCommit; force: LongInt): LongInt; cdecl; external 'c' name 'git_branch_create';

function git_branch_create_from_annotated(ref_out: PPGitReference; repo: PGitRepository; branch_name: PAnsiChar; target: PGitAnnotatedCommit; force: LongInt): LongInt; cdecl; external 'c' name 'git_branch_create_from_annotated';

function git_branch_delete(branch: PGitReference): LongInt; cdecl; external 'c' name 'git_branch_delete';

function git_branch_iterator_new(&out: PPGitBranchIterator; repo: PGitRepository; list_flags: TGitBranchT): LongInt; cdecl; external 'c' name 'git_branch_iterator_new';

function git_branch_next(&out: PPGitReference; out_type: PGitBranchT; iter: PGitBranchIterator): LongInt; cdecl; external 'c' name 'git_branch_next';

procedure git_branch_iterator_free(iter: PGitBranchIterator); cdecl; external 'c' name 'git_branch_iterator_free';

function git_branch_move(&out: PPGitReference; branch: PGitReference; new_branch_name: PAnsiChar; force: LongInt): LongInt; cdecl; external 'c' name 'git_branch_move';

function git_branch_lookup(&out: PPGitReference; repo: PGitRepository; branch_name: PAnsiChar; branch_type: TGitBranchT): LongInt; cdecl; external 'c' name 'git_branch_lookup';

function git_branch_name(&out: PPAnsiChar; ref: PGitReference): LongInt; cdecl; external 'c' name 'git_branch_name';

function git_branch_upstream(&out: PPGitReference; branch: PGitReference): LongInt; cdecl; external 'c' name 'git_branch_upstream';

function git_branch_set_upstream(branch: PGitReference; branch_name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_set_upstream';

function git_branch_upstream_name(&out: PGitBuf; repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_upstream_name';

function git_branch_is_head(branch: PGitReference): LongInt; cdecl; external 'c' name 'git_branch_is_head';

function git_branch_is_checked_out(branch: PGitReference): LongInt; cdecl; external 'c' name 'git_branch_is_checked_out';

function git_branch_remote_name(&out: PGitBuf; repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_remote_name';

function git_branch_upstream_remote(buf: PGitBuf; repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_upstream_remote';

function git_branch_upstream_merge(buf: PGitBuf; repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_upstream_merge';

function git_branch_name_is_valid(valid: PLongInt; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_branch_name_is_valid';

function git_checkout_options_init(opts: PGitCheckoutOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_checkout_options_init';

function git_checkout_head(repo: PGitRepository; opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_checkout_head';

function git_checkout_index(repo: PGitRepository; index: PGitIndex; opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_checkout_index';

function git_checkout_tree(repo: PGitRepository; treeish: PGitObject; opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_checkout_tree';

function git_index_options_init(opts: PGitIndexOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_index_options_init';

function git_index_open(index_out: PPGitIndex; index_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_open';

function git_index_open_ext(index_out: PPGitIndex; index_path: PAnsiChar; opts: PGitIndexOptions): LongInt; cdecl; external 'c' name 'git_index_open_ext';

function git_index_new(index_out: PPGitIndex): LongInt; cdecl; external 'c' name 'git_index_new';

function git_index_new_ext(index_out: PPGitIndex; opts: PGitIndexOptions): LongInt; cdecl; external 'c' name 'git_index_new_ext';

procedure git_index_free(index: PGitIndex); cdecl; external 'c' name 'git_index_free';

function git_index_owner(index: PGitIndex): PGitRepository; cdecl; external 'c' name 'git_index_owner';

function git_index_caps(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_caps';

function git_index_set_caps(index: PGitIndex; caps: LongInt): LongInt; cdecl; external 'c' name 'git_index_set_caps';

function git_index_version(index: PGitIndex): LongWord; cdecl; external 'c' name 'git_index_version';

function git_index_set_version(index: PGitIndex; version: LongWord): LongInt; cdecl; external 'c' name 'git_index_set_version';

function git_index_read(index: PGitIndex; force: LongInt): LongInt; cdecl; external 'c' name 'git_index_read';

function git_index_write(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_write';

function git_index_path(index: PGitIndex): PAnsiChar; cdecl; external 'c' name 'git_index_path';

function git_index_checksum(index: PGitIndex): PGitOid; cdecl; external 'c' name 'git_index_checksum';

function git_index_read_tree(index: PGitIndex; tree: PGitTree): LongInt; cdecl; external 'c' name 'git_index_read_tree';

function git_index_write_tree(&out: PGitOid; index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_write_tree';

function git_index_write_tree_to(&out: PGitOid; index: PGitIndex; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_index_write_tree_to';

function git_index_entrycount(index: PGitIndex): TSizeT; cdecl; external 'c' name 'git_index_entrycount';

function git_index_clear(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_clear';

function git_index_get_byindex(index: PGitIndex; n: TSizeT): PGitIndexEntry; cdecl; external 'c' name 'git_index_get_byindex';

function git_index_get_bypath(index: PGitIndex; path: PAnsiChar; stage: LongInt): PGitIndexEntry; cdecl; external 'c' name 'git_index_get_bypath';

function git_index_remove(index: PGitIndex; path: PAnsiChar; stage: LongInt): LongInt; cdecl; external 'c' name 'git_index_remove';

function git_index_remove_directory(index: PGitIndex; dir: PAnsiChar; stage: LongInt): LongInt; cdecl; external 'c' name 'git_index_remove_directory';

function git_index_add(index: PGitIndex; source_entry: PGitIndexEntry): LongInt; cdecl; external 'c' name 'git_index_add';

function git_index_entry_stage(entry: PGitIndexEntry): LongInt; cdecl; external 'c' name 'git_index_entry_stage';

function git_index_entry_is_conflict(entry: PGitIndexEntry): LongInt; cdecl; external 'c' name 'git_index_entry_is_conflict';

function git_index_iterator_new(iterator_out: PPGitIndexIterator; index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_iterator_new';

function git_index_iterator_next(&out: PPGitIndexEntry; iterator: PGitIndexIterator): LongInt; cdecl; external 'c' name 'git_index_iterator_next';

procedure git_index_iterator_free(iterator: PGitIndexIterator); cdecl; external 'c' name 'git_index_iterator_free';

function git_index_add_bypath(index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_add_bypath';

function git_index_add_from_buffer(index: PGitIndex; entry: PGitIndexEntry; buffer: Pointer; len: TSizeT): LongInt; cdecl; external 'c' name 'git_index_add_from_buffer';

function git_index_remove_bypath(index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_remove_bypath';

function git_index_add_all(index: PGitIndex; pathspec: PGitStrarray; flags: LongWord; callback: TGitIndexMatchedPathCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_index_add_all';

function git_index_remove_all(index: PGitIndex; pathspec: PGitStrarray; callback: TGitIndexMatchedPathCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_index_remove_all';

function git_index_update_all(index: PGitIndex; pathspec: PGitStrarray; callback: TGitIndexMatchedPathCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_index_update_all';

function git_index_find(at_pos: PSizeT; index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_find';

function git_index_find_prefix(at_pos: PSizeT; index: PGitIndex; prefix: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_find_prefix';

function git_index_conflict_add(index: PGitIndex; ancestor_entry: PGitIndexEntry; our_entry: PGitIndexEntry; their_entry: PGitIndexEntry): LongInt; cdecl; external 'c' name 'git_index_conflict_add';

function git_index_conflict_get(ancestor_out: PPGitIndexEntry; our_out: PPGitIndexEntry; their_out: PPGitIndexEntry; index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_conflict_get';

function git_index_conflict_remove(index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_conflict_remove';

function git_index_conflict_cleanup(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_conflict_cleanup';

function git_index_has_conflicts(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_has_conflicts';

function git_index_conflict_iterator_new(iterator_out: PPGitIndexConflictIterator; index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_conflict_iterator_new';

function git_index_conflict_next(ancestor_out: PPGitIndexEntry; our_out: PPGitIndexEntry; their_out: PPGitIndexEntry; iterator: PGitIndexConflictIterator): LongInt; cdecl; external 'c' name 'git_index_conflict_next';

procedure git_index_conflict_iterator_free(iterator: PGitIndexConflictIterator); cdecl; external 'c' name 'git_index_conflict_iterator_free';

function git_index_extension_lookup(&out: PGitBuf; index: PGitIndex; signature: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_extension_lookup';

function git_index_extension_add(index: PGitIndex; signature: PAnsiChar; data: PAnsiChar; data_len: TSizeT): LongInt; cdecl; external 'c' name 'git_index_extension_add';

function git_index_extension_remove(index: PGitIndex; signature: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_extension_remove';

function git_merge_file_input_init(opts: PGitMergeFileInput; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_file_input_init';

function git_merge_file_options_init(opts: PGitMergeFileOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_file_options_init';

function git_merge_options_init(opts: PGitMergeOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_options_init';

function git_merge_analysis(analysis_out: PGitMergeAnalysisT; preference_out: PGitMergePreferenceT; repo: PGitRepository; their_heads: PPGitAnnotatedCommit; their_heads_len: TSizeT): LongInt; cdecl; external 'c' name 'git_merge_analysis';

function git_merge_analysis_for_ref(analysis_out: PGitMergeAnalysisT; preference_out: PGitMergePreferenceT; repo: PGitRepository; our_ref: PGitReference; their_heads: PPGitAnnotatedCommit; their_heads_len: TSizeT): LongInt; cdecl; external 'c' name 'git_merge_analysis_for_ref';

function git_merge_base(&out: PGitOid; repo: PGitRepository; one: PGitOid; two: PGitOid): LongInt; cdecl; external 'c' name 'git_merge_base';

function git_merge_bases(&out: PGitOidarray; repo: PGitRepository; one: PGitOid; two: PGitOid): LongInt; cdecl; external 'c' name 'git_merge_bases';

function git_merge_base_many(&out: PGitOid; repo: PGitRepository; length: TSizeT; input_array: PGitOid): LongInt; cdecl; external 'c' name 'git_merge_base_many';

function git_merge_bases_many(&out: PGitOidarray; repo: PGitRepository; length: TSizeT; input_array: PGitOid): LongInt; cdecl; external 'c' name 'git_merge_bases_many';

function git_merge_base_octopus(&out: PGitOid; repo: PGitRepository; length: TSizeT; input_array: PGitOid): LongInt; cdecl; external 'c' name 'git_merge_base_octopus';

function git_merge_file(&out: PGitMergeFileResult; ancestor: PGitMergeFileInput; ours: PGitMergeFileInput; theirs: PGitMergeFileInput; opts: PGitMergeFileOptions): LongInt; cdecl; external 'c' name 'git_merge_file';

function git_merge_file_from_index(&out: PGitMergeFileResult; repo: PGitRepository; ancestor: PGitIndexEntry; ours: PGitIndexEntry; theirs: PGitIndexEntry; opts: PGitMergeFileOptions): LongInt; cdecl; external 'c' name 'git_merge_file_from_index';

procedure git_merge_file_result_free(result_2: PGitMergeFileResult); cdecl; external 'c' name 'git_merge_file_result_free';

function git_merge_trees(&out: PPGitIndex; repo: PGitRepository; ancestor_tree: PGitTree; our_tree: PGitTree; their_tree: PGitTree; opts: PGitMergeOptions): LongInt; cdecl; external 'c' name 'git_merge_trees';

function git_merge_commits(&out: PPGitIndex; repo: PGitRepository; our_commit: PGitCommit; their_commit: PGitCommit; opts: PGitMergeOptions): LongInt; cdecl; external 'c' name 'git_merge_commits';

function git_merge(repo: PGitRepository; their_heads: PPGitAnnotatedCommit; their_heads_len: TSizeT; merge_opts: PGitMergeOptions; checkout_opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_merge';

function git_cherrypick_options_init(opts: PGitCherrypickOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_cherrypick_options_init';

function git_cherrypick_commit(&out: PPGitIndex; repo: PGitRepository; cherrypick_commit: PGitCommit; our_commit: PGitCommit; mainline: LongWord; merge_options: PGitMergeOptions): LongInt; cdecl; external 'c' name 'git_cherrypick_commit';

function git_cherrypick(repo: PGitRepository; commit: PGitCommit; cherrypick_options: PGitCherrypickOptions): LongInt; cdecl; external 'c' name 'git_cherrypick';

function git_refspec_parse(refspec: PPGitRefspec; input: PAnsiChar; is_fetch: LongInt): LongInt; cdecl; external 'c' name 'git_refspec_parse';

procedure git_refspec_free(refspec: PGitRefspec); cdecl; external 'c' name 'git_refspec_free';

function git_refspec_src(refspec: PGitRefspec): PAnsiChar; cdecl; external 'c' name 'git_refspec_src';

function git_refspec_dst(refspec: PGitRefspec): PAnsiChar; cdecl; external 'c' name 'git_refspec_dst';

function git_refspec_string(refspec: PGitRefspec): PAnsiChar; cdecl; external 'c' name 'git_refspec_string';

function git_refspec_force(refspec: PGitRefspec): LongInt; cdecl; external 'c' name 'git_refspec_force';

function git_refspec_direction(spec: PGitRefspec): TGitDirection; cdecl; external 'c' name 'git_refspec_direction';

function git_refspec_src_matches_negative(refspec: PGitRefspec; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_refspec_src_matches_negative';

function git_refspec_src_matches(refspec: PGitRefspec; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_refspec_src_matches';

function git_refspec_dst_matches(refspec: PGitRefspec; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_refspec_dst_matches';

function git_refspec_transform(&out: PGitBuf; spec: PGitRefspec; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_refspec_transform';

function git_refspec_rtransform(&out: PGitBuf; spec: PGitRefspec; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_refspec_rtransform';

procedure git_credential_free(cred: PGitCredential); cdecl; external 'c' name 'git_credential_free';

function git_credential_has_username(cred: PGitCredential): LongInt; cdecl; external 'c' name 'git_credential_has_username';

function git_credential_get_username(cred: PGitCredential): PAnsiChar; cdecl; external 'c' name 'git_credential_get_username';

function git_credential_userpass_plaintext_new(&out: PPGitCredential; username: PAnsiChar; password: PAnsiChar): LongInt; cdecl; external 'c' name 'git_credential_userpass_plaintext_new';

function git_credential_default_new(&out: PPGitCredential): LongInt; cdecl; external 'c' name 'git_credential_default_new';

function git_credential_username_new(&out: PPGitCredential; username: PAnsiChar): LongInt; cdecl; external 'c' name 'git_credential_username_new';

function git_credential_ssh_key_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; privatekey: PAnsiChar; passphrase: PAnsiChar): LongInt; cdecl; external 'c' name 'git_credential_ssh_key_new';

function git_credential_ssh_key_memory_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; privatekey: PAnsiChar; passphrase: PAnsiChar): LongInt; cdecl; external 'c' name 'git_credential_ssh_key_memory_new';

function git_credential_ssh_interactive_new(&out: PPGitCredential; username: PAnsiChar; prompt_callback: TGitCredentialSshInteractiveCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_credential_ssh_interactive_new';

function git_credential_ssh_key_from_agent(&out: PPGitCredential; username: PAnsiChar): LongInt; cdecl; external 'c' name 'git_credential_ssh_key_from_agent';

function git_credential_ssh_custom_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; publickey_len: TSizeT; sign_callback: TGitCredentialSignCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_credential_ssh_custom_new';

function git_packbuilder_new(&out: PPGitPackbuilder; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_packbuilder_new';

function git_packbuilder_set_threads(pb: PGitPackbuilder; n: LongWord): LongWord; cdecl; external 'c' name 'git_packbuilder_set_threads';

function git_packbuilder_insert(pb: PGitPackbuilder; id: PGitOid; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_packbuilder_insert';

function git_packbuilder_insert_tree(pb: PGitPackbuilder; id: PGitOid): LongInt; cdecl; external 'c' name 'git_packbuilder_insert_tree';

function git_packbuilder_insert_commit(pb: PGitPackbuilder; id: PGitOid): LongInt; cdecl; external 'c' name 'git_packbuilder_insert_commit';

function git_packbuilder_insert_walk(pb: PGitPackbuilder; walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_packbuilder_insert_walk';

function git_packbuilder_insert_recur(pb: PGitPackbuilder; id: PGitOid; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_packbuilder_insert_recur';

function git_packbuilder_write_buf(buf: PGitBuf; pb: PGitPackbuilder): LongInt; cdecl; external 'c' name 'git_packbuilder_write_buf';

function git_packbuilder_write(pb: PGitPackbuilder; path: PAnsiChar; mode: LongWord; progress_cb: TGitIndexerProgressCb; progress_cb_payload: Pointer): LongInt; cdecl; external 'c' name 'git_packbuilder_write';

function git_packbuilder_hash(pb: PGitPackbuilder): PGitOid; cdecl; external 'c' name 'git_packbuilder_hash';

function git_packbuilder_name(pb: PGitPackbuilder): PAnsiChar; cdecl; external 'c' name 'git_packbuilder_name';

function git_packbuilder_foreach(pb: PGitPackbuilder; cb: TGitPackbuilderForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_packbuilder_foreach';

function git_packbuilder_object_count(pb: PGitPackbuilder): TSizeT; cdecl; external 'c' name 'git_packbuilder_object_count';

function git_packbuilder_written(pb: PGitPackbuilder): TSizeT; cdecl; external 'c' name 'git_packbuilder_written';

function git_packbuilder_set_callbacks(pb: PGitPackbuilder; progress_cb: TGitPackbuilderProgress; progress_cb_payload: Pointer): LongInt; cdecl; external 'c' name 'git_packbuilder_set_callbacks';

procedure git_packbuilder_free(pb: PGitPackbuilder); cdecl; external 'c' name 'git_packbuilder_free';

function git_proxy_options_init(opts: PGitProxyOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_proxy_options_init';

function git_remote_create(&out: PPGitRemote; repo: PGitRepository; name: PAnsiChar; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_create';

function git_remote_create_options_init(opts: PGitRemoteCreateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_remote_create_options_init';

function git_remote_create_with_opts(&out: PPGitRemote; url: PAnsiChar; opts: PGitRemoteCreateOptions): LongInt; cdecl; external 'c' name 'git_remote_create_with_opts';

function git_remote_create_with_fetchspec(&out: PPGitRemote; repo: PGitRepository; name: PAnsiChar; url: PAnsiChar; fetch: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_create_with_fetchspec';

function git_remote_create_anonymous(&out: PPGitRemote; repo: PGitRepository; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_create_anonymous';

function git_remote_create_detached(&out: PPGitRemote; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_create_detached';

function git_remote_lookup(&out: PPGitRemote; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_lookup';

function git_remote_dup(dest: PPGitRemote; source: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_dup';

function git_remote_owner(remote: PGitRemote): PGitRepository; cdecl; external 'c' name 'git_remote_owner';

function git_remote_name(remote: PGitRemote): PAnsiChar; cdecl; external 'c' name 'git_remote_name';

function git_remote_url(remote: PGitRemote): PAnsiChar; cdecl; external 'c' name 'git_remote_url';

function git_remote_pushurl(remote: PGitRemote): PAnsiChar; cdecl; external 'c' name 'git_remote_pushurl';

function git_remote_set_url(repo: PGitRepository; remote: PAnsiChar; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_set_url';

function git_remote_set_pushurl(repo: PGitRepository; remote: PAnsiChar; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_set_pushurl';

function git_remote_set_instance_url(remote: PGitRemote; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_set_instance_url';

function git_remote_set_instance_pushurl(remote: PGitRemote; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_set_instance_pushurl';

function git_remote_add_fetch(repo: PGitRepository; remote: PAnsiChar; refspec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_add_fetch';

function git_remote_get_fetch_refspecs(&array: PGitStrarray; remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_get_fetch_refspecs';

function git_remote_add_push(repo: PGitRepository; remote: PAnsiChar; refspec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_add_push';

function git_remote_get_push_refspecs(&array: PGitStrarray; remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_get_push_refspecs';

function git_remote_refspec_count(remote: PGitRemote): TSizeT; cdecl; external 'c' name 'git_remote_refspec_count';

function git_remote_get_refspec(remote: PGitRemote; n: TSizeT): PGitRefspec; cdecl; external 'c' name 'git_remote_get_refspec';

function git_remote_ls(&out: PPPGitRemoteHead; size: PSizeT; remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_ls';

function git_remote_connected(remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_connected';

function git_remote_oid_type(&out: PGitOidT; remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_oid_type';

function git_remote_stop(remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_stop';

function git_remote_disconnect(remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_disconnect';

procedure git_remote_free(remote: PGitRemote); cdecl; external 'c' name 'git_remote_free';

function git_remote_list(&out: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_remote_list';

function git_remote_init_callbacks(opts: PGitRemoteCallbacks; version: LongWord): LongInt; cdecl; external 'c' name 'git_remote_init_callbacks';

function git_fetch_options_init(opts: PGitFetchOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_fetch_options_init';

function git_push_options_init(opts: PGitPushOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_push_options_init';

function git_remote_connect_options_init(opts: PGitRemoteConnectOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_remote_connect_options_init';

function git_remote_connect(remote: PGitRemote; direction: TGitDirection; callbacks: PGitRemoteCallbacks; proxy_opts: PGitProxyOptions; custom_headers: PGitStrarray): LongInt; cdecl; external 'c' name 'git_remote_connect';

function git_remote_connect_ext(remote: PGitRemote; direction: TGitDirection; opts: PGitRemoteConnectOptions): LongInt; cdecl; external 'c' name 'git_remote_connect_ext';

function git_remote_download(remote: PGitRemote; refspecs: PGitStrarray; opts: PGitFetchOptions): LongInt; cdecl; external 'c' name 'git_remote_download';

function git_remote_upload(remote: PGitRemote; refspecs: PGitStrarray; opts: PGitPushOptions): LongInt; cdecl; external 'c' name 'git_remote_upload';

function git_remote_update_tips(remote: PGitRemote; callbacks: PGitRemoteCallbacks; update_flags: LongWord; download_tags: TGitRemoteAutotagOptionT; reflog_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_update_tips';

function git_remote_fetch(remote: PGitRemote; refspecs: PGitStrarray; opts: PGitFetchOptions; reflog_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_fetch';

function git_remote_prune(remote: PGitRemote; callbacks: PGitRemoteCallbacks): LongInt; cdecl; external 'c' name 'git_remote_prune';

function git_remote_push(remote: PGitRemote; refspecs: PGitStrarray; opts: PGitPushOptions): LongInt; cdecl; external 'c' name 'git_remote_push';

function git_remote_stats(remote: PGitRemote): PGitIndexerProgress; cdecl; external 'c' name 'git_remote_stats';

function git_remote_autotag(remote: PGitRemote): TGitRemoteAutotagOptionT; cdecl; external 'c' name 'git_remote_autotag';

function git_remote_set_autotag(repo: PGitRepository; remote: PAnsiChar; value: TGitRemoteAutotagOptionT): LongInt; cdecl; external 'c' name 'git_remote_set_autotag';

function git_remote_prune_refs(remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_prune_refs';

function git_remote_rename(problems: PGitStrarray; repo: PGitRepository; name: PAnsiChar; new_name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_rename';

function git_remote_name_is_valid(valid: PLongInt; remote_name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_name_is_valid';

function git_remote_delete(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_delete';

function git_remote_default_branch(&out: PGitBuf; remote: PGitRemote): LongInt; cdecl; external 'c' name 'git_remote_default_branch';

function git_clone_options_init(opts: PGitCloneOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_clone_options_init';

function git_clone(&out: PPGitRepository; url: PAnsiChar; local_path: PAnsiChar; options: PGitCloneOptions): LongInt; cdecl; external 'c' name 'git_clone';

procedure git_config_entry_free(entry: PGitConfigEntry); cdecl; external 'c' name 'git_config_entry_free';

function git_config_find_global(&out: PGitBuf): LongInt; cdecl; external 'c' name 'git_config_find_global';

function git_config_find_xdg(&out: PGitBuf): LongInt; cdecl; external 'c' name 'git_config_find_xdg';

function git_config_find_system(&out: PGitBuf): LongInt; cdecl; external 'c' name 'git_config_find_system';

function git_config_open_default(&out: PPGitConfig): LongInt; cdecl; external 'c' name 'git_config_open_default';

function git_config_new(&out: PPGitConfig): LongInt; cdecl; external 'c' name 'git_config_new';

function git_config_add_file_ondisk(cfg: PGitConfig; path: PAnsiChar; level: TGitConfigLevelT; repo: PGitRepository; force: LongInt): LongInt; cdecl; external 'c' name 'git_config_add_file_ondisk';

function git_config_open_ondisk(&out: PPGitConfig; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_open_ondisk';

function git_config_open_level(&out: PPGitConfig; parent: PGitConfig; level: TGitConfigLevelT): LongInt; cdecl; external 'c' name 'git_config_open_level';

function git_config_open_global(&out: PPGitConfig; config: PGitConfig): LongInt; cdecl; external 'c' name 'git_config_open_global';

function git_config_set_writeorder(cfg: PGitConfig; levels: PGitConfigLevelT; len: TSizeT): LongInt; cdecl; external 'c' name 'git_config_set_writeorder';

function git_config_snapshot(&out: PPGitConfig; config: PGitConfig): LongInt; cdecl; external 'c' name 'git_config_snapshot';

procedure git_config_free(cfg: PGitConfig); cdecl; external 'c' name 'git_config_free';

function git_config_get_entry(&out: PPGitConfigEntry; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_entry';

function git_config_get_int32(&out: PInt32T; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_int32';

function git_config_get_int64(&out: PInt64T; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_int64';

function git_config_get_bool(&out: PLongInt; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_bool';

function git_config_get_path(&out: PGitBuf; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_path';

function git_config_get_string(&out: PPAnsiChar; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_string';

function git_config_get_string_buf(&out: PGitBuf; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_string_buf';

function git_config_get_multivar_foreach(cfg: PGitConfig; name: PAnsiChar; regexp: PAnsiChar; callback: TGitConfigForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_config_get_multivar_foreach';

function git_config_multivar_iterator_new(&out: PPGitConfigIterator; cfg: PGitConfig; name: PAnsiChar; regexp: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_multivar_iterator_new';

function git_config_next(entry: PPGitConfigEntry; iter: PGitConfigIterator): LongInt; cdecl; external 'c' name 'git_config_next';

procedure git_config_iterator_free(iter: PGitConfigIterator); cdecl; external 'c' name 'git_config_iterator_free';

function git_config_set_int32(cfg: PGitConfig; name: PAnsiChar; value: TInt32T): LongInt; cdecl; external 'c' name 'git_config_set_int32';

function git_config_set_int64(cfg: PGitConfig; name: PAnsiChar; value: TInt64T): LongInt; cdecl; external 'c' name 'git_config_set_int64';

function git_config_set_bool(cfg: PGitConfig; name: PAnsiChar; value: LongInt): LongInt; cdecl; external 'c' name 'git_config_set_bool';

function git_config_set_string(cfg: PGitConfig; name: PAnsiChar; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_set_string';

function git_config_set_multivar(cfg: PGitConfig; name: PAnsiChar; regexp: PAnsiChar; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_set_multivar';

function git_config_delete_entry(cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_delete_entry';

function git_config_delete_multivar(cfg: PGitConfig; name: PAnsiChar; regexp: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_delete_multivar';

function git_config_foreach(cfg: PGitConfig; callback: TGitConfigForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_config_foreach';

function git_config_iterator_new(&out: PPGitConfigIterator; cfg: PGitConfig): LongInt; cdecl; external 'c' name 'git_config_iterator_new';

function git_config_iterator_glob_new(&out: PPGitConfigIterator; cfg: PGitConfig; regexp: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_iterator_glob_new';

function git_config_foreach_match(cfg: PGitConfig; regexp: PAnsiChar; callback: TGitConfigForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_config_foreach_match';

function git_config_get_mapped(&out: PLongInt; cfg: PGitConfig; name: PAnsiChar; maps: PGitConfigmap; map_n: TSizeT): LongInt; cdecl; external 'c' name 'git_config_get_mapped';

function git_config_lookup_map_value(&out: PLongInt; maps: PGitConfigmap; map_n: TSizeT; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_lookup_map_value';

function git_config_parse_bool(&out: PLongInt; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_parse_bool';

function git_config_parse_int32(&out: PInt32T; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_parse_int32';

function git_config_parse_int64(&out: PInt64T; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_parse_int64';

function git_config_parse_path(&out: PGitBuf; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_parse_path';

function git_config_backend_foreach_match(backend: PGitConfigBackend; regexp: PAnsiChar; callback: TGitConfigForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_config_backend_foreach_match';

function git_config_lock(tx: PPGitTransaction; cfg: PGitConfig): LongInt; cdecl; external 'c' name 'git_config_lock';

function git_describe_options_init(opts: PGitDescribeOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_describe_options_init';

function git_describe_format_options_init(opts: PGitDescribeFormatOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_describe_format_options_init';

function git_describe_commit(result_2: PPGitDescribeResult; committish: PGitObject; opts: PGitDescribeOptions): LongInt; cdecl; external 'c' name 'git_describe_commit';

function git_describe_workdir(&out: PPGitDescribeResult; repo: PGitRepository; opts: PGitDescribeOptions): LongInt; cdecl; external 'c' name 'git_describe_workdir';

function git_describe_format(&out: PGitBuf; result_2: PGitDescribeResult; opts: PGitDescribeFormatOptions): LongInt; cdecl; external 'c' name 'git_describe_format';

procedure git_describe_result_free(result_2: PGitDescribeResult); cdecl; external 'c' name 'git_describe_result_free';

function git_error_last(): PGitError; cdecl; external 'c' name 'git_error_last';

function git_rebase_options_init(opts: PGitRebaseOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_rebase_options_init';

function git_rebase_init(&out: PPGitRebase; repo: PGitRepository; branch: PGitAnnotatedCommit; upstream: PGitAnnotatedCommit; onto: PGitAnnotatedCommit; opts: PGitRebaseOptions): LongInt; cdecl; external 'c' name 'git_rebase_init';

function git_rebase_open(&out: PPGitRebase; repo: PGitRepository; opts: PGitRebaseOptions): LongInt; cdecl; external 'c' name 'git_rebase_open';

function git_rebase_orig_head_name(rebase: PGitRebase): PAnsiChar; cdecl; external 'c' name 'git_rebase_orig_head_name';

function git_rebase_orig_head_id(rebase: PGitRebase): PGitOid; cdecl; external 'c' name 'git_rebase_orig_head_id';

function git_rebase_onto_name(rebase: PGitRebase): PAnsiChar; cdecl; external 'c' name 'git_rebase_onto_name';

function git_rebase_onto_id(rebase: PGitRebase): PGitOid; cdecl; external 'c' name 'git_rebase_onto_id';

function git_rebase_operation_entrycount(rebase: PGitRebase): TSizeT; cdecl; external 'c' name 'git_rebase_operation_entrycount';

function git_rebase_operation_current(rebase: PGitRebase): TSizeT; cdecl; external 'c' name 'git_rebase_operation_current';

function git_rebase_operation_byindex(rebase: PGitRebase; idx: TSizeT): PGitRebaseOperation; cdecl; external 'c' name 'git_rebase_operation_byindex';

function git_rebase_next(operation: PPGitRebaseOperation; rebase: PGitRebase): LongInt; cdecl; external 'c' name 'git_rebase_next';

function git_rebase_inmemory_index(index: PPGitIndex; rebase: PGitRebase): LongInt; cdecl; external 'c' name 'git_rebase_inmemory_index';

function git_rebase_commit(id: PGitOid; rebase: PGitRebase; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_rebase_commit';

function git_rebase_abort(rebase: PGitRebase): LongInt; cdecl; external 'c' name 'git_rebase_abort';

function git_rebase_finish(rebase: PGitRebase; signature: PGitSignature): LongInt; cdecl; external 'c' name 'git_rebase_finish';

procedure git_rebase_free(rebase: PGitRebase); cdecl; external 'c' name 'git_rebase_free';

function git_trace_set(level: TGitTraceLevelT; cb: TGitTraceCb): LongInt; cdecl; external 'c' name 'git_trace_set';

function git_revert_options_init(opts: PGitRevertOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_revert_options_init';

function git_revert_commit(&out: PPGitIndex; repo: PGitRepository; revert_commit: PGitCommit; our_commit: PGitCommit; mainline: LongWord; merge_options: PGitMergeOptions): LongInt; cdecl; external 'c' name 'git_revert_commit';

function git_revert(repo: PGitRepository; commit: PGitCommit; given_opts: PGitRevertOptions): LongInt; cdecl; external 'c' name 'git_revert';

function git_revparse_single(&out: PPGitObject; repo: PGitRepository; spec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revparse_single';

function git_revparse_ext(object_out: PPGitObject; reference_out: PPGitReference; repo: PGitRepository; spec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revparse_ext';

function git_revparse(revspec: PGitRevspec; repo: PGitRepository; spec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revparse';

function git_stash_save(&out: PGitOid; repo: PGitRepository; stasher: PGitSignature; message: PAnsiChar; flags: TUint32T): LongInt; cdecl; external 'c' name 'git_stash_save';

function git_stash_save_options_init(opts: PGitStashSaveOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_stash_save_options_init';

function git_stash_save_with_opts(&out: PGitOid; repo: PGitRepository; opts: PGitStashSaveOptions): LongInt; cdecl; external 'c' name 'git_stash_save_with_opts';

function git_stash_apply_options_init(opts: PGitStashApplyOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_stash_apply_options_init';

function git_stash_apply(repo: PGitRepository; index: TSizeT; options: PGitStashApplyOptions): LongInt; cdecl; external 'c' name 'git_stash_apply';

function git_stash_foreach(repo: PGitRepository; callback: TGitStashCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_stash_foreach';

function git_stash_drop(repo: PGitRepository; index: TSizeT): LongInt; cdecl; external 'c' name 'git_stash_drop';

function git_stash_pop(repo: PGitRepository; index: TSizeT; options: PGitStashApplyOptions): LongInt; cdecl; external 'c' name 'git_stash_pop';

function git_status_options_init(opts: PGitStatusOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_status_options_init';

function git_status_foreach(repo: PGitRepository; callback: TGitStatusCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_status_foreach';

function git_status_foreach_ext(repo: PGitRepository; opts: PGitStatusOptions; callback: TGitStatusCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_status_foreach_ext';

function git_status_file(status_flags: PLongWord; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_status_file';

function git_status_list_new(&out: PPGitStatusList; repo: PGitRepository; opts: PGitStatusOptions): LongInt; cdecl; external 'c' name 'git_status_list_new';

function git_status_list_entrycount(statuslist: PGitStatusList): TSizeT; cdecl; external 'c' name 'git_status_list_entrycount';

function git_status_byindex(statuslist: PGitStatusList; idx: TSizeT): PGitStatusEntry; cdecl; external 'c' name 'git_status_byindex';

procedure git_status_list_free(statuslist: PGitStatusList); cdecl; external 'c' name 'git_status_list_free';

function git_status_should_ignore(ignored: PLongInt; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_status_should_ignore';

function git_submodule_update_options_init(opts: PGitSubmoduleUpdateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_submodule_update_options_init';

function git_submodule_update(submodule: PGitSubmodule; init: LongInt; options: PGitSubmoduleUpdateOptions): LongInt; cdecl; external 'c' name 'git_submodule_update';

function git_submodule_lookup(&out: PPGitSubmodule; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_submodule_lookup';

function git_submodule_dup(&out: PPGitSubmodule; source: PGitSubmodule): LongInt; cdecl; external 'c' name 'git_submodule_dup';

procedure git_submodule_free(submodule: PGitSubmodule); cdecl; external 'c' name 'git_submodule_free';

function git_submodule_foreach(repo: PGitRepository; callback: TGitSubmoduleCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_submodule_foreach';

function git_submodule_add_setup(&out: PPGitSubmodule; repo: PGitRepository; url: PAnsiChar; path: PAnsiChar; use_gitlink: LongInt): LongInt; cdecl; external 'c' name 'git_submodule_add_setup';

function git_submodule_clone(&out: PPGitRepository; submodule: PGitSubmodule; opts: PGitSubmoduleUpdateOptions): LongInt; cdecl; external 'c' name 'git_submodule_clone';

function git_submodule_add_finalize(submodule: PGitSubmodule): LongInt; cdecl; external 'c' name 'git_submodule_add_finalize';

function git_submodule_add_to_index(submodule: PGitSubmodule; write_index: LongInt): LongInt; cdecl; external 'c' name 'git_submodule_add_to_index';

function git_submodule_owner(submodule: PGitSubmodule): PGitRepository; cdecl; external 'c' name 'git_submodule_owner';

function git_submodule_name(submodule: PGitSubmodule): PAnsiChar; cdecl; external 'c' name 'git_submodule_name';

function git_submodule_path(submodule: PGitSubmodule): PAnsiChar; cdecl; external 'c' name 'git_submodule_path';

function git_submodule_url(submodule: PGitSubmodule): PAnsiChar; cdecl; external 'c' name 'git_submodule_url';

function git_submodule_resolve_url(&out: PGitBuf; repo: PGitRepository; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_submodule_resolve_url';

function git_submodule_branch(submodule: PGitSubmodule): PAnsiChar; cdecl; external 'c' name 'git_submodule_branch';

function git_submodule_set_branch(repo: PGitRepository; name: PAnsiChar; branch: PAnsiChar): LongInt; cdecl; external 'c' name 'git_submodule_set_branch';

function git_submodule_set_url(repo: PGitRepository; name: PAnsiChar; url: PAnsiChar): LongInt; cdecl; external 'c' name 'git_submodule_set_url';

function git_submodule_index_id(submodule: PGitSubmodule): PGitOid; cdecl; external 'c' name 'git_submodule_index_id';

function git_submodule_head_id(submodule: PGitSubmodule): PGitOid; cdecl; external 'c' name 'git_submodule_head_id';

function git_submodule_wd_id(submodule: PGitSubmodule): PGitOid; cdecl; external 'c' name 'git_submodule_wd_id';

function git_submodule_ignore(submodule: PGitSubmodule): TGitSubmoduleIgnoreT; cdecl; external 'c' name 'git_submodule_ignore';

function git_submodule_set_ignore(repo: PGitRepository; name: PAnsiChar; ignore: TGitSubmoduleIgnoreT): LongInt; cdecl; external 'c' name 'git_submodule_set_ignore';

function git_submodule_update_strategy(submodule: PGitSubmodule): TGitSubmoduleUpdateT; cdecl; external 'c' name 'git_submodule_update_strategy';

function git_submodule_set_update(repo: PGitRepository; name: PAnsiChar; update: TGitSubmoduleUpdateT): LongInt; cdecl; external 'c' name 'git_submodule_set_update';

function git_submodule_fetch_recurse_submodules(submodule: PGitSubmodule): TGitSubmoduleRecurseT; cdecl; external 'c' name 'git_submodule_fetch_recurse_submodules';

function git_submodule_set_fetch_recurse_submodules(repo: PGitRepository; name: PAnsiChar; fetch_recurse_submodules: TGitSubmoduleRecurseT): LongInt; cdecl; external 'c' name 'git_submodule_set_fetch_recurse_submodules';

function git_submodule_init(submodule: PGitSubmodule; overwrite: LongInt): LongInt; cdecl; external 'c' name 'git_submodule_init';

function git_submodule_repo_init(&out: PPGitRepository; sm: PGitSubmodule; use_gitlink: LongInt): LongInt; cdecl; external 'c' name 'git_submodule_repo_init';

function git_submodule_sync(submodule: PGitSubmodule): LongInt; cdecl; external 'c' name 'git_submodule_sync';

function git_submodule_open(repo: PPGitRepository; submodule: PGitSubmodule): LongInt; cdecl; external 'c' name 'git_submodule_open';

function git_submodule_reload(submodule: PGitSubmodule; force: LongInt): LongInt; cdecl; external 'c' name 'git_submodule_reload';

function git_submodule_status(status: PLongWord; repo: PGitRepository; name: PAnsiChar; ignore: TGitSubmoduleIgnoreT): LongInt; cdecl; external 'c' name 'git_submodule_status';

function git_submodule_location(location_status: PLongWord; submodule: PGitSubmodule): LongInt; cdecl; external 'c' name 'git_submodule_location';

function git_worktree_list(&out: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_worktree_list';

function git_worktree_lookup(&out: PPGitWorktree; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_worktree_lookup';

function git_worktree_open_from_repository(&out: PPGitWorktree; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_worktree_open_from_repository';

procedure git_worktree_free(wt: PGitWorktree); cdecl; external 'c' name 'git_worktree_free';

function git_worktree_validate(wt: PGitWorktree): LongInt; cdecl; external 'c' name 'git_worktree_validate';

function git_worktree_add_options_init(opts: PGitWorktreeAddOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_worktree_add_options_init';

function git_worktree_add(&out: PPGitWorktree; repo: PGitRepository; name: PAnsiChar; path: PAnsiChar; opts: PGitWorktreeAddOptions): LongInt; cdecl; external 'c' name 'git_worktree_add';

function git_worktree_lock(wt: PGitWorktree; reason: PAnsiChar): LongInt; cdecl; external 'c' name 'git_worktree_lock';

function git_worktree_unlock(wt: PGitWorktree): LongInt; cdecl; external 'c' name 'git_worktree_unlock';

function git_worktree_is_locked(reason: PGitBuf; wt: PGitWorktree): LongInt; cdecl; external 'c' name 'git_worktree_is_locked';

function git_worktree_name(wt: PGitWorktree): PAnsiChar; cdecl; external 'c' name 'git_worktree_name';

function git_worktree_path(wt: PGitWorktree): PAnsiChar; cdecl; external 'c' name 'git_worktree_path';

function git_worktree_prune_options_init(opts: PGitWorktreePruneOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_worktree_prune_options_init';

function git_worktree_is_prunable(wt: PGitWorktree; opts: PGitWorktreePruneOptions): LongInt; cdecl; external 'c' name 'git_worktree_is_prunable';

function git_worktree_prune(wt: PGitWorktree; opts: PGitWorktreePruneOptions): LongInt; cdecl; external 'c' name 'git_worktree_prune';

function git_credential_userpass(&out: PPGitCredential; url: PAnsiChar; user_from_url: PAnsiChar; allowed_types: LongWord; payload: Pointer): LongInt; cdecl; external 'c' name 'git_credential_userpass';

function git_blob_create_fromworkdir(id: PGitOid; repo: PGitRepository; relative_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_fromworkdir';

function git_blob_create_fromdisk(id: PGitOid; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_fromdisk';

function git_blob_create_fromstream(&out: PPGitWritestream; repo: PGitRepository; hintpath: PAnsiChar): LongInt; cdecl; external 'c' name 'git_blob_create_fromstream';

function git_blob_create_fromstream_commit(&out: PGitOid; stream: PGitWritestream): LongInt; cdecl; external 'c' name 'git_blob_create_fromstream_commit';

function git_blob_create_frombuffer(id: PGitOid; repo: PGitRepository; buffer: Pointer; len: TSizeT): LongInt; cdecl; external 'c' name 'git_blob_create_frombuffer';

function git_blob_filtered_content(&out: PGitBuf; blob: PGitBlob; as_path: PAnsiChar; check_for_binary_data: LongInt): LongInt; cdecl; external 'c' name 'git_blob_filtered_content';

function git_filter_list_stream_data(filters: PGitFilterList; data: PGitBuf; target: PGitWritestream): LongInt; cdecl; external 'c' name 'git_filter_list_stream_data';

function git_filter_list_apply_to_data(&out: PGitBuf; filters: PGitFilterList; &in: PGitBuf): LongInt; cdecl; external 'c' name 'git_filter_list_apply_to_data';

function git_treebuilder_write_with_buffer(oid: PGitOid; bld: PGitTreebuilder; tree: PGitBuf): LongInt; cdecl; external 'c' name 'git_treebuilder_write_with_buffer';

function git_buf_grow(buffer: PGitBuf; target_size: TSizeT): LongInt; cdecl; external 'c' name 'git_buf_grow';

function git_buf_set(buffer: PGitBuf; data: Pointer; datalen: TSizeT): LongInt; cdecl; external 'c' name 'git_buf_set';

function git_buf_is_binary(buf: PGitBuf): LongInt; cdecl; external 'c' name 'git_buf_is_binary';

function git_buf_contains_nul(buf: PGitBuf): LongInt; cdecl; external 'c' name 'git_buf_contains_nul';

procedure git_buf_free(buffer: PGitBuf); cdecl; external 'c' name 'git_buf_free';

function git_config_find_programdata(&out: PGitBuf): LongInt; cdecl; external 'c' name 'git_config_find_programdata';

function git_diff_format_email(&out: PGitBuf; diff: PGitDiff; opts: PGitDiffFormatEmailOptions): LongInt; cdecl; external 'c' name 'git_diff_format_email';

function git_diff_commit_as_email(&out: PGitBuf; repo: PGitRepository; commit: PGitCommit; patch_no: TSizeT; total_patches: TSizeT; flags: TUint32T; diff_opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_commit_as_email';

function git_diff_format_email_options_init(opts: PGitDiffFormatEmailOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_format_email_options_init';

function giterr_last(): PGitError; cdecl; external 'c' name 'giterr_last';

procedure giterr_clear(); cdecl; external 'c' name 'giterr_clear';

procedure giterr_set_str(error_class: LongInt; &string: PAnsiChar); cdecl; external 'c' name 'giterr_set_str';

procedure giterr_set_oom(); cdecl; external 'c' name 'giterr_set_oom';

function git_index_add_frombuffer(index: PGitIndex; entry: PGitIndexEntry; buffer: Pointer; len: TSizeT): LongInt; cdecl; external 'c' name 'git_index_add_frombuffer';

function git_object__size(&type: TGitObjectT): TSizeT; cdecl; external 'c' name 'git_object__size';

function git_object_typeisloose(&type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_typeisloose';

function git_odb_hash(oid: PGitOid; data: Pointer; len: TSizeT; object_type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_hash';

function git_odb_hashfile(oid: PGitOid; path: PAnsiChar; object_type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_hashfile';

function git_remote_is_valid_name(remote_name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_is_valid_name';

function git_reference_is_valid_name(refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_is_valid_name';

function git_tag_create_frombuffer(oid: PGitOid; repo: PGitRepository; buffer: PAnsiChar; force: LongInt): LongInt; cdecl; external 'c' name 'git_tag_create_frombuffer';

procedure git_cred_free(cred: PGitCredential); cdecl; external 'c' name 'git_cred_free';

function git_cred_has_username(cred: PGitCredential): LongInt; cdecl; external 'c' name 'git_cred_has_username';

function git_cred_get_username(cred: PGitCredential): PAnsiChar; cdecl; external 'c' name 'git_cred_get_username';

function git_cred_userpass_plaintext_new(&out: PPGitCredential; username: PAnsiChar; password: PAnsiChar): LongInt; cdecl; external 'c' name 'git_cred_userpass_plaintext_new';

function git_cred_default_new(&out: PPGitCredential): LongInt; cdecl; external 'c' name 'git_cred_default_new';

function git_cred_username_new(&out: PPGitCredential; username: PAnsiChar): LongInt; cdecl; external 'c' name 'git_cred_username_new';

function git_cred_ssh_key_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; privatekey: PAnsiChar; passphrase: PAnsiChar): LongInt; cdecl; external 'c' name 'git_cred_ssh_key_new';

function git_cred_ssh_key_memory_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; privatekey: PAnsiChar; passphrase: PAnsiChar): LongInt; cdecl; external 'c' name 'git_cred_ssh_key_memory_new';

function git_cred_ssh_interactive_new(&out: PPGitCredential; username: PAnsiChar; prompt_callback: TGitCredentialSshInteractiveCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_cred_ssh_interactive_new';

function git_cred_ssh_key_from_agent(&out: PPGitCredential; username: PAnsiChar): LongInt; cdecl; external 'c' name 'git_cred_ssh_key_from_agent';

function git_cred_ssh_custom_new(&out: PPGitCredential; username: PAnsiChar; publickey: PAnsiChar; publickey_len: TSizeT; sign_callback: TGitCredentialSignCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_cred_ssh_custom_new';

function git_cred_userpass(&out: PPGitCredential; url: PAnsiChar; user_from_url: PAnsiChar; allowed_types: LongWord; payload: Pointer): LongInt; cdecl; external 'c' name 'git_cred_userpass';

function git_oid_iszero(id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_iszero';

procedure git_oidarray_free(&array: PGitOidarray); cdecl; external 'c' name 'git_oidarray_free';

function git_strarray_copy(tgt: PGitStrarray; src: PGitStrarray): LongInt; cdecl; external 'c' name 'git_strarray_copy';

procedure git_strarray_free(&array: PGitStrarray); cdecl; external 'c' name 'git_strarray_free';

function git_blame_init_options(opts: PGitBlameOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_blame_init_options';

function git_checkout_init_options(opts: PGitCheckoutOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_checkout_init_options';

function git_cherrypick_init_options(opts: PGitCherrypickOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_cherrypick_init_options';

function git_clone_init_options(opts: PGitCloneOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_clone_init_options';

function git_describe_init_options(opts: PGitDescribeOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_describe_init_options';

function git_describe_init_format_options(opts: PGitDescribeFormatOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_describe_init_format_options';

function git_diff_init_options(opts: PGitDiffOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_init_options';

function git_diff_find_init_options(opts: PGitDiffFindOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_find_init_options';

function git_diff_format_email_init_options(opts: PGitDiffFormatEmailOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_format_email_init_options';

function git_diff_patchid_init_options(opts: PGitDiffPatchidOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_patchid_init_options';

function git_fetch_init_options(opts: PGitFetchOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_fetch_init_options';

function git_indexer_init_options(opts: PGitIndexerOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_indexer_init_options';

function git_merge_init_options(opts: PGitMergeOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_init_options';

function git_merge_file_init_input(input: PGitMergeFileInput; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_file_init_input';

function git_merge_file_init_options(opts: PGitMergeFileOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_merge_file_init_options';

function git_proxy_init_options(opts: PGitProxyOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_proxy_init_options';

function git_push_init_options(opts: PGitPushOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_push_init_options';

function git_rebase_init_options(opts: PGitRebaseOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_rebase_init_options';

function git_remote_create_init_options(opts: PGitRemoteCreateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_remote_create_init_options';

function git_repository_init_init_options(opts: PGitRepositoryInitOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_repository_init_init_options';

function git_revert_init_options(opts: PGitRevertOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_revert_init_options';

function git_stash_apply_init_options(opts: PGitStashApplyOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_stash_apply_init_options';

function git_status_init_options(opts: PGitStatusOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_status_init_options';

function git_submodule_update_init_options(opts: PGitSubmoduleUpdateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_submodule_update_init_options';

function git_worktree_add_init_options(opts: PGitWorktreeAddOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_worktree_add_init_options';

function git_worktree_prune_init_options(opts: PGitWorktreePruneOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_worktree_prune_init_options';

function git_email_create_options_init(opts: PGitEmailCreateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_email_create_options_init';

function git_email_create_from_commit(&out: PGitBuf; commit: PGitCommit; opts: PGitEmailCreateOptions): LongInt; cdecl; external 'c' name 'git_email_create_from_commit';

function git_libgit2_init(): LongInt; cdecl; external 'c' name 'git_libgit2_init';

function git_libgit2_shutdown(): LongInt; cdecl; external 'c' name 'git_libgit2_shutdown';

function git_graph_ahead_behind(ahead: PSizeT; behind: PSizeT; repo: PGitRepository; local: PGitOid; upstream: PGitOid): LongInt; cdecl; external 'c' name 'git_graph_ahead_behind';

function git_graph_descendant_of(repo: PGitRepository; commit: PGitOid; ancestor: PGitOid): LongInt; cdecl; external 'c' name 'git_graph_descendant_of';

function git_graph_reachable_from_any(repo: PGitRepository; commit: PGitOid; descendant_array: PGitOid; length: TSizeT): LongInt; cdecl; external 'c' name 'git_graph_reachable_from_any';

function git_ignore_add_rule(repo: PGitRepository; rules: PAnsiChar): LongInt; cdecl; external 'c' name 'git_ignore_add_rule';

function git_ignore_clear_internal_rules(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_ignore_clear_internal_rules';

function git_ignore_path_is_ignored(ignored: PLongInt; repo: PGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_ignore_path_is_ignored';

function git_mailmap_new(&out: PPGitMailmap): LongInt; cdecl; external 'c' name 'git_mailmap_new';

procedure git_mailmap_free(mm: PGitMailmap); cdecl; external 'c' name 'git_mailmap_free';

function git_mailmap_add_entry(mm: PGitMailmap; real_name: PAnsiChar; real_email: PAnsiChar; replace_name: PAnsiChar; replace_email: PAnsiChar): LongInt; cdecl; external 'c' name 'git_mailmap_add_entry';

function git_mailmap_from_buffer(&out: PPGitMailmap; buf: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_mailmap_from_buffer';

function git_mailmap_from_repository(&out: PPGitMailmap; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_mailmap_from_repository';

function git_mailmap_resolve(real_name: PPAnsiChar; real_email: PPAnsiChar; mm: PGitMailmap; name: PAnsiChar; email: PAnsiChar): LongInt; cdecl; external 'c' name 'git_mailmap_resolve';

function git_mailmap_resolve_signature(&out: PPGitSignature; mm: PGitMailmap; sig: PGitSignature): LongInt; cdecl; external 'c' name 'git_mailmap_resolve_signature';

function git_message_prettify(&out: PGitBuf; message: PAnsiChar; strip_comments: LongInt; comment_char: AnsiChar): LongInt; cdecl; external 'c' name 'git_message_prettify';

function git_message_trailers(arr: PGitMessageTrailerArray; message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_message_trailers';

procedure git_message_trailer_array_free(arr: PGitMessageTrailerArray); cdecl; external 'c' name 'git_message_trailer_array_free';

function git_note_iterator_new(&out: PPGitNoteIterator; repo: PGitRepository; notes_ref: PAnsiChar): LongInt; cdecl; external 'c' name 'git_note_iterator_new';

function git_note_commit_iterator_new(&out: PPGitNoteIterator; notes_commit: PGitCommit): LongInt; cdecl; external 'c' name 'git_note_commit_iterator_new';

procedure git_note_iterator_free(it: PGitNoteIterator); cdecl; external 'c' name 'git_note_iterator_free';

function git_note_next(note_id: PGitOid; annotated_id: PGitOid; it: PGitNoteIterator): LongInt; cdecl; external 'c' name 'git_note_next';

function git_note_read(&out: PPGitNote; repo: PGitRepository; notes_ref: PAnsiChar; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_note_read';

function git_note_commit_read(&out: PPGitNote; repo: PGitRepository; notes_commit: PGitCommit; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_note_commit_read';

function git_note_author(note: PGitNote): PGitSignature; cdecl; external 'c' name 'git_note_author';

function git_note_committer(note: PGitNote): PGitSignature; cdecl; external 'c' name 'git_note_committer';

function git_note_message(note: PGitNote): PAnsiChar; cdecl; external 'c' name 'git_note_message';

function git_note_id(note: PGitNote): PGitOid; cdecl; external 'c' name 'git_note_id';

function git_note_create(&out: PGitOid; repo: PGitRepository; notes_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; oid: PGitOid; note: PAnsiChar; force: LongInt): LongInt; cdecl; external 'c' name 'git_note_create';

function git_note_commit_create(notes_commit_out: PGitOid; notes_blob_out: PGitOid; repo: PGitRepository; parent: PGitCommit; author: PGitSignature; committer: PGitSignature; oid: PGitOid; note: PAnsiChar; allow_note_overwrite: LongInt): LongInt; cdecl; external 'c' name 'git_note_commit_create';

function git_note_remove(repo: PGitRepository; notes_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_note_remove';

function git_note_commit_remove(notes_commit_out: PGitOid; repo: PGitRepository; notes_commit: PGitCommit; author: PGitSignature; committer: PGitSignature; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_note_commit_remove';

procedure git_note_free(note: PGitNote); cdecl; external 'c' name 'git_note_free';

function git_note_default_ref(&out: PGitBuf; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_note_default_ref';

function git_note_foreach(repo: PGitRepository; notes_ref: PAnsiChar; note_cb: TGitNoteForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_note_foreach';

function git_odb_backend_pack_options_init(opts: PGitOdbBackendPackOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_odb_backend_pack_options_init';

function git_odb_backend_loose_options_init(opts: PGitOdbBackendLooseOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_odb_backend_loose_options_init';

function git_odb_backend_pack(&out: PPGitOdbBackend; objects_dir: PAnsiChar; opts: PGitOdbBackendPackOptions): LongInt; cdecl; external 'c' name 'git_odb_backend_pack';

function git_odb_backend_one_pack(&out: PPGitOdbBackend; index_file: PAnsiChar; opts: PGitOdbBackendPackOptions): LongInt; cdecl; external 'c' name 'git_odb_backend_one_pack';

function git_odb_backend_loose(&out: PPGitOdbBackend; objects_dir: PAnsiChar; opts: PGitOdbBackendLooseOptions): LongInt; cdecl; external 'c' name 'git_odb_backend_loose';

function git_patch_owner(patch: PGitPatch): PGitRepository; cdecl; external 'c' name 'git_patch_owner';

function git_patch_from_diff(&out: PPGitPatch; diff: PGitDiff; idx: TSizeT): LongInt; cdecl; external 'c' name 'git_patch_from_diff';

function git_patch_from_blobs(&out: PPGitPatch; old_blob: PGitBlob; old_as_path: PAnsiChar; new_blob: PGitBlob; new_as_path: PAnsiChar; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_patch_from_blobs';

function git_patch_from_blob_and_buffer(&out: PPGitPatch; old_blob: PGitBlob; old_as_path: PAnsiChar; buffer: Pointer; buffer_len: TSizeT; buffer_as_path: PAnsiChar; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_patch_from_blob_and_buffer';

function git_patch_from_buffers(&out: PPGitPatch; old_buffer: Pointer; old_len: TSizeT; old_as_path: PAnsiChar; new_buffer: Pointer; new_len: TSizeT; new_as_path: PAnsiChar; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_patch_from_buffers';

procedure git_patch_free(patch: PGitPatch); cdecl; external 'c' name 'git_patch_free';

function git_patch_get_delta(patch: PGitPatch): PGitDiffDelta; cdecl; external 'c' name 'git_patch_get_delta';

function git_patch_num_hunks(patch: PGitPatch): TSizeT; cdecl; external 'c' name 'git_patch_num_hunks';

function git_patch_line_stats(total_context: PSizeT; total_additions: PSizeT; total_deletions: PSizeT; patch: PGitPatch): LongInt; cdecl; external 'c' name 'git_patch_line_stats';

function git_patch_get_hunk(&out: PPGitDiffHunk; lines_in_hunk: PSizeT; patch: PGitPatch; hunk_idx: TSizeT): LongInt; cdecl; external 'c' name 'git_patch_get_hunk';

function git_patch_num_lines_in_hunk(patch: PGitPatch; hunk_idx: TSizeT): LongInt; cdecl; external 'c' name 'git_patch_num_lines_in_hunk';

function git_patch_get_line_in_hunk(&out: PPGitDiffLine; patch: PGitPatch; hunk_idx: TSizeT; line_of_hunk: TSizeT): LongInt; cdecl; external 'c' name 'git_patch_get_line_in_hunk';

function git_patch_size(patch: PGitPatch; include_context: LongInt; include_hunk_headers: LongInt; include_file_headers: LongInt): TSizeT; cdecl; external 'c' name 'git_patch_size';

function git_patch_print(patch: PGitPatch; print_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_patch_print';

function git_patch_to_buf(&out: PGitBuf; patch: PGitPatch): LongInt; cdecl; external 'c' name 'git_patch_to_buf';

function git_pathspec_new(&out: PPGitPathspec; pathspec: PGitStrarray): LongInt; cdecl; external 'c' name 'git_pathspec_new';

procedure git_pathspec_free(ps: PGitPathspec); cdecl; external 'c' name 'git_pathspec_free';

function git_pathspec_matches_path(ps: PGitPathspec; flags: TUint32T; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_pathspec_matches_path';

function git_pathspec_match_workdir(&out: PPGitPathspecMatchList; repo: PGitRepository; flags: TUint32T; ps: PGitPathspec): LongInt; cdecl; external 'c' name 'git_pathspec_match_workdir';

function git_pathspec_match_index(&out: PPGitPathspecMatchList; index: PGitIndex; flags: TUint32T; ps: PGitPathspec): LongInt; cdecl; external 'c' name 'git_pathspec_match_index';

function git_pathspec_match_tree(&out: PPGitPathspecMatchList; tree: PGitTree; flags: TUint32T; ps: PGitPathspec): LongInt; cdecl; external 'c' name 'git_pathspec_match_tree';

function git_pathspec_match_diff(&out: PPGitPathspecMatchList; diff: PGitDiff; flags: TUint32T; ps: PGitPathspec): LongInt; cdecl; external 'c' name 'git_pathspec_match_diff';

procedure git_pathspec_match_list_free(m: PGitPathspecMatchList); cdecl; external 'c' name 'git_pathspec_match_list_free';

function git_pathspec_match_list_entrycount(m: PGitPathspecMatchList): TSizeT; cdecl; external 'c' name 'git_pathspec_match_list_entrycount';

function git_pathspec_match_list_entry(m: PGitPathspecMatchList; pos: TSizeT): PAnsiChar; cdecl; external 'c' name 'git_pathspec_match_list_entry';

function git_pathspec_match_list_diff_entry(m: PGitPathspecMatchList; pos: TSizeT): PGitDiffDelta; cdecl; external 'c' name 'git_pathspec_match_list_diff_entry';

function git_pathspec_match_list_failed_entrycount(m: PGitPathspecMatchList): TSizeT; cdecl; external 'c' name 'git_pathspec_match_list_failed_entrycount';

function git_pathspec_match_list_failed_entry(m: PGitPathspecMatchList; pos: TSizeT): PAnsiChar; cdecl; external 'c' name 'git_pathspec_match_list_failed_entry';

function git_reflog_read(&out: PPGitReflog; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reflog_read';

function git_reflog_write(reflog: PGitReflog): LongInt; cdecl; external 'c' name 'git_reflog_write';

function git_reflog_append(reflog: PGitReflog; id: PGitOid; committer: PGitSignature; msg: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reflog_append';

function git_reflog_rename(repo: PGitRepository; old_name: PAnsiChar; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reflog_rename';

function git_reflog_delete(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reflog_delete';

function git_reflog_entrycount(reflog: PGitReflog): TSizeT; cdecl; external 'c' name 'git_reflog_entrycount';

function git_reflog_entry_byindex(reflog: PGitReflog; idx: TSizeT): PGitReflogEntry; cdecl; external 'c' name 'git_reflog_entry_byindex';

function git_reflog_drop(reflog: PGitReflog; idx: TSizeT; rewrite_previous_entry: LongInt): LongInt; cdecl; external 'c' name 'git_reflog_drop';

function git_reflog_entry_id_old(entry: PGitReflogEntry): PGitOid; cdecl; external 'c' name 'git_reflog_entry_id_old';

function git_reflog_entry_id_new(entry: PGitReflogEntry): PGitOid; cdecl; external 'c' name 'git_reflog_entry_id_new';

function git_reflog_entry_committer(entry: PGitReflogEntry): PGitSignature; cdecl; external 'c' name 'git_reflog_entry_committer';

function git_reflog_entry_message(entry: PGitReflogEntry): PAnsiChar; cdecl; external 'c' name 'git_reflog_entry_message';

procedure git_reflog_free(reflog: PGitReflog); cdecl; external 'c' name 'git_reflog_free';

function git_reset(repo: PGitRepository; target: PGitObject; reset_type: TGitResetT; checkout_opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_reset';

function git_reset_from_annotated(repo: PGitRepository; target: PGitAnnotatedCommit; reset_type: TGitResetT; checkout_opts: PGitCheckoutOptions): LongInt; cdecl; external 'c' name 'git_reset_from_annotated';

function git_reset_default(repo: PGitRepository; target: PGitObject; pathspecs: PGitStrarray): LongInt; cdecl; external 'c' name 'git_reset_default';

function git_revwalk_new(&out: PPGitRevwalk; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_revwalk_new';

function git_revwalk_reset(walker: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_reset';

function git_revwalk_push(walk: PGitRevwalk; id: PGitOid): LongInt; cdecl; external 'c' name 'git_revwalk_push';

function git_revwalk_push_glob(walk: PGitRevwalk; glob: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revwalk_push_glob';

function git_revwalk_push_head(walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_push_head';

function git_revwalk_hide(walk: PGitRevwalk; commit_id: PGitOid): LongInt; cdecl; external 'c' name 'git_revwalk_hide';

function git_revwalk_hide_glob(walk: PGitRevwalk; glob: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revwalk_hide_glob';

function git_revwalk_hide_head(walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_hide_head';

function git_revwalk_push_ref(walk: PGitRevwalk; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revwalk_push_ref';

function git_revwalk_hide_ref(walk: PGitRevwalk; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revwalk_hide_ref';

function git_revwalk_next(&out: PGitOid; walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_next';

function git_revwalk_sorting(walk: PGitRevwalk; sort_mode: LongWord): LongInt; cdecl; external 'c' name 'git_revwalk_sorting';

function git_revwalk_pathspec(walk: PGitRevwalk; pathspec: PGitPathspec): LongInt; cdecl; external 'c' name 'git_revwalk_pathspec';

function git_revwalk_push_range(walk: PGitRevwalk; range: PAnsiChar): LongInt; cdecl; external 'c' name 'git_revwalk_push_range';

function git_revwalk_simplify_first_parent(walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_simplify_first_parent';

procedure git_revwalk_free(walk: PGitRevwalk); cdecl; external 'c' name 'git_revwalk_free';

function git_revwalk_repository(walk: PGitRevwalk): PGitRepository; cdecl; external 'c' name 'git_revwalk_repository';

function git_revwalk_add_hide_cb(walk: PGitRevwalk; hide_cb: TGitRevwalkHideCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_revwalk_add_hide_cb';

function git_signature_new(&out: PPGitSignature; name: PAnsiChar; email: PAnsiChar; time: TGitTimeT; offset: LongInt): LongInt; cdecl; external 'c' name 'git_signature_new';

function git_signature_now(&out: PPGitSignature; name: PAnsiChar; email: PAnsiChar): LongInt; cdecl; external 'c' name 'git_signature_now';

function git_signature_default_from_env(author_out: PPGitSignature; committer_out: PPGitSignature; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_signature_default_from_env';

function git_signature_default(&out: PPGitSignature; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_signature_default';

function git_signature_from_buffer(&out: PPGitSignature; buf: PAnsiChar): LongInt; cdecl; external 'c' name 'git_signature_from_buffer';

function git_signature_dup(dest: PPGitSignature; sig: PGitSignature): LongInt; cdecl; external 'c' name 'git_signature_dup';

procedure git_signature_free(sig: PGitSignature); cdecl; external 'c' name 'git_signature_free';

function git_tag_lookup(&out: PPGitTag; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_tag_lookup';

function git_tag_lookup_prefix(&out: PPGitTag; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_tag_lookup_prefix';

procedure git_tag_free(tag: PGitTag); cdecl; external 'c' name 'git_tag_free';

function git_tag_id(tag: PGitTag): PGitOid; cdecl; external 'c' name 'git_tag_id';

function git_tag_owner(tag: PGitTag): PGitRepository; cdecl; external 'c' name 'git_tag_owner';

function git_tag_target(target_out: PPGitObject; tag: PGitTag): LongInt; cdecl; external 'c' name 'git_tag_target';

function git_tag_target_id(tag: PGitTag): PGitOid; cdecl; external 'c' name 'git_tag_target_id';

function git_tag_target_type(tag: PGitTag): TGitObjectT; cdecl; external 'c' name 'git_tag_target_type';

function git_tag_name(tag: PGitTag): PAnsiChar; cdecl; external 'c' name 'git_tag_name';

function git_tag_tagger(tag: PGitTag): PGitSignature; cdecl; external 'c' name 'git_tag_tagger';

function git_tag_message(tag: PGitTag): PAnsiChar; cdecl; external 'c' name 'git_tag_message';

function git_tag_create(oid: PGitOid; repo: PGitRepository; tag_name: PAnsiChar; target: PGitObject; tagger: PGitSignature; message: PAnsiChar; force: LongInt): LongInt; cdecl; external 'c' name 'git_tag_create';

function git_tag_annotation_create(oid: PGitOid; repo: PGitRepository; tag_name: PAnsiChar; target: PGitObject; tagger: PGitSignature; message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_tag_annotation_create';

function git_tag_create_from_buffer(oid: PGitOid; repo: PGitRepository; buffer: PAnsiChar; force: LongInt): LongInt; cdecl; external 'c' name 'git_tag_create_from_buffer';

function git_tag_create_lightweight(oid: PGitOid; repo: PGitRepository; tag_name: PAnsiChar; target: PGitObject; force: LongInt): LongInt; cdecl; external 'c' name 'git_tag_create_lightweight';

function git_tag_delete(repo: PGitRepository; tag_name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_tag_delete';

function git_tag_list(tag_names: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_tag_list';

function git_tag_list_match(tag_names: PGitStrarray; pattern: PAnsiChar; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_tag_list_match';

function git_tag_foreach(repo: PGitRepository; callback: TGitTagForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_tag_foreach';

function git_tag_peel(tag_target_out: PPGitObject; tag: PGitTag): LongInt; cdecl; external 'c' name 'git_tag_peel';

function git_tag_dup(&out: PPGitTag; source: PGitTag): LongInt; cdecl; external 'c' name 'git_tag_dup';

function git_tag_name_is_valid(valid: PLongInt; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_tag_name_is_valid';

function git_transaction_new(&out: PPGitTransaction; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_transaction_new';

function git_transaction_lock_ref(tx: PGitTransaction; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_transaction_lock_ref';

function git_transaction_set_target(tx: PGitTransaction; refname: PAnsiChar; target: PGitOid; sig: PGitSignature; msg: PAnsiChar): LongInt; cdecl; external 'c' name 'git_transaction_set_target';

function git_transaction_set_symbolic_target(tx: PGitTransaction; refname: PAnsiChar; target: PAnsiChar; sig: PGitSignature; msg: PAnsiChar): LongInt; cdecl; external 'c' name 'git_transaction_set_symbolic_target';

function git_transaction_set_reflog(tx: PGitTransaction; refname: PAnsiChar; reflog: PGitReflog): LongInt; cdecl; external 'c' name 'git_transaction_set_reflog';

function git_transaction_remove(tx: PGitTransaction; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_transaction_remove';

function git_transaction_commit(tx: PGitTransaction): LongInt; cdecl; external 'c' name 'git_transaction_commit';

procedure git_transaction_free(tx: PGitTransaction); cdecl; external 'c' name 'git_transaction_free';

// ── Bridge inline helpers (zero-copy, no SysUtils) ──
// Unified vocabulary: base's git_oid (20B) ↔ TGitOid (33B) via Move; handles remain opaque.
// base provides canonical 20B git_oid; this unit's TGitOid is 33B static-track extension.
function BindingsGitOidEquals(const A, B: TGitOid): Boolean; inline;
procedure BindingsGitOidCopy(out Dst: TGitOid; const Src: TGitOid); inline;

implementation

function BindingsGitOidEquals(const A, B: TGitOid): Boolean; inline;
begin
  Result := (A.&type = B.&type) and CompareMem(@A.id[0], @B.id[0], SizeOf(A.id));
end;

procedure BindingsGitOidCopy(out Dst: TGitOid; const Src: TGitOid); inline;
begin
  Dst.&type := Src.&type;
  Move(Src.id[0], Dst.id[0], SizeOf(Src.id));
end;


procedure abort(); cdecl;
begin
  System.RunError(217);
end;

procedure exit_(status: LongInt); cdecl;
begin
  System.Halt(status);
end;

function atoi(nptr: PAnsiChar): LongInt; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Acc := -Acc;
  Result := LongInt(Acc); { atoi 语义: strtol 随即截断为 int }
end;

function atol(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

function atoll(nptr: PAnsiChar): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  Acc: Int64;
begin
  Result := 0;
  if nptr = nil then Exit;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  Acc := 0;
  while (P^ >= '0') and (P^ <= '9') do begin
    if Acc > (High(Int64) - (Ord(P^) - 48)) div 10 then begin
      if Neg then Acc := Low(Int64) else Acc := High(Int64);
      while (P^ >= '0') and (P^ <= '9') do Inc(P);
      break;
    end;
    Acc := Acc * 10 + (Ord(P^) - 48);
    Inc(P);
  end;
  if Neg then Result := -Acc else Result := Acc;
end;

function __errno_location(): PLongInt; cdecl; external 'c' name '__errno_location';

const
  TENH: array[-307..308] of QWord = (
    $0031FA182C40C60D { 10^-307 hi },
    $0066789E3750F791 { 10^-306 hi },
    $009C16C5C5253575 { 10^-305 hi },
    $00D18E3B9B374169 { 10^-304 hi },
    $0105F1CA820511C3 { 10^-303 hi },
    $013B6E3D22865634 { 10^-302 hi },
    $017124E63593F5E1 { 10^-301 hi },
    $01A56E1FC2F8F359 { 10^-300 hi },
    $01DAC9A7B3B7302F { 10^-299 hi },
    $0210BE08D0527E1D { 10^-298 hi },
    $0244ED8B04671DA5 { 10^-297 hi },
    $027A28EDC580E50E { 10^-296 hi },
    $02B059949B708F29 { 10^-295 hi },
    $02E46FF9C24CB2F3 { 10^-294 hi },
    $03198BF832DFDFB0 { 10^-293 hi },
    $034FEEF63F97D79C { 10^-292 hi },
    $0383F559E7BEE6C1 { 10^-291 hi },
    $03B8F2B061AEA072 { 10^-290 hi },
    $03EF2F5C7A1A488E { 10^-289 hi },
    $04237D99CC506D59 { 10^-288 hi },
    $04585D003F6488AF { 10^-287 hi },
    $048E74404F3DAADB { 10^-286 hi },
    $04C308A831868AC9 { 10^-285 hi },
    $04F7CAD23DE82D7B { 10^-284 hi },
    $052DBD86CD6238D9 { 10^-283 hi },
    $05629674405D6388 { 10^-282 hi },
    $05973C115074BC6A { 10^-281 hi },
    $05CD0B15A491EB84 { 10^-280 hi },
    $060226ED86DB3333 { 10^-279 hi },
    $0636B0A8E891FFFF { 10^-278 hi },
    $066C5CD322B67FFF { 10^-277 hi },
    $06A1BA03F5B21000 { 10^-276 hi },
    $06D62884F31E93FF { 10^-275 hi },
    $070BB2A62FE638FF { 10^-274 hi },
    $07414FA7DDEFE3A0 { 10^-273 hi },
    $0775A391D56BDC87 { 10^-272 hi },
    $07AB0C764AC6D3A9 { 10^-271 hi },
    $07E0E7C9EEBC444A { 10^-270 hi },
    $081521BC6A6B555C { 10^-269 hi },
    $084A6A2B85062AB3 { 10^-268 hi },
    $0880825B3323DAB0 { 10^-267 hi },
    $08B4A2F1FFECD15C { 10^-266 hi },
    $08E9CBAE7FE805B3 { 10^-265 hi },
    $09201F4D0FF10390 { 10^-264 hi },
    $0954272053ED4474 { 10^-263 hi },
    $098930E868E89591 { 10^-262 hi },
    $09BF7D228322BAF5 { 10^-261 hi },
    $09F3AE3591F5B4D9 { 10^-260 hi },
    $0A2899C2F6732210 { 10^-259 hi },
    $0A5EC033B40FEA93 { 10^-258 hi },
    $0A9338205089F29C { 10^-257 hi },
    $0AC8062864AC6F43 { 10^-256 hi },
    $0AFE07B27DD78B14 { 10^-255 hi },
    $0B32C4CF8EA6B6EC { 10^-254 hi },
    $0B677603725064A8 { 10^-253 hi },
    $0B9D53844EE47DD1 { 10^-252 hi },
    $0BD25432B14ECEA3 { 10^-251 hi },
    $0C06E93F5DA2824C { 10^-250 hi },
    $0C3CA38F350B22DF { 10^-249 hi },
    $0C71E6398126F5CB { 10^-248 hi },
    $0CA65FC7E170B33E { 10^-247 hi },
    $0CDBF7B9D9CCE00D { 10^-246 hi },
    $0D117AD428200C08 { 10^-245 hi },
    $0D45D98932280F0A { 10^-244 hi },
    $0D7B4FEB7EB212CD { 10^-243 hi },
    $0DB111F32F2F4BC0 { 10^-242 hi },
    $0DE5566FFAFB1EB0 { 10^-241 hi },
    $0E1AAC0BF9B9E65C { 10^-240 hi },
    $0E50AB877C142FFA { 10^-239 hi },
    $0E84D6695B193BF8 { 10^-238 hi },
    $0EBA0C03B1DF8AF6 { 10^-237 hi },
    $0EF047824F2BB6DA { 10^-236 hi },
    $0F245962E2F6A490 { 10^-235 hi },
    $0F596FBB9BB44DB4 { 10^-234 hi },
    $0F8FCBAA82A16121 { 10^-233 hi },
    $0FC3DF4A91A4DCB5 { 10^-232 hi },
    $0FF8D71D360E13E2 { 10^-231 hi },
    $102F0CE4839198DB { 10^-230 hi },
    $1063680ED23AFF89 { 10^-229 hi },
    $1098421286C9BF6B { 10^-228 hi },
    $10CE5297287C2F45 { 10^-227 hi },
    $1102F39E794D9D8B { 10^-226 hi },
    $1137B08617A104EE { 10^-225 hi },
    $116D9CA79D89462A { 10^-224 hi },
    $11A281E8C275CBDA { 10^-223 hi },
    $11D72262F3133ED1 { 10^-222 hi },
    $120CEAFBAFD80E85 { 10^-221 hi },
    $124212DD4DE70913 { 10^-220 hi },
    $12769794A160CB58 { 10^-219 hi },
    $12AC3D79C9B8FE2E { 10^-218 hi },
    $12E1A66C1E139EDD { 10^-217 hi },
    $1316100725988694 { 10^-216 hi },
    $134B9408EEFEA839 { 10^-215 hi },
    $13813C85955F2923 { 10^-214 hi },
    $13B58BA6FAB6F36C { 10^-213 hi },
    $13EAEE90B964B047 { 10^-212 hi },
    $1420D51A73DEEE2D { 10^-211 hi },
    $14550A6110D6A9B8 { 10^-210 hi },
    $148A4CF9550C5426 { 10^-209 hi },
    $14C0701BD527B498 { 10^-208 hi },
    $14F48C22CA71A1BD { 10^-207 hi },
    $1529AF2B7D0E0A2D { 10^-206 hi },
    $15600D7B2E28C65C { 10^-205 hi },
    $159410D9F9B2F7F3 { 10^-204 hi },
    $15C91510781FB5F0 { 10^-203 hi },
    $15FF5A549627A36C { 10^-202 hi },
    $16339874DDD8C623 { 10^-201 hi },
    $16687E92154EF7AC { 10^-200 hi },
    $169E9E369AA2B597 { 10^-199 hi },
    $16D322E220A5B17E { 10^-198 hi },
    $1707EB9AA8CF1DDE { 10^-197 hi },
    $173DE6815302E556 { 10^-196 hi },
    $1772B010D3E1CF56 { 10^-195 hi },
    $17A75C1508DA432B { 10^-194 hi },
    $17DD331A4B10D3F6 { 10^-193 hi },
    $18123FF06EEA847A { 10^-192 hi },
    $1846CFEC8AA52598 { 10^-191 hi },
    $187C83E7AD4E6EFE { 10^-190 hi },
    $18B1D270CC51055F { 10^-189 hi },
    $18E6470CFF6546B6 { 10^-188 hi },
    $191BD8D03F3E9864 { 10^-187 hi },
    $1951678227871F3E { 10^-186 hi },
    $1985C162B168E70E { 10^-185 hi },
    $19BB31BB5DC320D2 { 10^-184 hi },
    $19F0FF151A99F483 { 10^-183 hi },
    $1A253EDA614071A4 { 10^-182 hi },
    $1A5A8E90F9908E0D { 10^-181 hi },
    $1A90991A9BFA58C8 { 10^-180 hi },
    $1AC4BF6142F8EEFA { 10^-179 hi },
    $1AF9EF3993B72AB8 { 10^-178 hi },
    $1B303583FC527AB3 { 10^-177 hi },
    $1B6442E4FB671960 { 10^-176 hi },
    $1B99539E3A40DFB8 { 10^-175 hi },
    $1BCFA885C8D117A6 { 10^-174 hi },
    $1C03C9539D82AEC8 { 10^-173 hi },
    $1C38BBA884E35A7A { 10^-172 hi },
    $1C6EEA92A61C3118 { 10^-171 hi },
    $1CA3529BA7D19EAF { 10^-170 hi },
    $1CD8274291C6065B { 10^-169 hi },
    $1D0E3113363787F2 { 10^-168 hi },
    $1D42DEAC01E2B4F7 { 10^-167 hi },
    $1D779657025B6235 { 10^-166 hi },
    $1DAD7BECC2F23AC2 { 10^-165 hi },
    $1DE26D73F9D764B9 { 10^-164 hi },
    $1E1708D0F84D3DE7 { 10^-163 hi },
    $1E4CCB0536608D61 { 10^-162 hi },
    $1E81FEE341FC585D { 10^-161 hi },
    $1EB67E9C127B6E74 { 10^-160 hi },
    $1EEC1E43171A4A11 { 10^-159 hi },
    $1F2192E9EE706E4B { 10^-158 hi },
    $1F55F7A46A0C89DD { 10^-157 hi },
    $1F8B758D848FAC55 { 10^-156 hi },
    $1FC1297872D9CBB5 { 10^-155 hi },
    $1FF573D68F903EA2 { 10^-154 hi },
    $202AD0CC33744E4B { 10^-153 hi },
    $2060C27FA028B0EF { 10^-152 hi },
    $2094F31F8832DD2A { 10^-151 hi },
    $20CA2FE76A3F9475 { 10^-150 hi },
    $21005DF0A267BCC9 { 10^-149 hi },
    $2134756CCB01ABFB { 10^-148 hi },
    $216992C7FDC216FA { 10^-147 hi },
    $219FF779FD329CB9 { 10^-146 hi },
    $21D3FAAC3E3FA1F3 { 10^-145 hi },
    $2208F9574DCF8A70 { 10^-144 hi },
    $223F37AD21436D0C { 10^-143 hi },
    $227382CC34CA2428 { 10^-142 hi },
    $22A8637F41FCAD32 { 10^-141 hi },
    $22DE7C5F127BD87E { 10^-140 hi },
    $23130DBB6B8D674F { 10^-139 hi },
    $2347D12A4670C123 { 10^-138 hi },
    $237DC574D80CF16B { 10^-137 hi },
    $23B29B69070816E3 { 10^-136 hi },
    $23E7424348CA1C9C { 10^-135 hi },
    $241D12D41AFCA3C3 { 10^-134 hi },
    $24522BC490DDE65A { 10^-133 hi },
    $2486B6B5B5155FF0 { 10^-132 hi },
    $24BC6463225AB7EC { 10^-131 hi },
    $24F1BEBDF578B2F4 { 10^-130 hi },
    $25262E6D72D6DFB0 { 10^-129 hi },
    $255BBA08CF8C979D { 10^-128 hi },
    $2591544581B7DEC2 { 10^-127 hi },
    $25C5A956E225D672 { 10^-126 hi },
    $25FB13AC9AAF4C0F { 10^-125 hi },
    $2630EC4BE0AD8F89 { 10^-124 hi },
    $2665275ED8D8F36C { 10^-123 hi },
    $269A71368F0F3047 { 10^-122 hi },
    $26D086C219697E2C { 10^-121 hi },
    $2704A8729FC3DDB7 { 10^-120 hi },
    $2739D28F47B4D525 { 10^-119 hi },
    $277023998CD10537 { 10^-118 hi },
    $27A42C7FF0054685 { 10^-117 hi },
    $27D9379FEC069826 { 10^-116 hi },
    $280F8587E7083E30 { 10^-115 hi },
    $2843B374F06526DE { 10^-114 hi },
    $2878A0522C7E7095 { 10^-113 hi },
    $28AEC866B79E0CBA { 10^-112 hi },
    $28E33D4032C2C7F5 { 10^-111 hi },
    $29180C903F7379F2 { 10^-110 hi },
    $294E0FB44F50586E { 10^-109 hi },
    $2982C9D0B1923745 { 10^-108 hi },
    $29B77C44DDF6C516 { 10^-107 hi },
    $29ED5B561574765B { 10^-106 hi },
    $2A225915CD68C9F9 { 10^-105 hi },
    $2A56EF5B40C2FC77 { 10^-104 hi },
    $2A8CAB3210F3BB95 { 10^-103 hi },
    $2AC1EAFF4A98553D { 10^-102 hi },
    $2AF665BF1D3E6A8D { 10^-101 hi },
    $2B2BFF2EE48E0530 { 10^-100 hi },
    $2B617F7D4ED8C33E { 10^-99 hi },
    $2B95DF5CA28EF40D { 10^-98 hi },
    $2BCB5733CB32B111 { 10^-97 hi },
    $2C0116805EFFAEAA { 10^-96 hi },
    $2C355C2076BF9A55 { 10^-95 hi },
    $2C6AB328946F80EA { 10^-94 hi },
    $2CA0AFF95CC5B092 { 10^-93 hi },
    $2CD4DBF7B3F71CB7 { 10^-92 hi },
    $2D0A12F5A0F4E3E5 { 10^-91 hi },
    $2D404BD984990E6F { 10^-90 hi },
    $2D745ECFE5BF520B { 10^-89 hi },
    $2DA97683DF2F268D { 10^-88 hi },
    $2DDFD424D6FAF031 { 10^-87 hi },
    $2E13E497065CD61F { 10^-86 hi },
    $2E48DDBCC7F40BA6 { 10^-85 hi },
    $2E7F152BF9F10E90 { 10^-84 hi },
    $2EB36D3B7C36A91A { 10^-83 hi },
    $2EE8488A5B445360 { 10^-82 hi },
    $2F1E5AACF2156838 { 10^-81 hi },
    $2F52F8AC174D6123 { 10^-80 hi },
    $2F87B6D71D20B96C { 10^-79 hi },
    $2FBDA48CE468E7C7 { 10^-78 hi },
    $2FF286D80EC190DC { 10^-77 hi },
    $3027288E1271F513 { 10^-76 hi },
    $305CF2B1970E7258 { 10^-75 hi },
    $309217AEFE690777 { 10^-74 hi },
    $30C69D9ABE034955 { 10^-73 hi },
    $30FC45016D841BAA { 10^-72 hi },
    $3131AB20E472914A { 10^-71 hi },
    $316615E91D8F359D { 10^-70 hi },
    $319B9B6364F30304 { 10^-69 hi },
    $31D1411E1F17E1E3 { 10^-68 hi },
    $32059165A6DDDA5B { 10^-67 hi },
    $323AF5BF109550F2 { 10^-66 hi },
    $3270D9976A5D5297 { 10^-65 hi },
    $32A50FFD44F4A73D { 10^-64 hi },
    $32DA53FC9631D10D { 10^-63 hi },
    $3310747DDDDF22A8 { 10^-62 hi },
    $3344919D5556EB52 { 10^-61 hi },
    $3379B604AAACA626 { 10^-60 hi },
    $33B011C2EAABE7D8 { 10^-59 hi },
    $33E41633A556E1CE { 10^-58 hi },
    $34191BC08EAC9A41 { 10^-57 hi },
    $344F62B0B257C0D2 { 10^-56 hi },
    $34839DAE6F76D883 { 10^-55 hi },
    $34B8851A0B548EA4 { 10^-54 hi },
    $34EEA6608E29B24D { 10^-53 hi },
    $352327FC58DA0F70 { 10^-52 hi },
    $3557F1FB6F10934C { 10^-51 hi },
    $358DEE7A4AD4B81F { 10^-50 hi },
    $35C2B50C6EC4F313 { 10^-49 hi },
    $35F7624F8A762FD8 { 10^-48 hi },
    $362D3AE36D13BBCE { 10^-47 hi },
    $366244CE242C5561 { 10^-46 hi },
    $3696D601AD376AB9 { 10^-45 hi },
    $36CC8B8218854567 { 10^-44 hi },
    $3701D7314F534B61 { 10^-43 hi },
    $37364CFDA3281E39 { 10^-42 hi },
    $376BE03D0BF225C7 { 10^-41 hi },
    $37A16C262777579C { 10^-40 hi },
    $37D5C72FB1552D83 { 10^-39 hi },
    $380B38FB9DAA78E4 { 10^-38 hi },
    $3841039D428A8B8F { 10^-37 hi },
    $38754484932D2E72 { 10^-36 hi },
    $38AA95A5B7F87A0F { 10^-35 hi },
    $38E09D8792FB4C49 { 10^-34 hi },
    $3914C4E977BA1F5C { 10^-33 hi },
    $3949F623D5A8A733 { 10^-32 hi },
    $398039D665896880 { 10^-31 hi },
    $39B4484BFEEBC2A0 { 10^-30 hi },
    $39E95A5EFEA6B347 { 10^-29 hi },
    $3A1FB0F6BE506019 { 10^-28 hi },
    $3A53CE9A36F23C10 { 10^-27 hi },
    $3A88C240C4AECB14 { 10^-26 hi },
    $3ABEF2D0F5DA7DD9 { 10^-25 hi },
    $3AF357C299A88EA7 { 10^-24 hi },
    $3B282DB34012B251 { 10^-23 hi },
    $3B5E392010175EE6 { 10^-22 hi },
    $3B92E3B40A0E9B4F { 10^-21 hi },
    $3BC79CA10C924223 { 10^-20 hi },
    $3BFD83C94FB6D2AC { 10^-19 hi },
    $3C32725DD1D243AC { 10^-18 hi },
    $3C670EF54646D497 { 10^-17 hi },
    $3C9CD2B297D889BC { 10^-16 hi },
    $3CD203AF9EE75616 { 10^-15 hi },
    $3D06849B86A12B9B { 10^-14 hi },
    $3D3C25C268497682 { 10^-13 hi },
    $3D719799812DEA11 { 10^-12 hi },
    $3DA5FD7FE1796495 { 10^-11 hi },
    $3DDB7CDFD9D7BDBB { 10^-10 hi },
    $3E112E0BE826D695 { 10^-9 hi },
    $3E45798EE2308C3A { 10^-8 hi },
    $3E7AD7F29ABCAF48 { 10^-7 hi },
    $3EB0C6F7A0B5ED8D { 10^-6 hi },
    $3EE4F8B588E368F1 { 10^-5 hi },
    $3F1A36E2EB1C432D { 10^-4 hi },
    $3F50624DD2F1A9FC { 10^-3 hi },
    $3F847AE147AE147B { 10^-2 hi },
    $3FB999999999999A { 10^-1 hi },
    $3FF0000000000000 { 10^0 hi },
    $4024000000000000 { 10^1 hi },
    $4059000000000000 { 10^2 hi },
    $408F400000000000 { 10^3 hi },
    $40C3880000000000 { 10^4 hi },
    $40F86A0000000000 { 10^5 hi },
    $412E848000000000 { 10^6 hi },
    $416312D000000000 { 10^7 hi },
    $4197D78400000000 { 10^8 hi },
    $41CDCD6500000000 { 10^9 hi },
    $4202A05F20000000 { 10^10 hi },
    $42374876E8000000 { 10^11 hi },
    $426D1A94A2000000 { 10^12 hi },
    $42A2309CE5400000 { 10^13 hi },
    $42D6BCC41E900000 { 10^14 hi },
    $430C6BF526340000 { 10^15 hi },
    $4341C37937E08000 { 10^16 hi },
    $4376345785D8A000 { 10^17 hi },
    $43ABC16D674EC800 { 10^18 hi },
    $43E158E460913D00 { 10^19 hi },
    $4415AF1D78B58C40 { 10^20 hi },
    $444B1AE4D6E2EF50 { 10^21 hi },
    $4480F0CF064DD592 { 10^22 hi },
    $44B52D02C7E14AF6 { 10^23 hi },
    $44EA784379D99DB4 { 10^24 hi },
    $45208B2A2C280291 { 10^25 hi },
    $4554ADF4B7320335 { 10^26 hi },
    $4589D971E4FE8402 { 10^27 hi },
    $45C027E72F1F1281 { 10^28 hi },
    $45F431E0FAE6D721 { 10^29 hi },
    $46293E5939A08CEA { 10^30 hi },
    $465F8DEF8808B024 { 10^31 hi },
    $4693B8B5B5056E17 { 10^32 hi },
    $46C8A6E32246C99C { 10^33 hi },
    $46FED09BEAD87C03 { 10^34 hi },
    $4733426172C74D82 { 10^35 hi },
    $476812F9CF7920E3 { 10^36 hi },
    $479E17B84357691B { 10^37 hi },
    $47D2CED32A16A1B1 { 10^38 hi },
    $48078287F49C4A1D { 10^39 hi },
    $483D6329F1C35CA5 { 10^40 hi },
    $48725DFA371A19E7 { 10^41 hi },
    $48A6F578C4E0A061 { 10^42 hi },
    $48DCB2D6F618C879 { 10^43 hi },
    $4911EFC659CF7D4C { 10^44 hi },
    $49466BB7F0435C9E { 10^45 hi },
    $497C06A5EC5433C6 { 10^46 hi },
    $49B18427B3B4A05C { 10^47 hi },
    $49E5E531A0A1C873 { 10^48 hi },
    $4A1B5E7E08CA3A8F { 10^49 hi },
    $4A511B0EC57E649A { 10^50 hi },
    $4A8561D276DDFDC0 { 10^51 hi },
    $4ABABA4714957D30 { 10^52 hi },
    $4AF0B46C6CDD6E3E { 10^53 hi },
    $4B24E1878814C9CE { 10^54 hi },
    $4B5A19E96A19FC41 { 10^55 hi },
    $4B905031E2503DA9 { 10^56 hi },
    $4BC4643E5AE44D13 { 10^57 hi },
    $4BF97D4DF19D6057 { 10^58 hi },
    $4C2FDCA16E04B86D { 10^59 hi },
    $4C63E9E4E4C2F344 { 10^60 hi },
    $4C98E45E1DF3B015 { 10^61 hi },
    $4CCF1D75A5709C1B { 10^62 hi },
    $4D03726987666191 { 10^63 hi },
    $4D384F03E93FF9F5 { 10^64 hi },
    $4D6E62C4E38FF872 { 10^65 hi },
    $4DA2FDBB0E39FB47 { 10^66 hi },
    $4DD7BD29D1C87A19 { 10^67 hi },
    $4E0DAC74463A989F { 10^68 hi },
    $4E428BC8ABE49F64 { 10^69 hi },
    $4E772EBAD6DDC73D { 10^70 hi },
    $4EACFA698C95390C { 10^71 hi },
    $4EE21C81F7DD43A7 { 10^72 hi },
    $4F16A3A275D49491 { 10^73 hi },
    $4F4C4C8B1349B9B5 { 10^74 hi },
    $4F81AFD6EC0E1411 { 10^75 hi },
    $4FB61BCCA7119916 { 10^76 hi },
    $4FEBA2BFD0D5FF5B { 10^77 hi },
    $502145B7E285BF99 { 10^78 hi },
    $50559725DB272F7F { 10^79 hi },
    $508AFCEF51F0FB5F { 10^80 hi },
    $50C0DE1593369D1B { 10^81 hi },
    $50F5159AF8044462 { 10^82 hi },
    $512A5B01B605557B { 10^83 hi },
    $516078E111C3556D { 10^84 hi },
    $5194971956342AC8 { 10^85 hi },
    $51C9BCDFABC1357A { 10^86 hi },
    $5200160BCB58C16C { 10^87 hi },
    $52341B8EBE2EF1C7 { 10^88 hi },
    $526922726DBAAE39 { 10^89 hi },
    $529F6B0F092959C7 { 10^90 hi },
    $52D3A2E965B9D81D { 10^91 hi },
    $53088BA3BF284E24 { 10^92 hi },
    $533EAE8CAEF261AD { 10^93 hi },
    $53732D17ED577D0C { 10^94 hi },
    $53A7F85DE8AD5C4F { 10^95 hi },
    $53DDF67562D8B363 { 10^96 hi },
    $5412BA095DC7701E { 10^97 hi },
    $5447688BB5394C25 { 10^98 hi },
    $547D42AEA2879F2E { 10^99 hi },
    $54B249AD2594C37D { 10^100 hi },
    $54E6DC186EF9F45C { 10^101 hi },
    $551C931E8AB87173 { 10^102 hi },
    $5551DBF316B346E8 { 10^103 hi },
    $558652EFDC6018A2 { 10^104 hi },
    $55BBE7ABD3781ECA { 10^105 hi },
    $55F170CB642B133F { 10^106 hi },
    $5625CCFE3D35D80E { 10^107 hi },
    $565B403DCC834E12 { 10^108 hi },
    $569108269FD210CB { 10^109 hi },
    $56C54A3047C694FE { 10^110 hi },
    $56FA9CBC59B83A3D { 10^111 hi },
    $5730A1F5B8132466 { 10^112 hi },
    $5764CA732617ED80 { 10^113 hi },
    $5799FD0FEF9DE8E0 { 10^114 hi },
    $57D03E29F5C2B18C { 10^115 hi },
    $58044DB473335DEF { 10^116 hi },
    $583961219000356B { 10^117 hi },
    $586FB969F40042C5 { 10^118 hi },
    $58A3D3E2388029BB { 10^119 hi },
    $58D8C8DAC6A0342A { 10^120 hi },
    $590EFB1178484135 { 10^121 hi },
    $59435CEAEB2D28C1 { 10^122 hi },
    $59783425A5F872F1 { 10^123 hi },
    $59AE412F0F768FAD { 10^124 hi },
    $59E2E8BD69AA19CC { 10^125 hi },
    $5A17A2ECC414A03F { 10^126 hi },
    $5A4D8BA7F519C84F { 10^127 hi },
    $5A827748F9301D32 { 10^128 hi },
    $5AB7151B377C247E { 10^129 hi },
    $5AECDA62055B2D9E { 10^130 hi },
    $5B22087D4358FC82 { 10^131 hi },
    $5B568A9C942F3BA3 { 10^132 hi },
    $5B8C2D43B93B0A8C { 10^133 hi },
    $5BC19C4A53C4E697 { 10^134 hi },
    $5BF6035CE8B6203D { 10^135 hi },
    $5C2B843422E3A84D { 10^136 hi },
    $5C6132A095CE4930 { 10^137 hi },
    $5C957F48BB41DB7C { 10^138 hi },
    $5CCADF1AEA12525B { 10^139 hi },
    $5D00CB70D24B7379 { 10^140 hi },
    $5D34FE4D06DE5057 { 10^141 hi },
    $5D6A3DE04895E46D { 10^142 hi },
    $5DA066AC2D5DAEC4 { 10^143 hi },
    $5DD4805738B51A75 { 10^144 hi },
    $5E09A06D06E26112 { 10^145 hi },
    $5E400444244D7CAB { 10^146 hi },
    $5E7405552D60DBD6 { 10^147 hi },
    $5EA906AA78B912CC { 10^148 hi },
    $5EDF485516E7577F { 10^149 hi },
    $5F138D352E5096AF { 10^150 hi },
    $5F48708279E4BC5B { 10^151 hi },
    $5F7E8CA3185DEB72 { 10^152 hi },
    $5FB317E5EF3AB327 { 10^153 hi },
    $5FE7DDDF6B095FF1 { 10^154 hi },
    $601DD55745CBB7ED { 10^155 hi },
    $6052A5568B9F52F4 { 10^156 hi },
    $60874EAC2E8727B1 { 10^157 hi },
    $60BD22573A28F19D { 10^158 hi },
    $60F2357684599702 { 10^159 hi },
    $6126C2D4256FFCC3 { 10^160 hi },
    $615C73892ECBFBF4 { 10^161 hi },
    $6191C835BD3F7D78 { 10^162 hi },
    $61C63A432C8F5CD6 { 10^163 hi },
    $61FBC8D3F7B3340C { 10^164 hi },
    $62315D847AD00087 { 10^165 hi },
    $6265B4E5998400A9 { 10^166 hi },
    $629B221EFFE500D4 { 10^167 hi },
    $62D0F5535FEF2084 { 10^168 hi },
    $630532A837EAE8A5 { 10^169 hi },
    $633A7F5245E5A2CF { 10^170 hi },
    $63708F936BAF85C1 { 10^171 hi },
    $63A4B378469B6732 { 10^172 hi },
    $63D9E056584240FE { 10^173 hi },
    $64102C35F729689F { 10^174 hi },
    $6444374374F3C2C6 { 10^175 hi },
    $647945145230B378 { 10^176 hi },
    $64AF965966BCE056 { 10^177 hi },
    $64E3BDF7E0360C36 { 10^178 hi },
    $6518AD75D8438F43 { 10^179 hi },
    $654ED8D34E547314 { 10^180 hi },
    $6583478410F4C7EC { 10^181 hi },
    $65B819651531F9E8 { 10^182 hi },
    $65EE1FBE5A7E7861 { 10^183 hi },
    $6622D3D6F88F0B3D { 10^184 hi },
    $665788CCB6B2CE0C { 10^185 hi },
    $668D6AFFE45F818F { 10^186 hi },
    $66C262DFEEBBB0F9 { 10^187 hi },
    $66F6FB97EA6A9D38 { 10^188 hi },
    $672CBA7DE5054486 { 10^189 hi },
    $6761F48EAF234AD4 { 10^190 hi },
    $679671B25AEC1D89 { 10^191 hi },
    $67CC0E1EF1A724EB { 10^192 hi },
    $680188D357087713 { 10^193 hi },
    $6835EB082CCA94D7 { 10^194 hi },
    $686B65CA37FD3A0D { 10^195 hi },
    $68A11F9E62FE4448 { 10^196 hi },
    $68D56785FBBDD55A { 10^197 hi },
    $690AC1677AAD4AB1 { 10^198 hi },
    $6940B8E0ACAC4EAF { 10^199 hi },
    $6974E718D7D7625A { 10^200 hi },
    $69AA20DF0DCD3AF1 { 10^201 hi },
    $69E0548B68A044D6 { 10^202 hi },
    $6A1469AE42C8560C { 10^203 hi },
    $6A498419D37A6B8F { 10^204 hi },
    $6A7FE52048590673 { 10^205 hi },
    $6AB3EF342D37A408 { 10^206 hi },
    $6AE8EB0138858D0A { 10^207 hi },
    $6B1F25C186A6F04C { 10^208 hi },
    $6B537798F4285630 { 10^209 hi },
    $6B88557F31326BBB { 10^210 hi },
    $6BBE6ADEFD7F06AA { 10^211 hi },
    $6BF302CB5E6F642A { 10^212 hi },
    $6C27C37E360B3D35 { 10^213 hi },
    $6C5DB45DC38E0C82 { 10^214 hi },
    $6C9290BA9A38C7D1 { 10^215 hi },
    $6CC734E940C6F9C6 { 10^216 hi },
    $6CFD022390F8B837 { 10^217 hi },
    $6D3221563A9B7323 { 10^218 hi },
    $6D66A9ABC9424FEB { 10^219 hi },
    $6D9C5416BB92E3E6 { 10^220 hi },
    $6DD1B48E353BCE70 { 10^221 hi },
    $6E0621B1C28AC20C { 10^222 hi },
    $6E3BAA1E332D728F { 10^223 hi },
    $6E714A52DFFC6799 { 10^224 hi },
    $6EA59CE797FB817F { 10^225 hi },
    $6EDB04217DFA61DF { 10^226 hi },
    $6F10E294EEBC7D2C { 10^227 hi },
    $6F451B3A2A6B9C76 { 10^228 hi },
    $6F7A6208B5068394 { 10^229 hi },
    $6FB07D457124123D { 10^230 hi },
    $6FE49C96CD6D16CC { 10^231 hi },
    $7019C3BC80C85C7F { 10^232 hi },
    $70501A55D07D39CF { 10^233 hi },
    $708420EB449C8843 { 10^234 hi },
    $70B9292615C3AA54 { 10^235 hi },
    $70EF736F9B3494E9 { 10^236 hi },
    $7123A825C100DD11 { 10^237 hi },
    $7158922F31411456 { 10^238 hi },
    $718EB6BAFD91596B { 10^239 hi },
    $71C33234DE7AD7E3 { 10^240 hi },
    $71F7FEC216198DDC { 10^241 hi },
    $722DFE729B9FF153 { 10^242 hi },
    $7262BF07A143F6D4 { 10^243 hi },
    $72976EC98994F489 { 10^244 hi },
    $72CD4A7BEBFA31AB { 10^245 hi },
    $73024E8D737C5F0B { 10^246 hi },
    $7336E230D05B76CD { 10^247 hi },
    $736C9ABD04725481 { 10^248 hi },
    $73A1E0B622C774D0 { 10^249 hi },
    $73D658E3AB795204 { 10^250 hi },
    $740BEF1C9657A686 { 10^251 hi },
    $74417571DDF6C814 { 10^252 hi },
    $7475D2CE55747A18 { 10^253 hi },
    $74AB4781EAD1989E { 10^254 hi },
    $74E10CB132C2FF63 { 10^255 hi },
    $75154FDD7F73BF3C { 10^256 hi },
    $754AA3D4DF50AF0B { 10^257 hi },
    $7580A6650B926D67 { 10^258 hi },
    $75B4CFFE4E7708C0 { 10^259 hi },
    $75EA03FDE214CAF1 { 10^260 hi },
    $7620427EAD4CFED6 { 10^261 hi },
    $7654531E58A03E8C { 10^262 hi },
    $768967E5EEC84E2F { 10^263 hi },
    $76BFC1DF6A7A61BB { 10^264 hi },
    $76F3D92BA28C7D15 { 10^265 hi },
    $7728CF768B2F9C5A { 10^266 hi },
    $775F03542DFB8370 { 10^267 hi },
    $779362149CBD3226 { 10^268 hi },
    $77C83A99C3EC7EB0 { 10^269 hi },
    $77FE494034E79E5C { 10^270 hi },
    $7832EDC82110C2F9 { 10^271 hi },
    $7867A93A2954F3B8 { 10^272 hi },
    $789D9388B3AA30A5 { 10^273 hi },
    $78D27C35704A5E67 { 10^274 hi },
    $79071B42CC5CF601 { 10^275 hi },
    $793CE2137F743382 { 10^276 hi },
    $79720D4C2FA8A031 { 10^277 hi },
    $79A6909F3B92C83D { 10^278 hi },
    $79DC34C70A777A4D { 10^279 hi },
    $7A11A0FC668AAC70 { 10^280 hi },
    $7A46093B802D578C { 10^281 hi },
    $7A7B8B8A6038AD6F { 10^282 hi },
    $7AB137367C236C65 { 10^283 hi },
    $7AE585041B2C477F { 10^284 hi },
    $7B1AE64521F7595E { 10^285 hi },
    $7B50CFEB353A97DB { 10^286 hi },
    $7B8503E602893DD2 { 10^287 hi },
    $7BBA44DF832B8D46 { 10^288 hi },
    $7BF06B0BB1FB384C { 10^289 hi },
    $7C2485CE9E7A065F { 10^290 hi },
    $7C59A742461887F6 { 10^291 hi },
    $7C9008896BCF54FA { 10^292 hi },
    $7CC40AABC6C32A38 { 10^293 hi },
    $7CF90D56B873F4C7 { 10^294 hi },
    $7D2F50AC6690F1F8 { 10^295 hi },
    $7D63926BC01A973B { 10^296 hi },
    $7D987706B0213D0A { 10^297 hi },
    $7DCE94C85C298C4C { 10^298 hi },
    $7E031CFD3999F7B0 { 10^299 hi },
    $7E37E43C8800759C { 10^300 hi },
    $7E6DDD4BAA009303 { 10^301 hi },
    $7EA2AA4F4A405BE2 { 10^302 hi },
    $7ED754E31CD072DA { 10^303 hi },
    $7F0D2A1BE4048F90 { 10^304 hi },
    $7F423A516E82D9BA { 10^305 hi },
    $7F76C8E5CA239029 { 10^306 hi },
    $7FAC7B1F3CAC7433 { 10^307 hi },
    $7FE1CCF385EBC8A0 { 10^308 hi }
  );
  TENL: array[-307..308] of Int64 = (
                        2 { 10^-307 lo },
     -9223372036854775802 { 10^-306 lo },
                        8 { 10^-305 lo },
                      587 { 10^-304 lo },
                    14064 { 10^-303 lo },
                    75109 { 10^-302 lo },
     -9223372036853429746 { 10^-301 lo },
     -9223372036849703791 { 10^-300 lo },
                 16388697 { 10^-299 lo },
               1774499711 { 10^-298 lo },
     -9223372028829969139 { 10^-297 lo },
     -9223372025326185851 { 10^-296 lo },
     -9223370822057248464 { 10^-295 lo },
     -9223368684972524575 { 10^-294 lo },
     -9223268149288085813 { 10^-293 lo },
     -9222333161187875860 { 10^-292 lo },
         7625641840482501 { 10^-291 lo },
     -9196612865613483899 { 10^-290 lo },
     -9193158972077837673 { 10^-289 lo },
     -9168126487163816472 { 10^-288 lo },
     -9159567556478990653 { 10^-287 lo },
     -9139021190299626438 { 10^-286 lo },
     -9121676111810153308 { 10^-285 lo },
     -9110995612505390181 { 10^-284 lo },
       129611968246199743 { 10^-283 lo },
     -9085782995664799326 { 10^-282 lo },
     -9070526033783629814 { 10^-281 lo },
       172912005781421181 { 10^-280 lo },
     -9033641515108289998 { 10^-279 lo },
       205315511206043970 { 10^-278 lo },
       216051202608657188 { 10^-277 lo },
     -8985206212962208763 { 10^-276 lo },
       250605974766649082 { 10^-275 lo },
       261466072743550649 { 10^-274 lo },
     -8940369019256394547 { 10^-273 lo },
       295890474250217472 { 10^-272 lo },
       306812698029584896 { 10^-271 lo },
     -8900948667801431680 { 10^-270 lo },
       337791449719276816 { 10^-269 lo },
       352433517924853332 { 10^-268 lo },
       360918037850841043 { 10^-267 lo },
       375712253555095495 { 10^-266 lo },
       390827323464885689 { 10^-265 lo },
     -8819067565059682087 { 10^-264 lo },
     -8804048555770133881 { 10^-263 lo },
     -8789289678046383319 { 10^-262 lo },
       450963315984297990 { 10^-261 lo },
       471566206793168388 { 10^-260 lo },
     -8732785731077775810 { 10^-259 lo },
       502533925459790387 { 10^-258 lo },
       513240875133344128 { 10^-257 lo },
       527941129817382896 { 10^-256 lo },
     -8688039948645490607 { 10^-255 lo },
       566796449001265530 { 10^-254 lo },
     -8643838104678395864 { 10^-253 lo },
       594011375692237774 { 10^-252 lo },
     -8623233848612830595 { 10^-251 lo },
     -8600105589081072441 { 10^-250 lo },
     -8585026465492974599 { 10^-249 lo },
       646928686026003986 { 10^-248 lo },
     -8561607616050813847 { 10^-247 lo },
       681815119974302879 { 10^-246 lo },
       699728127346696931 { 10^-245 lo },
       714782372411718556 { 10^-244 lo },
       712179856604746779 { 10^-243 lo },
       739389513124320548 { 10^-242 lo },
       754226005472164461 { 10^-241 lo },
       769393921186441481 { 10^-240 lo },
     -8433327747487827155 { 10^-239 lo },
       791504387155570747 { 10^-238 lo },
       806564516167638565 { 10^-237 lo },
     -8391744787821137259 { 10^-236 lo },
       846348282669347014 { 10^-235 lo },
       861108149186915964 { 10^-234 lo },
       875975003065657883 { 10^-233 lo },
     -8335631054736987298 { 10^-232 lo },
       897138486845911956 { 10^-231 lo },
     -8301829663439622174 { 10^-230 lo },
     -8284305333513558547 { 10^-229 lo },
     -8274072962800271663 { 10^-228 lo },
       967748299553233086 { 10^-227 lo },
       984833905780156278 { 10^-226 lo },
       995729301695086932 { 10^-225 lo },
     -8217901980252988242 { 10^-224 lo },
      1023276377962012179 { 10^-223 lo },
     -8181951212164995788 { 10^-222 lo },
     -8173561846573146878 { 10^-221 lo },
      1059419019484993404 { 10^-220 lo },
     -8139747247496079191 { 10^-219 lo },
     -8124457028393027734 { 10^-218 lo },
     -8103641642385194334 { 10^-217 lo },
     -8092799121503186101 { 10^-216 lo },
     -8078120070493833187 { 10^-215 lo },
      1165033315405014254 { 10^-214 lo },
      1175942567452454441 { 10^-213 lo },
      1190705032418597299 { 10^-212 lo },
     -8013563393791025168 { 10^-211 lo },
     -8002719308897327124 { 10^-210 lo },
     -7988038302873361945 { 10^-209 lo },
     -7967714443127485136 { 10^-208 lo },
      1268821672991141764 { 10^-207 lo },
     -7945869787490580169 { 10^-206 lo },
     -7952232640725206967 { 10^-205 lo },
     -7937314866633480612 { 10^-204 lo },
     -7899176346485036032 { 10^-203 lo },
     -7884505297715378432 { 10^-202 lo },
      1356461306567308192 { 10^-201 lo },
      1364476181109834273 { 10^-200 lo },
      1379155819642573141 { 10^-199 lo },
      1404608138080463210 { 10^-198 lo },
      1407051955071307540 { 10^-197 lo },
     -7793237502525671606 { 10^-196 lo },
     -7773343398918829426 { 10^-195 lo },
     -7769361567600872250 { 10^-194 lo },
     -7748084024683381634 { 10^-193 lo },
     -7728233976664758833 { 10^-192 lo },
     -7723958441425339126 { 10^-191 lo },
     -7709214837454533082 { 10^-190 lo },
     -7685941025099209620 { 10^-189 lo },
      1550486548008194681 { 10^-188 lo },
     -7666864347120933982 { 10^-187 lo },
      1584131222284665967 { 10^-186 lo },
      1582915802591669330 { 10^-185 lo },
     -7612123359789262573 { 10^-184 lo },
     -7612476066332640576 { 10^-183 lo },
     -7583466889431115369 { 10^-182 lo },
     -7568681469876961283 { 10^-181 lo },
     -7559121814836641800 { 10^-180 lo },
     -7543879626168082442 { 10^-179 lo },
      1699655362604722691 { 10^-178 lo },
      1714741637165188228 { 10^-177 lo },
      1713580448653192488 { 10^-176 lo },
      1728770295005247602 { 10^-175 lo },
      1743636479508585287 { 10^-174 lo },
     -7449773631068233795 { 10^-173 lo },
     -7434829489505242154 { 10^-172 lo },
      1797654312925896297 { 10^-171 lo },
      1812470527116117507 { 10^-170 lo },
     -7394486411352826818 { 10^-169 lo },
     -7373816329372311129 { 10^-168 lo },
     -7378349379204833017 { 10^-167 lo },
     -7345075913738045366 { 10^-166 lo },
     -7339392000097740429 { 10^-165 lo },
      1907657806960234508 { 10^-164 lo },
      1927498768518380039 { 10^-163 lo },
      1938747299587758217 { 10^-162 lo },
     -7272685023255879340 { 10^-161 lo },
      1959746700351171757 { 10^-160 lo },
      1974553614751377368 { 10^-159 lo },
     -7222534592737101370 { 10^-158 lo },
      2014937721198671816 { 10^-157 lo },
     -7195660364522599866 { 10^-156 lo },
     -7187267205058365010 { 10^-155 lo },
      2055031654800618483 { 10^-154 lo },
     -7150896248853878904 { 10^-153 lo },
     -7132626385169901387 { 10^-152 lo },
      2105214444971344158 { 10^-151 lo },
     -7118007202629126953 { 10^-150 lo },
      2128112808786557821 { 10^-149 lo },
      2150378704847931031 { 10^-148 lo },
      2160376628177293434 { 10^-147 lo },
     -7048696225447830680 { 10^-146 lo },
      2197369545894944623 { 10^-145 lo },
      2208531776897906507 { 10^-144 lo },
      2223610465558451486 { 10^-143 lo },
     -6985875133912107622 { 10^-142 lo },
     -6970941393175477888 { 10^-141 lo },
      2261481737768549439 { 10^-140 lo },
     -6943283478562891175 { 10^-139 lo },
     -6922929510352207753 { 10^-138 lo },
      2308085216923082454 { 10^-137 lo },
     -6917433106598114391 { 10^-136 lo },
     -6881320561845932811 { 10^-135 lo },
     -6866638945862932430 { 10^-134 lo },
     -6848568029603931873 { 10^-133 lo },
      2379872784373400165 { 10^-132 lo },
      2395002528442798846 { 10^-131 lo },
     -6801700238257017080 { 10^-130 lo },
      2435776599753213238 { 10^-129 lo },
     -6774827141061129859 { 10^-128 lo },
     -6763921467366679588 { 10^-127 lo },
      2478365411824158358 { 10^-126 lo },
     -6739809526770819311 { 10^-125 lo },
      2509728243035585317 { 10^-124 lo },
     -6699507609044543983 { 10^-123 lo },
     -6684408751134901354 { 10^-122 lo },
      2547201049757043466 { 10^-121 lo },
      2562504563619175885 { 10^-120 lo },
     -6649510319369241920 { 10^-119 lo },
      2589817179187686216 { 10^-118 lo },
     -6614253623653026573 { 10^-117 lo },
      2613423838358468417 { 10^-116 lo },
     -6580671501543130786 { 10^-115 lo },
     -6565692635521113125 { 10^-114 lo },
      2666993726254343773 { 10^-113 lo },
      2687499344461803514 { 10^-112 lo },
     -6517116040037961212 { 10^-111 lo },
     -6505958885777748348 { 10^-110 lo },
      2720468495323428714 { 10^-109 lo },
     -6477675614164716881 { 10^-108 lo },
     -6483645266140793429 { 10^-107 lo },
      2778484962396186215 { 10^-106 lo },
      2789684959541760001 { 10^-105 lo },
      2809780311493564929 { 10^-104 lo },
      2820922846565585025 { 10^-103 lo },
      2838874140091617873 { 10^-102 lo },
     -6371223741568980709 { 10^-101 lo },
     -6362413745387518268 { 10^-100 lo },
     -6347483914576816011 { 10^-99 lo },
      2898100922638176347 { 10^-98 lo },
     -6313526930651591794 { 10^-97 lo },
      2930955565638619335 { 10^-96 lo },
      2931907998147695589 { 10^-95 lo },
      2955788930666568248 { 10^-94 lo },
      2976082738276335715 { 10^-93 lo },
      2977399876241457645 { 10^-92 lo },
     -6227114761386606900 { 10^-91 lo },
      3001586934749545990 { 10^-90 lo },
     -6193495297407582961 { 10^-89 lo },
      3048464678931202519 { 10^-88 lo },
     -6168750817501021336 { 10^-87 lo },
     -6143385356664564080 { 10^-86 lo },
      3086154407076808599 { 10^-85 lo },
     -6119445957691251902 { 10^-84 lo },
     -6104572774925984750 { 10^-83 lo },
      3134751490642374261 { 10^-82 lo },
      3149449726929455634 { 10^-81 lo },
      3164444822567779478 { 10^-80 lo },
      3156645114622736260 { 10^-79 lo },
      3171423647473183410 { 10^-78 lo },
      3213423668297437269 { 10^-77 lo },
      3228649650581959787 { 10^-76 lo },
      3239800829089714566 { 10^-75 lo },
      3254865702131250663 { 10^-74 lo },
      3252741445267430150 { 10^-73 lo },
      3283565231004130844 { 10^-72 lo },
      3304228965786579666 { 10^-71 lo },
      3299896910559508579 { 10^-70 lo },
      3328766810794896232 { 10^-69 lo },
     -5875887842713295649 { 10^-68 lo },
      3361425932982415849 { 10^-67 lo },
      3370792248869510343 { 10^-66 lo },
      3393274059167405310 { 10^-65 lo },
      3403124768244593787 { 10^-64 lo },
     -5800764376180353229 { 10^-63 lo },
     -5789537391143715584 { 10^-62 lo },
     -5774377759941075904 { 10^-61 lo },
      3461970110699351216 { 10^-60 lo },
     -5747222420902737885 { 10^-59 lo },
     -5732349735972039402 { 10^-58 lo },
      3509535091037754066 { 10^-57 lo },
     -5699718155175692167 { 10^-56 lo },
      3525943175987022659 { 10^-55 lo },
     -5671380660079870914 { 10^-54 lo },
     -5656238187833260634 { 10^-53 lo },
     -5650602811629560768 { 10^-52 lo },
     -5635612432660503727 { 10^-51 lo },
     -5620372246814044654 { 10^-50 lo },
      3631430648259976141 { 10^-49 lo },
      3640480070600066433 { 10^-48 lo },
      3655509662310196961 { 10^-47 lo },
     -5553423596468199577 { 10^-46 lo },
      3682299265275852992 { 10^-45 lo },
      3704259509117775292 { 10^-44 lo },
     -5500895979609814165 { 10^-43 lo },
     -5490386432613360502 { 10^-42 lo },
     -5487876780380893516 { 10^-41 lo },
      3766752122278926810 { 10^-40 lo },
      3781824529517178960 { 10^-39 lo },
      3792783739217095781 { 10^-38 lo },
     -5412108435346033599 { 10^-37 lo },
      3825410887416450735 { 10^-36 lo },
     -5395845992869368529 { 10^-35 lo },
      3856671083969765240 { 10^-34 lo },
     -5353389510898767702 { 10^-33 lo },
     -5338405200598625580 { 10^-32 lo },
     -5320901836184265788 { 10^-31 lo },
     -5305676906553396554 { 10^-30 lo },
      3929936356769448093 { 10^-29 lo },
      3940768826356625604 { 10^-28 lo },
     -5265982804812254453 { 10^-27 lo },
     -5250868040867246105 { 10^-26 lo },
     -5236149060916603936 { 10^-25 lo },
      4006679902334268308 { 10^-24 lo },
      4017557959896326265 { 10^-23 lo },
     -5189706535989958807 { 10^-22 lo },
      4053088618013570910 { 10^-21 lo },
      4064309855427028278 { 10^-20 lo },
      4074159742176345351 { 10^-19 lo },
     -5127411775529120530 { 10^-18 lo },
     -5112228026728697815 { 10^-17 lo },
      4117896183574595481 { 10^-16 lo },
     -5081969668356835936 { 10^-15 lo },
      4129421565601463783 { 10^-14 lo },
     -5057879409136967787 { 10^-13 lo },
      4177509938886011014 { 10^-12 lo },
      4199597566440843434 { 10^-11 lo },
     -5011932077707260628 { 10^-10 lo },
     -4993570094577895365 { 10^-9 lo },
     -4985431856872862572 { 10^-8 lo },
      4257557416083959843 { 10^-7 lo },
      4272608056927624236 { 10^-6 lo },
     -4931749998473175452 { 10^-5 lo },
     -4920568101030369794 { 10^-4 lo },
     -4911013264060940550 { 10^-3 lo },
     -4895773082921918792 { 10^-2 lo },
     -4874696236665824870 { 10^-1 lo },
                        0 { 10^0 lo },
                        0 { 10^1 lo },
                        0 { 10^2 lo },
                        0 { 10^3 lo },
                        0 { 10^4 lo },
                        0 { 10^5 lo },
                        0 { 10^6 lo },
                        0 { 10^7 lo },
                        0 { 10^8 lo },
                        0 { 10^9 lo },
                        0 { 10^10 lo },
                        0 { 10^11 lo },
                        0 { 10^12 lo },
                        0 { 10^13 lo },
                        0 { 10^14 lo },
                        0 { 10^15 lo },
                        0 { 10^16 lo },
                        0 { 10^17 lo },
                        0 { 10^18 lo },
                        0 { 10^19 lo },
                        0 { 10^20 lo },
                        0 { 10^21 lo },
                        0 { 10^22 lo },
      4710765210229538816 { 10^23 lo },
      4715268809856909312 { 10^24 lo },
     -4482489004117196800 { 10^25 lo },
     -4471581848769658880 { 10^26 lo },
     -4465107924305313792 { 10^27 lo },
      4780645771244470272 { 10^28 lo },
      4800602457044418560 { 10^29 lo },
     -4417444370119131136 { 10^30 lo },
      4824677260566986752 { 10^31 lo },
     -4381139874854469632 { 10^32 lo },
      4857179894804643840 { 10^33 lo },
      4872391467718410240 { 10^34 lo },
      4883524634512719872 { 10^35 lo },
     -4322780941442351104 { 10^36 lo },
      4915961517140082688 { 10^37 lo },
      4926518402099445760 { 10^38 lo },
      4947636018668699648 { 10^39 lo },
     -4264885682169200640 { 10^40 lo },
     -4260289422739193856 { 10^41 lo },
     -4232661864668787200 { 10^42 lo },
     -4225271124803500544 { 10^43 lo },
     -4198339070503492880 { 10^44 lo },
      5038506455456638036 { 10^45 lo },
      5038319906572856136 { 10^46 lo },
     -4158041069000469699 { 10^47 lo },
     -4142947390359952378 { 10^48 lo },
      5096493544750428921 { 10^49 lo },
     -4109672288986812379 { 10^50 lo },
      5112961867177860753 { 10^51 lo },
      5127942638494901814 { 10^52 lo },
      5143200838688890850 { 10^53 lo },
     -4049453824984068859 { 10^54 lo },
     -4047821265268670184 { 10^55 lo },
     -4018616042527421396 { 10^56 lo },
     -4007708337187229897 { 10^57 lo },
      5231437703132034300 { 10^58 lo },
      5242260436232340027 { 10^59 lo },
      5260811358455337317 { 10^60 lo },
      5275599805665940926 { 10^61 lo },
     -3935124177120148269 { 10^62 lo },
     -3916930040107869436 { 10^63 lo },
     -3908372187110120567 { 10^64 lo },
      5323625835746936617 { 10^65 lo },
      5351038025413396254 { 10^66 lo },
      5358588297429754776 { 10^67 lo },
      5379895436365873951 { 10^68 lo },
     -3825742459394410996 { 10^69 lo },
     -3810526454637829233 { 10^70 lo },
     -3799387748040000397 { 10^71 lo },
      5441005738810886712 { 10^72 lo },
      5448138894227567384 { 10^73 lo },
      5469804492741534711 { 10^74 lo },
      5487468886786780795 { 10^75 lo },
     -3723704867926768153 { 10^76 lo },
      5508224084316221759 { 10^77 lo },
     -3705015043617495838 { 10^78 lo },
      5542071438375645305 { 10^79 lo },
     -3697297848379581936 { 10^80 lo },
      5577685379488012783 { 10^81 lo },
      5587784340134076631 { 10^82 lo },
     -3621667403428677900 { 10^83 lo },
     -3602558409137600212 { 10^84 lo },
     -3596769638475043363 { 10^85 lo },
     -3581731323737593516 { 10^86 lo },
      5663141587708117782 { 10^87 lo },
      5678307500522922971 { 10^88 lo },
      5679884581785203528 { 10^89 lo },
      5706896517143790083 { 10^90 lo },
     -3495878629083783490 { 10^91 lo },
     -3484890959576426898 { 10^92 lo },
     -3470030472785388535 { 10^93 lo },
     -3459907813468436970 { 10^94 lo },
     -3444842377311521842 { 10^95 lo },
     -3424167480645023647 { 10^96 lo },
     -3406742070601091780 { 10^97 lo },
      5809408818375143055 { 10^98 lo },
      5841511392415234258 { 10^99 lo },
     -3371801010376068620 { 10^100 lo },
      5869007220246249671 { 10^101 lo },
      5883848145480827129 { 10^102 lo },
     -3340623246721649085 { 10^103 lo },
     -3325724628735880237 { 10^104 lo },
      5935473250455630650 { 10^105 lo },
     -3270569817866145796 { 10^106 lo },
      5960653527999080458 { 10^107 lo },
     -3246900994591310086 { 10^108 lo },
      5987049862732030608 { 10^109 lo },
     -3219488607432541594 { 10^110 lo },
      6022635847818765184 { 10^111 lo },
      6040717016522513968 { 10^112 lo },
     -3177483718762223345 { 10^113 lo },
     -3162332615432932525 { 10^114 lo },
     -3147393787761911788 { 10^115 lo },
     -3132601501030441447 { 10^116 lo },
     -3109985017748389528 { 10^117 lo },
      6125770286988623422 { 10^118 lo },
      6144019587789745895 { 10^119 lo },
      6152439531315385665 { 10^120 lo },
     -3052078222701487433 { 10^121 lo },
     -3043279336276868406 { 10^122 lo },
      6197920679731074626 { 10^123 lo },
      6218386980831686121 { 10^124 lo },
      6235682018646938802 { 10^125 lo },
      6250993751027435998 { 10^126 lo },
      6262252117155159126 { 10^127 lo },
     -2942818903570211254 { 10^128 lo },
      6271183363525526621 { 10^129 lo },
     -2914089751168600236 { 10^130 lo },
      6326594571711135083 { 10^131 lo },
      6326935628266169905 { 10^132 lo },
     -2875916984470302703 { 10^133 lo },
      6370597604902122235 { 10^134 lo },
      6381114602043539315 { 10^135 lo },
     -2824579072555360168 { 10^136 lo },
     -2813525600035448722 { 10^137 lo },
     -2798582859478716790 { 10^138 lo },
     -2783282133503329748 { 10^139 lo },
     -2764665209935926738 { 10^140 lo },
     -2757981765230325019 { 10^141 lo },
     -2735929696574024216 { 10^142 lo },
     -2725785981832112445 { 10^143 lo },
     -2710733705315797446 { 10^144 lo },
      6522380884343060591 { 10^145 lo },
      6549120143124506321 { 10^146 lo },
      6557168882463097367 { 10^147 lo },
     -2646405176349729959 { 10^148 lo },
     -2631340626424745425 { 10^149 lo },
      6600869564198716042 { 10^150 lo },
     -2608076622153163565 { 10^151 lo },
     -2586908922816443134 { 10^152 lo },
      6617891749752725196 { 10^153 lo },
     -2558109114682113965 { 10^154 lo },
     -2553863620397432417 { 10^155 lo },
      6689635118904938366 { 10^156 lo },
      6704719235758830430 { 10^157 lo },
      6726332552995057677 { 10^158 lo },
      6743988035458870792 { 10^159 lo },
     -2479959329396673619 { 10^160 lo },
     -2453519974274445293 { 10^161 lo },
      6788024849156054516 { 10^162 lo },
      6802936600622187889 { 10^163 lo },
     -2428407539060103599 { 10^164 lo },
      6836307205845535296 { 10^165 lo },
      6847526947788242129 { 10^166 lo },
     -2363581497380342789 { 10^167 lo },
      6878180288986781571 { 10^168 lo },
      6893112902273744228 { 10^169 lo },
     -2319232948871384253 { 10^170 lo },
      6920755653331083244 { 10^171 lo },
     -2283652802272828403 { 10^172 lo },
     -2280460367429405632 { 10^173 lo },
     -2255152125300930006 { 10^174 lo },
      6982518012130186060 { 10^175 lo },
     -2239660513352827124 { 10^176 lo },
     -2224509502607739032 { 10^177 lo },
     -2197010944259824472 { 10^178 lo },
      7035010233023956060 { 10^179 lo },
     -2178459457511738085 { 10^180 lo },
      7074250895573587892 { 10^181 lo },
     -2135827874405473697 { 10^182 lo },
      7101326876339410185 { 10^183 lo },
     -2114567484804478102 { 10^184 lo },
      7125055747823104222 { 10^185 lo },
      7139782730942803221 { 10^186 lo },
      7164875495204004375 { 10^187 lo },
     -2052762650224809273 { 10^188 lo },
     -2037906256471820935 { 10^189 lo },
     -2015510141076237130 { 10^190 lo },
     -2000347819290846749 { 10^191 lo },
     -1989276216407007140 { 10^192 lo },
     -1971191925028135878 { 10^193 lo },
      7265953008968961208 { 10^194 lo },
      7275178623440543692 { 10^195 lo },
      7295308312253184992 { 10^196 lo },
      7310141167574771052 { 10^197 lo },
     -1904768273445174669 { 10^198 lo },
     -1878765979252208444 { 10^199 lo },
      7351786928465428502 { 10^200 lo },
     -1854989406989367310 { 10^201 lo },
      7389535513882014473 { 10^202 lo },
      7390553214977507116 { 10^203 lo },
      7405226470382092023 { 10^204 lo },
     -1800568927953557338 { 10^205 lo },
     -1780066375799959192 { 10^206 lo },
     -1765000480890275103 { 10^207 lo },
      7468193549396569294 { 10^208 lo },
     -1731172559048913408 { 10^209 lo },
      7507486656686235264 { 10^210 lo },
      7518742175219566113 { 10^211 lo },
      7538733424569326548 { 10^212 lo },
      7542067617601162022 { 10^213 lo },
      7563901724670788476 { 10^214 lo },
      7583846641578979885 { 10^215 lo },
     -1634268837453151601 { 10^216 lo },
      7607932478437570151 { 10^217 lo },
     -1595682660423078400 { 10^218 lo },
      7637122349227797761 { 10^219 lo },
      7637285979349467656 { 10^220 lo },
     -1554381575394684201 { 10^221 lo },
     -1539504987623781433 { 10^222 lo },
     -1524686767600595272 { 10^223 lo },
      7710998379181313434 { 10^224 lo },
      7731514096036767872 { 10^225 lo },
      7742481479065600672 { 10^226 lo },
     -1460225303981285796 { 10^227 lo },
      7776788537546717709 { 10^228 lo },
      7777443566502298754 { 10^229 lo },
     -1414812643094975834 { 10^230 lo },
     -1403724234051709617 { 10^231 lo },
     -1388737822840784221 { 10^232 lo },
      7844839795278712168 { 10^233 lo },
     -1366304042406080706 { 10^234 lo },
     -1344296962351928125 { 10^235 lo },
     -1329090432005011468 { 10^236 lo },
      7909777184276130567 { 10^237 lo },
     -1299982890856469961 { 10^238 lo },
      7927555536158797039 { 10^239 lo },
     -1278096064304659477 { 10^240 lo },
     -1254807474318889671 { 10^241 lo },
     -1239746570100565880 { 10^242 lo },
     -1222386819282796715 { 10^243 lo },
     -1207102050653348054 { 10^244 lo },
     -1195877389214435595 { 10^245 lo },
     -1178080082626325927 { 10^246 lo },
      8057988658405415185 { 10^247 lo },
     -1150854961185816405 { 10^248 lo },
      8091113990793215893 { 10^249 lo },
      8106412954591121275 { 10^250 lo },
     -1105550740174742361 { 10^251 lo },
     -1085597129957553688 { 10^252 lo },
      8149550550428492702 { 10^253 lo },
      8164821955346263173 { 10^254 lo },
      8168508878667849369 { 10^255 lo },
     -1033820050253003152 { 10^256 lo },
     -1018681385453496308 { 10^257 lo },
      -999507376594005116 { 10^258 lo },
      8240096742328358811 { 10^259 lo },
      -968662499998780802 { 10^260 lo },
      8269977678330400881 { 10^261 lo },
      -948096134511284791 { 10^262 lo },
      -932918589006358212 { 10^263 lo },
      -911626432758062109 { 10^264 lo },
      -894025693644464530 { 10^265 lo },
      -883984345900012526 { 10^266 lo },
      8353524032627828969 { 10^267 lo },
      8368405709970948498 { 10^268 lo },
      -836429182278502651 { 10^269 lo },
      -821482396386446138 { 10^270 lo },
      8417243843776749316 { 10^271 lo },
      -789276009973294789 { 10^272 lo },
      8447933695112687735 { 10^273 lo },
      8465129395903213130 { 10^274 lo },
      8475978919083309533 { 10^275 lo },
      -730964565005908052 { 10^276 lo },
      -734693648934921867 { 10^277 lo },
      8520154222361446403 { 10^278 lo },
      -685262872877450498 { 10^279 lo },
      -674182806188308034 { 10^280 lo },
      -659206822920037331 { 10^281 lo },
      -643939645134603876 { 10^282 lo },
      8596151911769212925 { 10^283 lo },
      -608349489051194622 { 10^284 lo },
      8620798535177573499 { 10^285 lo },
      -584347131941928141 { 10^286 lo },
      -563938291021428224 { 10^287 lo },
      -563826130167733248 { 10^288 lo },
      -535293119523626544 { 10^289 lo },
      -520497611701306812 { 10^290 lo },
      8715443047340349227 { 10^291 lo },
      -500284800902951895 { 10^292 lo },
      8749146895201199642 { 10^293 lo },
      -459934985830883232 { 10^294 lo },
      8769928034088087312 { 10^295 lo },
      8784919622776474324 { 10^296 lo },
      -423586102007307657 { 10^297 lo },
      8819814338074970427 { 10^298 lo },
      -386724635395810757 { 10^299 lo },
      -371941703467343670 { 10^300 lo },
      -356840738277287683 { 10^301 lo },
      -339556101781516386 { 10^302 lo },
      -364395930334296743 { 10^303 lo },
      8912599740500244377 { 10^304 lo },
      8927245410063936192 { 10^305 lo },
      -289281519602406847 { 10^306 lo },
      8947714589084859183 { 10^307 lo },
      -262288240075778555 { 10^308 lo }
  );
  BNH: array[-343..-303] of QWord = (
    $3BD7E53B957505FC { B(10^-343*2^1074) hi },
    $3C0DDE8A7AD2477B { B(10^-342*2^1074) hi },
    $3C42AB168CC36CAD { B(10^-341*2^1074) hi },
    $3C7755DC2FF447D8 { B(10^-340*2^1074) hi },
    $3CAD2B533BF159CE { B(10^-339*2^1074) hi },
    $3CE23B140576D821 { B(10^-338*2^1074) hi },
    $3D16C9D906D48E29 { B(10^-337*2^1074) hi },
    $3D4C7C4F4889B1B3 { B(10^-336*2^1074) hi },
    $3D81CDB18D560F10 { B(10^-335*2^1074) hi },
    $3DB6411DF0AB92D4 { B(10^-334*2^1074) hi },
    $3DEBD1656CD67789 { B(10^-333*2^1074) hi },
    $3E2162DF64060AB6 { B(10^-332*2^1074) hi },
    $3E55BB973D078D63 { B(10^-331*2^1074) hi },
    $3E8B2A7D0C4970BC { B(10^-330*2^1074) hi },
    $3EC0FA8E27ADE675 { B(10^-329*2^1074) hi },
    $3EF53931B1996013 { B(10^-328*2^1074) hi },
    $3F2A877E1DFFB817 { B(10^-327*2^1074) hi },
    $3F6094AED2BFD30F { B(10^-326*2^1074) hi },
    $3F94B9DA876FC7D2 { B(10^-325*2^1074) hi },
    $3FC9E851294BB9C7 { B(10^-324*2^1074) hi },
    $40003132B9CF541C { B(10^-323*2^1074) hi },
    $40343D7F68432923 { B(10^-322*2^1074) hi },
    $40694CDF4253F36C { B(10^-321*2^1074) hi },
    $409FA01712E8F047 { B(10^-320*2^1074) hi },
    $40D3C40E6BD1962C { B(10^-319*2^1074) hi },
    $4108B51206C5FBB8 { B(10^-318*2^1074) hi },
    $413EE25688777AA5 { B(10^-317*2^1074) hi },
    $41734D76154AACA7 { B(10^-316*2^1074) hi },
    $41A820D39A9D57D1 { B(10^-315*2^1074) hi },
    $41DE29088144ADC6 { B(10^-314*2^1074) hi },
    $4212D9A550CAEC9B { B(10^-313*2^1074) hi },
    $4247900EA4FDA7C2 { B(10^-312*2^1074) hi },
    $427D74124E3D11B3 { B(10^-311*2^1074) hi },
    $42B2688B70E62B10 { B(10^-310*2^1074) hi },
    $42E702AE4D1FB5D4 { B(10^-309*2^1074) hi },
    $431CC359E067A349 { B(10^-308*2^1074) hi },
    $4351FA182C40C60D { B(10^-307*2^1074) hi },
    $4386789E3750F791 { B(10^-306*2^1074) hi },
    $43BC16C5C5253575 { B(10^-305*2^1074) hi },
    $43F18E3B9B374169 { B(10^-304*2^1074) hi },
    $4425F1CA820511C3 { B(10^-303*2^1074) hi }
  );
  BNL: array[-343..-303] of Int64 = (
     -5159690598842135432 { B(10^-343*2^1074) lo },
     -5144695256522068074 { B(10^-342*2^1074) lo },
     -5125028576639503649 { B(10^-341*2^1074) lo },
     -5120253779779649958 { B(10^-340*2^1074) lo },
     -5105532331855544847 { B(10^-339*2^1074) lo },
     -5079114560109861970 { B(10^-338*2^1074) lo },
     -5070940431322719950 { B(10^-337*2^1074) lo },
      4163295982762877187 { B(10^-336*2^1074) lo },
     -5043573937215028386 { B(10^-335*2^1074) lo },
     -5028822827066092490 { B(10^-334*2^1074) lo },
     -5013761639100450493 { B(10^-333*2^1074) lo },
     -4986525345841316109 { B(10^-332*2^1074) lo },
     -4986883171666168455 { B(10^-331*2^1074) lo },
     -4961777912004831653 { B(10^-330*2^1074) lo },
      4279365447513825799 { B(10^-329*2^1074) lo },
     -4929246144139983497 { B(10^-328*2^1074) lo },
      4306074633698335019 { B(10^-327*2^1074) lo },
     -4896371613612738491 { B(10^-326*2^1074) lo },
      4334859888182940500 { B(10^-325*2^1074) lo },
     -4872704101112439828 { B(10^-324*2^1074) lo },
      4367127369014492441 { B(10^-323*2^1074) lo },
      4382275668879029808 { B(10^-322*2^1074) lo },
      4387872194296549103 { B(10^-321*2^1074) lo },
      4402850432394924715 { B(10^-320*2^1074) lo },
      4430436670406589163 { B(10^-319*2^1074) lo },
     -4779189300796307877 { B(10^-318*2^1074) lo },
      4457399451478370319 { B(10^-317*2^1074) lo },
      4474724517437917449 { B(10^-316*2^1074) lo },
      4485455048067495575 { B(10^-315*2^1074) lo },
     -4720816946395173406 { B(10^-314*2^1074) lo },
      4521140961542443859 { B(10^-313*2^1074) lo },
      4532281694526486568 { B(10^-312*2^1074) lo },
     -4687542359796783302 { B(10^-311*2^1074) lo },
     -4664101572729810878 { B(10^-310*2^1074) lo },
     -4649057963634351022 { B(10^-309*2^1074) lo },
     -4633917584274897228 { B(10^-308*2^1074) lo },
      4610944048293127120 { B(10^-307*2^1074) lo },
     -4605327493464365447 { B(10^-306*2^1074) lo },
      4620158362835091274 { B(10^-305*2^1074) lo },
      4648376717353203698 { B(10^-304*2^1074) lo },
      4668957652414722807 { B(10^-303*2^1074) lo }
  );

function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  Result := 0.0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            __errno_location()^ := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  Result := X;
end;


function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  FBits: LongWord;
  QW64: QWord;
  AbsQ: QWord;
  S: LongInt;
  THo: Double;
  TLo: Double;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    THo := H1;
    TLo := L1;
    Result := H1 + L1;
  end;

  { 106-bit double-double -> correct float rounding (round-half-even).
    Rounding through an intermediate double flips at the float 0.5ulp
    boundary (double rounding); use the exact residue R=(Hi-F)+Lo to
    pick the direction (error ~2^-105, tie misread ~2^-80) }
  function FloatR2(Hi, Lo: Double): Single;
  var FB, FB2: LongWord;
      Fv: Single;
      D, Up, Half, R: Double;
  begin
    Fv := Single(Hi);
    Move(Fv, FB, 4);
    if (FB and $7FFFFFFF) = 0 then begin
      { F = +-0: direction set by Hi+Lo vs half of min subnormal }
      FB2 := 1;
      Move(FB2, Fv, 4);
      Half := Double(Fv) * 0.5; { 2^-150 }
      R := Hi + Lo;
      if (FB shr 31) <> 0 then begin
        if R < -Half then FB := $80000001;
      end else begin
        if R > Half then FB := 1;
      end;
      Move(FB, Result, 4);
      Exit;
    end;
    D := Double(Fv);
    R := (Hi - D) + Lo;
    { next float toward +inf: FB2 = FB+1. At FLT_MAX it is +-Inf
      (Half not representable; use exact 2^103 double; tie only at
      float extremes) }
    FB2 := FB + 1;
    if (FB2 and $7F800000) = $7F800000 then begin
      if (FB shr 31) <> 0 then
        Bits := QWord($C660000000000000) { -2^103 }
      else
        Bits := QWord($4660000000000000); { +2^103 }
      Move(Bits, Half, 8);
    end else begin
      Move(FB2, Fv, 4);
      Up := Double(Fv);
      Half := (Up - D) * 0.5;
    end;
    if R > Half then
      FB := FB + 1
    else if R < -Half then
      FB := FB - 1;
    Move(FB, Result, 4);
  end;
begin
  Result := 0.0;
  IsHex := False;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P + L;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if endptr <> nil then endptr^ := P;
      __errno_location()^ := 34;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    if endptr <> nil then endptr^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
      Exit;
    end;
    { value = M x 2^T, T = ExpBits - 4*DfHex + 4*CutHex.
      strtof version: round directly in the float domain (24-bit
      round-half-even); the double intermediate double-rounds
      boundary cases by 1ulp }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 127 then begin
      { float exponent overflow -> +-Inf + ERANGE }
      __errno_location()^ := 34;
      FBits := $7F800000;
      if Neg then FBits := $FF800000;
      Move(FBits, Result, 4);
    end else if EvalI >= -126 then begin
      { float normal: 24-bit round-half-even }
      if L <= 23 then
        mant := M shl (23 - L)
      else begin
        BL := L - 23;
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 24) then begin
          { mantissa carry into 2^128: float overflow (FLT_MAX+0.5ulp tie) }
          mant := QWord(1) shl 23;
          Inc(EvalI);
          if EvalI > 127 then begin
            __errno_location()^ := 34;
            FBits := $7F800000;
            if Neg then FBits := $FF800000;
            Move(FBits, Result, 4);
            Exit;
          end;
        end;
      end;
      { mant in [2^23, 2^24): exponent field EvalI+127 }
      FBits := LongWord((EvalI + 127) shl 23) or LongWord(mant and $7FFFFF);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
    end else begin
      { float subnormal: grid 2^-149, grid count = M x 2^Rg, Rg = T + 149
        (ERANGE only when rounding inexact; 0x1p-149 exact -> 0) }
      Rg := T + 149;
      HexExact := True;
      if Rg >= 0 then begin
        { subnormal domain: Rg < 23-L -> grid < 2^24: no QWord overflow }
        mant := M shl Rg;
      end else begin
        BL := LongInt(-Rg);
        if BL >= 64 then begin
          { grid count < 0.5: rounds to 0 }
          mant := 0;
          HexExact := False;
        end else begin
          remLW := M and ((QWord(1) shl BL) - 1);
          mant := M shr BL;
          half := QWord(1) shl (BL - 1);
          if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
            Inc(mant);
          if remLW <> 0 then HexExact := False;
        end;
      end;
      if HexLost then HexExact := False; { 64-bit truncation also inexact }
      if mant >= (QWord(1) shl 23) then
        FBits := $00800000 { carry into 2^-126 (min normal) }
      else
        FBits := LongWord(mant);
      if Neg then FBits := FBits or $80000000;
      Move(FBits, Result, 4);
      IsHex := True;
    if not HexExact then __errno_location()^ := 34;
    end;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: endptr = original nptr (C99) }
    if endptr <> nil then endptr^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if endptr <> nil then endptr^ := P;
    __errno_location()^ := 34;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    THo := X;
    TLo := 0.0;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if endptr <> nil then endptr^ := P;
    begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if endptr <> nil then endptr^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  begin
      Move(X, QW64, 8);
      if (QW64 and QWord($7FF0000000000000)) = QWord($7FF0000000000000) then begin
        { Inf/NaN 输入：位级映射，不设 ERANGE }
        if (QW64 and QWord($FFFFFFFFFFFFF)) = 0 then begin
          FBits := $7F800000;
          if (QW64 shr 63) <> 0 then FBits := $FF800000;
          Move(FBits, Result, 4);
        end else begin
          FBits := $7FC00000 or LongWord(QW64 and QWord($3FFFFF));
          if (QW64 shr 63) <> 0 then FBits := FBits or $80000000;
          Move(FBits, Result, 4);
        end;
      end else if (QW64 and QWord($7FFFFFFFFFFFFFFF)) > QWord($47EFFFFFF0000000) then begin
        { |X| > FLT_MAX+0.5ulp：溢出 → ±Inf + ERANGE }
        __errno_location()^ := 34;
        FBits := $7F800000;
        if (QW64 shr 63) <> 0 then FBits := $FF800000;
        Move(FBits, Result, 4);
      end else begin
        if (QW64 and QWord($7FFFFFFFFFFFFFFF)) = 0 then
          Result := Single(X) { ±0：不经幂乘，双 double 未定义 }
        else begin
          Result := FloatR2(THo, TLo); { 106 位中间正确舍入 }
          Move(Result, FBits, 4);
          if Neg then FBits := FBits or $80000000; { Pmul 输入恒正，符号后补 }
          Move(FBits, Result, 4);
        end;
        Move(Result, FBits, 4);
        AbsQ := QW64 and QWord($7FFFFFFFFFFFFFFF);
        if (FBits and $7FFFFFFF) = 0 then begin
          if AbsQ <> 0 then
            __errno_location()^ := 34; { 下溢到 ±0（真 0 不设）}
        end else if IsHex then begin
          { hex：结果在 float 次正规域且舍入非精确才设 ERANGE
            （0x1p-149 精确 → 0；0x1.fffffep-127 进位非精确 → 34）}
          if AbsQ < QWord($3810000000000000) then begin
            if AbsQ < QWord($36A0000000000000) then
              __errno_location()^ := 34 { < 2^-149：float 不可表示 }
            else begin
              S := 926 - LongInt((AbsQ shr 52) and $7FF);
              if (AbsQ and ((QWord(1) shl S) - 1)) <> 0 then
                __errno_location()^ := 34; { 尾数落不出次正规网格 }
            end;
          end;
        end else if (FBits and $7F800000) = 0 then
          __errno_location()^ := 34; { decimal：次正规结果无条件 ERANGE }
      end;
    end;
end;


function atof(nptr: PAnsiChar): Double; cdecl;
procedure ClearFPUFlags;
{ 清除 MXCSR 的 6 个异常标志位而不改屏蔽掩码：
  FPC 的 try/except 不恢复 FPU 状态，异常后滞留的标志会让后续浮点运算误抛 }
begin
  asm
    subq $8, %rsp
    stmxcsr (%rsp)
    movl (%rsp), %eax
    andl $0xFFFFFFC0, %eax
    movl %eax, (%rsp)
    ldmxcsr (%rsp)
    addq $8, %rsp
  end;
end;

{ 与溢出阈值 T=2^1024-2^970（= DBL_MAX + 0.5ulp，309 位十进制整数）
  的前 60 位比较：S 某位大于 T 同位列 → 1（溢）；小于或 S 是 T 的
  真前缀（T 尾部位非零）→ -1。前 60 位全等且更长（概率 <1e-60，
  判定差 < 0.5ulp×1e-40）按不溢处理 }
function CmpT60(const S: array of AnsiChar; SLen: LongInt): LongInt;
const T60 = '179769313486231580793728971405303415079934132710037826936173';
var J: LongInt;
begin
  for J := 1 to SLen do begin
    if S[J - 1] < T60[J] then begin Result := -1; Exit; end;
    if S[J - 1] > T60[J] then begin Result := 1; Exit; end;
  end;
  Result := -1;
end;

{ Dekker 双精度乘积：hi+lo = a*b 精确（无 FMA 版），用于 k=308 大值幂乘 }
procedure TwoProd(const a, b: Double; out hi, lo: Double);
var ah, al, bh, bl, c: Double;
begin
  c := 134217729.0 * a; { (2^27+1) }
  ah := c - (c - a);
  al := a - ah;
  c := 134217729.0 * b;
  bh := c - (c - b);
  bl := b - bh;
  hi := a * b;
  lo := ((ah * bh - hi) + ah * bl + al * bh) + al * bl;
end;


var
  DummyEnd: PPAnsiChar;
  P: PAnsiChar;
  Neg: Boolean;
  Buf: array[0..511] of AnsiChar;
  I: LongInt;
  D: LongInt;
  HasDigits: Boolean;
  AnyNonZero: Boolean;
  IsHex: Boolean;
  ValErr: Integer;
  X: Double;
  L: LongInt;
  Bits: QWord;
  Scale: Double;
  ExpNeg: Boolean;
  ExpBits: Int64;
  ExpNegDec: Boolean;
  C: AnsiChar;
  Di: LongInt;
  Df: LongInt;
  SigCount: LongInt;
  ExpSign: LongInt;
  HasDecPoint: Boolean;
  FirstSig: Boolean;
  FirstInt: Boolean;
  KIntBase: LongInt;
  R: Boolean;
  HasExp: Boolean;
  Mhi: Int64;  { 尾数高 15 位（Double 精确）}
  Mlo: Int64;  { 尾数低 5 位（第 16-20 位）}
  MHw: Int64;
  MLw: Int64;
  SCh: LongInt;
  SCl: LongInt;
  k: Int64;
  KTotal: Int64;
  Ei: Int64;
  Overflow: Boolean;
  Underflow: Boolean;
  S60: array[0..59] of AnsiChar;
  S60Len: LongInt;
  Beyond60: Boolean;
  Q64: QWord;
  { hex 分支整数尾数（≤64 bit）与拼装 }
  M: QWord;
  MBits: LongInt;
  DfHex: LongInt;
  HexLost: Boolean;
  CutHex: LongInt;
  { decimal 高精度幂乘 }
  KIntL: LongInt;
  QN: QWord;
  HexExact: Boolean;
  QW: QWord;
  EvalI: Int64;
  Rg: Int64;
  BL: LongInt;
  mant: QWord;
  remLW: QWord;
  half: QWord;
  g: QWord;
  { NAN(n-char) payload：base-0 strtoul 语义 }
  NBuf: array[0..63] of AnsiChar;
  NLen: LongInt;
  NVal: QWord;
  NBase: LongInt;
  Novf: Boolean;
  Novak: Boolean;
  T: Int64;
  Idx: LongInt;
  Cmp: LongInt;
  THd: Double;
  TLd: Double;
  E308: LongInt;
  E308L: LongInt;
  H1: Double;
  L1: Double;
  H2: Double;
  L2: Double;
  H1b: Double;
  L1b: Double;
  H2b: Double;
  L2b: Double;
  Wh: Double;
  Wl: Double;
  WlB: Double;
  F2: Double; { BN 缩放临时（2^-1074）}
  XN: Double;

  { 双 double 幂乘：W（Wh+Wl 精确对）× 10^K。
    TH+TL = 10^K（106 位双 double 表；TL 可负/次正规/0，不作
    指数拆解——次正规低段无 [1,2)×2^E 规范形，拆解会放大误差）。
    主段 TwoProd(TH,Wh) 精确，TH×Wl 与 TL×W 并入低段，每步只摊
    ~2^-106 相对误差，最终一次舍入即正确 }
  function Pmul(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(TENH[K], fH, 8);
    Move(TENL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

  { BN 网格倍数定点版（表 B = 10^K×2^1074，全正规域），同 Pmul 结构 }
  function PmulB(Wh, Wl: Double; K: LongInt): Double;
  var fH, fL, H1, L1, B1, B2: Double;
  begin
    Move(BNH[K], fH, 8);
    Move(BNL[K], fL, 8);
    TwoProd(fH, Wh, H1, L1);
    L1 := L1 + fH * Wl;
    B1 := fL * Wh;
    B2 := fL * Wl;
    L1 := L1 + B1;
    L1 := L1 + B2;
    Result := H1 + L1;
  end;

begin
  DummyEnd := nil;
  Result := 0.0;
  if nptr = nil then begin
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
        (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  { INF / INFINITY (case-insensitive, must start at P) }
  if (P^ <> #0) and ((UpCase(P^) = 'I') and (P[1] <> #0) and
     (UpCase(P[1]) = 'N') and (P[2] <> #0) and (UpCase(P[2]) = 'F')) then
  begin
    L := 3;
    if (P[3] <> #0) and (UpCase(P[3]) = 'I') and (P[4] <> #0) and
       (UpCase(P[4]) = 'N') and (P[5] <> #0) and (UpCase(P[5]) = 'I') and
       (P[6] <> #0) and (UpCase(P[6]) = 'T') and (P[7] <> #0) and
       (UpCase(P[7]) = 'Y') then L := 8;
    { +Inf via bit pattern: avoids FPC EOverflow on literal overflow }
    Bits := $7FF0000000000000;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { NAN / NAN(n-char-sequence) }
  if (P^ <> #0) and ((UpCase(P^) = 'N') and (P[1] <> #0) and
     (UpCase(P[1]) = 'A') and (P[2] <> #0) and (UpCase(P[2]) = 'N')) then
  begin
    L := 3;
    NLen := 0;
    if P[3] = '(' then begin
      Inc(L); { '(' consumed }
      while P[L] <> #0 do begin
        C := P[L];
        if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
           ((C >= '0') and (C <= '9')) or (C = '_') then begin
          if NLen < 64 then begin NBuf[NLen] := C; Inc(NLen); end;
          Inc(L)
        end
        else break;
      end;
      if P[L] = ')' then begin
        { glibc(含 GCC __builtin_nan) 的 payload 映射：
          base-0 strtoul 语义（0x → hex、前导 0 → oct、否则 dec），
          必须整体合法否则 payload=0；数值溢出（strtoul 给 ULONG_MAX）→ 52 位全 1 }
        Inc(L);
        Novak := False;
        NVal := 0;
        NBase := 10;
        Idx := 0;
        if NLen = 0 then Novak := True
        else if (NLen >= 2) and (NBuf[0] = '0') and
                ((NBuf[1] = 'x') or (NBuf[1] = 'X')) then begin
          NBase := 16;
          Idx := 2;
          if NLen = 2 then Novak := True; { '0x' 后无数字：整体不合法 }
        end
        else if NBuf[0] = '0' then NBase := 8; { 前导 0 → octal }
        if not Novak then begin
          Novf := False;
          while Idx < NLen do begin
            C := NBuf[Idx];
            D := -1;
            if (C >= '0') and (C <= '9') then D := Ord(C) - 48
            else if (C >= 'a') and (C <= 'f') then D := Ord(C) - 87
            else if (C >= 'A') and (C <= 'F') then D := Ord(C) - 55;
            if (D < 0) or (D >= NBase) then begin Novak := True; break; end;
            { 注意 D/NBase 为有符号：须显式转 QWord 强制无符号除法 }
            if NVal > (High(QWord) - QWord(D)) div QWord(NBase) then Novf := True;
            NVal := NVal * NBase + D;
            Inc(Idx);
          end;
        end;
        if Novak then NVal := 0
        else if Novf then NVal := $FFFFFFFFFFFFF
        else NVal := NVal and $FFFFFFFFFFFFF;
        Bits := $7FF8000000000000 or NVal;
      end
      else begin
        L := 3; { 无闭合括号：括号组整体不消费（C99/glibc）}
        Bits := $7FF8000000000000;
      end;
    end
    else begin
      Bits := $7FF8000000000000;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P + L;
    Result := X;
    Exit;
  end;
  { hex float: 0x/0X with >=1 hex digit (after optional '.') to confirm }
  IsHex := False;
  if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin
    D := -1;
    if (P[2] >= '0') and (P[2] <= '9') then D := Ord(P[2]) - 48
    else if (P[2] >= 'a') and (P[2] <= 'f') then D := Ord(P[2]) - 87
    else if (P[2] >= 'A') and (P[2] <= 'F') then D := Ord(P[2]) - 55;
    if D >= 0 then IsHex := True
    else if P[2] = '.' then begin
      D := -1;
      if (P[3] >= '0') and (P[3] <= '9') then D := Ord(P[3]) - 48
      else if (P[3] >= 'a') and (P[3] <= 'f') then D := Ord(P[3]) - 87
      else if (P[3] >= 'A') and (P[3] <= 'F') then D := Ord(P[3]) - 55;
      if D >= 0 then IsHex := True;
    end;
  end;
  HasDigits := False;
  AnyNonZero := False;
  if IsHex then begin
    Inc(P, 2); { consume 0x prefix }
    M := 0;
    MBits := 0;
    DfHex := 0;
    HexLost := False;
    CutHex := 0;
    ExpBits := 0;
    try
      { integer hex digits }
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
        if D < 0 then break;
        HasDigits := True;
        if D <> 0 then AnyNonZero := True;
        if MBits >= 64 then begin
          if D <> 0 then HexLost := True;
          Inc(CutHex); { 被截断的 hex 位：量级修正 4×CutHex }
        end else begin
          M := (M shl 4) or QWord(D);
          Inc(MBits, 4);
        end;
        Inc(P);
      end;
      if P^ = '.' then begin
        Inc(P);
        while P^ <> #0 do begin
          D := -1;
          if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
          else if (P^ >= 'a') and (P^ <= 'f') then D := Ord(P^) - 87
          else if (P^ >= 'A') and (P^ <= 'F') then D := Ord(P^) - 55;
          if D < 0 then break;
          HasDigits := True;
          if D <> 0 then AnyNonZero := True;
          Inc(DfHex);
          if MBits >= 64 then begin
            if D <> 0 then HexLost := True;
            Inc(CutHex);
          end else begin
            M := (M shl 4) or QWord(D);
            Inc(MBits, 4);
          end;
          Inc(P);
        end;
      end;
      { hex exponent p[+-]digits }
      if ((P^ = 'p') or (P^ = 'P')) and (P[1] <> #0) and
         (((P[1] >= '0') and (P[1] <= '9')) or
          ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
          ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
      begin
        Inc(P);
        ExpNeg := False;
        if P^ = '+' then Inc(P)
        else if P^ = '-' then begin ExpNeg := True; Inc(P); end;
        ExpBits := 0;
        while (P^ >= '0') and (P^ <= '9') do begin
          if ExpBits < 1000000 then ExpBits := ExpBits * 10 + (Ord(P^) - 48);
          Inc(P);
        end;
        if ExpNeg then ExpBits := -ExpBits;
        if ExpBits > 4096 then ExpBits := 4096
        else if ExpBits < -4096 then ExpBits := -4096;
      end;
    except
      { 防御兜底（不应触发）}
      X := 0.0;
      Bits := $7FF0000000000000;
      Move(Bits, X, 8); { +Inf }
      ClearFPUFlags;
      if Neg then X := -X;
      if DummyEnd <> nil then DummyEnd^ := P;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if DummyEnd <> nil then DummyEnd^ := P;
    if not AnyNonZero then begin
      { 全零 hex：不设 errno（glibc）}
      X := 0.0;
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 值 = M × 2^T，T = ExpBits - 4*DfHex + 4*CutHex（CutHex 补回
      被 64-bit 窗口截断的低位量级）；一次规格化 + round-to-nearest-even }
    T := ExpBits - 4 * DfHex + 4 * CutHex;
    QW := M;
    L := 0;
    while QW > 1 do begin QW := QW shr 1; Inc(L); end;
    EvalI := T + L;
    if EvalI > 1023 then begin
      Bits := $7FF0000000000000;
      Move(Bits, X, 8);
      if Neg then X := -X;
      __errno_location()^ := 34;
      Result := X;
      Exit;
    end;
    if EvalI >= -1022 then begin
      { 正规数：msb 移到 bit 52（隐含位），低位截断时 round-half-even }
      BL := L - 52;
      if BL <= 0 then
        mant := M shl (-BL)
      else begin
        remLW := M and ((QWord(1) shl BL) - 1);
        mant := M shr BL;
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((mant and 1) = 1)) then
          Inc(mant);
        if mant = (QWord(1) shl 53) then begin
          { 尾数进位：EvalI+1，回到 2^52 }
          mant := QWord(1) shl 52;
          Inc(EvalI);
          if EvalI > 1023 then begin
            Bits := $7FF0000000000000;
            Move(Bits, X, 8);
            if Neg then X := -X;
            __errno_location()^ := 34;
            Result := X;
            Exit;
          end;
        end;
      end;
      Bits := (QWord(EvalI + 1023) shl 52) or (mant and $FFFFFFFFFFFFF);
      Move(Bits, X, 8);
      if Neg then X := -X;
      Result := X;
      Exit;
    end;
    { 次正规：网格 2^-1074，网格数 = M × 2^Rg，Rg = T + 1074
      （glibc：仅当结果非精确才置 ERANGE）}
    Rg := T + 1074;
    HexExact := True;
    if Rg >= 0 then begin
      { Rg ≤ 51-L（次正规域）→ 网格数 < 2^52：QWord 无溢出、无舍入、精确 }
      g := M shl Rg;
      Bits := g;
    end else begin
      BL := LongInt(-Rg);
      if BL >= 64 then begin
        { 网格数 < 0.5：舍入到 0（M<2^BL ⇒ rem<half）}
        g := 0;
        HexExact := False;
      end else begin
        g := M shr BL;
        remLW := M and ((QWord(1) shl BL) - 1);
        half := QWord(1) shl (BL - 1);
        if (remLW > half) or ((remLW = half) and ((g and 1) = 1)) then
          Inc(g);
        if remLW <> 0 then HexExact := False;
      end;
      if HexLost then HexExact := False; { 64-bit 截断也属非精确 }
      if g >= (QWord(1) shl 52) then
        Bits := $0010000000000000 { 进位到 DBL_MIN（正规下边界）}
      else
        Bits := g;
    end;
    Move(Bits, X, 8);
    if Neg then X := -X;
    if not HexExact then __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  { decimal: 扫描有效数字结构，同时预判量级 k（首位有效数字的 10 次幂）}
  I := 0;
  SigCount := 0;
  Di := 0;
  Df := 0;
  HasDecPoint := False;
  FirstSig := False;
  FirstInt := False;
  KIntBase := 0;
  k := 0;
  Mhi := 0;
  Mlo := 0;
  R := False;
  S60Len := 0;
  Beyond60 := False;
  while P^ <> #0 do begin
    if (P^ >= '0') and (P^ <= '9') then begin
      if I < 480 then begin Buf[I] := P^; Inc(I); end;
      if P^ <> '0' then AnyNonZero := True;
      HasDigits := True;
      if HasDecPoint then Inc(Df) else Inc(Di);
      if not FirstSig then begin
        if P^ <> '0' then begin
          FirstSig := True;
          if HasDecPoint then k := -Df
          else begin
            FirstInt := True;
            KIntBase := Di; { 首位有效时的整数位数，扫描后再定 k }
          end;
        end;
      end;
      if FirstSig then begin
        Inc(SigCount);
        if SigCount <= 60 then begin
          S60[SigCount - 1] := P^;
          if SigCount <= 15 then Mhi := Mhi * 10 + (Ord(P^) - 48)
          else if SigCount <= 20 then Mlo := Mlo * 10 + (Ord(P^) - 48);
        end else if P^ <> '0' then Beyond60 := True;
      end;
      Inc(P);
    end else if (P^ = '.') and (not HasDecPoint) then begin
      if I < 480 then begin Buf[I] := '.'; Inc(I); end;
      HasDecPoint := True;
      Inc(P);
    end else break;
  end;
  if FirstInt then k := Di - KIntBase;
  { exponent: consume only if followed by a valid exponent }
  ExpNegDec := False;
  Ei := 0;
  ExpSign := 1;
  HasExp := False;
  if ((P^ = 'e') or (P^ = 'E')) and (P[1] <> #0) and
     (((P[1] >= '0') and (P[1] <= '9')) or
      ((P[1] = '+') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9')) or
      ((P[1] = '-') and (P[2] <> #0) and (P[2] >= '0') and (P[2] <= '9'))) then
  begin
    HasExp := True;
    if I < 480 then begin Buf[I] := 'e'; Inc(I); end;
    Inc(P);
    if P^ = '+' then begin if I < 480 then begin Buf[I] := '+'; Inc(I); end; Inc(P); end
    else if P^ = '-' then begin
      ExpNegDec := True;
      ExpSign := -1;
      if I < 480 then begin Buf[I] := '-'; Inc(I); end;
      Inc(P);
    end;
    while P^ <> #0 do begin
      if (P^ >= '0') and (P^ <= '9') then begin
        if I < 480 then begin Buf[I] := P^; Inc(I); end;
        if Ei < 100000000000000 then
          Ei := Ei * 10 + (Ord(P^) - 48); { 饱和防 Int64 溢出 }
        Inc(P);
      end else break;
    end;
  end;
  if not HasDigits then begin
    { no conversion: DummyEnd = original nptr (C99) }
    if DummyEnd <> nil then DummyEnd^ := nptr;
    Result := 0.0;
    Exit;
  end;
  KTotal := k + ExpSign * Ei;
  { 溢出/下溢预判仅适用于非全零输入（全零不设 ERANGE、永不溢出/下溢）}
  if FirstSig then begin
    Overflow := KTotal > 308;
    if KTotal = 308 then begin
    if SigCount > 60 then S60Len := 60 else S60Len := SigCount;
    Cmp := CmpT60(S60, S60Len);
    Overflow := Cmp > 0;
  end;
    Underflow := KTotal < -324;
  end else begin
    Overflow := False;
    Underflow := False;
  end;
  Buf[I] := #0;
  if Overflow then begin
    X := 0.0;
    Bits := $7FF0000000000000;
    Move(Bits, X, 8); { +Inf }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if Underflow then begin
    X := 0.0;
    if Neg then X := -X; { -0.0 保留符号（C99）}
    if DummyEnd <> nil then DummyEnd^ := P;
    __errno_location()^ := 34;
    Result := X;
    Exit;
  end;
  if not FirstSig then begin
    { 全零：±0，不设 errno（0e999 等）}
    X := 0.0;
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 尾部补零：Mhi 15 位 / Mlo 5 位（M20 = MHw×1e5+MLw；SC>20 的
    截断误差 ≤ 10^-20 相对 << 0.5ulp，不影响舍入正确性）}
  if SigCount > 15 then begin SCh := 15; SCl := SigCount - 15; end
  else begin SCh := SigCount; SCl := 0; end;
  MHw := Mhi;
  MLw := Mlo;
  for I := SCh to 14 do MHw := MHw * 10;
  for I := SCl to 4 do MLw := MLw * 10;
  KIntL := KTotal - 19; { 表下标（值 = M20×10^KIntL）}
  { 合成双 double 尾数对：Wh+Wl = MHw×1e5 精确，WlB ≈ Wl + MLw = M20。
    单次幂乘吃全 20 位；两段独立幂乘相加会先丢 Mlo 低位再合并（1ulp 级）}
  TwoProd(Double(MHw), 100000.0, Wh, Wl);
  WlB := Wl + Double(MLw);
  if KIntL <= -308 then begin
    { BN 定点：网格数 = M20×B(KIntL)（B=10^K×2^1074 双 double，正规域），
      结果 = QN×2^-1074。覆盖次正规与 DBL_MIN 邻近（含舍入进位）}
    try
      XN := PmulB(Wh, WlB, KIntL);
    except
      ClearFPUFlags;
      XN := 0.0;
    end;
    { 直接 ×2^-1074 得结果：正规/次正规都由浮点精确舍入到网格。
      XN 误差 2^-104 相对 → 绝对 ~2^-1178 << 0.5 网格，舍入正确。
      不做网格整数拼接——QN 可达 2^114，Int64 的 Trunc 会硬件异常 }
    Bits := 1; { 2^-1074（最小次正规）}
    Move(Bits, F2, 8);
    X := XN * F2;
    Q64 := 0;
    Move(X, Q64, 8);
    if (Q64 and $7FF0000000000000) = 0 then
      __errno_location()^ := 34; { 十进制次正规无条件 ERANGE }
    if Neg then X := -X;
    if DummyEnd <> nil then DummyEnd^ := P;
    Result := X;
    Exit;
  end;
  { 主幂乘：值 = M20×10^KIntL（KIntL ∈ [-307, 289]，10^KIntL 正规 double）。
    双 double 单次幂乘 ~2^-106 相对误差，替代 FPC Val（其上溢/下溢/
    1ulp/MXCSR 均不可靠）}
  try
    X := Pmul(Wh, WlB, KIntL);
  except
    { 数学值 ∈ (DBL_MAX, DBL_MAX+0.5ulp]：C99 舍入到 DBL_MAX（不溢）}
    ClearFPUFlags;
    Q64 := $7FEFFFFFFFFFFFFF;
    Move(Q64, X, 8);
  end;
  if Neg then X := -X;
  if DummyEnd <> nil then DummyEnd^ := P;
  Q64 := 0;
  Move(X, Q64, 8);
  { 位模式后判定（幂乘正确性兜底；十进制仅次正规无条件 ERANGE）}
  if (Q64 = QWord($7FF0000000000000)) or (Q64 = QWord($FFF0000000000000)) then
    __errno_location()^ := 34
  else if (Q64 = 0) or (Q64 = QWord($8000000000000000)) then
    __errno_location()^ := 34
  else if (Q64 and $7FFFFFFFFFFFFFFF <> 0) and
          ((Q64 and $7FF0000000000000) = 0) then
    __errno_location()^ := 34;
  Result := X;
end;


function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Lim: QWord;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  if Neg then Lim := QWord(High(Int64)) + 1 { 2^63: LONG_MIN 幅度 }
  else Lim := QWord(High(Int64));
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (Lim - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE (glibc/msvcrt 均为 34) }
      Acc := Lim;
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then begin
    if Acc > QWord(High(Int64)) then Result := Low(Int64)
    else Result := -Int64(Acc);
  end else
    Result := Int64(Acc);
end;

function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl;
var
  P: PAnsiChar;
  Neg: Boolean;
  B: LongInt;
  Acc: QWord;
  D: LongInt;
  Converted: Boolean;
begin
  Result := 0;
  if nptr = nil then begin
    if endptr <> nil then endptr^ := nptr;
    Exit;
  end;
  P := nptr;
  while (P^ <> #0) and ((P^ = ' ') or (P^ = #9) or (P^ = #10) or
         (P^ = #11) or (P^ = #12) or (P^ = #13)) do Inc(P);
  Neg := False;
  if P^ = '+' then Inc(P)
  else if P^ = '-' then begin Neg := True; Inc(P); end;
  B := base;
  if B = 16 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then Inc(P, 2);
  end else if B = 0 then begin
    if (P^ = '0') and ((P[1] = 'x') or (P[1] = 'X')) then begin B := 16; Inc(P, 2); end
    else if P^ = '0' then B := 8
    else B := 10;
  end;
  Converted := False;
  Acc := 0;
  while P^ <> #0 do begin
    D := -1;
    if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
    else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
    else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
    if (D < 0) or (D >= B) then break;
    Converted := True;
    if Acc > (High(QWord) - QWord(D)) div QWord(B) then begin
      __errno_location()^ := 34; { ERANGE }
      Acc := High(QWord);
      Inc(P);
      while P^ <> #0 do begin
        D := -1;
        if (P^ >= '0') and (P^ <= '9') then D := Ord(P^) - 48
        else if (P^ >= 'a') and (P^ <= 'z') then D := Ord(P^) - 87
        else if (P^ >= 'A') and (P^ <= 'Z') then D := Ord(P^) - 55;
        if (D < 0) or (D >= B) then break;
        Inc(P);
      end;
      break;
    end;
    Acc := Acc * QWord(B) + QWord(D);
    Inc(P);
  end;
  if endptr <> nil then begin
    if Converted then endptr^ := P
    else endptr^ := nptr; { C99: 无转换时 endptr = 原 nptr }
  end;
  if Neg then Result := 0 - Acc { 负号环绕: "-1" → ULONG_MAX }
  else Result := Acc;
end;

var __c2p_rand_state: array[0..30] of LongWord;
    __c2p_rand_fptr: LongInt;
    __c2p_rand_rptr: LongInt;

function rand(): LongInt; cdecl;
var
  Val: QWord;
begin
  Val := (__c2p_rand_state[__c2p_rand_fptr] + __c2p_rand_state[__c2p_rand_rptr]) and $ffffffff;
  __c2p_rand_state[__c2p_rand_fptr] := LongWord(Val);
  Result := LongInt(Val shr 1);
  __c2p_rand_fptr := (__c2p_rand_fptr + 1) mod 31;
  __c2p_rand_rptr := (__c2p_rand_rptr + 1) mod 31;
end;

procedure srand(seed: LongWord); cdecl;
var
  W: Int64;
  I: LongInt;
begin
  if Seed = 0 then Seed := 1;
  __c2p_rand_state[0] := Seed;
  W := Seed;
  for I := 1 to 30 do
  begin
    W := (16807 * W) mod 2147483647;
    __c2p_rand_state[I] := LongWord(W);
  end;
  __c2p_rand_fptr := 3;
  __c2p_rand_rptr := 0;
  for I := 1 to 310 do
    rand();
end;

end.
