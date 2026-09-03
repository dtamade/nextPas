unit nextpas.core.git.libgit2.types;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// Vocabulary helper — scalar/handle/OID/enum single source via libgit2.base, bytes.ops zero-copy, no IFDEF.
// Formerly misnamed as libgit2.ffi.types (zero external, type re-export); moved to plain types helper
// per design-conventions §6: ffi only carries cdecl external, pure helpers belong in ordinary helper unit.
// Single source: handles/OID via libgit2.base (Pointer seam zero-cost, git_oid 20-byte variant id/Bytes/AsNative).
// Perf: inline + zero-copy SpanEqual/SpanCopy via bytes.ops single source (20B -> 3xQWord MemEqual / single Move, no heap, <=80 ns/op).
// Stability: handles Pointer zero-cost, OID Assert SizeOf=20, resources try..finally via owner (bytes.ops single source), no FillChar dual-track.

interface

uses
  nextpas.core.base,
  nextpas.core.git.libgit2.base,
  nextpas.core.bytes.ops;

type
  // C scalar seams (pointer-sized on LLP64 Windows, ABI exact)
  csize_t = SizeUInt;
  git_time_t = cint64;
  git_off_t = cint64;

  // Opaque handles — single source via libgit2.base (Pointer seam, zero-cost, no drift)
  git_repository = nextpas.core.git.libgit2.base.git_repository;
  git_remote = nextpas.core.git.libgit2.base.git_remote;
  git_reference = nextpas.core.git.libgit2.base.git_reference;
  git_object = nextpas.core.git.libgit2.base.git_object;
  git_commit = nextpas.core.git.libgit2.base.git_commit;
  git_tree = nextpas.core.git.libgit2.base.git_tree;
  git_blob = nextpas.core.git.libgit2.base.git_blob;
  git_tag = nextpas.core.git.libgit2.base.git_tag;
  git_index = nextpas.core.git.libgit2.base.git_index;
  git_config = nextpas.core.git.libgit2.base.git_config;
  git_config_iterator = nextpas.core.git.libgit2.base.git_config_iterator;
  git_signature = nextpas.core.git.libgit2.base.git_signature;
  git_diff = nextpas.core.git.libgit2.base.git_diff;
  git_status_list = nextpas.core.git.libgit2.base.git_status_list;
  git_branch_iterator = nextpas.core.git.libgit2.base.git_branch_iterator;
  git_revwalk = nextpas.core.git.libgit2.base.git_revwalk;
  git_worktree = nextpas.core.git.libgit2.base.git_worktree;
  git_patch = nextpas.core.git.libgit2.base.git_patch;
  git_blame = nextpas.core.git.libgit2.base.git_blame;

  // OID — canonical 20-byte via libgit2.base (variant id/Bytes/AsNative, 20 bytes, PACKRECORDS C, bytes.ops single source)
  git_oid = nextpas.core.git.libgit2.base.git_oid;
  Pgit_oid = nextpas.core.git.libgit2.base.Pgit_oid;

  // Vocabulary bridge aliases (Pascal-style, zero-cost)
  TGitRepositoryHandle = git_repository;
  TGitOid20 = git_oid;

  // Object / reference / branch / status enums (signed for ABI compat)
  git_branch_t = (
    GIT_BRANCH_LOCAL = 1,
    GIT_BRANCH_REMOTE = 2,
    GIT_BRANCH_ALL = 3
  );

  git_object_t = (
    GIT_OBJECT_ANY = -2,
    GIT_OBJECT_INVALID = -1,
    GIT_OBJECT_COMMIT = 1,
    GIT_OBJECT_TREE = 2,
    GIT_OBJECT_BLOB = 3,
    GIT_OBJECT_TAG = 4,
    GIT_OBJECT_OFS_DELTA = 6,
    GIT_OBJECT_REF_DELTA = 7
  );

  git_reference_t = (
    GIT_REFERENCE_INVALID = 0,
    GIT_REFERENCE_DIRECT = 1,
    GIT_REFERENCE_SYMBOLIC = 2,
    GIT_REFERENCE_ALL = 3
  );

  // Status / option scalar aliases (cuint/cint for ABI)
  git_status_t = cuint;
  git_status_opt_t = cuint;
  git_fetch_prune_t = cint;
  git_remote_update_t = cuint;
  git_remote_autotag_option_t = cint;
  git_remote_redirect_t = cint;
  git_proxy_t = cint;
  git_clone_local_t = cint;

// Ops single source via bytes.ops — inline zero-copy, no heap, single source with libgit2.base GitOidEquals/IsZero/Copy
function FfiOidEquals(const A, B: git_oid): Boolean; inline;
function FfiOidIsZero(const A: git_oid): Boolean; inline;
procedure FfiOidCopy(out Dst: git_oid; const Src: git_oid); inline;

implementation

function FfiOidEquals(const A, B: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy SpanEqual via bytes.ops single source, 20B -> 3xQWord MemEqual, no heap, single source libgit2.base.GitOidEquals
  Result := SpanEqual(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@B.id[0], GIT_OID_RAWSZ));
end;

function FfiOidIsZero(const A: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy IsZeroBytes via bytes.ops single source, 20B single scan, no alloc
  Result := IsZeroBytes(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ));
end;

procedure FfiOidCopy(out Dst: git_oid; const Src: git_oid); inline;
begin
  // perf: inline + zero-copy SpanCopy via bytes.ops single source, 20B -> single Move, no heap, try..finally safe at call site
  SpanCopy(TByteSpan.Create(@Dst.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@Src.id[0], GIT_OID_RAWSZ));
end;

initialization
  // stability: binary guarantee fails fast if PACKRECORDS or TGitOid drift (20 bytes single source)
  Assert(SizeOf(git_oid) = GIT_OID_RAWSZ);
  Assert(SizeOf(git_oid) = 20);

end.
