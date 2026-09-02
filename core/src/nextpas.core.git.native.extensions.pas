unit nextpas.core.git.native.extensions;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.revwalk,
  nextpas.core.git.native.archive,
  nextpas.core.git.native.submodule,
  nextpas.core.git.native.mailmap,
  nextpas.core.git.native.trailer,
  nextpas.core.git.native.bundle,
  nextpas.core.git.native.grep,
  nextpas.core.git.native.bisect,
  nextpas.core.git.native.attributes;

type
  TGitOid = nextpas.core.git.native.base.TGitOid;
  TGitSubmodule = nextpas.core.git.native.submodule.TGitSubmodule;
  TGitSubmoduleArray = nextpas.core.git.native.submodule.TGitSubmoduleArray;
  TGitMailmapEntry = nextpas.core.git.native.mailmap.TGitMailmapEntry;
  TGitMailmap = nextpas.core.git.native.mailmap.TGitMailmap;
  TGitTrailer = nextpas.core.git.native.trailer.TGitTrailer;
  TGitTrailerArray = nextpas.core.git.native.trailer.TGitTrailerArray;
  TGitBundleRef = nextpas.core.git.native.bundle.TGitBundleRef;
  TGitBundleRefArray = nextpas.core.git.native.bundle.TGitBundleRefArray;
  TGitBundlePrereq = nextpas.core.git.native.bundle.TGitBundlePrereq;
  TGitBundlePrereqArray = nextpas.core.git.native.bundle.TGitBundlePrereqArray;
  TGitBundleHeader = nextpas.core.git.native.bundle.TGitBundleHeader;
  TGitGrepHit = nextpas.core.git.native.grep.TGitGrepHit;
  TGitGrepHitArray = nextpas.core.git.native.grep.TGitGrepHitArray;
  TGitBisectCheck = nextpas.core.git.native.bisect.TGitBisectCheck;
  TGitBisectResult = nextpas.core.git.native.bisect.TGitBisectResult;
  TGitOidArray = nextpas.core.git.native.revwalk.TGitOidArray;
  TGitAttr = nextpas.core.git.native.attributes.TGitAttr;
  TGitAttrArray = nextpas.core.git.native.attributes.TGitAttrArray;
  TGitAttrEntry = nextpas.core.git.native.attributes.TGitAttrEntry;
  TGitAttrEntries = nextpas.core.git.native.attributes.TGitAttrEntries;
  TGitAttrKind = nextpas.core.git.native.attributes.TGitAttrKind;

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

function GitParseAttributes(const AText: string): TGitAttrEntries; overload; inline;
function GitParseAttributes(const AData: TBytes): TGitAttrEntries; overload; inline;
function GitLoadAttributes(const AGitDir: string): TGitAttrEntries; inline;
function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray; overload; inline;
function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray; overload; inline;
function GitAttributeGet(const AGitDir, APath, AName: string): string; overload; inline;
function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string; overload; inline;

implementation

