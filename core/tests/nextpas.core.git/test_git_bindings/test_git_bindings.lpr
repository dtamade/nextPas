program test_git_bindings;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.git.libgit2.bindings,
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs,
  nextpas.core.git.libgit2.bindings.consts,
  nextpas.core.git.libgit2.bindings.oid,
  nextpas.core.git.libgit2.bindings.commit,
  nextpas.core.git.libgit2.bindings.repo;

{ Golden numbers come from the C probe (abi_probe.c) compiled with the
  host gcc against the same libgit2 headers the bindings were generated
  from (libgit2 1.9.0, linux-x86_64-lp64). If libgit2 is upgraded, rerun
  the probe and refresh these numbers together with the bindings unit. }

function OffsetOfOidId: SizeInt;
var
  R: TGitOid;
begin
  Result := NativeUInt(@R.id) - NativeUInt(@R);
end;

function OffsetOfStrarrayCount: SizeInt;
var
  R: TGitStrarray;
begin
  Result := NativeUInt(@R.count) - NativeUInt(@R);
end;

function OffsetOfSignatureWhen: SizeInt;
var
  R: TGitSignature;
begin
  Result := NativeUInt(@R.when) - NativeUInt(@R);
end;

function OffsetOfErrorKlass: SizeInt;
var
  R: TGitError;
begin
  Result := NativeUInt(@R.klass) - NativeUInt(@R);
end;

function OffsetOfCheckoutPaths: SizeInt;
var
  R: TGitCheckoutOptions;
begin
  Result := NativeUInt(@R.paths) - NativeUInt(@R);
end;

function OffsetOfCloneCheckoutBranch: SizeInt;
var
  R: TGitCloneOptions;
begin
  Result := NativeUInt(@R.checkout_branch) - NativeUInt(@R);
end;

function OffsetOfCallbacksCredentials: SizeInt;
var
  R: TGitRemoteCallbacks;
begin
  Result := NativeUInt(@R.credentials) - NativeUInt(@R);
end;

function OffsetOfFetchDownloadTags: SizeInt;
var
  R: TGitFetchOptions;
begin
  Result := NativeUInt(@R.download_tags) - NativeUInt(@R);
end;

function OffsetOfPushUpdateSrc: SizeInt;
var
  R: TGitPushUpdate;
begin
  Result := NativeUInt(@R.src) - NativeUInt(@R);
end;

function OffsetOfIndexEntryPath: SizeInt;
var
  R: TGitIndexEntry;
begin
  Result := NativeUInt(@R.path) - NativeUInt(@R);
end;

procedure TestCoreStructSizes;
begin
  // git_oid grew a leading type byte in newer libgit2: 1 + 20 payload + pad
  CheckTrue(SizeOf(TGitOid) = 33, 'sizeof(git_oid) = 33');
  CheckTrue(SizeOf(TGitStrarray) = 16, 'sizeof(git_strarray) = 16');
  CheckTrue(SizeOf(TGitSignature) = 32, 'sizeof(git_signature) = 32');
  CheckTrue(SizeOf(TGitTime) = 16, 'sizeof(git_time) = 16');
  CheckTrue(SizeOf(TGitCommitarray) = 16, 'sizeof(git_commitarray) = 16');
  CheckTrue(SizeOf(TGitBuf) = 24, 'sizeof(git_buf) = 24');
  CheckTrue(SizeOf(TGitError) = 16, 'sizeof(git_error) = 16');
  CheckTrue(SizeOf(TGitPushUpdate) = 88, 'sizeof(git_push_update) = 88');
  CheckTrue(SizeOf(TGitStatusEntry) = 24, 'sizeof(git_status_entry) = 24');
  CheckTrue(SizeOf(TGitDiffDelta) = 144, 'sizeof(git_diff_delta) = 144');
  CheckTrue(SizeOf(TGitIndexEntry) = 88, 'sizeof(git_index_entry) = 88');
end;

