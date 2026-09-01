unit nextpas.core.git.libgit2.base;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.git.native.base,
  nextpas.core.bytes.ops;

const
  // Single source: OID sizes reuse native.base (GitOidRawLen = 20)
  GIT_OID_RAWSZ = nextpas.core.git.native.base.GitOidRawLen;
  GIT_OID_SHA1_SIZE = nextpas.core.git.native.base.GitOidRawLen;
  GIT_OID_MAX_SIZE = 32;

type
  // Shared opaque handles (Pointer seam, zero-cost)
  git_repository = Pointer;
  git_remote = Pointer;
  git_reference = Pointer;
  git_object = Pointer;
  git_commit = Pointer;
  git_tree = Pointer;
  git_blob = Pointer;
  git_tag = Pointer;
  git_index = Pointer;
  git_config = Pointer;
  git_diff = Pointer;
  git_patch = Pointer;
  git_revwalk = Pointer;
  git_worktree = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_config_iterator = Pointer;
  git_signature = Pointer;

  // Single source: canonical SHA1 OID (20 bytes) via native.base.TGitOid.
  // Variant exposes both C `id` and Pascal `Bytes` zero-cost overlay; binary-identical, no branch.
  git_oid = record
    case Integer of
      0: (id: array[0..19] of Byte;);
      1: (Bytes: array[0..19] of Byte;);
  end;
  Pgit_oid = ^git_oid;
  // Legacy static-track OID (type prefix + 32 bytes) - SHA256-ready padded, not default TGitOid
  TGitOid33 = record
    &type: Byte;
    id: array[0..31] of Byte;
  end;
  PGitOid33 = ^TGitOid33;
  // Single source alias: TGitOid is native 20-byte (not 33-byte); TGitOid33 retained for compat
  TGitOid = nextpas.core.git.native.base.TGitOid;
  PGitOid = ^TGitOid;
  // Compat alias for libgit2 consumers expecting 20-byte via Pascal name
  TGitOid20 = git_oid;
  PGitOid20 = ^TGitOid20;

function GitOid20Equals(const A, B: git_oid): Boolean; inline;
function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
procedure GitOid20Copy(out Dst: git_oid; const Src: git_oid); inline;
procedure GitOidCopy20To33(out Dst: TGitOid33; const Src: git_oid); inline;
procedure GitOidCopy33To20(out Dst: git_oid; const Src: TGitOid33); inline;
function GitOidToNative(const A: git_oid): TGitOid; inline;
function NativeToGitOid(const A: TGitOid): git_oid; inline;
function GitOidSameNative(const A, B: TGitOid): Boolean; inline;

// Canonical generic OID ops (base/ops single source via bytes.ops, inline zero-copy, no heap)
function GitOidEquals(const A, B: git_oid): Boolean; inline;
function GitOidIsZero(const A: git_oid): Boolean; inline;
procedure GitOidCopy(out Dst: git_oid; const Src: git_oid); inline;
// Compatibility Inline-suffix aliases (moved from ffi, single source via base)
function GitOidEqualsInline(const A, B: git_oid): Boolean; inline;
function GitOidIsZeroInline(const A: git_oid): Boolean; inline;
procedure GitOidCopyInline(out Dst: git_oid; const Src: git_oid); inline;

type
  { ops Helper: record helper for git_oid, zero-copy via bytes.ops single source }
  TGitOidHelper = record helper for git_oid
    function Equals(const AOther: git_oid): Boolean; inline;
    function IsZero: Boolean; inline;
    procedure Assign(const ASrc: git_oid); inline;
  end;

implementation

function GitOid20Equals(const A, B: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy via bytes.ops SpanEqual single source, 20 bytes -> 3x QWord, alias to GitOidEquals
  Result := GitOidEquals(A, B);
end;

function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
begin
  // perf: inline + single CompareMem after type byte, zero-copy
  Result := (A.&type = B.&type) and CompareMem(@A.id[0], @B.id[0], GIT_OID_MAX_SIZE);
end;

procedure GitOid20Copy(out Dst: git_oid; const Src: git_oid); inline;
begin
  // perf: inline + single Move zero-copy (bytes.ops single source), alias to GitOidCopy
  GitOidCopy(Dst, Src);
end;

procedure GitOidCopy20To33(out Dst: TGitOid33; const Src: git_oid); inline;
begin
  Dst.&type := 1; // GIT_OID_SHA1
  Move(Src.id[0], Dst.id[0], GIT_OID_RAWSZ);
  FillChar(Dst.id[GIT_OID_RAWSZ], GIT_OID_MAX_SIZE - GIT_OID_RAWSZ, 0);
end;

procedure GitOidCopy33To20(out Dst: git_oid; const Src: TGitOid33); inline;
begin
  Move(Src.id[0], Dst.id[0], GIT_OID_RAWSZ);
end;

function GitOidToNative(const A: git_oid): TGitOid; inline;
begin
  // zero-copy: same 20 bytes, single Move single source (native.base Bytes == git_oid.id overlay)
  Move(A.id[0], Result.Bytes[0], GIT_OID_RAWSZ);
end;

function NativeToGitOid(const A: TGitOid): git_oid; inline;
begin
  Move(A.Bytes[0], Result.id[0], GIT_OID_RAWSZ);
end;

function GitOidSameNative(const A, B: TGitOid): Boolean; inline;
begin
  // single source: delegates to native.base GitOidSame (which uses bytes.ops CompareMem)
  Result := nextpas.core.git.native.base.GitOidSame(A, B);
end;

function GitOidEquals(const A, B: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy SpanEqual via bytes.ops MemEqual, 20 bytes -> 3x QWord, no heap/SysUtils, single source
  Result := SpanEqual(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@B.id[0], GIT_OID_RAWSZ));
end;

function GitOidIsZero(const A: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy TByteSpan view via bytes.ops IsZeroBytes single source, 20 bytes single scan, no alloc
  Result := IsZeroBytes(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ));
end;

procedure GitOidCopy(out Dst: git_oid; const Src: git_oid); inline;
begin
  // perf: inline + single Move zero-copy (bytes.ops single source), no heap
  Move(Src.id[0], Dst.id[0], GIT_OID_RAWSZ);
end;

function GitOidEqualsInline(const A, B: git_oid): Boolean; inline;
begin
  // compatibility alias: single source via GitOidEquals (bytes.ops)
  Result := GitOidEquals(A, B);
end;

function GitOidIsZeroInline(const A: git_oid): Boolean; inline;
begin
  Result := GitOidIsZero(A);
end;

procedure GitOidCopyInline(out Dst: git_oid; const Src: git_oid); inline;
begin
  GitOidCopy(Dst, Src);
end;

{ TGitOidHelper }

function TGitOidHelper.Equals(const AOther: git_oid): Boolean; inline;
begin
  // perf: inline helper delegates to bytes.ops SpanEqual single source
  Result := GitOidEquals(Self, AOther);
end;

function TGitOidHelper.IsZero: Boolean; inline;
begin
  Result := GitOidIsZero(Self);
end;

procedure TGitOidHelper.Assign(const ASrc: git_oid); inline;
begin
  GitOidCopy(Self, ASrc);
end;

end.
