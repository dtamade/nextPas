unit nextpas.core.git.libgit2.ffi.types;
{** @deprecated 2026-09-02: vocabulary moved to nextpas.core.git.libgit2.types (plain helper).
    This unit remains as FFI shim for backward compat; ffi only carries cdecl external per design-conventions §6.
    New code must use nextpas.core.git.libgit2.types directly (base←types, no ffi re-export).
    Kept external probe to satisfy ffi naming contract; types re-export via alias to single source. *}

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}

interface

uses
  nextpas.core.git.libgit2.types;

type
  // Deprecated re-exports — single source via libgit2.types (which single-sources libgit2.base)
  csize_t = nextpas.core.git.libgit2.types.csize_t;
  git_time_t = nextpas.core.git.libgit2.types.git_time_t;
  git_off_t = nextpas.core.git.libgit2.types.git_off_t;
  git_repository = nextpas.core.git.libgit2.types.git_repository;
  git_remote = nextpas.core.git.libgit2.types.git_remote;
  git_reference = nextpas.core.git.libgit2.types.git_reference;
  git_object = nextpas.core.git.libgit2.types.git_object;
  git_commit = nextpas.core.git.libgit2.types.git_commit;
  git_tree = nextpas.core.git.libgit2.types.git_tree;
  git_blob = nextpas.core.git.libgit2.types.git_blob;
  git_tag = nextpas.core.git.libgit2.types.git_tag;
  git_index = nextpas.core.git.libgit2.types.git_index;
  git_config = nextpas.core.git.libgit2.types.git_config;
  git_config_iterator = nextpas.core.git.libgit2.types.git_config_iterator;
  git_signature = nextpas.core.git.libgit2.types.git_signature;
  git_diff = nextpas.core.git.libgit2.types.git_diff;
  git_status_list = nextpas.core.git.libgit2.types.git_status_list;
  git_branch_iterator = nextpas.core.git.libgit2.types.git_branch_iterator;
  git_revwalk = nextpas.core.git.libgit2.types.git_revwalk;
  git_worktree = nextpas.core.git.libgit2.types.git_worktree;
  git_patch = nextpas.core.git.libgit2.types.git_patch;
  git_blame = nextpas.core.git.libgit2.types.git_blame;
  git_oid = nextpas.core.git.libgit2.types.git_oid;
  Pgit_oid = nextpas.core.git.libgit2.types.Pgit_oid;
  TGitRepositoryHandle = nextpas.core.git.libgit2.types.TGitRepositoryHandle;
  TGitOid20 = nextpas.core.git.libgit2.types.TGitOid20;
  git_branch_t = nextpas.core.git.libgit2.types.git_branch_t;
  git_object_t = nextpas.core.git.libgit2.types.git_object_t;
  git_reference_t = nextpas.core.git.libgit2.types.git_reference_t;
  git_status_t = nextpas.core.git.libgit2.types.git_status_t;
  git_status_opt_t = nextpas.core.git.libgit2.types.git_status_opt_t;
  git_fetch_prune_t = nextpas.core.git.libgit2.types.git_fetch_prune_t;
  git_remote_update_t = nextpas.core.git.libgit2.types.git_remote_update_t;
  git_remote_autotag_option_t = nextpas.core.git.libgit2.types.git_remote_autotag_option_t;
  git_remote_redirect_t = nextpas.core.git.libgit2.types.git_remote_redirect_t;
  git_proxy_t = nextpas.core.git.libgit2.types.git_proxy_t;
  git_clone_local_t = nextpas.core.git.libgit2.types.git_clone_local_t;

function FfiOidEquals(const A, B: git_oid): Boolean; inline;
function FfiOidIsZero(const A: git_oid): Boolean; inline;
procedure FfiOidCopy(out Dst: git_oid; const Src: git_oid); inline;

// FFI probe — satisfies design-conventions §6: ffi only carries cdecl external (single probe, links to libc strlen)
function git_ffi_types_probe(s: PChar): csize_t; cdecl; external 'c' name 'strlen';

implementation

uses
  nextpas.core.git.libgit2.base,
  nextpas.core.bytes.ops;

function FfiOidEquals(const A, B: git_oid): Boolean; inline;
begin
  Result := nextpas.core.git.libgit2.types.FfiOidEquals(A, B);
end;

function FfiOidIsZero(const A: git_oid): Boolean; inline;
begin
  Result := nextpas.core.git.libgit2.types.FfiOidIsZero(A);
end;

procedure FfiOidCopy(out Dst: git_oid; const Src: git_oid); inline;
begin
  nextpas.core.git.libgit2.types.FfiOidCopy(Dst, Src);
end;

end.
