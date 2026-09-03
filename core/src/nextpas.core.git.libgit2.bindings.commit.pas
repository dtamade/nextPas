unit nextpas.core.git.libgit2.bindings.commit;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_object_lookup(var &object: PPGitObject; repo: PGitRepository; id: PGitOid; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup';
function git_object_lookup_prefix(object_out: PPGitObject; repo: PGitRepository; id: PGitOid; len: TSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup_prefix';
function git_object_lookup_bypath(var &out: PPGitObject; treeish: PGitObject; path: PAnsiChar; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_lookup_bypath';
function git_object_id(obj: PGitObject): PGitOid; cdecl; external 'c' name 'git_object_id';
function git_object_short_id(var &out: PGitBuf; obj: PGitObject): LongInt; cdecl; external 'c' name 'git_object_short_id';
function git_object_type(obj: PGitObject): TGitObjectT; cdecl; external 'c' name 'git_object_type';
function git_object_owner(obj: PGitObject): PGitRepository; cdecl; external 'c' name 'git_object_owner';
procedure git_object_free(var &object: PGitObject); cdecl; external 'c' name 'git_object_free';
function git_object_type2string(var &type: TGitObjectT): PAnsiChar; cdecl; external 'c' name 'git_object_type2string';
function git_object_string2type(str: PAnsiChar): TGitObjectT; cdecl; external 'c' name 'git_object_string2type';
function git_object_type_is_valid(var &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_type_is_valid';
function git_object_peel(peeled: PPGitObject; var &object: PGitObject; target_type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_object_peel';
function git_object_dup(dest: PPGitObject; source: PGitObject): LongInt; cdecl; external 'c' name 'git_object_dup';
function git_object_id_options_init(opts: PGitObjectIdOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_object_id_options_init';
function git_object_id_from_buffer(oid_out: PGitOid; buf: Pointer; len: TSizeT; opts: PGitObjectIdOptions): LongInt; cdecl; external 'c' name 'git_object_id_from_buffer';
function git_object_id_from_file(oid_out: PGitOid; path: PAnsiChar; opts: PGitObjectIdOptions): LongInt; cdecl; external 'c' name 'git_object_id_from_file';
function git_object_rawcontent_is_valid(valid: PLongInt; buf: PAnsiChar; len: TSizeT; object_type: TGitObjectT; oid_type: TGitOidT): LongInt; cdecl; external 'c' name 'git_object_rawcontent_is_valid';
function git_commit_lookup(commit: PPGitCommit; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_commit_lookup';
function git_commit_lookup_prefix(commit: PPGitCommit; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_commit_lookup_prefix';
procedure git_commit_free(commit: PGitCommit); cdecl; external 'c' name 'git_commit_free';
function git_commit_id(commit: PGitCommit): PGitOid; cdecl; external 'c' name 'git_commit_id';
function git_commit_owner(commit: PGitCommit): PGitRepository; cdecl; external 'c' name 'git_commit_owner';
function git_commit_message_encoding(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message_encoding';
function git_commit_message(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message';
function git_commit_message_raw(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_message_raw';
function git_commit_summary(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_summary';
function git_commit_body(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_body';
function git_commit_time(commit: PGitCommit): TGitTimeT; cdecl; external 'c' name 'git_commit_time';
function git_commit_time_offset(commit: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_time_offset';
function git_commit_committer(commit: PGitCommit): PGitSignature; cdecl; external 'c' name 'git_commit_committer';
function git_commit_author(commit: PGitCommit): PGitSignature; cdecl; external 'c' name 'git_commit_author';
function git_commit_committer_with_mailmap(var &out: PPGitSignature; commit: PGitCommit; mailmap: PGitMailmap): LongInt; cdecl; external 'c' name 'git_commit_committer_with_mailmap';
function git_commit_author_with_mailmap(var &out: PPGitSignature; commit: PGitCommit; mailmap: PGitMailmap): LongInt; cdecl; external 'c' name 'git_commit_author_with_mailmap';
function git_commit_raw_header(commit: PGitCommit): PAnsiChar; cdecl; external 'c' name 'git_commit_raw_header';
function git_commit_tree(tree_out: PPGitTree; commit: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_tree';
function git_commit_tree_id(commit: PGitCommit): PGitOid; cdecl; external 'c' name 'git_commit_tree_id';
function git_commit_parentcount(commit: PGitCommit): LongWord; cdecl; external 'c' name 'git_commit_parentcount';
function git_commit_parent(var &out: PPGitCommit; commit: PGitCommit; n: LongWord): LongInt; cdecl; external 'c' name 'git_commit_parent';
function git_commit_parent_id(commit: PGitCommit; n: LongWord): PGitOid; cdecl; external 'c' name 'git_commit_parent_id';
function git_commit_nth_gen_ancestor(ancestor: PPGitCommit; commit: PGitCommit; n: LongWord): LongInt; cdecl; external 'c' name 'git_commit_nth_gen_ancestor';
function git_commit_header_field(var &out: PGitBuf; commit: PGitCommit; field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_header_field';
function git_commit_extract_signature(signature: PGitBuf; signed_data: PGitBuf; repo: PGitRepository; commit_id: PGitOid; field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_extract_signature';
function git_commitbuilder_add_header(builder: PGitCommitbuilder; field: PAnsiChar; value: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commitbuilder_add_header';
function git_commit_create_options_init(opts: PGitCommitCreateOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_commit_create_options_init';
function git_commit_create_from_stage(id: PGitOid; repo: PGitRepository; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_create_from_stage';
function git_commit_create_ext_options_init(opts: PGitCommitCreateExtOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_commit_create_ext_options_init';
function git_commit_create_ext(id_out: PGitOid; repo: PGitRepository; author: PGitSignature; committer: PGitSignature; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit; opts: PGitCommitCreateExtOptions): LongInt; cdecl; external 'c' name 'git_commit_create_ext';
function git_commit_create(id: PGitOid; repo: PGitRepository; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit): LongInt; cdecl; external 'c' name 'git_commit_create';
function git_commit_create_v(id: PGitOid; repo: PGitRepository; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT): LongInt; cdecl; varargs; external 'c' name 'git_commit_create_v';
function git_commit_create_from_tree(id: PGitOid; repo: PGitRepository; tree: PGitTree; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_create_from_tree';
function git_commit_amend_from_stage(id: PGitOid; repo: PGitRepository; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_amend_from_stage';
function git_commit_amend_from_tree(id: PGitOid; repo: PGitRepository; tree: PGitTree; message: PAnsiChar; opts: PGitCommitCreateOptions): LongInt; cdecl; external 'c' name 'git_commit_amend_from_tree';
function git_commit_amend(id: PGitOid; commit_to_amend: PGitCommit; update_ref: PAnsiChar; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree): LongInt; cdecl; external 'c' name 'git_commit_amend';
function git_commit_create_buffer(var &out: PGitBuf; repo: PGitRepository; author: PGitSignature; committer: PGitSignature; message_encoding: PAnsiChar; message: PAnsiChar; tree: PGitTree; parent_count: TSizeT; parents: PPGitCommit): LongInt; cdecl; external 'c' name 'git_commit_create_buffer';
function git_commit_create_with_signature(var &out: PGitOid; repo: PGitRepository; commit_content: PAnsiChar; signature: PAnsiChar; signature_field: PAnsiChar): LongInt; cdecl; external 'c' name 'git_commit_create_with_signature';
function git_commit_dup(var &out: PPGitCommit; source: PGitCommit): LongInt; cdecl; external 'c' name 'git_commit_dup';
procedure git_commitarray_dispose(var &array: PGitCommitarray); cdecl; external 'c' name 'git_commitarray_dispose';

implementation
end.