function GitArchive(const AGitDir: string; const ATreeOid: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.archive.GitArchive(AGitDir, ATreeOid);
end;

function GitArchive(const AGitDir: string; const ACommitOid: TGitOid; APeelCommit: Boolean): TBytes; inline;
begin
  Result := nextpas.core.git.native.archive.GitArchive(AGitDir, ACommitOid, APeelCommit);
end;

function GitArchiveRef(const AGitDir, ARef: string): TBytes; inline;
begin
  Result := nextpas.core.git.native.archive.GitArchiveRef(AGitDir, ARef);
end;

function GitArchiveToFile(const AGitDir, ARef, AOutPath: string): string; inline;
begin
  Result := nextpas.core.git.native.archive.GitArchiveToFile(AGitDir, ARef, AOutPath);
end;

function GitParseGitModules(const AText: string): TGitSubmoduleArray; inline;
begin
  Result := nextpas.core.git.native.submodule.GitParseGitModules(AText);
end;

function GitParseGitModules(const AData: TBytes): TGitSubmoduleArray; inline;
begin
  Result := nextpas.core.git.native.submodule.GitParseGitModules(AData);
end;

function GitListSubmodules(const AGitDir: string): TGitSubmoduleArray; inline;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodules(AGitDir);
end;

function GitListSubmodulesAtTree(const AGitDir: string; const ATreeOid: TGitOid): TGitSubmoduleArray; inline;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodulesAtTree(AGitDir, ATreeOid);
end;

function GitListSubmodulesAtRef(const AGitDir, ARef: string): TGitSubmoduleArray; inline;
begin
  Result := nextpas.core.git.native.submodule.GitListSubmodulesAtRef(AGitDir, ARef);
end;

function GitSubmoduleAtPath(const AGitDir, APath: string): TGitSubmodule; inline;
begin
  Result := nextpas.core.git.native.submodule.GitSubmoduleAtPath(AGitDir, APath);
end;

function GitParseMailmap(const AText: string): TGitMailmap; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitParseMailmap(AText);
end;

function GitParseMailmap(const AData: TBytes): TGitMailmap; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitParseMailmap(AData);
end;

function GitLoadMailmap(const AGitDir: string): TGitMailmap; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitLoadMailmap(AGitDir);
end;

function GitMailmapResolve(const AMailmap: TGitMailmap; const AName, AEmail: string; out AOutName, AOutEmail: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolve(AMailmap, AName, AEmail, AOutName, AOutEmail);
end;

function GitMailmapResolveName(const AMailmap: TGitMailmap; const AName, AEmail: string): string; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolveName(AMailmap, AName, AEmail);
end;

function GitMailmapResolveEmail(const AMailmap: TGitMailmap; const AName, AEmail: string): string; inline;
begin
  Result := nextpas.core.git.native.mailmap.GitMailmapResolveEmail(AMailmap, AName, AEmail);
end;

function GitParseTrailers(const AMessage: string): TGitTrailerArray; inline;
begin
  Result := nextpas.core.git.native.trailer.GitParseTrailers(AMessage);
end;

function GitFindTrailer(const ATrailers: TGitTrailerArray; const AKey: string): string; inline;
begin
  Result := nextpas.core.git.native.trailer.GitFindTrailer(ATrailers, AKey);
end;

function GitHasTrailer(const ATrailers: TGitTrailerArray; const AKey: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.trailer.GitHasTrailer(ATrailers, AKey);
end;

function GitFormatTrailer(const AKey, AValue: string): string; inline;
begin
  Result := nextpas.core.git.native.trailer.GitFormatTrailer(AKey, AValue);
end;

function GitFormatTrailers(const ATrailers: TGitTrailerArray): string; inline;
begin
  Result := nextpas.core.git.native.trailer.GitFormatTrailers(ATrailers);
end;

function GitAppendTrailer(const AMessage, AKey, AValue: string): string; inline;
begin
  Result := nextpas.core.git.native.trailer.GitAppendTrailer(AMessage, AKey, AValue);
end;

function GitBundleCreate(const AGitDir, ARef, ABundlePath: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreate(AGitDir, ARef, ABundlePath);
end;

function GitBundleCreateFromRevs(const AGitDir: string; const ARevs: array of string; const ABundlePath: string): Integer; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreateFromRevs(AGitDir, ARevs, ABundlePath);
end;

function GitBundleCreateRange(const AGitDir, AFromRev, AToRev, ABundlePath: string): Integer; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleCreateRange(AGitDir, AFromRev, AToRev, ABundlePath);
end;

function GitBundleVerify(const ABundlePath: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleVerify(ABundlePath);
end;

function GitBundleList(const ABundlePath: string): TGitBundleRefArray; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleList(ABundlePath);
end;

function GitBundleParseHeader(const ABundlePath: string): TGitBundleHeader; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleParseHeader(ABundlePath);
end;

function GitBundleParseHeaderBytes(const AData: TBytes): TGitBundleHeader; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleParseHeaderBytes(AData);
end;

function GitBundleUnbundle(const ABundlePath, ATargetGitDir: string): Integer; inline;
begin
  Result := nextpas.core.git.native.bundle.GitBundleUnbundle(ABundlePath, ATargetGitDir);
end;

function GitGrep(const AGitDir, ARev, APattern: string): TGitGrepHitArray; inline;
begin
  Result := nextpas.core.git.native.grep.GitGrep(AGitDir, ARev, APattern);
end;

function GitGrep(const AGitDir, ARev, APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; inline;
begin
  Result := nextpas.core.git.native.grep.GitGrep(AGitDir, ARev, APattern, AIgnoreCase);
end;

function GitGrepTree(const AGitDir: string; const ATreeOid: TGitOid; const APattern: string; AIgnoreCase: Boolean): TGitGrepHitArray; inline;
begin
  Result := nextpas.core.git.native.grep.GitGrepTree(AGitDir, ATreeOid, APattern, AIgnoreCase);
end;

function GitBisectCandidates(const AGitDir, AGoodRev, ABadRev: string): TGitOidArray; inline;
begin
  Result := nextpas.core.git.native.bisect.GitBisectCandidates(AGitDir, AGoodRev, ABadRev);
end;

function GitBisectFind(const AGitDir: string; const AGoodRev, ABadRev: string; ACheck: TGitBisectCheck): TGitBisectResult; inline;
begin
  Result := nextpas.core.git.native.bisect.GitBisectFind(AGitDir, AGoodRev, ABadRev, ACheck);
end;

function GitParseAttributes(const AText: string): TGitAttrEntries; inline;
begin
  Result := nextpas.core.git.native.attributes.GitParseAttributes(AText);
end;

function GitParseAttributes(const AData: TBytes): TGitAttrEntries; inline;
begin
  Result := nextpas.core.git.native.attributes.GitParseAttributes(AData);
end;

function GitLoadAttributes(const AGitDir: string): TGitAttrEntries; inline;
begin
  Result := nextpas.core.git.native.attributes.GitLoadAttributes(AGitDir);
end;

function GitAttributesFor(const AGitDir, APath: string): TGitAttrArray; inline;
begin
  Result := nextpas.core.git.native.attributes.GitAttributesFor(AGitDir, APath);
end;

function GitAttributesFor(const AEntries: TGitAttrEntries; const APath: string): TGitAttrArray; inline;
begin
  Result := nextpas.core.git.native.attributes.GitAttributesFor(AEntries, APath);
end;

function GitAttributeGet(const AGitDir, APath, AName: string): string; inline;
begin
  Result := nextpas.core.git.native.attributes.GitAttributeGet(AGitDir, APath, AName);
end;

function GitAttributeGet(const AEntries: TGitAttrEntries; const APath, AName: string): string; inline;
begin
  Result := nextpas.core.git.native.attributes.GitAttributeGet(AEntries, APath, AName);
end;

end.