procedure TestOptionsStructSizes;
begin
  // large nested option structs are where hand-written layouts break
  CheckTrue(SizeOf(TGitCheckoutOptions) = 144,
    'sizeof(git_checkout_options) = 144');
  CheckTrue(SizeOf(TGitCloneOptions) = 416,
    'sizeof(git_clone_options) = 416');
  CheckTrue(SizeOf(TGitRemoteCallbacks) = 128,
    'sizeof(git_remote_callbacks) = 128');
  CheckTrue(SizeOf(TGitFetchOptions) = 216,
    'sizeof(git_fetch_options) = 216');
end;

procedure TestFieldOffsets;
begin
  CheckTrue(OffsetOfOidId = 1, 'offsetof(git_oid.id) = 1');
  CheckTrue(OffsetOfStrarrayCount = 8, 'offsetof(git_strarray.count) = 8');
  CheckTrue(OffsetOfSignatureWhen = 16, 'offsetof(git_signature.when) = 16');
  CheckTrue(OffsetOfErrorKlass = 8, 'offsetof(git_error.klass) = 8');
  CheckTrue(OffsetOfCheckoutPaths = 64,
    'offsetof(git_checkout_options.paths) = 64');
  CheckTrue(OffsetOfCloneCheckoutBranch = 376,
    'offsetof(git_clone_options.checkout_branch) = 376');
  CheckTrue(OffsetOfCallbacksCredentials = 24,
    'offsetof(git_remote_callbacks.credentials) = 24');
  CheckTrue(OffsetOfFetchDownloadTags = 144,
    'offsetof(git_fetch_options.download_tags) = 144');
  CheckTrue(OffsetOfPushUpdateSrc = 16,
    'offsetof(git_push_update.src) = 16');
  CheckTrue(OffsetOfIndexEntryPath = 80,
    'offsetof(git_index_entry.path) = 80');
end;

procedure TestMacroConstantsSurviveTranslation;
begin
  CheckTrue(GIT_ERROR = -1, 'GIT_ERROR macro constant = -1');
  CheckTrue(GIT_CHECKOUT_OPTIONS_VERSION = 1,
    'GIT_CHECKOUT_OPTIONS_VERSION = 1');
  CheckTrue(GIT_CLONE_OPTIONS_VERSION = 1, 'GIT_CLONE_OPTIONS_VERSION = 1');
end;

{ Referencing the externals forces the linker to see them; the test binary
  links -lgit2 through its Makefile so existence is proven at build time.
  Here we only assert the declarations resolved to non-nil addresses via
  assigned variables — enough to prove name spelling matches the library. }
procedure TestApiSymbolsResolvable;
begin
  CheckTrue(@git_repository_init <> nil, 'git_repository_init declared');
  CheckTrue(@git_repository_init_ext <> nil,
    'git_repository_init_ext declared');
  CheckTrue(@git_annotated_commit_lookup <> nil,
    'git_annotated_commit_lookup declared');
  CheckTrue(@git_libgit2_version <> nil, 'git_libgit2_version declared');
  CheckTrue(@git_commitarray_dispose <> nil,
    'git_commitarray_dispose declared');
end;

var
  Maj, Min, Rev: LongInt;
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.git.libgit2.bindings');
  T.Test('core struct sizes match the C probe', @TestCoreStructSizes);
  T.Test('options struct sizes match the C probe', @TestOptionsStructSizes);
  T.Test('field offsets match the C probe', @TestFieldOffsets);
  T.Test('macro constants survive translation',
    @TestMacroConstantsSurviveTranslation);
  T.Test('api symbols resolvable', @TestApiSymbolsResolvable);
  if not T.Run then Halt(1);

  // live cross-check when the shared library is present at runtime:
  // ask the library itself for its version and print it for the report
  git_libgit2_version(@Maj, @Min, @Rev);
  WriteLn('[info] runtime libgit2: ', Maj, '.', Min, '.', Rev);
end.
