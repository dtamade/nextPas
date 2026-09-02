unit nextpas.core.git.libgit2.ffi.types;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// Scalar + handle + OID vocabulary — single source via libgit2.base, bytes.ops zero-copy, no IFDEF.

interface

uses
  nextpas.core.base,
  nextpas.core.git.libgit2.base;

type
  // C scalar seams (pointer-sized on LLP64 Windows)
  csize_t = SizeUInt;
  git_time_t = cint64;
  git_off_t = cint64;

  // Opaque handles (Pointer seam, zero-cost)
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
  git_config_iterator = Pointer;
  git_signature = Pointer;
  git_diff = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_revwalk = Pointer;
  git_worktree = Pointer;
  git_patch = Pointer;
  git_blame = Pointer;

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

implementation

end.
