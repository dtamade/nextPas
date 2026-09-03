unit nextpas.core.git.libgit2.bindings.refs;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_reference_lookup(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_lookup';
function git_reference_name_to_id(var &out: PGitOid; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_name_to_id';
function git_reference_dwim(var &out: PPGitReference; repo: PGitRepository; shorthand: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_dwim';
function git_reference_symbolic_create_matching(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar; target: PAnsiChar; force: LongInt; current_value: PAnsiChar; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_create_matching';
function git_reference_symbolic_create(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar; target: PAnsiChar; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_create';
function git_reference_create(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar; id: PGitOid; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_create';
function git_reference_create_matching(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar; id: PGitOid; force: LongInt; current_id: PGitOid; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_create_matching';
function git_reference_target(ref: PGitReference): PGitOid; cdecl; external 'c' name 'git_reference_target';
function git_reference_target_peel(ref: PGitReference): PGitOid; cdecl; external 'c' name 'git_reference_target_peel';
function git_reference_symbolic_target(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_symbolic_target';
function git_reference_type(ref: PGitReference): TGitReferenceT; cdecl; external 'c' name 'git_reference_type';
function git_reference_name(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_name';
function git_reference_resolve(var &out: PPGitReference; ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_resolve';
function git_reference_owner(ref: PGitReference): PGitRepository; cdecl; external 'c' name 'git_reference_owner';
function git_reference_symbolic_set_target(var &out: PPGitReference; ref: PGitReference; target: PAnsiChar; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_symbolic_set_target';
function git_reference_set_target(var &out: PPGitReference; ref: PGitReference; id: PGitOid; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_set_target';
function git_reference_rename(new_ref: PPGitReference; ref: PGitReference; new_name: PAnsiChar; force: LongInt; log_message: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_rename';
function git_reference_delete(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_delete';
function git_reference_remove(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_remove';
function git_reference_list(var &array: PGitStrarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_reference_list';
function git_reference_foreach(repo: PGitRepository; callback: TGitReferenceForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach';
function git_reference_foreach_name(repo: PGitRepository; callback: TGitReferenceForeachNameCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach_name';
function git_reference_dup(dest: PPGitReference; source: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_dup';
procedure git_reference_free(ref: PGitReference); cdecl; external 'c' name 'git_reference_free';
function git_reference_cmp(ref1: PGitReference; ref2: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_cmp';
function git_reference_iterator_new(var &out: PPGitReferenceIterator; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_reference_iterator_new';
function git_reference_iterator_glob_new(var &out: PPGitReferenceIterator; repo: PGitRepository; glob: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_iterator_glob_new';
function git_reference_next(var &out: PPGitReference; iter: PGitReferenceIterator): LongInt; cdecl; external 'c' name 'git_reference_next';
function git_reference_next_name(var &out: PPAnsiChar; iter: PGitReferenceIterator): LongInt; cdecl; external 'c' name 'git_reference_next_name';
procedure git_reference_iterator_free(iter: PGitReferenceIterator); cdecl; external 'c' name 'git_reference_iterator_free';
function git_reference_foreach_glob(repo: PGitRepository; glob: PAnsiChar; callback: TGitReferenceForeachNameCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_reference_foreach_glob';
function git_reference_has_log(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_has_log';
function git_reference_ensure_log(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_ensure_log';
function git_reference_is_branch(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_branch';
function git_reference_is_remote(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_remote';
function git_reference_is_tag(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_tag';
function git_reference_is_note(ref: PGitReference): LongInt; cdecl; external 'c' name 'git_reference_is_note';
function git_reference_normalize_name(buffer_out: PAnsiChar; buffer_size: TSizeT; name: PAnsiChar; flags: LongWord): LongInt; cdecl; external 'c' name 'git_reference_normalize_name';
function git_reference_peel(var &out: PPGitObject; ref: PGitReference; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_reference_peel';
function git_reference_name_is_valid(valid: PLongInt; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_reference_name_is_valid';
function git_reference_shorthand(ref: PGitReference): PAnsiChar; cdecl; external 'c' name 'git_reference_shorthand';
function git_refdb_new(var &out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_refdb_new';
function git_refdb_open(var &out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_refdb_open';
function git_refdb_compress(refdb: PGitRefdb): LongInt; cdecl; external 'c' name 'git_refdb_compress';
procedure git_refdb_free(refdb: PGitRefdb); cdecl; external 'c' name 'git_refdb_free';

implementation
end.
