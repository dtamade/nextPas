unit nextpas.core.git.native;

{$I nextpas.core.settings.inc}

{**
 * @desc Pure-Pascal git subfamily thin BC gateway — object-layer duplicate collapsed.
 *  Owner boundary: `nextpas.core.git.native.objects` is the single source for
 *  object-layer (oid/zlib/loose/pack/refs/objmodel/write); `native` retains only
 *  type/const re-exports for BC (fan-in = 1: objects → owners). New code must use
 *  `nextpas.core.git.native.objects` directly for all object-layer functions.
 *  Extended domains are shard facades (staging/history/branches/transport/extensions)
 *  and must be used directly (`uses nextpas.core.git.native.staging` etc.);
 *  legacy `uses nextpas.core.git.native` for those domains is deprecated.
 *  Perf: object-layer `inline` + zero-copy (Move/PByte+Len/TByteSpan via bytes.ops
 *  single source) lives single-sourced in `native.objects`; this shim holds zero
 *  inline forwards to avoid I-Cache duplication and double thin gateway.
 *  Stability: TPackFile owns IMappedFile (refcounted, auto released on Free);
 *  TBytes refcounted, exception-safe (no manual free leak).
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.objects;

type
  { Re-export core object types (single source via objects shard) — BC shim, prefer objects directly }
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

{ Object-layer functions: single-sourced in nextpas.core.git.native.objects.
  Use that unit directly (inline + zero-copy via bytes.ops, PByte+Len/TByteSpan,
  Move 20B oid, Adler32/Deflate via compress/checksum single source) to avoid
  double thin gateway and I-Cache duplication. This shim intentionally exposes
  no function forwards; see objects.pas for the authoritative inline impl. }

implementation

end.
