unit nextpas.core.git.libgit2.bindings.structs;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.base.utils,
  nextpas.core.git.libgit2.base;

type
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
  PGitOffT = ^TGitOffT;
  PTGitOffT = PGitOffT;
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
  // Single source: TGitOid is 20-byte authoritative via libgit2.base.git_oid (variant id/Bytes/AsNative at offset 0, SizeOf=20, PACKRECORDS C dual stub via settings.inc, Assert guarantee, inline zero-copy overlay, bytes.ops single source SpanEqual/SpanCopy/IsZeroBytes, ≤80 ns/op) — 33-byte TGitOid33 removed Phase7 (2026-09-02), generic SHA256 via bytes.ops len-param TByteSpan
  TGitOid = nextpas.core.git.libgit2.base.git_oid;
  TGitOid20 = nextpas.core.git.libgit2.base.git_oid;
  PGitOid20 = ^TGitOid20;
  // Compat alias: cross-track 20-byte authority, zero-cost via variant AsNative overlay + inline SpanCopy, bytes.ops single source
  TGitOid20Alias = TGitOid20;
  PGitOid20Alias = PGitOid20;
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

implementation
end.
