unit nextpas.core.git.libgit2.bindings.extra;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_filter_options_init(opts: PGitFilterOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_filter_options_init';
function git_filter_list_load(filters: PPGitFilterList; repo: PGitRepository; blob: PGitBlob; path: PAnsiChar; mode: TGitFilterModeT; flags: TUint32T): LongInt; cdecl; external 'c' name 'git_filter_list_load';
function git_filter_list_load_ext(filters: PPGitFilterList; repo: PGitRepository; blob: PGitBlob; path: PAnsiChar; mode: TGitFilterModeT; opts: PGitFilterOptions): LongInt; cdecl; external 'c' name 'git_filter_list_load_ext';
function git_filter_list_contains(filters: PGitFilterList; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_filter_list_contains';
function git_filter_list_apply_to_buffer(var &out: PGitBuf; filters: PGitFilterList; var &in: PAnsiChar; in_len: TSizeT): LongInt; cdecl; external 'c' name 'git_filter_list_apply_to_buffer';
procedure git_filter_list_free(filters: PGitFilterList); cdecl; external 'c' name 'git_filter_list_free';
function git_attr_value(attr: PAnsiChar): TGitAttrValueT; cdecl; external 'c' name 'git_attr_value';
function git_attr_get(value_out: PPAnsiChar; repo: PGitRepository; flags: TUint32T; path: PAnsiChar; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get';
function git_attr_get_many(values_out: PPAnsiChar; repo: PGitRepository; flags: TUint32T; path: PAnsiChar; num_attr: TSizeT; names: PPAnsiChar): LongInt; cdecl; external 'c' name 'git_attr_get_many';
function git_blob_lookup(blob: PPGitBlob; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_blob_lookup';
procedure git_blob_free(blob: PGitBlob); cdecl; external 'c' name 'git_blob_free';
function git_blob_id(blob: PGitBlob): PGitOid; cdecl; external 'c' name 'git_blob_id';
function git_blob_rawcontent(blob: PGitBlob): Pointer; cdecl; external 'c' name 'git_blob_rawcontent';
function git_blob_rawsize(blob: PGitBlob): TGitObjectSizeT; cdecl; external 'c' name 'git_blob_rawsize';
function git_checkout_options_init(opts: PGitCheckoutOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_checkout_options_init';
function git_checkout_head(repo: PGitRepository; opts: Pointer): LongInt; cdecl; external 'c' name 'git_checkout_head';
function git_config_open_default(var &out: PPGitConfig): LongInt; cdecl; external 'c' name 'git_config_open_default';
function git_config_get_string(var out_value: PChar; cfg: PGitConfig; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_get_string';
function git_config_set_string(cfg: PGitConfig; name: PAnsiChar; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_config_set_string';
procedure git_config_free(cfg: PGitConfig); cdecl; external 'c' name 'git_config_free';
function git_remote_list(var out_list: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_remote_list';
function git_remote_lookup(var remote: PGitRemote; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_remote_lookup';
procedure git_remote_free(remote: PGitRemote); cdecl; external 'c' name 'git_remote_free';
function git_revwalk_new(var walk: PGitRevwalk; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_revwalk_new';
function git_revwalk_push_head(walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_push_head';
function git_revwalk_next(var &out: PGitOid; walk: PGitRevwalk): LongInt; cdecl; external 'c' name 'git_revwalk_next';
procedure git_revwalk_free(walk: PGitRevwalk); cdecl; external 'c' name 'git_revwalk_free';
function git_signature_new(var &out: PPGitSignature; name: PAnsiChar; email: PAnsiChar; time: TGitTimeT; offset: LongInt): LongInt; cdecl; external 'c' name 'git_signature_new';
procedure git_signature_free(sig: PGitSignature); cdecl; external 'c' name 'git_signature_free';
function git_status_list_new(var status_list: PGitStatusList; repo: PGitRepository; opts: Pointer): LongInt; cdecl; external 'c' name 'git_status_list_new';
procedure git_status_list_free(status_list: PGitStatusList); cdecl; external 'c' name 'git_status_list_free';
function git_index_add_bypath(index: PGitIndex; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_index_add_bypath';
function git_index_write(index: PGitIndex): LongInt; cdecl; external 'c' name 'git_index_write';
procedure git_index_free(index: PGitIndex); cdecl; external 'c' name 'git_index_free';
function git_clone(var repo: PGitRepository; url: PAnsiChar; local_path: PAnsiChar; options: Pointer): LongInt; cdecl; external 'c' name 'git_clone';
function git_worktree_add(var wt: PGitWorktree; repo: PGitRepository; name: PAnsiChar; path: PAnsiChar; opts: PGitWorktreeAddOptions): LongInt; cdecl; external 'c' name 'git_worktree_add';
function git_worktree_list(var list: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_worktree_list';
procedure git_worktree_free(wt: PGitWorktree); cdecl; external 'c' name 'git_worktree_free';
function git_tag_lookup(var &out: PPGitTag; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_tag_lookup';
procedure git_tag_free(tag: PGitTag); cdecl; external 'c' name 'git_tag_free';
function git_transaction_new(var &out: PPGitTransaction; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_transaction_new';
procedure git_transaction_free(tx: PGitTransaction); cdecl; external 'c' name 'git_transaction_free';

implementation
end.
