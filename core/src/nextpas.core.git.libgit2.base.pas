unit nextpas.core.git.libgit2.base;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils;

const
  // Canonical OID sizes: runtime track (SHA1 20) vs static track (type+32 SHA256-ready 33)
  GIT_OID_RAWSZ = 20;
  GIT_OID_SHA1_SIZE = 20;
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

  // Canonical SHA1 OID (runtime/tracked, 20 bytes) - ffi owner
  git_oid = record
    id: array[0..19] of Byte;
  end;
  Pgit_oid = ^git_oid;
  // Static-track OID (type prefix + 32 bytes) - bindings owner, 33 bytes padded
  TGitOid33 = record
    &type: Byte;
    id: array[0..31] of Byte;
  end;
  PGitOid33 = ^TGitOid33;
  // Unified alias: bindings' TGitOid maps to 33-byte, ffi's git_oid maps to 20-byte;
  // base exposes both with zero-copy converters.
  TGitOid = TGitOid33;

function GitOid20Equals(const A, B: git_oid): Boolean; inline;
function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
procedure GitOid20Copy(out Dst: git_oid; const Src: git_oid); inline;
procedure GitOidCopy20To33(out Dst: TGitOid33; const Src: git_oid); inline;
procedure GitOidCopy33To20(out Dst: git_oid; const Src: TGitOid33); inline;

implementation

function GitOid20Equals(const A, B: git_oid): Boolean; inline;
begin
  Result := CompareMem(@A.id[0], @B.id[0], GIT_OID_RAWSZ);
end;

function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
begin
  Result := (A.&type = B.&type) and CompareMem(@A.id[0], @B.id[0], GIT_OID_MAX_SIZE);
end;

procedure GitOid20Copy(out Dst: git_oid; const Src: git_oid); inline;
begin
  Move(Src.id[0], Dst.id[0], GIT_OID_RAWSZ);
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

end.
