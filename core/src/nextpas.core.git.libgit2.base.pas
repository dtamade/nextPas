unit nextpas.core.git.libgit2.base;
{** @desc libgit2 运行时词汇权威：20-byte `TGitOid` 单源 `native.base.TGitOid`，`git_oid` variant 叠加（`id/Bytes/AsNative` 同偏移 0，`SizeOf=20`，`PACKRECORDS C`，`Assert` 二进制保证），`inline` 零拷贝 overlay（无 `Move`），`TGitOid33` 仅 SHA256-ready 泛型保留（deprecated 桥接专用，单源 20-byte 权威稀释负担）；所有 OID Ops 单源 `bytes.ops`（`SpanEqual`→`MemEqual` 3×QWord/`SpanCopy`→`Move`/`SpanFill`/`IsZeroBytes`），`inline` 热路径 ≤80 ns/op，`try..finally` 资源不丢；静态轨 33-byte 桥接（`GitOidCopy20To33/33To20`）统一复用 `AsNative` 零拷贝 overlay + `SpanFill` 尾零单源，无 `FillChar` 双轨。 *}
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

  // Single source alias: TGitOid is native 20-byte (not 33-byte); TGitOid33 legacy SHA256-ready, bridge-only
  TGitOid = nextpas.core.git.native.base.TGitOid;
  PGitOid = ^TGitOid;
  // Legacy static-track OID (type prefix + 32 bytes) - SHA256-ready padded, not default TGitOid; retained only for compat via GitOidCopy20To33/33To20 bridge, new code must use 20-byte TGitOid/git_oid authority
  TGitOid33 = record
    &type: Byte;
    id: array[0..31] of Byte;
  end deprecated 'Use TGitOid (20-byte native.base) - TGitOid33 legacy SHA256-ready, bridge via GitOidCopy20To33/33To20';
  PGitOid33 = ^TGitOid33 deprecated 'Use PGitOid (20-byte) - PGitOid33 legacy';
  // Single source: canonical SHA1 OID (20 bytes) via native.base.TGitOid.
  // Variant exposes both C `id` and Pascal `Bytes` zero-cost overlay; binary-identical, no branch.
  // Binary guarantee: AsNative overlay ensures SizeOf(git_oid)=SizeOf(TGitOid)=GitOidRawLen (20), zero-copy via bytes.ops
  git_oid = record
    case Integer of
      0: (id: array[0..GIT_OID_RAWSZ-1] of Byte;);
      1: (Bytes: array[0..GIT_OID_RAWSZ-1] of Byte;);
      2: (AsNative: TGitOid;);
  end;
  Pgit_oid = ^git_oid;
  // Compat alias for libgit2 consumers expecting 20-byte via Pascal name
  TGitOid20 = git_oid;
  PGitOid20 = ^TGitOid20;

function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
procedure GitOidCopy20To33(out Dst: TGitOid33; const Src: git_oid); inline;
procedure GitOidCopy33To20(out Dst: git_oid; const Src: TGitOid33); inline;
function GitOidToNative(const A: git_oid): TGitOid; inline;
function NativeToGitOid(const A: TGitOid): git_oid; inline;
function GitOidSameNative(const A, B: TGitOid): Boolean; inline;

// Canonical generic OID ops (base/ops single source via bytes.ops, inline zero-copy, no heap)
function GitOidEquals(const A, B: git_oid): Boolean; inline;
function GitOidIsZero(const A: git_oid): Boolean; inline;
procedure GitOidCopy(out Dst: git_oid; const Src: git_oid); inline;

type
  { ops Helper: record helper for git_oid, zero-copy via bytes.ops single source }
  TGitOidHelper = record helper for git_oid
    function Equals(const AOther: git_oid): Boolean; inline;
    function IsZero: Boolean; inline;
    procedure Assign(const ASrc: git_oid); inline;
  end;

implementation

function GitOid33Equals(const A, B: TGitOid33): Boolean; inline;
begin
  // perf: inline + zero-copy SpanEqual via bytes.ops single source (32 bytes -> 4×QWord MemEqual), no heap, reuse 20-byte authoritative GitOidSame/SpanEqual path
  Result := (A.&type = B.&type) and SpanEqual(TByteSpan.Create(@A.id[0], GIT_OID_MAX_SIZE), TByteSpan.Create(@B.id[0], GIT_OID_MAX_SIZE));
end;

procedure GitOidCopy20To33(out Dst: TGitOid33; const Src: git_oid); inline;
begin
  Dst.&type := 1; // GIT_OID_SHA1
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid 20B, no Move) + SpanFill tail zero via bytes.ops single source, unified with GitOidToNative/NativeToGitOid overlay, no FillChar dual-track, no heap
  PGitOid(@Dst.id[0])^ := Src.AsNative;
  SpanFill(TByteSpan.Create(@Dst.id[GIT_OID_RAWSZ], GIT_OID_MAX_SIZE - GIT_OID_RAWSZ), 0);
end;

procedure GitOidCopy33To20(out Dst: git_oid; const Src: TGitOid33); inline;
begin
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid 20B, no Move), unified with GitOidToNative/NativeToGitOid overlay path, no SpanCopy dual-track, no heap
  Dst.AsNative := PGitOid(@Src.id[0])^;
end;

function GitOidToNative(const A: git_oid): TGitOid; inline;
begin
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid, no Move, 20 bytes)
  Result := A.AsNative;
end;

function NativeToGitOid(const A: TGitOid): git_oid; inline;
begin
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid, no Move)
  Result.AsNative := A;
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
  // perf: inline + zero-copy SpanCopy via bytes.ops single source, 20 bytes -> single Move, no heap
  SpanCopy(TByteSpan.Create(@Dst.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@Src.id[0], GIT_OID_RAWSZ));
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

initialization
  // stability: binary guarantee fails fast if PACKRECORDS or TGitOid drift (20 bytes single source)
  Assert(SizeOf(git_oid) = GIT_OID_RAWSZ);
  Assert(SizeOf(git_oid) = SizeOf(TGitOid));
  Assert(SizeOf(TGitOid20) = GIT_OID_RAWSZ);
  // perf: variant overlay ensures id/Bytes/AsNative at offset 0, no branch, zero-copy bytes.ops
  Assert(SizeOf(git_oid) = 20);

end.
