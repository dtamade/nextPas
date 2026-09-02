unit nextpas.core.git.native.transport;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
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
  nextpas.core.git.native.revparse;

type
  TGitOid = nextpas.core.git.native.base.TGitOid;
  TGitWorktree = nextpas.core.git.native.worktree.TGitWorktree;
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
  gasNak = nextpas.core.git.native.negotiate.gasNak;
  gasAck = nextpas.core.git.native.negotiate.gasAck;
  gasCommon = nextpas.core.git.native.negotiate.gasCommon;
  gasContinue = nextpas.core.git.native.negotiate.gasContinue;
  gasReady = nextpas.core.git.native.negotiate.gasReady;

  gsbData = nextpas.core.git.native.sideband.gsbData;
  gsbProgress = nextpas.core.git.native.sideband.gsbProgress;
  gsbError = nextpas.core.git.native.sideband.gsbError;

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

implementation

function GitConfigPath(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigPath(AGitDir);
end;

function GitConfigExists(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigExists(AGitDir);
end;

function GitParseConfig(const AData: TBytes): TGitConfig; inline;
begin
  Result := nextpas.core.git.native.config.GitParseConfig(AData);
end;

function GitReadConfig(const AGitDir: string): TGitConfig; inline;
begin
  Result := nextpas.core.git.native.config.GitReadConfig(AGitDir);
end;

function GitConfigHas(const AConfig: TGitConfig; const AKey: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigHas(AConfig, AKey);
end;

function GitConfigGet(const AConfig: TGitConfig; const AKey: string): string; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigGet(AConfig, AKey);
end;

function GitConfigGetAll(const AConfig: TGitConfig; const AKey: string): TStringArray; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigGetAll(AConfig, AKey);
end;

function GitConfigGetBool(const AConfig: TGitConfig; const AKey: string; out AValue: Boolean): Boolean; inline;
begin
  Result := nextpas.core.git.native.config.GitConfigGetBool(AConfig, AKey, AValue);
end;

function GitPktEncode(const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncode(AData);
end;

function GitPktEncodeStr(const AText: string): TBytes; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeStr(AText);
end;

function GitPktEncodeFlush: TBytes; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeFlush;
end;

function GitPktEncodeDelim: TBytes; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktEncodeDelim;
end;

function GitPktDecode(const AFrame: TBytes; out APkt: TGitPkt): Boolean; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktDecode(AFrame, APkt);
end;

function GitPktIsFlush(const AFrame: TBytes): Boolean; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktIsFlush(AFrame);
end;

function GitPktIsDelim(const AFrame: TBytes): Boolean; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktIsDelim(AFrame);
end;

function GitPktScan(const AStream: TBytes): TGitPktArray; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktScan(AStream);
end;

function GitPktJoin(const APkts: TGitPktArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.pktline.GitPktJoin(APkts);
end;

function GitRemoteList(const AGitDir: string): TGitRemoteArray; inline;
begin
  Result := nextpas.core.git.native.remote.GitRemoteList(AGitDir);
end;

function GitRemoteFind(const AGitDir: string; const AName: string; out ARemote: TGitRemote): Boolean; inline;
begin
  Result := nextpas.core.git.native.remote.GitRemoteFind(AGitDir, AName, ARemote);
end;

function GitRemoteCount(const AGitDir: string): Integer; inline;
begin
  Result := nextpas.core.git.native.remote.GitRemoteCount(AGitDir);
end;

function GitRemoteUrl(const AGitDir: string; const AName: string): string; inline;
begin
  Result := nextpas.core.git.native.remote.GitRemoteUrl(AGitDir, AName);
end;

function GitParseAdvertise(const AStream: TBytes): TGitAdvertised; inline;
begin
  Result := nextpas.core.git.native.advertise.GitParseAdvertise(AStream);
end;

function GitParseAdvertisedRefs(const AStream: TBytes): TGitAdvertisedRefArray; inline;
begin
  Result := nextpas.core.git.native.advertise.GitParseAdvertisedRefs(AStream);
end;

function GitAdvertiseFind(const AAdv: TGitAdvertised; const AName: string; out ARef: TGitAdvertisedRef): Boolean; inline;
begin
  Result := nextpas.core.git.native.advertise.GitAdvertiseFind(AAdv, AName, ARef);
end;

function GitHasCapability(const AAdv: TGitAdvertised; const ACap: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.advertise.GitHasCapability(AAdv, ACap);
end;

function GitEncodeWant(const AOid: TGitOid; const ACaps: TStringArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWant(AOid, ACaps);
end;

function GitEncodeWantSimple(const AOid: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWantSimple(AOid);
end;

function GitEncodeWants(const AOids: array of TGitOid; const ACaps: TStringArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeWants(AOids, ACaps);
end;

function GitEncodeHave(const AOid: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeHave(AOid);
end;

function GitEncodeDone: TBytes; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitEncodeDone;
end;

function GitParseAck(const AData: TBytes; out AAck: TGitAck): Boolean; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAck(AData, AAck);
end;

function GitParseAckLine(const ALine: string; out AAck: TGitAck): Boolean; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAckLine(ALine, AAck);
end;

function GitParseAckStream(const AStream: TBytes): TGitAckArray; inline;
begin
  Result := nextpas.core.git.native.negotiate.GitParseAckStream(AStream);
end;

function GitSidebandEncode(AKind: TGitSidebandKind; const AData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandEncode(AKind, AData);
end;

function GitSidebandEncodeStr(AKind: TGitSidebandKind; const AText: string): TBytes; inline;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandEncodeStr(AKind, AText);
end;

function GitSidebandDecode(const APktData: TBytes; out AKind: TGitSidebandKind; out APayload: TBytes): Boolean; inline;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandDecode(APktData, AKind, APayload);
end;

procedure GitSidebandDemux(const AStream: TBytes; out ADemuxed: TGitSidebandDemuxed); inline;
begin
  nextpas.core.git.native.sideband.GitSidebandDemux(AStream, ADemuxed);
end;

function GitSidebandDemuxRaw(const AStream: TBytes): TGitSidebandArray; inline;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandDemuxRaw(AStream);
end;

function GitSidebandJoin(const AEntries: TGitSidebandArray): TBytes; inline;
begin
  Result := nextpas.core.git.native.sideband.GitSidebandJoin(AEntries);
end;

function GitBuildPackIndex(const APackData: TBytes): TBytes; inline;
begin
  Result := nextpas.core.git.native.indexer.GitBuildPackIndex(APackData);
end;

function GitBuildPackIndexFile(const APackPath: string): string; inline;
begin
  Result := nextpas.core.git.native.indexer.GitBuildPackIndexFile(APackPath);
end;

function GitPackIndexPath(const APackPath: string): string; inline;
begin
  Result := nextpas.core.git.native.indexer.GitPackIndexPath(APackPath);
end;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPack(ARemoteGitDir, AWants);
end;

function GitFetchPack(const ARemoteGitDir: string; const AWants: array of TGitOid; const AHaves: array of TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPack(ARemoteGitDir, AWants, AHaves);
end;

function GitFetchPackSingle(const ARemoteGitDir: string; const AWant: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.fetch.GitFetchPackSingle(ARemoteGitDir, AWant);
end;

function GitLsRemote(const ARemoteGitDir: string): TGitAdvertised; inline;
begin
  Result := nextpas.core.git.native.clone.GitLsRemote(ARemoteGitDir);
end;

function GitCloneBare(const ARemoteGitDir, ALocalGitDir: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.clone.GitCloneBare(ARemoteGitDir, ALocalGitDir);
end;

function GitCloneBareHead(const ARemoteGitDir, ALocalGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.clone.GitCloneBareHead(ARemoteGitDir, ALocalGitDir);
end;

function GitClone(const ARemoteGitDir, ALocalWorkTree: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.clone.GitClone(ARemoteGitDir, ALocalWorkTree);
end;

function GitCloneHead(const ARemoteGitDir, ALocalWorkTree: string): string; inline;
begin
  Result := nextpas.core.git.native.clone.GitCloneHead(ARemoteGitDir, ALocalWorkTree);
end;

procedure GitCheckoutTree(const AGitDir, AWorkTree: string; const ATreeOid: TGitOid); inline;
begin
  nextpas.core.git.native.checkout.GitCheckoutTree(AGitDir, AWorkTree, ATreeOid);
end;

procedure GitCheckoutHead(const AGitDir, AWorkTree: string); inline;
begin
  nextpas.core.git.native.checkout.GitCheckoutHead(AGitDir, AWorkTree);
end;

function GitCheckoutCommit(const AGitDir, AWorkTree: string; const ACommitOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.checkout.GitCheckoutCommit(AGitDir, AWorkTree, ACommitOid);
end;

function GitCheckoutRef(const AGitDir, AWorkTree, ARefName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.checkout.GitCheckoutRef(AGitDir, AWorkTree, ARefName);
end;

function GitOidZero: TGitOid; inline;
begin
  Result := nextpas.core.git.native.push.GitOidZero;
end;

function GitOidIsZero(const AOid: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.push.GitOidIsZero(AOid);
end;

function GitPush(const ALocalGitDir, ARemoteGitDir, ARefName: string; const AOldOid, ANewOid: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.push.GitPush(ALocalGitDir, ARemoteGitDir, ARefName, AOldOid, ANewOid);
end;

function GitPush(const ALocalGitDir, ARemoteGitDir: string; const AUpdates: array of TGitPushUpdate): Boolean; inline;
begin
  Result := nextpas.core.git.native.push.GitPush(ALocalGitDir, ARemoteGitDir, AUpdates);
end;

function GitPushBranch(const ALocalGitDir, ARemoteGitDir, ABranchName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.push.GitPushBranch(ALocalGitDir, ARemoteGitDir, ABranchName);
end;

function GitResetHard(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.reset.GitResetHard(AGitDir, AWorkTree, ATargetOid);
end;

function GitResetHard(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.reset.GitResetHard(AGitDir, AWorkTree, ATargetRef);
end;

function GitRemotePrune(const ALocalGitDir, ARemoteName: string): TStringArray; inline;
begin
  { perf: inline thin forward to owner prune; zero-copy TStringArray CoW, bytes.ops not needed, single-source owner via nextpas.core.git.native.prune }
  Result := nextpas.core.git.native.prune.GitRemotePrune(ALocalGitDir, ARemoteName);
end;

function GitClean(const AGitDir, AWorkTree: string): TStringArray; inline;
begin
  { inline + zero-copy TStringArray CoW; single-source owner clean via bytes.ops scan, no alloc until delete }
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored);
end;

function GitClean(const AGitDir, AWorkTree: string; ARemoveDirs, ARemoveIgnored, ADryRun: Boolean): TStringArray; inline;
begin
  Result := nextpas.core.git.native.clean.GitClean(AGitDir, AWorkTree, ARemoveDirs, ARemoveIgnored, ADryRun);
end;

function GitRevParse(const AGitDir, ARev: string): TGitOid; inline;
begin
  { perf: inline + zero-copy TGitOid 20B Move via bytes.ops SpanCopy single source, owner revparse }
  Result := nextpas.core.git.native.revparse.GitRevParse(AGitDir, ARev);
end;

function GitRevParseCommit(const AGitDir, ARev: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.revparse.GitRevParseCommit(AGitDir, ARev);
end;

end.
